import Foundation
import Observation

/// The running timer.
public struct Running: Equatable, Sendable {
    public let project: String
    public let start: Date
}

/// One Project's line in the Panel for a Day.
public struct Row: Equatable, Sendable {
    public let project: String
    public let total: TimeInterval

    public init(project: String, total: TimeInterval) {
        self.project = project
        self.total = total
    }
}

/// One Day's grand total, as shown in the Week strip.
public struct DayTotal: Equatable, Sendable {
    public let day: Day
    public let total: TimeInterval

    public init(day: Day, total: TimeInterval) {
        self.day = day
        self.total = total
    }
}

/// Core's single entry point: the timer, totals and the Day files behind them.
@MainActor @Observable
public final class Tracker {
    public private(set) var running: Running?
    /// The Project ▶ starts: the one most recently started. Kept in `defaults` across launches.
    public private(set) var selectedProject: String? {
        didSet { defaults?.set(selectedProject, forKey: Self.selectedProjectKey) }
    }
    /// The clock's time at the last command or `tick()`. Totals of a running timer count up to here.
    public private(set) var now: Date

    @ObservationIgnored private let clock: TimeSource
    @ObservationIgnored private let store: DayStore
    @ObservationIgnored private let defaults: UserDefaults?
    private var todayEntries: [Entry] = []
    /// Other Days' Entries, read on first use and dropped on `reload()` so hand edits show up.
    @ObservationIgnored private var otherDays: [Day: [Entry]] = [:]

    private static let selectedProjectKey = "selectedProject"

    /// Reads today's file. An open Entry there is the running timer, so a timer survives a relaunch.
    /// With no `defaults`, the Selected Project is kept in memory only.
    public init(clock: TimeSource, storageRoot: URL, defaults: UserDefaults? = nil) {
        self.clock = clock
        self.store = DayStore(root: storageRoot)
        self.defaults = defaults
        self.now = clock.now
        self.selectedProject = defaults?.string(forKey: Self.selectedProjectKey)
        reload()
    }

    /// Re-reads today's file, and other Days' files when next asked for. A file that won't parse reads
    /// as empty; writes to it are refused.
    public func reload() {
        now = clock.now
        otherDays = [:]
        todayEntries = (try? store.load(today)) ?? []
        running = todayEntries.lazy.compactMap { entry -> Running? in
            if case .timed(let project, let start, nil) = entry { return Running(project: project, start: start) }
            return nil
        }.first
        if let running { selectedProject = running.project }
    }

    public var today: Day { Day(containing: now, in: clock.calendar) }

    /// Starts a timer for `project`, pausing any running one first.
    public func start(_ project: String) throws {
        try pause()
        try updateToday { $0.append(.timed(project: project, start: now, end: nil)) }
        running = Running(project: project, start: now)
        selectedProject = project
    }

    public func pause() throws {
        now = clock.now
        guard running != nil else { return }
        try updateToday { entries in
            entries = entries.map { entry in
                if case .timed(let project, let start, nil) = entry {
                    return .timed(project: project, start: start, end: now)
                }
                return entry
            }
        }
        running = nil
    }

    /// Pauses the running timer, or starts the Selected Project. Does nothing with no Selected Project;
    /// the UI opens the ＋ form instead.
    public func toggle() throws {
        if running != nil {
            try pause()
        } else if let selectedProject {
            try start(selectedProject)
        }
    }

    /// Called every second by the UI so running totals advance.
    public func tick() {
        now = clock.now
    }

    /// The Project's total on `day`, never below zero.
    public func total(_ project: String, on day: Day) -> TimeInterval {
        let raw = entries(on: day)
            .filter { $0.project == project }
            .reduce(0) { $0 + $1.seconds(asOf: now) }
        return max(0, raw)
    }

    /// One Row per Project with Entries on `day`, in the order each first appears in the Day file.
    public func rows(_ day: Day) -> [Row] {
        var projects: [String] = []
        for entry in entries(on: day) where !projects.contains(entry.project) {
            projects.append(entry.project)
        }
        return projects.map { Row(project: $0, total: total($0, on: day)) }
    }

    /// The Day's grand total: the sum of its Rows, each already clamped at zero.
    public func dayTotal(_ day: Day) -> TimeInterval {
        rows(day).reduce(0) { $0 + $1.total }
    }

    /// The seven Days of `day`'s week, starting on the calendar's first weekday, with their totals.
    public func weekTotals(containing day: Day) -> [DayTotal] {
        let first = day.startOfWeek(in: calendar)
        return (0..<7).map { offset in
            let day = first.adding(days: offset, in: calendar)
            return DayTotal(day: day, total: dayTotal(day))
        }
    }

    /// The calendar Days and weeks are counted in.
    public var calendar: Calendar { clock.calendar }

    /// The Day's Entries: today's from memory, any other Day's from its file (empty if missing or malformed).
    private func entries(on day: Day) -> [Entry] {
        if day == today { return todayEntries }
        if let cached = otherDays[day] { return cached }
        let loaded = (try? store.load(day)) ?? []
        otherDays[day] = loaded
        return loaded
    }

    /// Re-reads today's file, applies `change` and writes it back.
    private func updateToday(_ change: (inout [Entry]) -> Void) throws {
        let day = today
        var entries = try store.load(day)
        change(&entries)
        try store.save(day, entries, timeZone: clock.calendar.timeZone)
        otherDays[day] = nil
        todayEntries = entries
    }
}

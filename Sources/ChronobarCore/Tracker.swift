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
    /// Days whose file failed to parse when last read. Writes to them are refused until it parses again.
    public private(set) var malformedDays: Set<Day> = []

    @ObservationIgnored private let clock: TimeSource
    @ObservationIgnored private let store: DayStore
    @ObservationIgnored private let defaults: UserDefaults?
    private var todayEntries: [Entry] = []

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

    /// Re-reads today's file. A file that won't parse is flagged in `malformedDays` and the last good
    /// read is kept, so a running timer keeps running.
    public func reload() {
        now = clock.now
        guard let entries = try? read(today) else { return }
        todayEntries = entries
        running = todayEntries.lazy.compactMap { entry -> Running? in
            if case .timed(let project, let start, nil) = entry { return Running(project: project, start: start) }
            return nil
        }.first
        if let running { selectedProject = running.project }
    }

    public var today: Day { Day(containing: now, in: clock.calendar) }

    /// Whether `day`'s file failed to parse when last read. The Panel warns about it.
    public func isMalformed(_ day: Day) -> Bool { malformedDays.contains(day) }

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
        let raw = todayEntries
            .filter { $0.project == project }
            .reduce(0) { $0 + $1.seconds(asOf: now) }
        return max(0, raw)
    }

    /// One Row per Project with Entries on `day`, in the order each first appears in the Day file.
    public func rows(_ day: Day) -> [Row] {
        var projects: [String] = []
        for entry in todayEntries where !projects.contains(entry.project) {
            projects.append(entry.project)
        }
        return projects.map { Row(project: $0, total: total($0, on: day)) }
    }

    /// The Day's grand total: the sum of its Rows, each already clamped at zero.
    public func dayTotal(_ day: Day) -> TimeInterval {
        rows(day).reduce(0) { $0 + $1.total }
    }

    /// Re-reads today's file, applies `change` and writes it back.
    private func updateToday(_ change: (inout [Entry]) -> Void) throws {
        let day = today
        var entries = try read(day)
        change(&entries)
        try store.save(day, entries, timeZone: clock.calendar.timeZone)
        todayEntries = entries
    }

    /// Loads `day`'s file, recording in `malformedDays` whether it parsed.
    private func read(_ day: Day) throws -> [Entry] {
        do {
            let entries = try store.load(day)
            malformedDays.remove(day)
            return entries
        } catch {
            malformedDays.insert(day)
            throw error
        }
    }
}

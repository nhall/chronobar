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

/// The (i) Time Summary: grand totals for today, yesterday, this week and this month.
public struct Summary: Equatable, Sendable {
    public let today: TimeInterval
    public let yesterday: TimeInterval
    public let week: TimeInterval
    public let month: TimeInterval

    public init(today: TimeInterval, yesterday: TimeInterval, week: TimeInterval, month: TimeInterval) {
        self.today = today
        self.yesterday = yesterday
        self.week = week
        self.month = month
    }
}

/// The idle alert's answers.
public enum IdleChoice: Sendable {
    /// Drop the Idle time and keep the timer running from now.
    case remove
    /// Drop the Idle time and leave the timer stopped.
    case removeAndStop
    /// Count the Idle time.
    case keep
}

/// Core's single entry point: the timer, totals and the Day files behind them.
@MainActor @Observable
public final class Tracker {
    public private(set) var running: Running?
    /// The Project ▶ starts: the one most recently started. Kept in `defaults` across launches.
    public private(set) var selectedProject: String? {
        didSet { defaults?.set(selectedProject, forKey: Self.selectedProjectKey) }
    }
    /// The active Projects, in `projects.txt` order.
    public private(set) var projects: [String] = []
    /// The clock's time at the last command or `tick()`. Totals of a running timer count up to here.
    public private(set) var now: Date

    @ObservationIgnored private let clock: TimeSource
    @ObservationIgnored private let store: DayStore
    @ObservationIgnored private let projectStore: ProjectStore
    @ObservationIgnored private let defaults: UserDefaults?
    private var todayEntries: [Entry] = []
    /// The Day `todayEntries` came from. It lags `today` from midnight until the next `tick()` or command.
    @ObservationIgnored private var loadedDay: Day
    /// Other Days' Entries, read on first use and dropped on `reload()` so hand edits show up.
    @ObservationIgnored private var otherDays: [Day: [Entry]] = [:]

    private static let selectedProjectKey = "selectedProject"

    /// Reads today's file. An open Entry there is the running timer, so a timer survives a relaunch.
    /// With no `defaults`, the Selected Project is kept in memory only.
    public init(clock: TimeSource, storageRoot: URL, defaults: UserDefaults? = nil) {
        self.clock = clock
        self.store = DayStore(root: storageRoot)
        self.projectStore = ProjectStore(root: storageRoot)
        self.defaults = defaults
        self.now = clock.now
        self.selectedProject = defaults?.string(forKey: Self.selectedProjectKey)
        self.loadedDay = Day(containing: clock.now, in: clock.calendar)
        reload()
    }

    /// Re-reads today's file and the Project list, and other Days' files when next asked for. A file that
    /// won't parse reads as empty; writes to it are refused.
    public func reload() {
        now = clock.now
        projects = (try? projectStore.load()) ?? []
        otherDays = [:]
        loadedDay = today
        todayEntries = (try? store.load(today)) ?? []
        running = todayEntries.lazy.compactMap { entry -> Running? in
            if case .timed(let project, let start, nil) = entry { return Running(project: project, start: start) }
            return nil
        }.first
        // A running Project that was archived keeps running but isn't selected again.
        if let running, projects.contains(where: { ProjectName.matches($0, running.project) }) {
            selectedProject = running.project
        }
    }

    public var today: Day { Day(containing: now, in: clock.calendar) }

    /// Starts a timer for `project`, pausing any running one first. A new name creates a Project.
    public func start(_ name: String) throws {
        let project = try addProject(name)
        try pause()
        try updateToday { $0.append(.timed(project: project, start: now, end: nil)) }
        running = Running(project: project, start: now)
        selectedProject = project
    }

    public func pause() throws {
        now = clock.now
        rollOver()
        guard running != nil else { return }
        try updateToday { Self.close(&$0, at: now) }
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

    /// Called every second by the UI so running totals advance, and on wake. Rolls over to a new Day.
    public func tick() {
        now = clock.now
        rollOver()
    }

    /// Answers the idle alert. `remove` and `removeAndStop` drop the time since `idleStart` from every Day
    /// it covers: a timed Entry straddling it ends there, later timed Entries are deleted and manual Entries
    /// stay. `remove` then restarts the running Project from now. If any of those Day files won't parse,
    /// nothing is changed.
    public func resolveIdle(since idleStart: Date, choice: IdleChoice) throws {
        now = clock.now
        rollOver()
        guard choice != .keep else { return }
        let idleStart = min(idleStart, now)
        let project = running?.project
        let firstDay = Day(containing: idleStart, in: clock.calendar)
        let days = Set(store.days().filter { $0 >= firstDay } + [today]).sorted()
        // Read every Day before writing any, so a malformed one refuses the whole removal.
        let loaded = try days.map { ($0, try store.load($0)) }
        for (day, entries) in loaded {
            let kept = Self.removing(entries, after: idleStart, asOf: now)
            if kept != entries { try store.save(day, kept, timeZone: clock.calendar.timeZone) }
        }
        reload()
        if choice == .remove, let project {
            try updateToday { $0.append(.timed(project: project, start: now, end: nil)) }
            running = Running(project: project, start: now)
        }
    }

    /// `entries` without their timed time after `cut`; an open Entry counts up to `now`.
    private static func removing(_ entries: [Entry], after cut: Date, asOf now: Date) -> [Entry] {
        entries.compactMap { entry in
            guard case .timed(let project, let start, let end) = entry else { return entry }
            if start >= cut { return nil }
            if (end ?? now) > cut { return .timed(project: project, start: start, end: cut) }
            return entry
        }
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

    /// Today, yesterday, today's week (as in the Week strip) and today's calendar month, each the sum
    /// of its Days' totals.
    public func summary() -> Summary {
        let today = today
        let daysInMonth = calendar.range(of: .day, in: .month, for: today.noon(in: calendar))!
        let month = daysInMonth.reduce(0) { sum, day in
            sum + dayTotal(Day(year: today.year, month: today.month, day: day))
        }
        return Summary(
            today: dayTotal(today),
            yesterday: dayTotal(today.adding(days: -1, in: calendar)),
            week: weekTotals(containing: today).reduce(0) { $0 + $1.total },
            month: month)
    }

    /// The calendar Days and weeks are counted in.
    public var calendar: Calendar { clock.calendar }

    /// The Day's Entries: the loaded Day's from memory, any other Day's from its file (empty if missing
    /// or malformed).
    private func entries(on day: Day) -> [Entry] {
        if day == loadedDay { return todayEntries }
        if let cached = otherDays[day] { return cached }
        let loaded = (try? store.load(day)) ?? []
        otherDays[day] = loaded
        return loaded
    }

    /// Adds `name` to the Project list and returns the Project's name. A name matching an active Project
    /// returns its stored spelling and changes nothing; one matching an archived Project revives it with
    /// the spelling its most recent Entries used.
    @discardableResult
    public func addProject(_ name: String) throws -> String {
        let name = ProjectName.trimmed(name)
        guard !name.isEmpty else { throw EmptyProjectName() }
        var list = try projectStore.load()
        if let existing = list.first(where: { ProjectName.matches($0, name) }) {
            projects = list
            return existing
        }
        let project = historicalName(matching: name) ?? name
        list.append(project)
        try projectStore.save(list)
        projects = list
        return project
    }

    /// Active Projects containing `text`, ignoring case and surrounding spaces. Names starting with it
    /// come first; otherwise the Project list's order is kept.
    public func suggestions(for text: String) -> [String] {
        let text = ProjectName.trimmed(text)
        guard !text.isEmpty else { return projects }
        let matching = projects.filter { $0.range(of: text, options: .caseInsensitive) != nil }
        let prefixed = matching.filter { $0.range(of: text, options: [.caseInsensitive, .anchored]) != nil }
        return prefixed + matching.filter { !prefixed.contains($0) }
    }

    /// The name a past Entry used for this Project, newest Day first. Malformed Days are skipped.
    private func historicalName(matching name: String) -> String? {
        for day in store.days() {
            let entries = (try? store.load(day)) ?? []
            if let entry = entries.last(where: { ProjectName.matches($0.project, name) }) { return entry.project }
        }
        return nil
    }

    /// Removes the Project matching `name` from the Project list. Its Entries stay in the Day files.
    public func archiveProject(_ name: String) throws {
        var list = try projectStore.load()
        list.removeAll { ProjectName.matches($0, name) }
        try projectStore.save(list)
        projects = list
        if let selectedProject, ProjectName.matches(selectedProject, name) { self.selectedProject = nil }
    }

    /// After midnight, splits a running timer at the start of each new Day so every Day's file holds only
    /// that Day's time, then loads today. A file that won't parse keeps its open Entry (#9 retries).
    private func rollOver() {
        guard loadedDay != today else { return }
        while let running, loadedDay < today {
            let midnight = clock.calendar.dateInterval(of: .day, for: running.start)!.end
            let next = Day(containing: midnight, in: clock.calendar)
            try? update(loadedDay) { Self.close(&$0, at: midnight) }
            try? update(next) { $0.append(.timed(project: running.project, start: midnight, end: nil)) }
            loadedDay = next
            self.running = Running(project: running.project, start: midnight)
        }
        reload()
    }

    /// Ends every open Entry at `end`.
    private static func close(_ entries: inout [Entry], at end: Date) {
        entries = entries.map { entry in
            if case .timed(let project, let start, nil) = entry {
                return .timed(project: project, start: start, end: end)
            }
            return entry
        }
    }

    private func updateToday(_ change: (inout [Entry]) -> Void) throws {
        try update(today, change)
    }

    /// Re-reads `day`'s file, applies `change` and writes it back.
    private func update(_ day: Day, _ change: (inout [Entry]) -> Void) throws {
        var entries = try store.load(day)
        change(&entries)
        try store.save(day, entries, timeZone: clock.calendar.timeZone)
        otherDays[day] = nil
        todayEntries = entries
    }
}

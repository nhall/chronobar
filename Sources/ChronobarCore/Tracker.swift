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
    /// Days whose file failed to parse when last read. Writes to them are refused until it parses again.
    public private(set) var malformedDays: Set<Day> = []

    @ObservationIgnored private let clock: TimeSource
    @ObservationIgnored private let store: DayStore
    @ObservationIgnored private let projectStore: ProjectStore
    @ObservationIgnored private let defaults: UserDefaults?
    private var todayEntries: [Entry] = []
    /// The Day `todayEntries` came from. It lags `today` from midnight until the next `tick()` or command.
    @ObservationIgnored private var loadedDay: Day
    /// Other Days' Entries, read on first use and dropped on `reload()` so hand edits show up.
    @ObservationIgnored private var otherDays: [Day: [Entry]] = [:]
    /// Writes deferred because their Day's file was malformed, oldest first. Retried on `tick()`,
    /// `reload()` and before every write; lost on quit, which leaves the open Entry for crash recovery.
    @ObservationIgnored private var pending: [(day: Day, change: (inout [Entry]) -> Void)] = []

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

    /// Retries deferred writes, then re-reads today's file and the Project list, and other Days' files
    /// when next asked for. A Day file that won't parse is flagged in `malformedDays` and its last good
    /// read is kept (for a Day not read before, just its deferred writes), so a running timer keeps running.
    public func reload() {
        now = clock.now
        projects = (try? projectStore.load()) ?? []
        otherDays = [:]
        retryPending()
        if let entries = try? read(today) {
            todayEntries = entries
        } else if loadedDay != today {
            todayEntries = []
            for (day, change) in pending where day == today { change(&todayEntries) }
        }
        loadedDay = today
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

    /// Whether `day`'s file failed to parse when last read. The Panel warns about it.
    public func isMalformed(_ day: Day) -> Bool { malformedDays.contains(day) }

    /// Starts a timer for `project`, pausing any running one first. A new name creates a Project.
    /// Refused, leaving any running timer alone, while today's file is malformed.
    public func start(_ name: String) throws {
        now = clock.now
        retryPending()
        _ = try read(today)
        let project = try addProject(name)
        try pause()
        let start = now
        try updateToday { $0.append(.timed(project: project, start: start, end: nil)) }
        running = Running(project: project, start: start)
        selectedProject = project
    }

    /// Closes the running Entry. If today's file is malformed the timer still stops, and closing the
    /// Entry waits until the file parses again.
    public func pause() throws {
        now = clock.now
        rollOver()
        guard running != nil else { return }
        let end = now
        try updateToday(deferringIfMalformed: true) { Self.close(&$0, at: end) }
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

    /// Called every second by the UI so running totals advance, and on wake. Rolls over to a new Day and
    /// retries deferred writes.
    public func tick() {
        now = clock.now
        rollOver()
        retryPending()
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
        // Read every Day before writing any, so a malformed one (or one with deferred writes still queued)
        // refuses the whole removal.
        retryPending()
        let loaded = try days.map { day in
            guard !pending.contains(where: { $0.day == day }) else { throw DayFile.Malformed() }
            return (day, try read(day))
        }
        for (day, entries) in loaded {
            let kept = Self.removing(entries, after: idleStart, asOf: now)
            if kept != entries { try store.save(day, kept, timeZone: clock.calendar.timeZone) }
        }
        reload()
        if choice == .remove, let project {
            let start = now
            try updateToday { $0.append(.timed(project: project, start: start, end: nil)) }
            running = Running(project: project, start: start)
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

    /// The Day's Entries: the loaded Day's from memory, any other Day's from its file, read once until the
    /// next `reload()`. A missing file is empty; a malformed one is flagged in `malformedDays` and reads as
    /// just its deferred writes.
    private func entries(on day: Day) -> [Entry] {
        if day == loadedDay { return todayEntries }
        if let cached = otherDays[day] { return cached }
        var loaded: [Entry]
        if let entries = try? read(day) {
            loaded = entries
        } else {
            loaded = []
            for (pendingDay, change) in pending where pendingDay == day { change(&loaded) }
        }
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

    /// Adds a typed duration (`1:30`, `45`) to the Project on `day` as a manual Entry, without starting a
    /// timer. A new name creates a Project. Throws `InvalidDuration` for anything but a positive total.
    public func log(_ name: String, _ duration: String, on day: Day) throws {
        guard case .absolute(let seconds) = try DurationInput(parsing: duration), seconds > 0 else {
            throw InvalidDuration(text: duration)
        }
        now = clock.now
        rollOver()
        let project = try addProject(name)
        try update(day) { $0.append(.manual(project: project, seconds: seconds, note: .manual)) }
    }

    /// Sets the Project's total on `day` to a typed total (`1:15`) or changes it (`+15`, `-10`), starting
    /// from the total shown and never going below zero. Writes one adjustment Entry of the new total minus
    /// the stored sum; a running timer keeps running. Throws `InvalidDuration` for a typo.
    public func adjust(_ project: String, _ input: String, on day: Day) throws {
        let input = try DurationInput(parsing: input)
        now = clock.now
        rollOver()
        let target: TimeInterval = switch input {
        case .absolute(let seconds): TimeInterval(seconds)
        case .relative(let seconds): max(0, total(project, on: day) + TimeInterval(seconds))
        }
        let now = now
        func difference(_ entries: [Entry]) -> Int {
            let raw = entries.filter { $0.project == project }.reduce(0) { $0 + $1.seconds(asOf: now) }
            return Int((target - raw).rounded())
        }
        guard difference(entries(on: day)) != 0 else { return }
        // The difference is taken again from the Entries as re-read, so a hand edit can't skew it.
        try update(day) { entries in
            let seconds = difference(entries)
            if seconds != 0 { entries.append(.manual(project: project, seconds: seconds, note: .adjustment)) }
        }
    }

    /// After midnight, splits a running timer at the start of each new Day so every Day's file holds only
    /// that Day's time, then loads today. Writes to a file that won't parse wait until it does.
    private func rollOver() {
        guard loadedDay != today else { return }
        while let running, loadedDay < today {
            let midnight = clock.calendar.dateInterval(of: .day, for: running.start)!.end
            let next = Day(containing: midnight, in: clock.calendar)
            let project = running.project
            try? update(loadedDay, deferringIfMalformed: true) { Self.close(&$0, at: midnight) }
            try? update(next, deferringIfMalformed: true) {
                $0.append(.timed(project: project, start: midnight, end: nil))
            }
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

    private func updateToday(
        deferringIfMalformed: Bool = false, _ change: @escaping (inout [Entry]) -> Void
    ) throws {
        try update(today, deferringIfMalformed: deferringIfMalformed, change)
    }

    /// Re-reads `day`'s file, applies `change` and writes it back, after any earlier deferred writes to
    /// it. If the file is malformed the write is refused, or with `deferringIfMalformed` applied to the
    /// cached Entries only and queued until the file parses.
    private func update(
        _ day: Day, deferringIfMalformed: Bool = false, _ change: @escaping (inout [Entry]) -> Void
    ) throws {
        retryPending()
        do {
            guard !pending.contains(where: { $0.day == day }) else { throw DayFile.Malformed() }
            try write(day, change)
        } catch is DayFile.Malformed where deferringIfMalformed {
            if day == loadedDay { change(&todayEntries) }
            pending.append((day, change))
        }
    }

    /// Applies deferred writes in order. A Day whose file still won't parse keeps its writes queued.
    private func retryPending() {
        var blocked: Set<Day> = []
        pending = pending.filter { day, change in
            guard !blocked.contains(day), (try? write(day, change)) != nil else {
                blocked.insert(day)
                return true
            }
            return false
        }
    }

    /// Re-reads `day`'s file, applies `change` and writes it back.
    private func write(_ day: Day, _ change: (inout [Entry]) -> Void) throws {
        var entries = try read(day)
        change(&entries)
        try store.save(day, entries, timeZone: clock.calendar.timeZone)
        if day == loadedDay { todayEntries = entries } else { otherDays[day] = entries }
    }

    /// Loads `day`'s file, recording in `malformedDays` whether it parsed.
    private func read(_ day: Day) throws -> [Entry] {
        do {
            let entries = try store.load(day)
            // Only touch the observable set on a change: views read past Days while rendering.
            if malformedDays.contains(day) { malformedDays.remove(day) }
            return entries
        } catch {
            if !malformedDays.contains(day) { malformedDays.insert(day) }
            throw error
        }
    }
}

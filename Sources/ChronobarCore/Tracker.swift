import Foundation
import Observation

/// The running timer.
public struct Running: Equatable, Sendable {
    public let project: String
    public let start: Date
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
    /// Idle time to ask about with the idle alert; cleared by `resolveIdle`.
    public private(set) var pendingIdle: PendingIdle?

    @ObservationIgnored private let clock: TimeSource
    /// When this Tracker was made, and the Heartbeat the last run left: an Entry still open from before
    /// then was left by a crash.
    @ObservationIgnored private let launched: Date
    @ObservationIgnored private let lastAlive: Date?
    /// Days that were malformed and have since parsed, to check for Entries left open.
    @ObservationIgnored private var reparsed: Set<Day> = []
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
    private static let heartbeatKey = "heartbeat"

    /// Reads today's file. An open Entry there is the running timer, so a timer survives a relaunch.
    /// With no `defaults`, the Selected Project is kept in memory only.
    public init(clock: TimeSource, storageRoot: URL, defaults: UserDefaults? = nil) {
        self.clock = clock
        self.store = DayStore(root: storageRoot)
        self.projectStore = ProjectStore(root: storageRoot)
        self.defaults = defaults
        self.now = clock.now
        self.launched = clock.now
        self.lastAlive = defaults?.object(forKey: Self.heartbeatKey) as? Date
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
        let known = running
        if let entries = try? read(today) {
            todayEntries = entries
        } else if loadedDay != today {
            todayEntries = []
            for (day, change) in pending where day == today { change(&todayEntries) }
        }
        loadedDay = today
        let open = todayEntries.compactMap(\.openTimer)
        // An open Entry in a file that just parsed again is left for `recoverReparsedDays` to recover.
        running = open.first { $0 == known } ?? (reparsed.contains(today) ? nil : open.first)
        // A running Project that was archived keeps running but isn't selected again.
        if let running, projects.contains(where: { ProjectName.matches($0, running.project) }) {
            selectedProject = storedName(running.project)
        }
        recoverReparsedDays()
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
    /// retries deferred writes, then recovers any Entry left open in a Day file that parsed again.
    public func tick() {
        now = clock.now
        rollOver()
        retryPending()
        recoverReparsedDays()
        unblockPendingIdle()
    }

    /// Clears `pendingIdle.blockedBy` once that Day's file parses and its deferred writes have landed.
    private func unblockPendingIdle() {
        guard let idle = pendingIdle, let day = idle.blockedBy,
              !pending.contains(where: { $0.day == day }), (try? read(day)) != nil else { return }
        pendingIdle = PendingIdle(since: idle.since, until: idle.until)
    }

    /// Records the clock's time as the last moment Chronobar was alive, while a timer runs. The UI calls
    /// it every minute and on sleep; `recoverAfterLaunch()` reads it after a crash.
    public func heartbeat() {
        guard running != nil else { return }
        defaults?.set(clock.now, forKey: Self.heartbeatKey)
    }

    /// Called once at launch. Quitting closes the running Entry, so an Entry still open means Chronobar
    /// crashed or the Mac was forced off. Returns when it was last known alive (the later of the Entry's
    /// start and the last Heartbeat) so the UI can ask about the time since with the idle alert; nil if
    /// nothing was left open. An Entry open on a past Day becomes the running timer and is split across
    /// the Days since, as after waking from sleep, so the idle removal can cut it. The same goes for an
    /// Entry found open later in a Day file that was malformed at launch, once it parses.
    @discardableResult
    public func recoverAfterLaunch() -> Date? {
        now = clock.now
        if let running {
            recover(running, on: loadedDay)
        } else if let (day, entries) = lastTimedDay(), let open = entries.lazy.compactMap(\.openTimer).first {
            recover(open, on: day)
        }
        return pendingIdle?.since
    }

    /// Recovers open Entries in Day files that were malformed and now parse. Core's own running Entry is
    /// left alone; any other one was left by a crash.
    private func recoverReparsedDays() {
        let days = reparsed
        reparsed = []
        for day in days.sorted() where !pending.contains(where: { $0.day == day }) {
            for timer in entries(on: day).compactMap(\.openTimer) where !(day == loadedDay && timer == running) {
                recover(timer, on: day)
            }
        }
    }

    /// Makes an Entry left open by a crash the running timer, split across the Days since, with the time
    /// since it was last alive pending as Idle time. If another timer runs already, the Entry is closed
    /// when Chronobar launched (or at the end of its Day) and only the time before that is pending.
    private func recover(_ timer: Running, on day: Day) {
        let lastAlive = max(timer.start, lastAlive ?? timer.start)
        if running == nil || running == timer {
            if day != loadedDay {
                todayEntries = entries(on: day)
                loadedDay = day
            }
            running = timer
            noteIdle(PendingIdle(since: lastAlive))
            rollOver()
        } else {
            let end = max(timer.start, min(launched, calendar.dateInterval(of: .day, for: timer.start)!.end))
            try? update(day, deferringIfMalformed: true) { entries in
                entries = entries.map { $0.openTimer == timer ? .timed(project: timer.project, start: timer.start, end: end) : $0 }
            }
            noteIdle(PendingIdle(since: min(lastAlive, end), until: end))
        }
    }

    /// Adds `idle` to `pendingIdle`, which then covers both.
    private func noteIdle(_ idle: PendingIdle) {
        guard let pendingIdle else { return self.pendingIdle = idle }
        let until = pendingIdle.until.flatMap { a in idle.until.map { max(a, $0) } }
        self.pendingIdle = PendingIdle(since: min(pendingIdle.since, idle.since), until: until)
    }

    /// The newest past Day whose file has a timed Entry, with its Entries. Malformed Days are skipped.
    private func lastTimedDay() -> (Day, [Entry])? {
        for day in store.days() where day < today {
            guard let entries = try? read(day) else { continue }
            if entries.contains(where: { if case .timed = $0 { true } else { false } }) { return (day, entries) }
        }
        return nil
    }

    /// Answers the idle alert. `remove` and `removeAndStop` drop the time from `idleStart` to `idleEnd`
    /// (nil: now) from every Day it covers: a timed Entry straddling either end is cut there, timed Entries
    /// inside are deleted and manual Entries stay. `remove` then restarts the running Project from now if
    /// the cut stopped it; `removeAndStop` leaves it stopped. If any of those Day files won't parse,
    /// nothing is changed.
    public func resolveIdle(since idleStart: Date, until idleEnd: Date? = nil, choice: IdleChoice) throws {
        now = clock.now
        rollOver()
        guard choice != .keep else { return pendingIdle = nil }
        let idleEnd = idleEnd.map { min($0, now) }
        let idleStart = min(idleStart, idleEnd ?? now)
        let project = running?.project
        let firstDay = Day(containing: idleStart, in: clock.calendar)
        let lastDay = idleEnd.map { Day(containing: $0, in: clock.calendar) } ?? today
        let days = Set(store.days().filter { $0 >= firstDay && $0 <= lastDay } + [today]).sorted()
        // Read every Day before writing any, so a malformed one (or one with deferred writes still queued)
        // refuses the whole removal.
        retryPending()
        let loaded: [(Day, [Entry])]
        do {
            loaded = try days.map { day in
                guard !pending.contains(where: { $0.day == day }) else { throw MalformedDayFile(day: day) }
                do { return (day, try read(day)) } catch is DayFile.Malformed { throw MalformedDayFile(day: day) }
            }
        } catch let error as MalformedDayFile {
            let since = min(idleStart, pendingIdle?.since ?? idleStart)
            pendingIdle = PendingIdle(since: since, until: idleEnd ?? now, blockedBy: error.day)
            throw error
        }
        for (day, entries) in loaded {
            let kept = Self.removing(entries, from: idleStart, to: idleEnd, asOf: now)
            if kept != entries { try store.save(day, kept, timeZone: clock.calendar.timeZone) }
        }
        pendingIdle = nil
        reload()
        if choice == .removeAndStop {
            try pause()
        } else if running == nil, let project {
            let start = now
            try updateToday { $0.append(.timed(project: project, start: start, end: nil)) }
            running = Running(project: project, start: start)
        }
    }

    /// `entries` without their timed time from `cut` to `resume` (nil: no end); an open Entry counts up to
    /// `now`. An Entry running on past `resume` carries on from there.
    private static func removing(_ entries: [Entry], from cut: Date, to resume: Date?, asOf now: Date) -> [Entry] {
        entries.flatMap { entry -> [Entry] in
            guard case .timed(let project, let start, let end) = entry else { return [entry] }
            if (end ?? now) <= cut { return [entry] }
            if let resume, start >= resume { return [entry] }
            var pieces: [Entry] = []
            if start < cut { pieces.append(.timed(project: project, start: start, end: cut)) }
            if let resume, end.map({ $0 > resume }) ?? true {
                pieces.append(.timed(project: project, start: resume, end: end))
            }
            return pieces
        }
    }

    /// The Project's total on `day`, never below zero.
    public func total(_ project: String, on day: Day) -> TimeInterval {
        max(0, Self.sum(of: project, in: entries(on: day), asOf: now))
    }

    /// The raw sum of the Project's Entries, which may be negative after an adjustment.
    private static func sum(of project: String, in entries: [Entry], asOf now: Date) -> TimeInterval {
        entries.filter { ProjectName.matches($0.project, project) }.reduce(0) { $0 + $1.seconds(asOf: now) }
    }

    /// One Row per Project with Entries on `day`, in the order each first appears in the Day file. Names
    /// that match are one Project, shown as the Project list spells it, else as its first Entry does.
    public func rows(_ day: Day) -> [Row] {
        var names: [String] = []
        for entry in entries(on: day) where !names.contains(where: { ProjectName.matches($0, entry.project) }) {
            names.append(storedName(entry.project))
        }
        return names.map { Row(project: $0, total: total($0, on: day)) }
    }

    /// The Project list's spelling of `name`, else `name` trimmed.
    private func storedName(_ name: String) -> String {
        projects.first { ProjectName.matches($0, name) } ?? ProjectName.trimmed(name)
    }

    /// The Day's grand total: the sum of its Rows, each already clamped at zero.
    public func dayTotal(_ day: Day) -> TimeInterval {
        rows(day).reduce(0) { $0 + $1.total }
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
        let project = rows(day).first { ProjectName.matches($0.project, project) }?.project ?? storedName(project)
        func difference(_ entries: [Entry]) -> Int {
            Int((target - Self.sum(of: project, in: entries, asOf: now)).rounded())
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
            if malformedDays.contains(day) {
                malformedDays.remove(day)
                reparsed.insert(day)
            }
            return entries
        } catch {
            if !malformedDays.contains(day) { malformedDays.insert(day) }
            throw error
        }
    }
}

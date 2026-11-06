import Foundation
import Observation

/// Core's single entry point: the timers, totals and the Day files behind them.
@MainActor @Observable
public final class Tracker {
    /// Every running timer, each an open Entry in the loaded Day's file. Every start still pauses the
    /// others, so for now at most one runs.
    public private(set) var timers = RunningTimers()

    /// Compatibility view for callers written for a single timer: the newest running timer. Callers
    /// move to `timers` as the app learns to show several; then this goes.
    public var running: Running? { timers.newest }
    /// The Project ▶ starts: the one most recently started. Kept in `defaults` across launches.
    public private(set) var selectedProject: String? {
        didSet { defaults?.set(selectedProject, forKey: Self.selectedProjectKey) }
    }
    /// The active Projects, in `projects.txt` order.
    public private(set) var projects: [String] = []
    /// The clock's time at the last command or `tick()`. Totals of a running timer count up to here.
    public private(set) var now: Date
    /// Idle time to ask about with the idle alert; cleared by `resolveIdle`.
    public private(set) var pendingIdle: PendingIdle?

    @ObservationIgnored private let clock: TimeSource
    /// When this Tracker was made, and the Heartbeat the last run left: an Entry still open from before
    /// then was left by a crash.
    @ObservationIgnored private let launched: Date
    @ObservationIgnored private let lastAlive: Date?
    @ObservationIgnored private let files: DayFiles
    @ObservationIgnored private let projectStore: ProjectStore
    @ObservationIgnored private let defaults: UserDefaults?

    private static let selectedProjectKey = "selectedProject"
    private static let heartbeatKey = "heartbeat"

    /// Reads today's file. Each open Entry there is a running timer, so timers survive a relaunch.
    /// With no `defaults`, the Selected Project is kept in memory only.
    public init(clock: TimeSource, storageRoot: URL, defaults: UserDefaults? = nil) {
        self.clock = clock
        self.files = DayFiles(root: storageRoot, clock: clock)
        self.projectStore = ProjectStore(root: storageRoot)
        self.defaults = defaults
        self.now = clock.now
        self.launched = clock.now
        self.lastAlive = defaults?.object(forKey: Self.heartbeatKey) as? Date
        self.selectedProject = defaults?.string(forKey: Self.selectedProjectKey)
        reload()
    }

    /// Days whose file failed to parse when last read. Writes to them are refused until it parses again.
    public var malformedDays: Set<Day> { files.malformed }

    /// Retries deferred writes, then re-reads today's file and the Project list, and other Days' files
    /// when next asked for. A Day file that won't parse is flagged in `malformedDays` and its last good
    /// read is kept (for a Day not read before, just its deferred writes), so running timers keep running.
    public func reload() {
        now = clock.now
        projects = (try? projectStore.load()) ?? []
        let known = timers
        files.load(today)
        let reparsed = files.takeReparsed()
        let open = files.loadedEntries.compactMap(\.openTimer)
        // An open Entry in a file that just parsed again is left for `recover(reparsed:)`, unless it is
        // one of Core's own timers.
        timers = RunningTimers(reparsed.contains(today) ? open.filter { known.contains($0) } : open)
        // A running Project that was archived keeps running but isn't selected again.
        if let running, projects.contains(where: { ProjectName.matches($0, running.project) }) {
            selectedProject = storedName(running.project)
        }
        recover(reparsed: reparsed)
    }

    public var today: Day { Day(containing: now, in: calendar) }

    /// Whether `day`'s file failed to parse when last read. The Panel warns about it.
    public func isMalformed(_ day: Day) -> Bool { malformedDays.contains(day) }

    /// Starts a timer for `project`, pausing every running one first. A new name creates a Project.
    /// Refused, leaving the running timers alone, while today's file is malformed. Timers run only today:
    /// unlike `log` and `adjust` this takes no Day, so no Day other than today ever gets a timer.
    /// Returns the Project's name as `addProject` resolves it, the name its row is shown under.
    @discardableResult
    public func start(_ name: String, source: EntrySource = .app) throws -> String {
        now = clock.now
        files.retryPending()
        _ = try files.read(today)
        let project = try addProject(name)
        try pause()
        let timer = Running(project: project, start: now, source: source)
        try files.update(today) { $0.append(.timed(project: project, start: timer.start, end: nil, source: source)) }
        timers.insert(timer)
        selectedProject = project
        return project
    }

    /// Pauses every running timer, closing their Entries. If today's file is malformed the timers still
    /// stop, and closing the Entries waits until the file parses again.
    public func pause() throws {
        catchUp()
        guard !timers.isEmpty else { return }
        let end = now
        try files.update(today, deferringIfMalformed: true) { Self.close(&$0, at: end) }
        timers = RunningTimers()
    }

    /// Pauses `name`'s timer, if it runs, leaving any others running. Deferred like `pause()`.
    public func pause(_ name: String) throws {
        catchUp()
        guard let timer = timers[name] else { return }
        let end = now
        try files.update(today, deferringIfMalformed: true) { Self.close(&$0, at: end, only: timer.project) }
        timers.remove(timer.project)
    }

    /// Whether `toggle()` has a timer to pause or a Selected Project to start.
    public var canToggle: Bool { !timers.isEmpty || selectedProject != nil }

    /// Pauses every running timer, or with none running starts the Selected Project. Does nothing with no
    /// Selected Project; the UI opens the ＋ form instead.
    public func toggle() throws {
        if !timers.isEmpty {
            try pause()
        } else if let selectedProject {
            try start(selectedProject)
        }
    }

    /// Whether `name`'s timer is running.
    public func isRunning(_ name: String) -> Bool { timers.contains(name) }

    /// A Panel row's ▶/⏸: pauses `name` if it is running, otherwise starts it, pausing every other timer.
    public func toggle(_ name: String) throws {
        if isRunning(name) {
            try pause(name)
        } else {
            try start(name)
        }
    }

    /// Called every second by the UI so running totals advance, and on wake. Rolls over to a new Day and
    /// retries deferred writes, then recovers any Entry left open in a Day file that parsed again.
    public func tick() {
        catchUp()
        files.retryPending()
        recover(reparsed: files.takeReparsed())
        unblockPendingIdle()
    }

    /// Clears `pendingIdle.blockedBy` once that Day's file parses and its deferred writes have landed.
    private func unblockPendingIdle() {
        guard let idle = pendingIdle, let day = idle.blockedBy,
              !files.hasPending(day), (try? files.read(day)) != nil else { return }
        pendingIdle = PendingIdle(since: idle.since, until: idle.until)
    }

    /// Records the clock's time as the last moment Chronobar was alive, while any timer runs. The UI calls
    /// it every minute and on sleep; `recoverAfterLaunch()` reads it after a crash.
    public func heartbeat() {
        guard !timers.isEmpty else { return }
        defaults?.set(clock.now, forKey: Self.heartbeatKey)
    }

    /// Called once at launch. Quitting closes the running Entries, so an Entry still open means Chronobar
    /// crashed or the Mac was forced off. Returns when it was last known alive (the later of the earliest
    /// open Entry's start and the last Heartbeat) so the UI can ask about the time since with the idle
    /// alert; nil if nothing was left open. Entries open on a past Day become running timers and are split
    /// across the Days since, as after waking from sleep, so the idle removal can cut them. The same goes
    /// for Entries found open later in a Day file that was malformed at launch, once it parses.
    @discardableResult
    public func recoverAfterLaunch() -> Date? {
        now = clock.now
        if !timers.isEmpty {
            recover(Array(timers), on: files.loadedDay)
        } else if let (day, entries) = lastTimedDay() {
            recover(entries.compactMap(\.openTimer), on: day)
        }
        return pendingIdle?.since
    }

    /// Recovers open Entries in Day files that were malformed and now parse. Core's own running timers are
    /// left alone; any other open Entry was left by a crash.
    private func recover(reparsed days: Set<Day>) {
        for day in days.sorted() where !files.hasPending(day) {
            let found = files.entries(on: day).compactMap(\.openTimer)
            recover(found.filter { !(day == files.loadedDay && timers.contains($0)) }, on: day)
        }
    }

    /// Makes Entries left open on `day` by a crash running timers, split across the Days since, with the
    /// time since each was last alive pending as Idle time. If other timers run already, the Entries are
    /// closed when Chronobar launched (or at the end of their Day) and only the time before that is pending.
    private func recover(_ found: [Running], on day: Day) {
        guard !found.isEmpty else { return }
        if timers.allSatisfy(found.contains) {
            files.move(to: day)
            timers = RunningTimers(found)
            for timer in found { noteIdle(PendingIdle(since: max(timer.start, lastAlive ?? timer.start))) }
            rollOver()
            return
        }
        for timer in found {
            let lastAlive = max(timer.start, lastAlive ?? timer.start)
            let end = max(timer.start, min(launched, calendar.dateInterval(of: .day, for: timer.start)!.end))
            try? files.update(day, deferringIfMalformed: true) { entries in
                entries = entries.map { $0.openTimer == timer ? $0.closed(at: end) : $0 }
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
        for day in files.days() where day < today {
            guard let entries = try? files.read(day) else { continue }
            if entries.contains(where: { if case .timed = $0 { true } else { false } }) { return (day, entries) }
        }
        return nil
    }

    /// Answers the idle alert. `remove` and `removeAndStop` drop the time from `idleStart` to `idleEnd`
    /// (nil: now) from every Day it covers: a timed Entry straddling either end is cut there, timed Entries
    /// inside are deleted and manual Entries stay. `remove` then restarts from now each running timer the
    /// cut stopped, with its source; `removeAndStop` leaves them all stopped. If any of those Day files
    /// won't parse, nothing is changed.
    public func resolveIdle(since idleStart: Date, until idleEnd: Date? = nil, choice: IdleChoice) throws {
        catchUp()
        guard choice != .keep else { return pendingIdle = nil }
        let idleEnd = idleEnd.map { min($0, now) }
        let idleStart = min(idleStart, idleEnd ?? now)
        let running = timers
        let firstDay = Day(containing: idleStart, in: calendar)
        let lastDay = idleEnd.map { Day(containing: $0, in: calendar) } ?? today
        let days = Set(files.days().filter { $0 >= firstDay && $0 <= lastDay } + [today]).sorted()
        // Read every Day before writing any, so a malformed one (or one with deferred writes still queued)
        // refuses the whole removal.
        files.retryPending()
        let loaded: [(Day, [Entry])]
        do {
            loaded = try days.map { day in
                guard !files.hasPending(day) else { throw MalformedDayFile(day: day) }
                do { return (day, try files.read(day)) } catch is DayFile.Malformed { throw MalformedDayFile(day: day) }
            }
        } catch let error as MalformedDayFile {
            let since = min(idleStart, pendingIdle?.since ?? idleStart)
            pendingIdle = PendingIdle(since: since, until: idleEnd ?? now, blockedBy: error.day)
            throw error
        }
        for (day, entries) in loaded {
            let kept = Self.removing(entries, from: idleStart, to: idleEnd, asOf: now)
            if kept != entries { try files.save(day, kept) }
        }
        pendingIdle = nil
        reload()
        if choice == .removeAndStop {
            try pause()
            return
        }
        let stopped = running.filter { !timers.contains($0.project) }
        guard !stopped.isEmpty else { return }
        let start = now
        try files.update(today) { entries in
            for timer in stopped {
                entries.append(.timed(project: timer.project, start: start, end: nil, source: timer.source))
            }
        }
        for timer in stopped { timers.insert(Running(project: timer.project, start: start, source: timer.source)) }
    }

    /// `entries` without their timed time from `cut` to `resume` (nil: no end); an open Entry counts up to
    /// `now`. An Entry running on past `resume` carries on from there.
    private static func removing(_ entries: [Entry], from cut: Date, to resume: Date?, asOf now: Date) -> [Entry] {
        entries.flatMap { entry -> [Entry] in
            guard case .timed(let project, let start, let end, let source) = entry else { return [entry] }
            if (end ?? now) <= cut { return [entry] }
            if let resume, start >= resume { return [entry] }
            var pieces: [Entry] = []
            if start < cut { pieces.append(.timed(project: project, start: start, end: cut, source: source)) }
            if let resume, end.map({ $0 > resume }) ?? true {
                pieces.append(.timed(project: project, start: resume, end: end, source: source))
            }
            return pieces
        }
    }

    /// The Project's total on `day`, never below zero.
    public func total(_ project: String, on day: Day) -> TimeInterval {
        max(0, Self.sum(of: project, in: files.entries(on: day), asOf: now))
    }

    /// The raw sum of the Project's Entries, which may be negative after an adjustment.
    private static func sum(of project: String, in entries: [Entry], asOf now: Date) -> TimeInterval {
        entries.filter { ProjectName.matches($0.project, project) }.reduce(0) { $0 + $1.seconds(asOf: now) }
    }

    /// One Row per Project with Entries on `day`, in the order each first appears in the Day file. Names
    /// that match are one Project, shown as the Project list spells it, else as its first Entry does.
    public func rows(_ day: Day) -> [Row] {
        var names: [String] = []
        for entry in files.entries(on: day) where !names.contains(where: { ProjectName.matches($0, entry.project) }) {
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

    /// The Day's Elapsed time: the clock time covered by at least one timed Entry, a running timer
    /// counted up to now. Below the Day total when timers overlap; manual Entries count only there.
    public func elapsed(_ day: Day) -> TimeInterval {
        Entry.elapsed(files.entries(on: day), asOf: now)
    }

    /// The calendar Days and weeks are counted in.
    public var calendar: Calendar { clock.calendar }

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

    /// Active Projects containing `text` anywhere, ignoring case and surrounding spaces. A name matching
    /// `text` exactly comes first, then names starting with it, then the rest; within each, the most
    /// recently used first.
    public func suggestions(for text: String) -> [String] {
        let text = ProjectName.trimmed(text)
        let recent = projectsByRecentUse()
        guard !text.isEmpty else { return recent }
        // Rank 0 is an exact match, 1 starts with `text`, 2 contains it; `recency` keeps recent use within each.
        let ranked = recent.enumerated().compactMap { recency, name -> (rank: Int, recency: Int, name: String)? in
            guard let found = name.range(of: text, options: .caseInsensitive) else { return nil }
            let rank = ProjectName.matches(name, text) ? 0 : found.lowerBound == name.startIndex ? 1 : 2
            return (rank, recency, name)
        }
        return ranked.sorted { ($0.rank, $0.recency) < ($1.rank, $1.recency) }.map(\.name)
    }

    /// What a typed name would start or log: an active Project, an archived one with time in the Day
    /// files (each with the spelling `addProject` would use), or a new one. Nil for a blank name.
    /// Reads other Days' files once until the next `reload`, so it can be asked on every keystroke.
    public func match(_ name: String) -> ProjectMatch? {
        let name = ProjectName.trimmed(name)
        guard !name.isEmpty else { return nil }
        if let active = projects.first(where: { ProjectName.matches($0, name) }) { return .active(active) }
        for day in files.days() {
            if let entry = files.entries(on: day).last(where: { ProjectName.matches($0.project, name) }) {
                return .archived(entry.project)
            }
        }
        return .new
    }

    /// The active Projects, the one with the latest Entry on today or a past Day first. Projects with no
    /// such Entry (new by hand, or with time only on future Days) follow in the Project list's order.
    private func projectsByRecentUse() -> [String] {
        var used: [String] = []
        let days = [today] + files.days().filter { $0 < today }
        for day in days where used.count < projects.count {
            for entry in files.entries(on: day).reversed() {
                if let project = projects.first(where: { ProjectName.matches($0, entry.project) }),
                   !used.contains(project) {
                    used.append(project)
                }
            }
        }
        return used + projects.filter { !used.contains($0) }
    }

    /// The name a past Entry used for this Project, newest Day first. Malformed Days are skipped.
    private func historicalName(matching name: String) -> String? {
        for day in files.days() {
            let entries = (try? files.read(day)) ?? []
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

    /// Adds a typed duration (`1:30`, `45`) to the Project on `day`, past, today or future, as a manual
    /// Entry, without starting a timer. A new name creates a Project. Throws `InvalidDuration` for
    /// anything but a positive total. Returns the Project's name as `addProject` resolves it, the name its
    /// row is shown under.
    @discardableResult
    public func log(_ name: String, _ duration: String, on day: Day) throws -> String {
        guard case .absolute(let seconds) = try DurationInput(parsing: duration), seconds > 0 else {
            throw InvalidDuration(text: duration)
        }
        catchUp()
        let project = try addProject(name)
        try files.update(day) { $0.append(.manual(project: project, seconds: seconds, note: .manual)) }
        return project
    }

    /// Sets the Project's total on `day`, past, today or future, to a typed total (`1:15`) or changes it
    /// (`+15`, `-10`), starting from the total shown and never going below zero. Writes one adjustment Entry of the new total minus
    /// the stored sum; a running timer keeps running. Throws `InvalidDuration` for a typo.
    public func adjust(_ project: String, _ input: String, on day: Day) throws {
        let input = try DurationInput(parsing: input)
        catchUp()
        let target: TimeInterval = switch input {
        case .absolute(let seconds): TimeInterval(seconds)
        case .relative(let seconds): max(0, total(project, on: day) + TimeInterval(seconds))
        }
        let now = now
        let project = rows(day).first { ProjectName.matches($0.project, project) }?.project ?? storedName(project)
        func difference(_ entries: [Entry]) -> Int {
            Int((target - Self.sum(of: project, in: entries, asOf: now)).rounded())
        }
        guard difference(files.entries(on: day)) != 0 else { return }
        // The difference is taken again from the Entries as re-read, so a hand edit can't skew it.
        try files.update(day) { entries in
            let seconds = difference(entries)
            if seconds != 0 { entries.append(.manual(project: project, seconds: seconds, note: .adjustment)) }
        }
    }

    /// Brings `now` up to the clock and rolls over to a new Day. Every command starts with this.
    private func catchUp() {
        now = clock.now
        rollOver()
    }

    /// After midnight, splits every running timer at the start of each new Day so every Day's file holds
    /// only that Day's time, then loads today. Writes to a file that won't parse wait until it does.
    private func rollOver() {
        guard files.loadedDay != today else { return }
        while !timers.isEmpty, files.loadedDay < today {
            let midnight = calendar.dateInterval(of: .day, for: files.loadedDay.noon(in: calendar))!.end
            let next = Day(containing: midnight, in: calendar)
            let carried = timers.map { Running(project: $0.project, start: midnight, source: $0.source) }
            try? files.update(files.loadedDay, deferringIfMalformed: true) { Self.close(&$0, at: midnight) }
            try? files.update(next, deferringIfMalformed: true) { entries in
                for timer in carried {
                    entries.append(.timed(project: timer.project, start: midnight, end: nil, source: timer.source))
                }
            }
            // Load the new Day as written, or as its deferred writes leave it if its file won't parse.
            files.move(to: next)
            timers = RunningTimers(carried)
        }
        reload()
    }

    /// Ends every open Entry at `end`, or with `project` only that Project's.
    private static func close(_ entries: inout [Entry], at end: Date, only project: String? = nil) {
        entries = entries.map { entry in
            if let project, !ProjectName.matches(entry.project, project) { return entry }
            return entry.closed(at: end)
        }
    }
}

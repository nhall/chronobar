import Foundation
import Observation

/// Core's single entry point: the timers, totals and the Day files behind them.
@MainActor @Observable
public final class Tracker {
    /// Every running timer, each an open Entry in the loaded Day's file, at most one per Project.
    public private(set) var timers = RunningTimers()
    /// Whether `start` pauses every other running timer, whatever started them. The Settings toggle
    /// "Starting a timer pauses the others"; off by default.
    public var startPausesOthers = false
    /// How long a timer runs before `tick()` reports it for the long-running warning; nil for Off. The
    /// Settings pop-up; nothing is ever cut automatically.
    public var longRunningThreshold: TimeInterval?
    /// How long without keyboard or mouse input before `reportInput(idleFor:)` counts as Idle time; nil
    /// for Off. The Settings pop-up; sleep and lock count either way.
    public var idleThreshold: TimeInterval?
    /// The Pinned Projects, always suggested, in `projects.txt` order.
    public var projects: [String] { labels.pinned }
    /// The archived Projects, never suggested until typed again, in `archived.txt` order.
    public var archived: [String] { labels.archived }
    /// The clock's time at the last command, `reload()` or `tick()`. Totals of a running timer count up to
    /// here.
    public private(set) var now: Date
    /// Idle time to ask about with the idle alert; cleared by `resolveIdle`.
    public var pendingIdle: PendingIdle? { pending?.idle }
    /// The pending Idle time, and whether Core holds it (after crash recovery or a refused removal) rather
    /// than only having had it reported, so it's asked about even with no timer started in the app running.
    private var pending: (idle: PendingIdle, held: Bool)?

    @ObservationIgnored private let clock: TimeSource
    /// When this Tracker was made, and the Heartbeat the last run left: an Entry still open from before
    /// then was left by a crash.
    @ObservationIgnored private let launched: Date
    @ObservationIgnored private let lastAlive: Date?
    @ObservationIgnored let files: DayFiles
    /// The Pinned and Archived Labels, and every rule about Labels apart from their time.
    @ObservationIgnored let labels: LabelCatalogue
    @ObservationIgnored private let defaults: UserDefaults?
    /// The runs `tick()` has reported as long-running, so each is reported once, across relaunches too.
    @ObservationIgnored private var warnings: LongRunningWarnings
    /// When the Mac went to sleep or locked with a timer started in the app running, until it came back.
    @ObservationIgnored private var awaySince: Date?
    /// Whether `takeIdleQuestion()` handed out a question `resolveIdle` hasn't answered yet.
    @ObservationIgnored private var idleQuestionAwaitingAnswer = false

    private static let heartbeatKey = "heartbeat"
    /// Where v1 kept the Project ▶ started. Nothing reads it now; it is removed at launch.
    private static let retiredSelectedProjectKey = "selectedProject"

    /// Reads today's file. Each open Entry there is a running timer, so timers survive a relaunch.
    public init(clock: TimeSource, storageRoot: URL, defaults: UserDefaults? = nil) {
        self.clock = clock
        self.files = DayFiles(root: storageRoot, clock: clock)
        self.labels = LabelCatalogue(root: storageRoot, files: files)
        self.defaults = defaults
        self.now = clock.now
        self.launched = clock.now
        self.lastAlive = defaults?.object(forKey: Self.heartbeatKey) as? Date
        self.warnings = LongRunningWarnings(defaults: defaults)
        defaults?.removeObject(forKey: Self.retiredSelectedProjectKey)
        reread()
    }

    /// Days whose file failed to parse when last read. Writes to them are refused until it parses again.
    public var malformedDays: Set<Day> { files.malformed }

    /// Brings Core up to now, then re-reads today's file and the pinned and archived lists, and other Days'
    /// files when next asked for. Catching up rolls over past midnight, retries deferred writes, recovers
    /// Entries open in Day files that parsed again and unblocks `pendingIdle` once its Day can be read, so
    /// no caller has to tick first. It doesn't look for long-running timers; only `tick()` does. A Day file
    /// that won't parse is flagged in `malformedDays` and its last good read is kept (for a Day not read
    /// before, just its deferred writes), so running timers keep running.
    public func reload() {
        bringUpToNow()
        reread()
    }

    /// What `reload()` and `tick()` start with: catches up, then unblocks `pendingIdle` once its Day can be
    /// read.
    private func bringUpToNow() {
        catchUp()
        unblockPendingIdle()
    }

    /// `reload()` without catching up: retries deferred writes and re-reads today's file and the Label
    /// lists. Rollover and the corrections call it after they write, so catching up never recurses.
    func reread() {
        now = clock.now
        refresh(known: Array(timers), reparsed: files.load(today))
    }

    /// After today's file was loaded: re-reads the pinned and archived lists and takes the running timers
    /// from today's open Entries, then recovers those in `reparsed`, the Days that parsed again. An open
    /// Entry in today's file that just parsed again is left for `recover(reparsed:)`, unless it is one of
    /// `known`, Core's own timers.
    private func refresh(known: [Running], reparsed: Set<Day>) {
        labels.reload()
        let open = files.loadedEntries.compactMap(\.openTimer)
        timers = RunningTimers(reparsed.contains(today) ? open.filter(known.contains) : open)
        recover(reparsed: reparsed)
    }

    public var today: Day { Day(containing: now, in: calendar) }

    /// Whether `day`'s file failed to parse when last read. The Panel warns about it.
    public func isMalformed(_ day: Day) -> Bool { malformedDays.contains(day) }

    /// Starts a timer for `project`, leaving the running ones running unless `startPausesOthers` is on. A
    /// Project already running keeps its timer, start and source, and the others keep running whatever the
    /// setting, so this is a no-op for it. A new name
    /// creates a Project. Refused, leaving the running timers alone, while today's file is malformed.
    /// Timers run only today: unlike `log` and `adjust` this takes no Day, so no Day other than today ever
    /// gets a timer. Returns what it did: the Project's stored spelling, whether it was already running,
    /// its running Timer and the Timers it paused.
    @discardableResult
    public func start(_ name: String, source: EntrySource = .app) throws -> StartOutcome {
        catchUp()
        try files.checkReadable(today)
        return try labels.resolvingForWrite(name) { project, bringingBack in
            if let running = timers[project] {
                return StartOutcome(project: project, alreadyRunning: true, timer: running, paused: [])
            }
            let timer = Running(project: project, start: now, source: source)
            let pausesOthers = startPausesOthers
            // One write closes the others, opens the new Entry and brings the Project back, so a failed save
            // leaves every timer and file as it was.
            try files.change([today], alongWith: bringingBack) { _, entries in
                if pausesOthers { Self.close(&entries, at: timer.start) }
                entries.append(.timed(project: project, start: timer.start, end: nil, source: source))
            }
            let paused = pausesOthers ? timers.map { PausedTimer(timer: $0, end: timer.start) } : []
            if pausesOthers { timers = RunningTimers() }
            timers.insert(timer)
            return StartOutcome(project: project, alreadyRunning: false, timer: timer, paused: paused)
        }
    }

    /// Pauses every running timer, closing their Entries. If today's file is malformed the timers still
    /// stop, and closing the Entries waits until the file parses again.
    public func pause() throws {
        catchUp()
        guard !timers.isEmpty else { return }
        let end = now
        try files.changeOrDefer(today) { Self.close(&$0, at: end) }
        timers = RunningTimers()
    }

    /// Pauses `name`'s timer, if it runs, leaving any others running. Deferred like `pause()`. Returns the
    /// timer it stopped, whose Entry now ends at `now`; nil if `name` wasn't running.
    @discardableResult
    public func pause(_ name: String) throws -> Running? {
        catchUp()
        guard let timer = timers[name] else { return nil }
        let end = now
        try files.changeOrDefer(today) { Self.close(&$0, at: end, only: timer.project) }
        timers.remove(timer.project)
        return timer
    }

    /// The long-running warning's Stop: pauses `run`'s timer now, unless that run has already ended, so a
    /// late click never stops a timer started again since.
    public func pause(_ run: TimerRun) throws {
        catchUp()
        guard let timer = timers[run.project], self.run(of: timer) == run else { return }
        try pause(timer.project)
    }

    /// Called when Chronobar quits: pauses the timers started in the app and leaves agents' timers open,
    /// so quitting by habit never stops an agent's timing. Deferred like `pause()`.
    public func quit() throws {
        try pauseAppTimers()
    }

    /// Pauses every timer started in the app, leaving agents' timers running. Deferred like `pause()`.
    private func pauseAppTimers() throws {
        catchUp()
        let app = timers.filter { $0.source == .app }
        guard !app.isEmpty else { return }
        let end = now
        try files.changeOrDefer(today) { entries in
            for timer in app { Self.close(&entries, at: end, only: timer.project) }
        }
        for timer in app { timers.remove(timer.project) }
    }

    /// Whether `name`'s timer is running.
    public func isRunning(_ name: String) -> Bool { timers.contains(name) }

    /// A Panel row's ▶/⏸: pauses `name` if it is running, otherwise starts it as `start` does.
    public func toggle(_ name: String) throws {
        if isRunning(name) {
            try pause(name)
        } else {
            try start(name)
        }
    }

    /// Called by the app only, every second so running totals advance, and on wake. Catches up as
    /// `reload()` does (without re-reading), then returns a Long-running warning for each timer that has run
    /// for `longRunningThreshold` since the last tick, once per run and worded on this Tracker's calendar.
    /// Nothing else ticks, so the app sees every warning; callers that tick only to catch up can ignore the
    /// result.
    @discardableResult
    public func tick() -> [LongRunningWarning] {
        bringUpToNow()
        guard let threshold = longRunningThreshold else { return [] }
        return warnings.due(among: timers.map(run(of:)), at: now, threshold: threshold)
            .map { warning(for: $0, threshold: threshold) }
    }

    /// The Long-running warning for `run`, past a threshold of `threshold` seconds, on this Tracker's
    /// calendar.
    private func warning(for run: TimerRun, threshold: TimeInterval) -> LongRunningWarning {
        let since = TimeWording(calendar: calendar, today: today).time(run.since)
        return LongRunningWarning(
            run: run, title: "\(run.project) is still running",
            body: "Running for over \(Int(threshold / 3600)) hours, since \(since). Stop it if it's done.")
    }

    /// `timer`'s current run, which began at its start, or for a timer carried over at midnight, at the
    /// start of the Entry it was split from on the Day before, followed back as far as the splits go.
    private func run(of timer: Running) -> TimerRun {
        TimerRun(project: timer.project, since: files.run(of: timer)[0].start)
    }

    /// Clears `pendingIdle.blockedBy` once that Day's file parses and its deferred writes have landed.
    private func unblockPendingIdle() {
        guard case let (idle, held)? = pending, let day = idle.blockedBy, (try? files.checkReadable(day)) != nil
        else { return }
        pending = (PendingIdle(since: idle.since, until: idle.until), held)
    }

    // MARK: Idle time

    /// The running timers started in the app, the only ones Idle time applies to: agents keep working
    /// while the user is away.
    private var appTimers: [Running] { timers.filter { $0.source == .app } }

    /// Whether a timer started in the app runs, so input inactivity is worth sampling for
    /// `reportInput(idleFor:)`.
    public var appTimerRuns: Bool { !appTimers.isEmpty }

    /// The Mac went to sleep or locked its screen. Recorded on Chronobar's clock while a timer started in
    /// the app runs; a second report before `reportBack()` keeps the earlier time.
    public func reportAway() {
        catchUp()
        guard !appTimers.isEmpty else { return }
        awaySince = min(awaySince ?? now, now)
    }

    /// The Mac woke or its screen unlocked: the time since `reportAway()` is Idle time running up to now.
    public func reportBack() {
        catchUp()
        guard let since = awaySince else { return }
        awaySince = nil
        noteReported(PendingIdle(since: since))
    }

    /// How long the app has had no keyboard or mouse input, sampled every second while a timer started in
    /// the app runs. Once it reaches `idleThreshold`, the time since the last input is Idle time running up
    /// to now.
    public func reportInput(idleFor seconds: TimeInterval) {
        // Sampled every second, just after `tick()`: catch up only when there's Idle time to note.
        guard let idleThreshold, seconds >= idleThreshold else { return }
        catchUp()
        guard !appTimers.isEmpty else { return }
        noteReported(PendingIdle(since: now - seconds))
    }

    /// The idle alert's question, if one is due, marked out until `resolveIdle` answers it. One is due for
    /// `pendingIdle` once no Day blocks it and no question is out, while a timer started in the app runs or
    /// for Idle time Core holds. Idle time only reported, with no such timer left to cut, is dropped.
    public func takeIdleQuestion() -> IdleQuestion? {
        guard !idleQuestionAwaitingAnswer, case let (idle, held)? = pending, idle.blockedBy == nil
        else { return nil }
        let timedLabels = appTimers.map(\.project)
        guard !timedLabels.isEmpty || held else {
            clearPendingIdle()
            return nil
        }
        idleQuestionAwaitingAnswer = true
        let subject = IdleSubject(since: idle.since, until: idle.until, labels: timedLabels)
        return IdleQuestion(subject: subject,
                            message: IdleWording(calendar: calendar, today: today).message(for: subject))
    }

    /// The alert to show when `resolveIdle` throws `error`: which Day and file refused the removal, with the
    /// date on this Tracker's calendar.
    public func idleRefusal(_ error: MalformedDayFile) -> IdleRefusal {
        IdleWording(calendar: calendar, today: today).refusal(error)
    }

    /// Folds a report's Idle time into `pendingIdle`, unless a question is out: reports that arrive while
    /// the alert is open are left out, so alerts never stack.
    private func noteReported(_ idle: PendingIdle) {
        guard !idleQuestionAwaitingAnswer else { return }
        noteIdle(idle, held: false)
    }

    /// Records the clock's time as the last moment Chronobar was alive, while any timer runs. The UI calls
    /// it every minute and on sleep; `recoverAfterLaunch()` reads it after a crash.
    public func heartbeat() {
        guard !timers.isEmpty else { return }
        defaults?.set(clock.now, forKey: Self.heartbeatKey)
    }

    /// Called once at launch. Quitting closes the app-started Entries, so one still open means Chronobar
    /// crashed or the Mac was forced off. Returns when it was last known alive (the later of the earliest
    /// open app-started Entry's start and the last Heartbeat) so the UI can ask about the time since with
    /// the idle alert; nil if none was left open. Agents' open Entries become running timers with no Idle
    /// time, whether a crash or quitting left them. Entries open on a past Day become running timers and
    /// are split across the Days since, as after waking from sleep, so the idle removal can cut them. The
    /// same goes for Entries found open later in a Day file that was malformed at launch, once it parses.
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
        for day in days.sorted() {
            let found = files.entries(on: day).compactMap(\.openTimer)
            recover(found.filter { !(day == files.loadedDay && timers.contains($0)) }, on: day)
        }
    }

    /// Makes Entries left open on `day` by a crash (or by quitting, for agents' timers) running timers,
    /// split across the Days since. For timers started in the app the time since each was last alive is
    /// pending as Idle time; agents' timers just keep running. If other timers run already, the Entries are
    /// closed when Chronobar launched (or at the end of their Day) and only the app-started time before
    /// that is pending.
    private func recover(_ found: [Running], on day: Day) {
        guard !found.isEmpty else { return }
        if timers.allSatisfy(found.contains) {
            timers = RunningTimers(found)
            for timer in found where timer.source == .app {
                noteIdle(PendingIdle(since: max(timer.start, lastAlive ?? timer.start)), held: true)
            }
            apply(files.catchUp(to: today, carrying: found, from: day))
            return
        }
        for timer in found {
            let lastAlive = max(timer.start, lastAlive ?? timer.start)
            let end = max(timer.start, min(launched, files.end(of: Day(containing: timer.start, in: calendar))))
            try? files.changeOrDefer(day) { entries in
                entries = entries.map { $0.openTimer == timer ? $0.closed(at: end) : $0 }
            }
            if timer.source == .app { noteIdle(PendingIdle(since: min(lastAlive, end), until: end), held: true) }
        }
    }

    /// Adds `idle` to `pendingIdle`, which then covers both: the earliest start, up to now if either runs
    /// up to now and otherwise to the later end, still blocked if it was. `held` is for Idle time Core holds
    /// (after a crash, or a refused removal), asked about even with no timer started in the app running.
    private func noteIdle(_ idle: PendingIdle, held: Bool) {
        guard let pending else { return self.pending = (idle, held) }
        let until = pending.idle.until.flatMap { a in idle.until.map { max(a, $0) } }
        self.pending = (PendingIdle(since: min(pending.idle.since, idle.since), until: until,
                                    blockedBy: pending.idle.blockedBy ?? idle.blockedBy),
                        pending.held || held)
    }

    private func clearPendingIdle() {
        pending = nil
    }

    /// The newest past Day whose file has a timed Entry, with its Entries. Malformed Days are skipped.
    private func lastTimedDay() -> (Day, [Entry])? {
        for day in files.days() where day < today {
            guard let entries = files.reread(day) else { continue }
            if entries.contains(where: { if case .timed = $0 { true } else { false } }) { return (day, entries) }
        }
        return nil
    }

    /// Answers the idle alert, for the timers started in the app only: agents kept working while the user
    /// was away, so their Entries and timers are left alone. `remove` and `removeAndStop` drop the time
    /// from `idleStart` to `idleEnd` (nil: now) from every Day it covers: an app-started timed Entry
    /// straddling either end is cut there, those inside are deleted and manual Entries stay. `remove` then
    /// restarts from now each app timer the cut stopped; `removeAndStop` leaves every app timer stopped. If
    /// any of those Day files won't parse, or one can't be saved, nothing is changed. Either way the Idle
    /// time is cleared, except that one refused by a malformed Day is held until the file parses.
    public func resolveIdle(since idleStart: Date, until idleEnd: Date? = nil, choice: IdleChoice) throws {
        // Whatever the answer, and whether the removal goes through or not, the question is answered.
        defer { idleQuestionAwaitingAnswer = false }
        catchUp()
        guard choice != .keep else { return clearPendingIdle() }
        let idleEnd = idleEnd.map { min($0, now) }
        let idleStart = min(idleStart, idleEnd ?? now)
        let running = timers
        let firstDay = Day(containing: idleStart, in: calendar)
        let lastDay = idleEnd.map { Day(containing: $0, in: calendar) } ?? today
        let days = files.days().filter { $0 >= firstDay && $0 <= lastDay } + [today]
        // The removal and the restart or stop after it are one All-or-nothing change. A malformed Day (or one
        // with deferred writes still queued) refuses it whole and blocks the Idle time until it parses.
        do {
            try files.change(days) { day, entries in
                entries = Self.removing(entries, from: idleStart, to: idleEnd, asOf: now)
                if day == today { entries = Self.resumed(entries, running: running, choice: choice, at: now) }
            }
        } catch let error as MalformedDayFile {
            let since = min(idleStart, pendingIdle?.since ?? idleStart)
            pending = (PendingIdle(since: since, until: idleEnd ?? now, blockedBy: error.day), held: true)
            throw error
        } catch {
            // A Day that couldn't be saved: asked once, as for any answer, rather than every second.
            clearPendingIdle()
            throw error
        }
        clearPendingIdle()
        reread()
    }

    /// Today's `entries` after an idle removal, with the app timers it stopped started again at `now`
    /// (`remove`), or with every app timer stopped at `now` (`removeAndStop`).
    private static func resumed(_ entries: [Entry], running: RunningTimers, choice: IdleChoice, at now: Date) -> [Entry] {
        if choice == .removeAndStop {
            return entries.map { $0.openTimer?.source == .app ? $0.closed(at: now) : $0 }
        }
        let open = entries.compactMap(\.openTimer)
        let stopped = running.filter { timer in
            timer.source == .app && !open.contains { ProjectName.matches($0.project, timer.project) }
        }
        return entries + stopped.map { .timed(project: $0.project, start: now, end: nil, source: $0.source) }
    }

    /// `entries` without their app-started time from `cut` to `resume` (nil: no end); an open Entry counts
    /// up to `now`. An Entry running on past `resume` carries on from there. Agents worked on while the
    /// user was away, so their Entries stay whole.
    private static func removing(_ entries: [Entry], from cut: Date, to resume: Date?, asOf now: Date) -> [Entry] {
        entries.flatMap { entry -> [Entry] in
            guard case .timed(let project, let start, let end, let source) = entry, source == .app else {
                return [entry]
            }
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
    /// that match are one Project, shown as the Project list spells it, else as its first Entry does. A
    /// Row's total is in whole seconds, rounded down, so the Day total built from them adds up exactly.
    public func rows(_ day: Day) -> [Row] {
        var names: [String] = []
        for entry in files.entries(on: day) where !names.contains(where: { ProjectName.matches($0, entry.project) }) {
            names.append(labels.shownName(entry.project))
        }
        return names.map { Row(project: $0, total: total($0, on: day).rounded(.down)) }
    }

    /// The Day's grand total: the sum of its Rows, each already clamped at zero and in whole seconds.
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

    // MARK: Labels

    /// Pins `name`: adds it to `projects.txt`, so it is always suggested, and takes it off `archived.txt`.
    /// Returns the Project's name, spelled as for start. Pinning a Pinned Project changes nothing.
    @discardableResult
    public func pinProject(_ name: String) throws -> String {
        try labels.pin(name)
    }

    /// Whether `name` is a Pinned Project, ignoring case and surrounding spaces.
    public func isPinned(_ name: String) -> Bool {
        labels.isPinned(name)
    }

    /// Suggested Projects containing `text` anywhere, ignoring case and surrounding spaces. A name matching
    /// `text` exactly comes first, then names starting with it, then the rest; within each, the most
    /// recently used first.
    public func suggestions(for text: String) -> [String] {
        labels.suggestions(for: text, today: today, calendar: calendar)
    }

    /// What a typed name would start or log: a suggested Project, an archived one, an unused one (time in
    /// the Day files but not lately), each spelled as start would write it, or a new one. Nil for a blank
    /// name. Reads other Days' files once until the next `reload`, so it can be asked on every keystroke.
    public func match(_ name: String) -> ProjectMatch? {
        labels.match(name, today: today, calendar: calendar)
    }

    /// Archives the Project matching `name`: takes it off `projects.txt` and adds it to `archived.txt`, so
    /// it isn't suggested until typed again. Its Entries stay in the Day files and a running timer keeps
    /// running. Reads both lists before writing either and writes them together, so if one won't parse or
    /// can't be saved nothing changes. Returns the stored spelling archived: the Archived one if it already
    /// was, else as start spells it.
    @discardableResult
    public func archiveProject(_ name: String) throws -> String {
        try labels.archive(name)
    }

    /// Adds a typed duration (`1:30`, `45`) to the Project on `day`, past, today or future, as a manual
    /// Entry, without starting a timer. An archived Project comes back. Throws `InvalidDuration` for
    /// anything but a positive total. Returns what it stored: the Project's name with its stored spelling,
    /// the name its row is shown under, the Day and the seconds.
    @discardableResult
    public func log(_ name: String, _ duration: String, on day: Day) throws -> Logged {
        guard case .absolute(let seconds) = try DurationInput(parsing: duration), seconds > 0 else {
            throw InvalidDuration(text: duration)
        }
        catchUp()
        return try labels.resolvingForWrite(name) { project, bringingBack in
            try files.change([day], alongWith: bringingBack) { _, entries in
                entries.append(.manual(project: project, seconds: seconds, note: .manual))
            }
            return Logged(project: project, day: day, seconds: seconds)
        }
    }

    /// Sets the Project's total on `day`, past, today or future, to a typed total (`1:15`) or changes it
    /// (`+15`, `-10`), starting from the total shown and never going below zero. Writes one adjustment
    /// Entry of the new total minus the stored sum; a running timer keeps running. Throws `InvalidDuration`
    /// for a typo. Returns the Project as stored, the Day, and its Total before and after; equal Totals
    /// when nothing was written.
    @discardableResult
    public func adjust(_ project: String, _ input: String, on day: Day) throws -> Adjustment {
        let input = try DurationInput(parsing: input)
        catchUp()
        let before = total(project, on: day)
        let target: TimeInterval = switch input {
        case .absolute(let seconds): TimeInterval(seconds)
        case .relative(let seconds): max(0, before + TimeInterval(seconds))
        }
        let now = now
        let project = rows(day).first { ProjectName.matches($0.project, project) }?.project ?? labels.shownName(project)
        func difference(_ entries: [Entry]) -> Int {
            Int((target - Self.sum(of: project, in: entries, asOf: now)).rounded())
        }
        func outcome() -> Adjustment {
            Adjustment(project: project, day: day, before: before.wholeSeconds,
                       after: total(project, on: day).wholeSeconds)
        }
        guard difference(files.entries(on: day)) != 0 else { return outcome() }
        // The difference is taken again from the Entries as re-read, so a hand edit can't skew it.
        try files.change([day]) { _, entries in
            let seconds = difference(entries)
            if seconds != 0 { entries.append(.manual(project: project, seconds: seconds, note: .adjustment)) }
        }
        return outcome()
    }

    /// Brings `now` up to the clock and the Day files up to today: after midnight every running timer is
    /// split at the start of each new Day, so every Day's file holds only that Day's time. Deferred writes
    /// are retried, and Entries left open in a Day file that parsed again are recovered. Every command
    /// starts with this.
    func catchUp() {
        now = clock.now
        apply(files.catchUp(to: today, carrying: Array(timers)))
    }

    /// Takes the running timers from what `DayFiles.catchUp` carried into today, if it moved to today, and
    /// recovers the Days that parsed again.
    private func apply(_ caught: DayFiles.CatchUp) {
        guard let carried = caught.carried else { return recover(reparsed: caught.reparsed) }
        refresh(known: carried, reparsed: caught.reparsed)
    }

    /// Ends every open Entry at `end`, or with `project` only that Project's.
    private static func close(_ entries: inout [Entry], at end: Date, only project: String? = nil) {
        entries = entries.map { entry in
            if let project, !ProjectName.matches(entry.project, project) { return entry }
            return entry.closed(at: end)
        }
    }
}

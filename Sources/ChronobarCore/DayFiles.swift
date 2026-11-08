import Foundation
import Observation

/// Core's view of the Day files: each Day's Entries, read once and kept until the next `load`, and writes
/// to a malformed file, deferred until it parses. The loaded Day (the running timers') is held in memory,
/// so timers keep running while its file won't parse.
///
/// Every change goes through here, one of two ways. An All-or-nothing change (`change`) reads every Day it
/// covers first and refuses the whole change if one won't parse or still has deferred writes, then saves
/// every changed Day, with any Label-list writes, or none. A deferring change (`changeOrDefer`), for
/// pausing, quitting, rollover and crash recovery, never refuses for a malformed file: it waits until the
/// file parses. The midnight rules (where a Day ends, cutting a span into Days, following a run back across
/// its splits) live here too, so no caller works out midnight itself.
@MainActor @Observable
final class DayFiles {
    /// Days whose file failed to parse when last read. Writes to them are refused until it parses again.
    private(set) var malformed: Set<Day> = []
    /// The loaded Day's Entries.
    private(set) var loadedEntries: [Entry] = []
    /// The Day `loadedEntries` came from. It lags today from midnight until the next `catchUp`.
    @ObservationIgnored private(set) var loadedDay: Day

    @ObservationIgnored private let store: DayStore
    @ObservationIgnored private let clock: TimeSource
    /// Other Days' Entries, read on first use and dropped on `load` so hand edits show up.
    @ObservationIgnored private var otherDays: [Day: [Entry]] = [:]
    /// The Days with a file, listed on first use and dropped on `load` like `otherDays`.
    @ObservationIgnored private var listedDays: [Day]?
    /// Writes deferred because their Day's file was malformed, oldest first. Retried before every change and
    /// on `catchUp`; lost on quit, which leaves the open Entry for crash recovery.
    @ObservationIgnored private var pending: [(day: Day, change: (inout [Entry]) -> Void)] = []
    /// Days that were malformed and have since parsed, until handed out once their deferred writes landed.
    @ObservationIgnored private var reparsed: Set<Day> = []

    private var calendar: Calendar { clock.calendar }

    init(root: URL, clock: TimeSource) {
        self.store = DayStore(root: root)
        self.clock = clock
        self.loadedDay = Day(containing: clock.now, in: clock.calendar)
    }

    // MARK: Reading

    /// Every Day with a file, newest first. The folder is listed once until the next `load`, so views can
    /// ask while rendering; Days this writes to are added as they are written.
    func days() -> [Day] {
        if let listedDays { return listedDays }
        let days = store.days()
        listedDays = days
        return days
    }

    /// The Day's Entries: the loaded Day's from memory, any other Day's from its file, read once until the
    /// next `load`. A missing file is empty; a malformed one is flagged and reads as just its deferred writes.
    func entries(on day: Day) -> [Entry] {
        if day == loadedDay { return loadedEntries }
        if let cached = otherDays[day] { return cached }
        let entries = (try? read(day)) ?? replayed(day)
        otherDays[day] = entries
        return entries
    }

    /// The Day's Entries as its file holds them now; nil if it won't parse, which is flagged in `malformed`.
    func reread(_ day: Day) -> [Entry]? {
        try? read(day)
    }

    /// Retries deferred writes, then throws `MalformedDayFile` if `day`'s file won't parse or writes to it
    /// are still waiting: the check an All-or-nothing change makes of each Day before changing any.
    func checkReadable(_ day: Day) throws {
        retryPending()
        _ = try strictRead(day)
    }

    /// Retries deferred writes and forgets other Days' Entries, then loads `day`. If its file won't parse
    /// its last good read is kept (for a Day not loaded before, just its deferred writes). Returns the Days
    /// that have parsed again, as `catchUp` does.
    func load(_ day: Day) -> Set<Day> {
        otherDays = [:]
        listedDays = nil
        retryPending()
        if let entries = try? read(day) {
            loadedEntries = entries
        } else if loadedDay != day {
            loadedEntries = replayed(day)
        }
        loadedDay = day
        return takeReparsed()
    }

    // MARK: Changing

    /// An All-or-nothing change: retries deferred writes, then reads every one of `days` from its file and
    /// applies `edit` to each Day's Entries as just read, never as cached earlier, so a hand edit made
    /// since is kept. Saves every Day whose Entries changed, with `others`, all or none. Throws
    /// `MalformedDayFile` before changing anything if a Day won't parse or still has deferred writes, and
    /// whatever `edit` throws.
    func change(
        _ days: some Sequence<Day>, alongWith others: [FileWrite] = [], _ edit: (Day, inout [Entry]) throws -> Void
    ) throws {
        retryPending()
        let read = try Set(days).sorted().map { day in (day, try strictRead(day)) }
        var changed: [(Day, [Entry])] = []
        for (day, entries) in read {
            var edited = entries
            try edit(day, &edited)
            if edited != entries { changed.append((day, edited)) }
        }
        try store.save(changed, alongWith: others, timeZone: calendar.timeZone)
        for (day, entries) in changed { remember(day, entries) }
    }

    /// A deferring change: re-reads `day`'s file, applies `edit` and writes it back, after any earlier
    /// deferred writes to it. If the file won't parse, `edit` is applied to the loaded Entries only (when
    /// `day` is the loaded Day) and queued until the file parses.
    func changeOrDefer(_ day: Day, _ edit: @escaping (inout [Entry]) -> Void) throws {
        retryPending()
        do {
            // Behind earlier deferred writes, this one waits its turn.
            if !hasPending(day) { return try write(day, edit) }
        } catch is DayFile.Malformed {}
        if day == loadedDay { edit(&loadedEntries) }
        pending.append((day, edit))
    }

    // MARK: Catching up

    /// What `catchUp` did.
    struct CatchUp {
        /// The running timers as carried over into today, each from today's midnight unless it started
        /// today; nil if the loaded Day was today already, so nothing was carried or loaded.
        let carried: [Running]?
        /// The Days that were malformed and have parsed again, with their deferred writes landed.
        let reparsed: Set<Day>
    }

    /// Brings the Day files up to `today`. If the loaded Day (or `day`, for timers found open there) is
    /// earlier, closes every open Entry at each midnight since and carries `running` into the Day after, each
    /// Day's writes deferred if its file won't parse, then loads today. Either way retries deferred writes.
    func catchUp(to today: Day, carrying running: [Running], from day: Day? = nil) -> CatchUp {
        if let day { move(to: day) }
        guard loadedDay != today else {
            retryPending()
            return CatchUp(carried: nil, reparsed: takeReparsed())
        }
        var carried = running
        while !carried.isEmpty, loadedDay < today {
            let midnight = end(of: loadedDay)
            let next = Day(containing: midnight, in: calendar)
            carried = carried.map { Running(project: $0.project, start: midnight, source: $0.source) }
            let opened = carried
            try? changeOrDefer(loadedDay) { $0 = $0.map { $0.closed(at: midnight) } }
            try? changeOrDefer(next) { entries in
                entries += opened.map { .timed(project: $0.project, start: midnight, end: nil, source: $0.source) }
            }
            // Load the new Day as written, or as its deferred writes leave it if its file won't parse.
            move(to: next)
        }
        return CatchUp(carried: carried, reparsed: load(today))
    }

    // MARK: Midnight

    /// The moment `day` ends and the next Day starts: its midnight, or where daylight saving skips
    /// midnight, the first moment of the next Day.
    func end(of day: Day) -> Date {
        calendar.dateInterval(of: .day, for: day.noon(in: calendar))!.end
    }

    /// The first moment of `day`.
    func start(of day: Day) -> Date {
        calendar.startOfDay(for: day.noon(in: calendar))
    }

    /// `start` to `end` (nil: still running, up to `today`) cut at each midnight, one piece per Day, oldest
    /// first.
    func cut(from start: Date, to end: Date?, through today: Day) -> [DayPiece] {
        var pieces: [DayPiece] = []
        var from = start
        while true {
            let day = Day(containing: from, in: calendar)
            let midnight = self.end(of: day)
            if let end, end <= midnight { return pieces + [DayPiece(day: day, start: from, end: end)] }
            if end == nil, day >= today { return pieces + [DayPiece(day: day, start: from, end: nil)] }
            pieces.append(DayPiece(day: day, start: from, end: midnight))
            from = midnight
        }
    }

    /// The Entries `timer`'s run is stored as, oldest first: its own open Entry last, and before it, for a
    /// timer carried over at midnight, each Entry on an earlier Day it was split from, as last read.
    func run(of timer: Running) -> [DayPiece] {
        run(of: timer, reading: entries(on:))
    }

    /// `run(of:)` from the files as they are now. Throws `MalformedDayFile` if a Day the run may reach back
    /// into won't parse or still has deferred writes, as the run's start can't be known then.
    func readRun(of timer: Running) throws -> [DayPiece] {
        retryPending()
        return try run(of: timer, reading: strictRead)
    }

    /// Follows `timer` back while each piece starts at midnight, reading the Day before with `read`.
    private func run(of timer: Running, reading read: (Day) throws -> [Entry]) rethrows -> [DayPiece] {
        var pieces = [DayPiece(day: Day(containing: timer.start, in: calendar), start: timer.start, end: nil)]
        while pieces[0].start == start(of: pieces[0].day) {
            let day = pieces[0].day.adding(days: -1, in: calendar)
            let split = try read(day).lazy.compactMap { entry -> Date? in
                guard case .timed(let project, let from, pieces[0].start?, _) = entry,
                      ProjectName.matches(project, timer.project) else { return nil }
                return from
            }.first
            guard let split else { break }
            pieces.insert(DayPiece(day: day, start: split, end: pieces[0].start), at: 0)
        }
        return pieces
    }

    // MARK: Internals

    /// Whether writes to `day` are still waiting for its file to parse.
    private func hasPending(_ day: Day) -> Bool { pending.contains { $0.day == day } }

    /// `day`'s Entries from its file, refusing with `MalformedDayFile` if it won't parse or still has
    /// deferred writes. The one place that error is raised.
    private func strictRead(_ day: Day) throws -> [Entry] {
        guard !hasPending(day) else { throw MalformedDayFile(day: day) }
        do { return try read(day) } catch is DayFile.Malformed { throw MalformedDayFile(day: day) }
    }

    /// The Days that parsed again and have no deferred writes left. Those still waiting stay for later.
    private func takeReparsed() -> Set<Day> {
        let ready = reparsed.filter { !hasPending($0) }
        reparsed.subtract(ready)
        return ready
    }

    /// Makes `day` the loaded Day, with its Entries as last read.
    private func move(to day: Day) {
        guard day != loadedDay else { return }
        loadedEntries = entries(on: day)
        otherDays[day] = nil
        loadedDay = day
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

    /// Loads `day`'s file, recording in `malformed` whether it parsed. Throws `DayFile.Malformed`.
    private func read(_ day: Day) throws -> [Entry] {
        do {
            let entries = try store.load(day)
            // Only touch the observable set on a change: views read past Days while rendering.
            if malformed.contains(day) {
                malformed.remove(day)
                reparsed.insert(day)
            }
            return entries
        } catch {
            if !malformed.contains(day) { malformed.insert(day) }
            throw error
        }
    }

    /// Re-reads `day`'s file, applies `change` and writes it back.
    private func write(_ day: Day, _ change: (inout [Entry]) -> Void) throws {
        var entries = try read(day)
        change(&entries)
        try store.save([(day, entries)], timeZone: calendar.timeZone)
        remember(day, entries)
    }

    /// Keeps `entries`, just written, as `day`'s.
    private func remember(_ day: Day, _ entries: [Entry]) {
        if let listed = listedDays, !listed.contains(day) { listedDays = (listed + [day]).sorted(by: >) }
        if day == loadedDay { loadedEntries = entries } else { otherDays[day] = entries }
    }

    /// A malformed Day as its deferred writes would leave an empty file.
    private func replayed(_ day: Day) -> [Entry] {
        var entries: [Entry] = []
        for (pendingDay, change) in pending where pendingDay == day { change(&entries) }
        return entries
    }
}

/// One Day's part of a stretch of time cut at midnight.
struct DayPiece: Equatable {
    let day: Day
    let start: Date
    /// Nil for a piece still running.
    let end: Date?
}

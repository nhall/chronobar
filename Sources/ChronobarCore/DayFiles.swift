import Foundation
import Observation

/// Core's view of the Day files: each Day's Entries, read once and kept until the next `load`, and writes
/// to a malformed file, deferred until it parses. The loaded Day (the running timer's) is held in memory,
/// so a timer keeps running while its file won't parse.
@MainActor @Observable
final class DayFiles {
    /// Days whose file failed to parse when last read. Writes to them are refused until it parses again.
    private(set) var malformed: Set<Day> = []
    /// The loaded Day's Entries.
    private(set) var loadedEntries: [Entry] = []
    /// The Day `loadedEntries` came from. It lags today from midnight until the next tick or command.
    @ObservationIgnored private(set) var loadedDay: Day

    @ObservationIgnored private let store: DayStore
    @ObservationIgnored private let clock: TimeSource
    /// Other Days' Entries, read on first use and dropped on `load` so hand edits show up.
    @ObservationIgnored private var otherDays: [Day: [Entry]] = [:]
    /// The Days with a file, listed on first use and dropped on `load` like `otherDays`.
    @ObservationIgnored private var listedDays: [Day]?
    /// Writes deferred because their Day's file was malformed, oldest first. Retried before every write and
    /// on `retryPending()`; lost on quit, which leaves the open Entry for crash recovery.
    @ObservationIgnored private var pending: [(day: Day, change: (inout [Entry]) -> Void)] = []
    /// Days that were malformed and have since parsed.
    @ObservationIgnored private var reparsed: Set<Day> = []

    init(root: URL, clock: TimeSource) {
        self.store = DayStore(root: root)
        self.clock = clock
        self.loadedDay = Day(containing: clock.now, in: clock.calendar)
    }

    /// Every Day with a file, newest first. The folder is listed once until the next `load`, so views can
    /// ask while rendering; Days this writes to are added as they are written.
    func days() -> [Day] {
        if let listedDays { return listedDays }
        let days = store.days()
        listedDays = days
        return days
    }

    /// Whether writes to `day` are still waiting for its file to parse.
    func hasPending(_ day: Day) -> Bool { pending.contains { $0.day == day } }

    /// The Days that were malformed and have parsed since the last call.
    func takeReparsed() -> Set<Day> {
        defer { reparsed = [] }
        return reparsed
    }

    /// Retries deferred writes and forgets other Days' Entries, then loads `day`. If its file won't parse
    /// its last good read is kept (for a Day not loaded before, just its deferred writes).
    func load(_ day: Day) {
        otherDays = [:]
        listedDays = nil
        retryPending()
        if let entries = try? read(day) {
            loadedEntries = entries
        } else if loadedDay != day {
            loadedEntries = replayed(day)
        }
        loadedDay = day
    }

    /// Makes `day` the loaded Day, with its Entries as last read.
    func move(to day: Day) {
        guard day != loadedDay else { return }
        loadedEntries = entries(on: day)
        otherDays[day] = nil
        loadedDay = day
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

    /// Re-reads `day`'s file, applies `change` and writes it back, after any earlier deferred writes to
    /// it. If the file is malformed the write is refused, or with `deferringIfMalformed` applied to the
    /// loaded Entries only and queued until the file parses.
    func update(
        _ day: Day, deferringIfMalformed: Bool = false, _ change: @escaping (inout [Entry]) -> Void
    ) throws {
        retryPending()
        do {
            guard !hasPending(day) else { throw DayFile.Malformed() }
            try write(day, change)
        } catch is DayFile.Malformed where deferringIfMalformed {
            if day == loadedDay { change(&loadedEntries) }
            pending.append((day, change))
        }
    }

    /// Replaces `day`'s Entries.
    func save(_ day: Day, _ entries: [Entry]) throws {
        try write(day) { $0 = entries }
    }

    /// Applies deferred writes in order. A Day whose file still won't parse keeps its writes queued.
    func retryPending() {
        var blocked: Set<Day> = []
        pending = pending.filter { day, change in
            guard !blocked.contains(day), (try? write(day, change)) != nil else {
                blocked.insert(day)
                return true
            }
            return false
        }
    }

    /// Loads `day`'s file, recording in `malformed` whether it parsed.
    func read(_ day: Day) throws -> [Entry] {
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
        try store.save(day, entries, timeZone: clock.calendar.timeZone)
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

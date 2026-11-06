import Foundation

/// A timed Entry as a correction stored it.
public struct TimedEntry: Equatable, Sendable {
    public let project: String
    public let start: Date
    /// Nil for the running timer's Entry.
    public let end: Date?
    public let source: EntrySource

    public init(project: String, start: Date, end: Date?, source: EntrySource) {
        self.project = project
        self.start = start
        self.end = end
        self.source = source
    }

    /// The Day the Entry is stored on.
    public func day(in calendar: Calendar) -> Day { Day(containing: start, in: calendar) }
}

/// A correction named a Project with no running timer.
public struct NotRunning: Error, Equatable {
    public let project: String

    public init(project: String) { self.project = project }
}

/// A correction gave a time after now, which would book time that hasn't happened.
public struct FutureTime: Error, Equatable {
    public let time: Date
}

/// A duration was added to a Day after today.
public struct FutureDay: Error, Equatable {
    public let day: Day

    public init(day: Day) { self.day = day }
}

/// A correction's end isn't after its start, which would book no time or negative time.
public struct EndBeforeStart: Error, Equatable {
    public let start: Date
    public let end: Date
}

/// A correction would put time on the Project where it already has some, counting it twice.
public struct Overlap: Error, Equatable {
    public let project: String
    /// The Project's Entry already covering part of that time; a running one ends at nil.
    public let start: Date
    public let end: Date?
}

/// Corrections after the fact. Each one checks its times, then reads every Day it writes before writing
/// any, so a refusal changes nothing.
extension Tracker {
    /// Stops `name`'s timer at `end`, a time in its run up to now. For a timer carried over at midnight
    /// `end` may fall on an earlier Day: the run's Entries after it are removed. Returns the Entry that
    /// now ends at `end`.
    public func stop(_ name: String, at end: Date) throws -> TimedEntry {
        catchUp()
        guard let timer = timers[name] else { throw NotRunning(project: ProjectName.trimmed(name)) }
        let pieces = try readablePieces(of: timer)
        guard end <= now else { throw FutureTime(time: end) }
        guard end > pieces[0].start else { throw EndBeforeStart(start: pieces[0].start, end: end) }
        let stored = split(timer.project, from: pieces[0].start, to: end, source: timer.source)
        try replace(timer.project, pieces, with: stored)
        return stored.last!
    }

    /// Moves the start of `name`'s timer to `start`, any time up to now. A start before today's midnight
    /// puts that time on the Days before, as if the timer had run over midnight; a later one takes the
    /// run's time off the Days before. Refused if the Project already has time in the new stretch.
    /// Returns the run's Entries, oldest first: the timer's open Entry last, which starts at today's
    /// midnight for a run from an earlier Day, after the finished ones on the Days before.
    @discardableResult
    public func setStart(_ name: String, at start: Date) throws -> [TimedEntry] {
        catchUp()
        guard let timer = timers[name] else { throw NotRunning(project: ProjectName.trimmed(name)) }
        guard start <= now else { throw FutureTime(time: start) }
        let stored = split(timer.project, from: start, to: nil, source: timer.source)
        try replace(timer.project, try readablePieces(of: timer), with: stored)
        return stored
    }

    /// Adds a finished timed Entry for `name` from `start` to `end`, up to now, without starting a timer,
    /// cut at each midnight so every Day holds its own part. An archived Project comes back. Refused if the
    /// Project already has time in that stretch. Returns the Entries stored, one per Day, oldest first.
    @discardableResult
    public func addEntry(_ name: String, start: Date, end: Date, source: EntrySource = .app) throws -> [TimedEntry] {
        catchUp()
        guard end > start else { throw EndBeforeStart(start: start, end: end) }
        guard end <= now else { throw FutureTime(time: end) }
        let name = ProjectName.trimmed(name)
        guard !name.isEmpty else { throw EmptyProjectName() }
        // Checked under the name as typed first, so a refusal doesn't take the Project off `archived.txt`.
        _ = try replacing(name, [], with: split(name, from: start, to: end, source: source))
        let project = try resolve(name)
        let stored = split(project, from: start, to: end, source: source)
        try replace(project, [], with: stored)
        return stored
    }

    /// Adds a typed duration (`1:30`, `45`) to `name` on `day` as a manual Entry, as `log` does, but only
    /// up to today: time on a future Day hasn't happened.
    @discardableResult
    public func addEntry(_ name: String, duration: String, on day: Day) throws -> String {
        catchUp()
        guard day <= today else { throw FutureDay(day: day) }
        do { return try log(name, duration, on: day) } catch is DayFile.Malformed { throw MalformedDayFile(day: day) }
    }

    /// `timer`'s run as `runPieces` finds it. Throws if a Day the run may reach back into won't parse, as
    /// the run's start can't be known then.
    private func readablePieces(of timer: Running) throws -> [(day: Day, start: Date)] {
        let pieces = runPieces(of: timer)
        let first = pieces[0]
        if first.start == calendar.startOfDay(for: first.day.noon(in: calendar)) {
            let before = first.day.adding(days: -1, in: calendar)
            if files.hasPending(before) || (try? files.read(before)) == nil {
                throw MalformedDayFile(day: before)
            }
        }
        return pieces
    }

    /// `start` to `end` (nil: still running, today) as one timed Entry per Day, cut at each midnight.
    private func split(_ project: String, from start: Date, to end: Date?, source: EntrySource) -> [TimedEntry] {
        var pieces: [TimedEntry] = []
        var from = start
        while true {
            let day = Day(containing: from, in: calendar)
            let midnight = calendar.dateInterval(of: .day, for: day.noon(in: calendar))!.end
            if let end, end <= midnight {
                pieces.append(TimedEntry(project: project, start: from, end: end, source: source))
                return pieces
            }
            if end == nil, day >= today {
                pieces.append(TimedEntry(project: project, start: from, end: nil, source: source))
                return pieces
            }
            pieces.append(TimedEntry(project: project, start: from, end: midnight, source: source))
            from = midnight
        }
    }

    /// Replaces the Project's Entries starting at `old` (a run's pieces, or none) with `new`, each in
    /// place on its Day, or appended where that Day had none. Then reloads, so the timers match the file.
    /// Refused if a Day won't parse, or if `new` overlaps the Project's other timed Entries.
    private func replace(_ project: String, _ old: [(day: Day, start: Date)], with new: [TimedEntry]) throws {
        for (day, entries) in try replacing(project, old, with: new) { try files.save(day, entries) }
        reload()
    }

    /// Each Day's Entries as `replace` would write them.
    private func replacing(
        _ project: String, _ old: [(day: Day, start: Date)], with new: [TimedEntry]
    ) throws -> [(Day, [Entry])] {
        let days = Set(old.map(\.day) + new.map { $0.day(in: calendar) }).sorted()
        files.retryPending()
        var changed: [(Day, [Entry])] = []
        for day in days {
            guard !files.hasPending(day) else { throw MalformedDayFile(day: day) }
            var entries: [Entry]
            do { entries = try files.read(day) } catch is DayFile.Malformed { throw MalformedDayFile(day: day) }
            let replaced = old.first { $0.day == day }.flatMap { piece in
                entries.firstIndex { entry in
                    guard case .timed(let name, piece.start, _, _) = entry else { return false }
                    return ProjectName.matches(name, project)
                }
            }
            if let replaced { entries.remove(at: replaced) }
            let added = new.filter { $0.day(in: calendar) == day }
            if let overlap = overlap(of: added, with: entries) { throw overlap }
            let timed = added.map { Entry.timed(project: $0.project, start: $0.start, end: $0.end, source: $0.source) }
            entries.insert(contentsOf: timed, at: replaced ?? entries.endIndex)
            changed.append((day, entries))
        }
        return changed
    }

    /// The first of the Project's timed `entries` sharing time with one of `added`, as an `Overlap`.
    private func overlap(of added: [TimedEntry], with entries: [Entry]) -> Overlap? {
        for new in added {
            for case .timed(let project, let start, let end, _) in entries
            where ProjectName.matches(project, new.project) && start < (new.end ?? now) && new.start < (end ?? now) {
                return Overlap(project: project, start: start, end: end)
            }
        }
        return nil
    }
}

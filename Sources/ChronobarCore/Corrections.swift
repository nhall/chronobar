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

/// A relabel named a Label with no Entries on its Day, so there is no row to move.
public struct NoTimeOnDay: Error, Equatable {
    public let project: String
    public let day: Day

    public init(project: String, day: Day) {
        self.project = project
        self.day = day
    }
}

/// A relabel this version doesn't make yet. Each is refused and changes nothing.
public struct UnsupportedRelabel: Error, Equatable {
    public enum Reason: Sendable {
        /// The Label's Timer is running and its run reaches the Day.
        case running
        /// The new Label already has time on the Day, so the rows would merge.
        case merge
        /// The new Label is the same Label spelled with other capitals or spaces.
        case respelling
    }

    /// The running or respelled Label, or the one the rows would merge into, as stored.
    public let project: String
    public let reason: Reason

    public init(project: String, reason: Reason) {
        self.project = project
        self.reason = reason
    }
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
        let pieces = try files.readRun(of: timer)
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
        try replace(timer.project, try files.readRun(of: timer), with: stored)
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
        return try labels.resolvingForWrite(name) { project, bringingBack in
            let stored = split(project, from: start, to: end, source: source)
            try replace(project, [], with: stored, alongWith: bringingBack)
            return stored
        }
    }

    /// Adds a typed duration (`1:30`, `45`) to `name` on `day` as a manual Entry, as `log` does, but only
    /// up to today: time on a future Day hasn't happened. Returns what it stored, as `log` does.
    @discardableResult
    public func addEntry(_ name: String, duration: String, on day: Day) throws -> Logged {
        catchUp()
        guard day <= today else { throw FutureDay(day: day) }
        return try log(name, duration, on: day)
    }

    /// Relabels `name`'s row on `day`: moves every one of its Entries there, timed and manual, adjustments
    /// included, to `newName`, written under its stored spelling as for start. The Label on other Days is
    /// untouched, and an archived new Label comes back. Relabeling to the row's own spelling changes
    /// nothing. Refused if the Label has no Entries on `day` or `day`'s file won't parse or has writes
    /// waiting; and, for now, for a running Timer's run, a new Label with time on `day` already, and a fix of
    /// capitalisation or spacing alone. Returns what it stored.
    @discardableResult
    public func relabel(_ name: String, to newName: String, on day: Day) throws -> Relabeling {
        catchUp()
        let target = ProjectName.trimmed(newName)
        guard !target.isEmpty else { throw EmptyProjectName() }
        try files.checkReadable(day)
        guard let row = rows(day).first(where: { ProjectName.matches($0.project, name) }) else {
            throw NoTimeOnDay(project: ProjectName.trimmed(name), day: day)
        }
        if ProjectName.matches(row.project, target) {
            guard target == row.project else { throw UnsupportedRelabel(project: row.project, reason: .respelling) }
            return relabeling(row.project, on: day)
        }
        if let timer = timers[name], try files.readRun(of: timer).contains(where: { $0.day == day }) {
            throw UnsupportedRelabel(project: timer.project, reason: .running)
        }
        return try labels.resolvingForWrite(target) { project, bringingBack in
            // Checked again on the Entries as re-read, so a hand edit since can't slip past.
            try files.change([day], alongWith: bringingBack) { _, entries in
                guard entries.contains(where: { ProjectName.matches($0.project, name) }) else {
                    throw NoTimeOnDay(project: ProjectName.trimmed(name), day: day)
                }
                if entries.contains(where: { ProjectName.matches($0.project, project) }) {
                    throw UnsupportedRelabel(project: project, reason: .merge)
                }
                entries = entries.map { ProjectName.matches($0.project, name) ? $0.relabeled(project) : $0 }
            }
            reread()
            return relabeling(project, on: day)
        }
    }

    /// The Label's row on `day` as a relabel returns it: its timed Entries there and its Total.
    private func relabeling(_ project: String, on day: Day) -> Relabeling {
        let entries = files.entries(on: day).compactMap { entry -> TimedEntry? in
            guard case .timed(let label, let start, let end, let source) = entry,
                  ProjectName.matches(label, project) else { return nil }
            return TimedEntry(project: label, start: start, end: end, source: source)
        }
        return Relabeling(project: project, day: day, entries: entries, total: total(project, on: day).wholeSeconds)
    }

    /// `start` to `end` (nil: still running, today) as one timed Entry per Day, cut at each midnight.
    private func split(_ project: String, from start: Date, to end: Date?, source: EntrySource) -> [TimedEntry] {
        files.cut(from: start, to: end, through: today).map { piece in
            TimedEntry(project: project, start: piece.start, end: piece.end, source: source)
        }
    }

    /// Replaces the Project's Entries starting at `old` (a run's pieces, or none) with `new`, each in
    /// place on its Day, or appended where that Day had none, writing `others` too: one All-or-nothing
    /// change. Then re-reads, so the timers match the file. Refused if a Day won't parse, or if `new`
    /// overlaps the Project's other timed Entries.
    private func replace(
        _ project: String, _ old: [DayPiece], with new: [TimedEntry], alongWith others: [FileWrite] = []
    ) throws {
        let days = old.map(\.day) + new.map { $0.day(in: calendar) }
        try files.change(days, alongWith: others) { day, entries in
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
        }
        reread()
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

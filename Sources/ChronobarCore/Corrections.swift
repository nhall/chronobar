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

/// A relabel onto a Label whose Timer is running and reaches the Day: the row would merge into a running
/// row, and a running row would put two Timers on one Label. Refused, changing nothing.
public struct NewLabelRunning: Error, Equatable {
    /// The new Label, as its Timer stores it.
    public let project: String

    public init(project: String) { self.project = project }
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
    /// included, to `newName`, written under its stored spelling as for start. A new Label with time on `day`
    /// already gets the moved Entries beside its own, merging the rows; refused with `Overlap` if timed
    /// Entries of the two would share time. The Label on other Days is untouched, and an archived new Label
    /// comes back; the old Label's lists are left alone. A fix of capitals or spaces alone is written as
    /// typed, and respells the Label on the Pinned or Archived Labels too, in the same save. Relabeling to
    /// the row's own spelling changes nothing. A running row's Timer runs on under the new Label as the
    /// same Timer: its start, Source and Long-running warning stay. Where that run began on an earlier Day,
    /// or runs on past `day`, its pieces on those Days move too, and only they: the one case reaching past
    /// `day`, and every Day it touches is checked and written together. A stopped run's pieces are separate
    /// rows, so only `day`'s moves. Refused with `NewLabelRunning` where the new Label's Timer runs on a Day
    /// being relabeled, unless it is the row's own Timer and only its capitals or spaces change. Refused too
    /// if the Label has no Entries on `day`, a Day's file won't parse or has writes waiting, or a Label list
    /// won't parse. Returns what it stored.
    @discardableResult
    public func relabel(_ name: String, to newName: String, on day: Day) throws -> Relabeling {
        catchUp()
        let target = ProjectName.trimmed(newName)
        guard !target.isEmpty else { throw EmptyProjectName() }
        try files.checkReadable(day)
        guard let row = rows(day).first(where: { ProjectName.matches($0.project, name) }) else {
            throw NoTimeOnDay(project: ProjectName.trimmed(name), day: day)
        }
        if target == row.project { return relabeling(row.project, from: row.project, on: day) }
        let run = try run(of: name, reaching: day)
        let moving = run.isEmpty ? nil : timers[name]
        let days = Set([day] + run.map(\.day))
        // Two Timers never share a Label; a fix of capitals or spaces keeps the one it has.
        if !ProjectName.matches(target, name) { try refuseRunning(target, on: days) }
        return try labels.resolvingForRelabel(row.project, to: target) { project, lists in
            try files.change(days, alongWith: lists) { changing, entries in
                // `day`'s whole row moves; on another Day only the run's piece does, not the Label's other time.
                let piece = changing == day ? nil : run.first { $0.day == changing }
                try move(name, to: project, only: piece, in: &entries, on: changing)
            }
            reread()
            if let moving, let timer = timers[project] { rekeyWarning(from: moving.project, to: timer) }
            return relabeling(project, from: row.project, on: day)
        }
    }

    /// The run of `name`'s Timer, oldest piece first, if it reaches `day`, as read now; empty if `name` isn't
    /// running or its run doesn't reach `day`. A relabel moves all of it, its pieces on other Days included,
    /// so it stays one Timer that can still be stopped or moved back past midnight.
    private func run(of name: String, reaching day: Day) throws -> [DayPiece] {
        guard let timer = timers[name] else { return [] }
        let pieces = try files.readRun(of: timer)
        return pieces.contains { $0.day == day } ? pieces : []
    }

    /// Refuses with `NewLabelRunning` if `project`'s Timer runs on one of `days`.
    private func refuseRunning(_ project: String, on days: Set<Day>) throws {
        guard let timer = timers[project],
              try files.readRun(of: timer).contains(where: { days.contains($0.day) }) else { return }
        throw NewLabelRunning(project: timer.project)
    }

    /// Moves `name`'s Entries in `entries`, `day`'s as just re-read, to `project`: all of them, or with
    /// `piece` only the run's Entry starting there. Unless only capitals or spaces change, it is a merge,
    /// refused with `NewLabelRunning` if `project` has an open Entry there and with `Overlap` where the moved
    /// timed Entries share time with its own. Refused with `NoTimeOnDay` if nothing moves.
    private func move(
        _ name: String, to project: String, only piece: DayPiece?, in entries: inout [Entry], on day: Day
    ) throws {
        let moves = { (entry: Entry) -> Bool in
            guard ProjectName.matches(entry.project, name) else { return false }
            guard let piece else { return true }
            return entry.timedEntry?.start == piece.start
        }
        guard entries.contains(where: moves) else {
            throw NoTimeOnDay(project: ProjectName.trimmed(name), day: day)
        }
        if !ProjectName.matches(project, name) {
            // Checked again on the Entries as re-read, so a Timer started by a hand edit since can't slip past.
            let open = entries.lazy.compactMap(\.openTimer)
            if let timer = open.first(where: { ProjectName.matches($0.project, project) }) {
                throw NewLabelRunning(project: timer.project)
            }
            let moved = entries.filter(moves).compactMap { $0.relabeled(project).timedEntry }
            if let overlap = overlap(of: moved, with: entries) { throw overlap }
        }
        entries = entries.map { moves($0) ? $0.relabeled(project) : $0 }
    }

    /// The Label's row on `day` as a relabel from `old` returns it: its timed Entries there, its Total and
    /// its Timer if that runs on `day`.
    private func relabeling(_ project: String, from old: String, on day: Day) -> Relabeling {
        let entries = files.entries(on: day).filter { ProjectName.matches($0.project, project) }
            .compactMap(\.timedEntry)
        let timer = timers[project].flatMap { timer in
            files.run(of: timer).contains { $0.day == day } ? timer : nil
        }
        return Relabeling(oldProject: old, project: project, day: day, entries: entries,
                          total: total(project, on: day).wholeSeconds, timer: timer)
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

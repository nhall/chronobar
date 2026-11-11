import Foundation
import ChronobarCore

/// Fixing recordings after the fact: `stop` at a time, `set_start`, `add_entry` and `adjust`. Core checks
/// the times and refuses anything that would book time that hasn't happened or count time twice.
extension Operations {
    func stop(_ label: String?, at end: Date) throws(OperationError) -> StopResult {
        let label = try namedOrOnlyRunning(label)
        let entry = try core { try tracker.stop(label, at: end) }
        return StopResult(entry: result(entry), running: runningTimers(), today: todayResult())
    }

    func setStart(_ label: String?, at start: Date) throws(OperationError) -> SetStartResult {
        let label = try namedOrOnlyRunning(label, to: "move")
        let run = try core { try tracker.setStart(label, at: start) }
        guard let timer = runningTimers().first(where: { ProjectName.matches($0.label, run.last!.project) }) else {
            throw OperationError(.failed, "\(label)'s timer stopped while its start moved.")
        }
        return SetStartResult(timer: timer, earlier: run.dropLast().map(result), today: todayResult())
    }

    func addEntry(_ label: String, _ span: EntrySpan) throws(OperationError) -> AddEntryResult {
        switch span {
        case .times(let start, let end):
            let entries = try core { try tracker.addEntry(label, start: start, end: end, source: .agent) }
            let days = entries.map { $0.day(in: tracker.calendar) }
            return AddEntryResult(label: entries[0].project, entries: entries.map(result), manual: nil,
                                  days: days.map(dayResult))
        case .duration(let duration, let date):
            let day = try date.map(parsedDay) ?? tracker.today
            let logged = try core { try tracker.addEntry(label, duration: duration, on: day) }
            let manual = ManualEntryResult(date: logged.day.description, seconds: logged.seconds,
                                           totalSeconds: totalSeconds(logged.project, on: logged.day))
            return AddEntryResult(label: logged.project, entries: [], manual: manual,
                                  days: [dayResult(logged.day)])
        }
    }

    func adjust(_ label: String, _ input: String, on date: String?) throws(OperationError) -> AdjustResult {
        let label = try named(label)
        let day = try date.map(parsedDay) ?? tracker.today
        let adjustment = try core { try tracker.adjust(label, input, on: day) }
        return AdjustResult(label: adjustment.project, date: adjustment.day.description,
                            changeSeconds: adjustment.change, totalSeconds: adjustment.after,
                            day: dayResult(adjustment.day))
    }

    func relabel(_ label: String, to newLabel: String, on date: String?) throws(OperationError) -> RelabelResult {
        let label = try named(label)
        let day = try date.map(parsedDay) ?? tracker.today
        let relabeling = try core { try tracker.relabel(label, to: newLabel, on: day) }
        return RelabelResult(label: relabeling.project, date: relabeling.day.description,
                             entries: relabeling.entries.map(result), totalSeconds: relabeling.total,
                             day: dayResult(relabeling.day))
    }

    /// The `OperationError` for a correction Core refused, or nil for any other error.
    func correctionError(_ error: any Error) -> OperationError? {
        switch error {
        case let error as NotRunning:
            OperationError(.notRunning, "\(error.project) isn't running.\(runningList())", running: runningTimers())
        case let error as FutureTime:
            OperationError(.futureTime, "\(time(error.time)) is in the future; it's now \(time(tracker.now)). "
                           + "Chronobar only records time that has happened.")
        case let error as FutureDay:
            OperationError(.futureTime, "\(error.day) is after today, so its time hasn't happened yet.")
        case let error as EndBeforeStart:
            OperationError(.endBeforeStart, "The end, \(time(error.end)), isn't after the start, \(time(error.start)).")
        case let error as Overlap:
            OperationError(.overlap, "\(error.project) already has time from \(time(error.start)) to "
                           + "\(error.end.map(time) ?? "now (it's running)"), which this would count twice.")
        case let error as InvalidDuration:
            OperationError(.invalidDuration, "\"\(error.text)\" isn't a duration such as 1:30 or 45 (minutes); "
                           + "adjust also takes a change such as +15 or -10.")
        case let error as NoTimeOnDay:
            OperationError(.unknownLabel, "\(error.project) has no time on \(error.day), so there's nothing to relabel.")
        case let error as UnsupportedRelabel:
            // Refusals until relabel handles these cases; `failed`, so no new error kind goes on the wire.
            switch error.reason {
            case .running:
                OperationError(.failed, "\(error.project)'s timer is running, and Chronobar can't relabel a "
                               + "running timer yet. Stop it first, then relabel.")
            case .merge:
                OperationError(.failed, "\(error.project) already has time that Day, and Chronobar can't merge "
                               + "two rows yet. Pick a Label with no time that Day.")
            }
        default:
            nil
        }
    }

    /// A finished Entry Core stored, with the Label's total on its Day.
    private func result(_ entry: TimedEntry) -> EntryResult {
        let day = entry.day(in: tracker.calendar)
        return EntryResult(label: entry.project, start: entry.start, end: entry.end ?? tracker.now,
                           source: entry.source, totalSeconds: totalSeconds(entry.project, on: day))
    }

    /// `date` as the Day files write it, for a message.
    private func time(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZoneSeparator: .colon, timeZone: timeZone))
    }
}

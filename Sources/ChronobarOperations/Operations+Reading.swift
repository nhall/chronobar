import Foundation
import ChronobarCore

/// The operations that read where time went and keep the Label lists tidy: `day`, `week`, `summary`,
/// `labels`, `pin` and `archive`.
extension Operations {
    func day(_ date: String?) throws(OperationError) -> DayRowsResult {
        let sheet = tracker.daySheet(try date.map(parsedDay) ?? tracker.today)
        return DayRowsResult(
            day: dayResult(sheet),
            rows: sheet.rows.map { row in
                RowResult(label: row.project, totalSeconds: row.time.seconds, totalMinutes: row.time.minutes,
                          running: row.isRunning)
            },
            malformed: sheet.isMalformed)
    }

    func week(_ date: String?) throws(OperationError) -> WeekResult {
        let sheet = tracker.weekSheet(containing: try date.map(parsedDay) ?? tracker.today)
        return WeekResult(first: sheet.first.description, last: sheet.last.description,
                          totalSeconds: sheet.total.seconds, totalMinutes: sheet.total.minutes,
                          elapsedSeconds: sheet.clockTime.seconds, elapsedMinutes: sheet.clockTime.minutes,
                          days: sheet.days.map(dayResult),
                          labels: sheet.lines.map { line in
                              LabelTotalResult(label: line.project, totalSeconds: line.time.seconds,
                                               totalMinutes: line.time.minutes)
                          },
                          malformed: sheet.malformed.map(\.description))
    }

    func summary() -> SummaryResult {
        let periods = tracker.summaryPeriods()
        func period(_ period: SummaryPeriod) -> PeriodResult {
            PeriodResult(first: period.first.description, last: period.last.description,
                         totalSeconds: seconds(period.total), elapsedSeconds: seconds(period.elapsed))
        }
        return SummaryResult(today: period(periods.today), yesterday: period(periods.yesterday),
                             week: period(periods.week), month: period(periods.month))
    }

    func labels(_ query: String?) -> LabelsResult {
        let query = query.map(ProjectName.trimmed) ?? ""
        let labels = tracker.suggestions(for: query).map { label in
            LabelResult(label: label, pinned: tracker.projects.contains { ProjectName.matches($0, label) })
        }
        let match: LabelMatchResult? = switch tracker.match(query) {
        case nil: nil
        case .new: LabelMatchResult(kind: .new, label: nil)
        case .active(let label): LabelMatchResult(kind: .suggested, label: label)
        case .archived(let label): LabelMatchResult(kind: .archived, label: label)
        case .unused(let label): LabelMatchResult(kind: .unused, label: label)
        }
        return LabelsResult(labels: labels, match: match)
    }

    func pin(_ label: String) throws(OperationError) -> PinResult {
        let wasPinned = tracker.isPinned(label)
        let project = try core { try tracker.pinProject(label) }
        return PinResult(label: project, alreadyPinned: wasPinned, pinned: tracker.projects)
    }

    /// Refused for a Label Chronobar doesn't know, as the Panel only offers to archive the Labels it lists.
    func archive(_ label: String) throws(OperationError) -> ArchiveResult {
        let name = ProjectName.trimmed(label)
        guard let match = tracker.match(name) else {
            throw OperationError(.invalidLabel, "The Label is empty. Name the Label to archive.")
        }
        guard match != .new else {
            throw OperationError(.unknownLabel, "No Label is called \(name), so there's nothing to archive. "
                                 + "The labels command lists them.")
        }
        let wasArchived = tracker.archived.contains { ProjectName.matches($0, name) }
        let wasPinned = tracker.isPinned(name)
        let stored = try core { try tracker.archiveProject(name) }
        return ArchiveResult(label: stored, alreadyArchived: wasArchived, unpinned: wasPinned,
                             running: tracker.isRunning(stored))
    }

    /// The Day `date` names as `YYYY-MM-DD`; refused unless it is on the calendar (no 31 November).
    func parsedDay(_ date: String) throws(OperationError) -> Day {
        guard let day = Day(date), Day(containing: day.noon(in: tracker.calendar), in: tracker.calendar) == day else {
            throw OperationError(.invalidDate, "\"\(date)\" isn't a date. Write it YYYY-MM-DD, such as 2026-11-03.")
        }
        return day
    }

    /// `day`'s date, Day total and Clock time, as its Day sheet has them.
    func dayResult(_ day: Day) -> DayResult {
        dayResult(tracker.daySheet(day))
    }

    private func dayResult(_ sheet: DaySheet) -> DayResult {
        DayResult(date: sheet.day.description, totalSeconds: sheet.total.seconds, totalMinutes: sheet.total.minutes,
                  elapsedSeconds: sheet.clockTime.seconds, elapsedMinutes: sheet.clockTime.minutes)
    }
}

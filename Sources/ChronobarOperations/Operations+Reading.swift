import Foundation
import ChronobarCore

/// The operations that read where time went and keep the Label lists tidy: `day`, `week`, `summary`,
/// `labels`, `pin` and `archive`.
extension Operations {
    func day(_ date: String?) throws(OperationError) -> DayRowsResult {
        let day = try date.map(parsedDay) ?? tracker.today
        return DayRowsResult(
            day: dayResult(day),
            rows: tracker.rows(day).map { row in
                RowResult(label: row.project, totalSeconds: seconds(row.total),
                          running: day == tracker.today && tracker.isRunning(row.project))
            },
            malformed: tracker.isMalformed(day))
    }

    func week(_ date: String?) throws(OperationError) -> WeekResult {
        let days = tracker.weekTotals(containing: try date.map(parsedDay) ?? tracker.today).map(\.day)
        var labels: [LabelTotalResult] = []
        for row in days.flatMap(tracker.rows) {
            if let index = labels.firstIndex(where: { ProjectName.matches($0.label, row.project) }) {
                labels[index] = LabelTotalResult(label: labels[index].label,
                                                 totalSeconds: labels[index].totalSeconds + seconds(row.total))
            } else {
                labels.append(LabelTotalResult(label: row.project, totalSeconds: seconds(row.total)))
            }
        }
        let results = days.map(dayResult)
        return WeekResult(first: days[0].description, last: days[6].description,
                          totalSeconds: results.map(\.totalSeconds).reduce(0, +),
                          elapsedSeconds: results.map(\.elapsedSeconds).reduce(0, +),
                          days: results, labels: labels,
                          malformed: days.filter(tracker.isMalformed).map(\.description))
    }

    func summary() -> SummaryResult {
        let summary = tracker.summary()
        let calendar = tracker.calendar
        let today = tracker.today
        let yesterday = today.adding(days: -1, in: calendar)
        let week = today.startOfWeek(in: calendar)
        let days = calendar.range(of: .day, in: .month, for: today.noon(in: calendar))!
        func period(_ first: Day, _ last: Day, _ total: TimeInterval, _ elapsed: TimeInterval) -> PeriodResult {
            PeriodResult(first: first.description, last: last.description, totalSeconds: seconds(total),
                         elapsedSeconds: seconds(elapsed))
        }
        return SummaryResult(
            today: period(today, today, summary.today, summary.elapsed.today),
            yesterday: period(yesterday, yesterday, summary.yesterday, summary.elapsed.yesterday),
            week: period(week, week.adding(days: 6, in: calendar), summary.week, summary.elapsed.week),
            month: period(Day(year: today.year, month: today.month, day: days.lowerBound),
                          Day(year: today.year, month: today.month, day: days.upperBound - 1),
                          summary.month, summary.elapsed.month))
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
        case .archived(let label):
            LabelMatchResult(kind: tracker.archived.contains { ProjectName.matches($0, label) } ? .archived : .unused,
                             label: label)
        }
        return LabelsResult(labels: labels, match: match)
    }

    func pin(_ label: String) throws(OperationError) -> PinResult {
        let wasPinned = isPinned(label)
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
        let wasPinned = isPinned(name)
        try core { try tracker.archiveProject(name) }
        let stored = tracker.archived.first { ProjectName.matches($0, name) } ?? name
        return ArchiveResult(label: stored, alreadyArchived: wasArchived, unpinned: wasPinned,
                             running: tracker.isRunning(stored))
    }

    private func isPinned(_ label: String) -> Bool {
        tracker.projects.contains { ProjectName.matches($0, label) }
    }

    /// The Day `date` names as `YYYY-MM-DD`; refused unless it is on the calendar (no 31 November).
    func parsedDay(_ date: String) throws(OperationError) -> Day {
        guard let day = Day(date), Day(containing: day.noon(in: tracker.calendar), in: tracker.calendar) == day else {
            throw OperationError(.invalidDate, "\"\(date)\" isn't a date. Write it YYYY-MM-DD, such as 2026-11-03.")
        }
        return day
    }

    /// `day`'s date, Day total and Elapsed time.
    func dayResult(_ day: Day) -> DayResult {
        DayResult(date: day.description, totalSeconds: seconds(tracker.dayTotal(day)),
                  elapsedSeconds: seconds(tracker.elapsed(day)))
    }
}

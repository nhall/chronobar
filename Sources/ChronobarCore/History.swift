import Foundation

/// The Week strip and the (i) Time Summary, built from Day totals.
extension Tracker {
    /// The seven Days of `day`'s week, starting on the calendar's first weekday, with their totals.
    public func weekTotals(containing day: Day) -> [DayTotal] {
        week(containing: day).map { DayTotal(day: $0, total: dayTotal($0)) }
    }

    /// The seven Days of `day`'s week, starting on the calendar's first weekday.
    func week(containing day: Day) -> [Day] {
        let first = day.startOfWeek(in: calendar)
        return (0..<7).map { first.adding(days: $0, in: calendar) }
    }

    /// Today, yesterday, today's week (as in the Week strip) and today's calendar month, each the sum
    /// of its Days' totals, and likewise of its Days' Elapsed time.
    public func summary() -> Summary {
        let periods = summaryPeriods()
        return Summary(
            today: periods.today.total,
            yesterday: periods.yesterday.total,
            week: periods.week.total,
            month: periods.month.total,
            elapsed: Summary.Elapsed(
                today: periods.today.elapsed,
                yesterday: periods.yesterday.elapsed,
                week: periods.week.elapsed,
                month: periods.month.elapsed))
    }

    /// The Time Summary's periods with the Days each covers. Their figures are plain sums, rounded down only
    /// when shown, never apportioned (ADR 0005).
    public func summaryPeriods() -> SummaryPeriods {
        let today = today
        let month = calendar.range(of: .day, in: .month, for: today.noon(in: calendar))!.map {
            Day(year: today.year, month: today.month, day: $0)
        }
        func period(_ days: [Day]) -> SummaryPeriod {
            SummaryPeriod(first: days[0], last: days[days.count - 1],
                          total: days.reduce(0) { $0 + dayTotal($1) }, elapsed: days.reduce(0) { $0 + elapsed($1) })
        }
        return SummaryPeriods(
            today: period([today]),
            yesterday: period([today.adding(days: -1, in: calendar)]),
            week: period(week(containing: today)),
            month: period(month))
    }
}

import Foundation

/// The Week strip and the (i) Time Summary, built from Day totals.
extension Tracker {
    /// The seven Days of `day`'s week, starting on the calendar's first weekday, with their totals.
    public func weekTotals(containing day: Day) -> [DayTotal] {
        let first = day.startOfWeek(in: calendar)
        return (0..<7).map { offset in
            let day = first.adding(days: offset, in: calendar)
            return DayTotal(day: day, total: dayTotal(day))
        }
    }

    /// Today, yesterday, today's week (as in the Week strip) and today's calendar month, each the sum
    /// of its Days' totals, and likewise of its Days' Elapsed time.
    public func summary() -> Summary {
        let today = today
        let yesterday = today.adding(days: -1, in: calendar)
        let first = today.startOfWeek(in: calendar)
        let week = (0..<7).map { first.adding(days: $0, in: calendar) }
        let month = calendar.range(of: .day, in: .month, for: today.noon(in: calendar))!.map {
            Day(year: today.year, month: today.month, day: $0)
        }
        func sum(_ days: [Day], _ value: (Day) -> TimeInterval) -> TimeInterval {
            days.reduce(0) { $0 + value($1) }
        }
        return Summary(
            today: dayTotal(today),
            yesterday: dayTotal(yesterday),
            week: sum(week, dayTotal),
            month: sum(month, dayTotal),
            elapsed: Summary.Elapsed(
                today: elapsed(today),
                yesterday: elapsed(yesterday),
                week: sum(week, elapsed),
                month: sum(month, elapsed)))
    }
}

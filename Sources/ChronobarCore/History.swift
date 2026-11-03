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
    /// of its Days' totals.
    public func summary() -> Summary {
        let today = today
        let daysInMonth = calendar.range(of: .day, in: .month, for: today.noon(in: calendar))!
        let month = daysInMonth.reduce(0) { sum, day in
            sum + dayTotal(Day(year: today.year, month: today.month, day: day))
        }
        return Summary(
            today: dayTotal(today),
            yesterday: dayTotal(today.adding(days: -1, in: calendar)),
            week: weekTotals(containing: today).reduce(0) { $0 + $1.total },
            month: month)
    }
}

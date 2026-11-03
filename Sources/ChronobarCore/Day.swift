import Foundation

/// A calendar date in local time.
public struct Day: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(containing date: Date, in calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    /// `YYYY-MM-DD`, as used in Day file names and their `date` field.
    public init?(_ string: String) {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        self.init(year: year, month: month, day: day)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// Noon on this Day: a moment safely inside it, even where DST skips or repeats midnight.
    public func noon(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    /// The Day `count` Days later (earlier if negative).
    public func adding(days count: Int, in calendar: Calendar) -> Day {
        Day(containing: calendar.date(byAdding: .day, value: count, to: noon(in: calendar))!, in: calendar)
    }

    /// The first Day of this Day's week, which starts on the calendar's `firstWeekday`.
    public func startOfWeek(in calendar: Calendar) -> Day {
        let weekday = calendar.component(.weekday, from: noon(in: calendar))
        return adding(days: -((weekday - calendar.firstWeekday + 7) % 7), in: calendar)
    }
}

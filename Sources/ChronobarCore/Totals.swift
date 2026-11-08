import Foundation

/// One Project's line in the Panel for a Day.
public struct Row: Equatable, Sendable {
    public let project: String
    public let total: TimeInterval

    public init(project: String, total: TimeInterval) {
        self.project = project
        self.total = total
    }
}

/// One Day's grand total, as shown in the Week strip.
public struct DayTotal: Equatable, Sendable {
    public let day: Day
    public let total: TimeInterval

    public init(day: Day, total: TimeInterval) {
        self.day = day
        self.total = total
    }
}

/// One period of the Time Summary: the Days it covers, the sum of their Day totals and of their Elapsed
/// time.
public struct SummaryPeriod: Equatable, Sendable {
    /// The first and last Day; the same for a single Day.
    public let first: Day
    public let last: Day
    public let total: TimeInterval
    public let elapsed: TimeInterval

    public init(first: Day, last: Day, total: TimeInterval, elapsed: TimeInterval) {
        self.first = first
        self.last = last
        self.total = total
        self.elapsed = elapsed
    }
}

/// The Time Summary's periods: today, yesterday, today's week (as in the Week strip) and today's calendar
/// month.
public struct SummaryPeriods: Equatable, Sendable {
    public let today: SummaryPeriod
    public let yesterday: SummaryPeriod
    public let week: SummaryPeriod
    public let month: SummaryPeriod

    public init(today: SummaryPeriod, yesterday: SummaryPeriod, week: SummaryPeriod, month: SummaryPeriod) {
        self.today = today
        self.yesterday = yesterday
        self.week = week
        self.month = month
    }
}

/// The (i) Time Summary: grand totals for today, yesterday, this week and this month, with the
/// Elapsed time beside each.
public struct Summary: Equatable, Sendable {
    public let today: TimeInterval
    public let yesterday: TimeInterval
    public let week: TimeInterval
    public let month: TimeInterval
    public let elapsed: Elapsed

    /// The Elapsed time of each period: the sum of its Days' Elapsed time.
    public struct Elapsed: Equatable, Sendable {
        public let today: TimeInterval
        public let yesterday: TimeInterval
        public let week: TimeInterval
        public let month: TimeInterval

        public init(today: TimeInterval, yesterday: TimeInterval, week: TimeInterval, month: TimeInterval) {
            self.today = today
            self.yesterday = yesterday
            self.week = week
            self.month = month
        }
    }

    public init(
        today: TimeInterval, yesterday: TimeInterval, week: TimeInterval, month: TimeInterval, elapsed: Elapsed
    ) {
        self.today = today
        self.yesterday = yesterday
        self.week = week
        self.month = month
        self.elapsed = elapsed
    }
}

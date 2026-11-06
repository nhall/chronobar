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

/// The (i) Time Summary: grand totals for today, yesterday, this week and this month.
public struct Summary: Equatable, Sendable {
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

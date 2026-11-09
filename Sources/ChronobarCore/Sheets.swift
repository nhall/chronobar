import Foundation

/// A time as shown: whole seconds, rounded down, and the whole minutes shown for it, which for a row under
/// a Total can be a minute more than its seconds rounded down (`RowMinutes`).
public struct Figure: Equatable, Sendable {
    public let seconds: Int
    public let minutes: Int

    public init(seconds: Int, minutes: Int) {
        self.seconds = seconds
        self.minutes = minutes
    }

    /// A plain figure: `seconds` rounded down to the minute.
    init(seconds: Int) {
        self.init(seconds: seconds, minutes: seconds / 60)
    }
}

/// One Day as the Panel and `chronobar day` show it, every row's minutes adding up to the Total line
/// above them (ADR 0005).
public struct DaySheet: Equatable, Sendable {
    /// One Project's row.
    public struct Row: Equatable, Sendable {
        /// The Project as stored: the Project list's spelling, else its first Entry's on the Day.
        public let project: String
        /// The Project's time on the Day, never below zero, with its share of the Total's minutes.
        public let time: Figure
        /// The Source of the Project's running Timer; nil unless it runs, so always nil on a past Day.
        public let runningSource: EntrySource?

        public var isRunning: Bool { runningSource != nil }
    }

    public let day: Day
    /// In the order each Project first appears in the Day file.
    public let rows: [Row]
    /// The sum of the rows' seconds, rounded down to the minute.
    public let total: Figure
    /// Clock time, rounded down to the second and to the minute.
    public let clockTime: Figure
    /// Whether the Day's file failed to parse when last read.
    public let isMalformed: Bool
}

/// A week as `chronobar week` shows it, built from its Days' sheets.
public struct WeekSheet: Equatable, Sendable {
    /// One Project's week line.
    public struct Line: Equatable, Sendable {
        /// The Project as its first row in the week shows it.
        public let project: String
        /// The sum of the Project's rows' seconds, with its share of the week's Total minutes.
        public let time: Figure

        public init(project: String, time: Figure) {
            self.project = project
            self.time = time
        }
    }

    /// The seven Days, starting on the calendar's first weekday, as in the Week strip.
    public let days: [DaySheet]
    /// One per Project with rows in the week, names matching regardless of case, in the order each first
    /// appears; their minutes add up to `total`'s.
    public let lines: [Line]
    /// The sums of the Days' seconds and of their minutes as shown, so the Day lines add up to the week's.
    public let total: Figure
    public let clockTime: Figure

    init(days: [DaySheet]) {
        self.days = days
        var sums: [(project: String, seconds: Int)] = []
        for row in days.flatMap(\.rows) {
            if let index = sums.firstIndex(where: { ProjectName.matches($0.project, row.project) }) {
                sums[index].seconds += row.time.seconds
            } else {
                sums.append((row.project, row.time.seconds))
            }
        }
        func sum(_ figure: (DaySheet) -> Figure) -> Figure {
            Figure(seconds: days.map { figure($0).seconds }.reduce(0, +),
                   minutes: days.map { figure($0).minutes }.reduce(0, +))
        }
        total = sum(\.total)
        clockTime = sum(\.clockTime)
        let minutes = RowMinutes(seconds: sums.map { TimeInterval($0.seconds) }, total: total.minutes).rows
        lines = zip(sums, minutes).map { Line(project: $0.project, time: Figure(seconds: $0.seconds, minutes: $1)) }
    }

    public var first: Day { days[0].day }
    public var last: Day { days[days.count - 1].day }
    /// The Days whose file failed to parse when last read, first to last.
    public var malformed: [Day] { days.filter(\.isMalformed).map(\.day) }
}

extension Tracker {
    /// The week containing `day`, as `chronobar week` shows it.
    public func weekSheet(containing day: Day) -> WeekSheet {
        WeekSheet(days: week(containing: day).map(daySheet))
    }

    /// `day` as the Panel and `chronobar day` show it.
    public func daySheet(_ day: Day) -> DaySheet {
        let rows = rows(day)
        let minutes = RowMinutes(seconds: rows.map(\.total))
        // Timers run only today.
        let timers = day == today ? timers : RunningTimers()
        return DaySheet(
            day: day,
            rows: zip(rows, minutes.rows).map { row, minutes in
                DaySheet.Row(project: row.project, time: Figure(seconds: Int(row.total), minutes: minutes),
                             runningSource: timers[row.project]?.source)
            },
            total: Figure(seconds: Int(rows.reduce(0) { $0 + $1.total }), minutes: minutes.total),
            clockTime: Figure(seconds: elapsed(day).wholeSeconds),
            isMalformed: isMalformed(day))
    }
}

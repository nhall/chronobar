import Foundation

/// The Panel's line between the Week strip and the rows, "Total 2:57 · Clock time 2:50", and with a
/// period's name instead of "Total" each line of the (i) Time Summary. The total adds up the Labels'
/// time; the clock time is the time at least one timer ran, which is less when timers ran side by side.
public struct DayTotalLine: Equatable, Sendable {
    /// "Total", or the Time Summary period's name: "This week".
    public let name: String
    /// The total: "2:57".
    public let total: String
    /// "Clock time 2:50".
    public let clockTime: String
    /// VoiceOver reads the line as one: "Total 2 hours 57 minutes, clock time 2 hours 50 minutes".
    public let accessibilityLabel: String
    public let help = "Total adds up every Label's time. Clock time counts the time when any timer was "
        + "running, overlapping timers once, and doesn't include time logged by hand."

    public init(_ name: String = "Total", total: TimeInterval, elapsed: TimeInterval) {
        self.name = name
        self.total = DurationFormat.hoursMinutes(total)
        clockTime = "Clock time \(DurationFormat.hoursMinutes(elapsed))"
        accessibilityLabel =
            "\(name) \(DurationFormat.spoken(total)), clock time \(DurationFormat.spoken(elapsed))"
    }

    /// The whole line: "Total 2:57 · Clock time 2:50".
    public var text: String { "\(name) \(total) · \(clockTime)" }
}

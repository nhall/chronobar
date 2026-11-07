import Foundation

/// The Panel's line between the Week strip and the rows: "Total" on the leading edge and "2:57 · 2:50
/// elapsed" on the trailing edge, the elapsed time in smaller text. The total is the Day total; the
/// elapsed time is the clock time at least one timer covered, which is less when timers ran side by side.
public struct DayTotalLine: Equatable, Sendable {
    public let label = "Total"
    /// The Day total: "2:57".
    public let total: String
    /// After the total, in smaller text: "· 2:50 elapsed".
    public let elapsed: String
    /// VoiceOver reads the line as one: "Total for the day, 2 hours 57 minutes, 2 hours 50 minutes elapsed".
    public let accessibilityLabel: String
    public let help: String

    public init(total: TimeInterval, elapsed: TimeInterval) {
        let elapsedTime = DurationFormat.hoursMinutes(elapsed)
        self.total = DurationFormat.hoursMinutes(total)
        self.elapsed = "· \(elapsedTime) elapsed"
        accessibilityLabel =
            "Total for the day, \(DurationFormat.spoken(total)), \(DurationFormat.spoken(elapsed)) elapsed"
        help = "Total for the day · \(elapsedTime) elapsed, the clock time at least one timer ran"
    }
}

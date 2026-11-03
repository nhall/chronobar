import Foundation

public enum DurationFormat {
    /// `h:mm`, rounded down to the minute and never below `0:00`.
    public static func hoursMinutes(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds) / 60)
        let mm = minutes % 60
        return "\(minutes / 60):\(mm < 10 ? "0" : "")\(mm)"
    }
}

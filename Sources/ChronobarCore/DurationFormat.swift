import Foundation

public enum DurationFormat {
    /// `h:mm`, rounded down to the minute and never below `0:00`.
    public static func hoursMinutes(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds) / 60)
        let mm = minutes % 60
        return "\(minutes / 60):\(mm < 10 ? "0" : "")\(mm)"
    }

    /// The same minutes as `hoursMinutes` in words, for VoiceOver: "1 hour 23 minutes", "0 minutes".
    public static func spoken(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds) / 60)
        let (h, m) = (minutes / 60, minutes % 60)
        let hours = h == 1 ? "1 hour" : "\(h) hours"
        let mins = m == 1 ? "1 minute" : "\(m) minutes"
        if h == 0 { return mins }
        return m == 0 ? hours : "\(hours) \(mins)"
    }
}

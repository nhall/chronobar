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
        let totalMinutes = Int(max(0, seconds) / 60)
        let (hours, minutes) = (totalMinutes / 60, totalMinutes % 60)
        let hoursText = hours == 1 ? "1 hour" : "\(hours) hours"
        let minutesText = minutes == 1 ? "1 minute" : "\(minutes) minutes"
        if hours == 0 { return minutesText }
        return minutes == 0 ? hoursText : "\(hoursText) \(minutesText)"
    }
}

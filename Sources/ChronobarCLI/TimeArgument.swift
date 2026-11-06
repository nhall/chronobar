import Foundation

/// A time typed on the command line: `HH:MM` (or `H:MM`) for that time today in local time, or an ISO 8601
/// time with an offset, as MCP and `--json` use.
enum TimeArgument {
    /// The moment `text` names, with `now` and `calendar` giving today and the local time zone; nil if it
    /// is neither form.
    static func parse(_ text: String, now: Date, calendar: Calendar) -> Date? {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        if parts.count == 2, (1...2).contains(parts[0].count), parts[1].count == 2,
           parts.allSatisfy({ $0.allSatisfy { ("0"..."9").contains($0) } }),
           let hour = Int(parts[0]), let minute = Int(parts[1]), (0...23).contains(hour), (0...59).contains(minute) {
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now)
        }
        for style in [Date.ISO8601FormatStyle(timeZoneSeparator: .colon), Date.ISO8601FormatStyle()] {
            if let date = try? style.parse(text) { return date }
        }
        return nil
    }
}

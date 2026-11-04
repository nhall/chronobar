import Foundation

/// The Week strip as VoiceOver reads it.
public enum WeekStripAccessibility {
    /// A Day's date, its total, and whether it is today or the viewed Day:
    /// "Tuesday, November 3, 1 hour 23 minutes, today, viewed".
    public static func label(_ item: DayTotal, today: Day, viewed: Day, calendar: Calendar,
                             locale: Locale) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.wide).month(.wide).day()
        var parts = [item.day.noon(in: calendar).formatted(style), DurationFormat.spoken(item.total)]
        if item.day == today { parts.append("today") }
        if item.day == viewed { parts.append("viewed") }
        return parts.joined(separator: ", ")
    }
}

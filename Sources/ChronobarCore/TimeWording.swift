import Foundation

/// Times and dates as Core's wording shows them, on Tracker's calendar (its time zone and locale) and
/// Chronobar's today, so they match the Panel's whatever the Mac's calendar.
struct TimeWording {
    let calendar: Calendar
    let today: Day

    /// "2:10 PM" on Chronobar's today, with the date on other Days.
    func time(_ date: Date) -> String {
        format(date, date: Day(containing: date, in: calendar) == today ? .omitted : .abbreviated, time: .shortened)
    }

    /// `date` in the given styles, on Tracker's calendar, time zone and locale.
    func format(_ date: Date, date dateStyle: Date.FormatStyle.DateStyle,
                time timeStyle: Date.FormatStyle.TimeStyle) -> String {
        date.formatted(Date.FormatStyle(date: dateStyle, time: timeStyle, locale: locale, calendar: calendar,
                                        timeZone: calendar.timeZone))
    }

    var locale: Locale { calendar.locale ?? .autoupdatingCurrent }
}

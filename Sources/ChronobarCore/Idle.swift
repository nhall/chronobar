import Foundation

/// The idle alert's answers.
public enum IdleChoice: Sendable {
    /// Drop the Idle time and keep the timer running from now.
    case remove
    /// Drop the Idle time and leave the timer stopped.
    case removeAndStop
    /// Count the Idle time.
    case keep

    /// The alert's button for this answer.
    public var title: String {
        switch self {
        case .remove: "Remove idle time"
        case .removeAndStop: "Remove & stop"
        case .keep: "Keep"
        }
    }
}

/// The alert shown when a malformed Day refuses the idle removal, from `Tracker.idleRefusal(_:)`.
public struct IdleRefusal: Equatable, Sendable {
    public let title: String
    /// Names the Day's full date and its file, and says the question comes back once the file parses.
    public let text: String
}

/// Idle time Core is holding for the idle alert: left by a crash, found in a Day file that parsed again
/// with an Entry still open, or a removal refused because a Day file was malformed.
public struct PendingIdle: Equatable, Sendable {
    public let since: Date
    /// Where the Idle time ends; nil runs up to now. A refused removal ends where it was answered, as the
    /// time after that was worked.
    public let until: Date?
    /// The malformed Day file that refused the removal. Ask again once it's nil (the file parses).
    public let blockedBy: Day?

    public init(since: Date, until: Date? = nil, blockedBy: Day? = nil) {
        self.since = since
        self.until = until
        self.blockedBy = blockedBy
    }
}

/// What the idle alert asks about, from `Tracker.takeIdleQuestion()`. Answer it with `Tracker.resolveIdle`
/// for `since` and `until`.
///
/// Two questions are equal when they ask about the same Idle time for the same Timers; `message` is how
/// Tracker words that on its calendar, so it isn't compared.
public struct IdleQuestion: Equatable, Sendable {
    public let since: Date
    /// Where the Idle time ends; nil runs up to now.
    public let until: Date?
    /// The Labels of the running Timers started in the app, in the order they started: the Timers the
    /// answer applies to.
    public let labels: [String]
    /// The alert's text: "You've been idle since 2:10 PM. Website Redesign is still running." or "You were
    /// idle from 2:10 PM to 2:30 PM. …", with the date on times that aren't on Chronobar's today. Empty on
    /// a question made with `init(since:until:labels:)` rather than by Tracker.
    public let message: String

    /// A question to compare with one Tracker offered.
    public init(since: Date, until: Date?, labels: [String]) {
        self.init(since: since, until: until, labels: labels, message: "")
    }

    init(since: Date, until: Date?, labels: [String], message: String) {
        self.since = since
        self.until = until
        self.labels = labels
        self.message = message
    }

    public static func == (lhs: IdleQuestion, rhs: IdleQuestion) -> Bool {
        lhs.since == rhs.since && lhs.until == rhs.until && lhs.labels == rhs.labels
    }
}

/// The idle alert's wording, on Tracker's calendar (its time zone and locale) and Chronobar's today.
struct IdleWording {
    let calendar: Calendar
    let today: Day

    func message(since: Date, until: Date?, labels: [String]) -> String {
        // One alert for every app timer; each choice applies to all of them.
        let running = labels.formatted(.list(type: .and).locale(locale))
        let verb = labels.count == 1 ? "is" : "are"
        if let until {
            return "You were idle from \(time(since)) to \(time(until))."
                + (labels.isEmpty ? "" : " \(running) \(verb) running.")
        }
        return "You've been idle since \(time(since))."
            + (labels.isEmpty ? "" : " \(running) \(verb) still running.")
    }

    /// Says which Day file stopped the removal.
    func refusal(_ error: MalformedDayFile) -> IdleRefusal {
        let day = error.day
        let date = day.noon(in: calendar).formatted(
            Date.FormatStyle(date: .complete, time: .omitted, locale: locale, calendar: calendar,
                             timeZone: calendar.timeZone))
        return IdleRefusal(
            title: "The idle time wasn't removed",
            text: "The file for \(date) (days/\(day).json) can't be read, so it can't be changed. Fix it by "
                + "hand in the data folder and you'll be asked again. Until then the idle time still counts.")
    }

    /// "2:10 PM" on Chronobar's today, with the date on other Days.
    private func time(_ date: Date) -> String {
        let style: Date.FormatStyle.DateStyle = Day(containing: date, in: calendar) == today ? .omitted : .abbreviated
        return date.formatted(Date.FormatStyle(date: style, time: .shortened, locale: locale, calendar: calendar,
                                               timeZone: calendar.timeZone))
    }

    private var locale: Locale { calendar.locale ?? .autoupdatingCurrent }
}

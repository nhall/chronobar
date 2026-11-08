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

/// What an idle question asks about: the Idle time and the Timers an answer applies to.
public struct IdleSubject: Equatable, Sendable {
    public let since: Date
    /// Where the Idle time ends; nil runs up to now.
    public let until: Date?
    /// The Labels of the running Timers started in the app, in the order they started: the Timers the
    /// answer applies to.
    public let labels: [String]

    public init(since: Date, until: Date?, labels: [String]) {
        self.since = since
        self.until = until
        self.labels = labels
    }
}

/// The idle alert's question, from `Tracker.takeIdleQuestion()`. Answer it with `Tracker.resolveIdle` for
/// `since` and `until`.
public struct IdleQuestion: Equatable, Sendable {
    public let subject: IdleSubject
    /// The alert's text: "You've been idle since 2:10 PM. Website Redesign is still running." or "You were
    /// idle from 2:10 PM to 2:30 PM. …", with the date on times that aren't on Chronobar's today.
    public let message: String

    public var since: Date { subject.since }
    public var until: Date? { subject.until }
}

/// The idle alert's wording, on Tracker's calendar (its time zone and locale) and Chronobar's today.
struct IdleWording {
    let calendar: Calendar
    let today: Day

    func message(for subject: IdleSubject) -> String {
        let (since, until, labels) = (subject.since, subject.until, subject.labels)
        let running = labels.formatted(.list(type: .and).locale(times.locale))
        let verb = labels.count == 1 ? "is" : "are"
        if let until {
            return "You were idle from \(times.time(since)) to \(times.time(until))."
                + (labels.isEmpty ? "" : " \(running) \(verb) running.")
        }
        return "You've been idle since \(times.time(since))."
            + (labels.isEmpty ? "" : " \(running) \(verb) still running.")
    }

    /// Says which Day file stopped the removal.
    func refusal(_ error: MalformedDayFile) -> IdleRefusal {
        let day = error.day
        let date = times.format(day.noon(in: calendar), date: .complete, time: .omitted)
        return IdleRefusal(
            title: "The idle time wasn't removed",
            text: "The file for \(date) (days/\(day).json) can't be read, so it can't be changed. Fix it by "
                + "hand in the data folder and you'll be asked again. Until then the idle time still counts.")
    }

    private var times: TimeWording { TimeWording(calendar: calendar, today: today) }
}

import Foundation

/// The idle alert's answers.
public enum IdleChoice: Sendable {
    /// Drop the Idle time and keep the timer running from now.
    case remove
    /// Drop the Idle time and leave the timer stopped.
    case removeAndStop
    /// Count the Idle time.
    case keep
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
public struct IdleQuestion: Equatable, Sendable {
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

import Foundation

/// A timer that just ran past the long-running threshold, with the warning that names it.
///
/// Two values are equal when they name the same run (its Label and the start of its run), whatever their
/// wording, so a run rebuilt from a notification's saved Label and start still matches the one `tick()`
/// returned.
public struct LongRunning: Equatable, Sendable {
    public let project: String
    /// When this run of the timer started, before any midnight split.
    public let since: Date
    /// The warning's title: "Website Redesign is still running".
    public var title: String { "\(project) is still running" }
    /// The warning's text: "Running for over 4 hours, since 9:00 AM. Stop it if it's done.", with the date on
    /// a start that isn't on Chronobar's today. Empty on a run named by `init(project:since:)`.
    public let body: String

    /// Names a run without its wording, as the warning's Stop does to stop it.
    public init(project: String, since: Date) {
        self.init(project: project, since: since, body: "")
    }

    init(project: String, since: Date, body: String) {
        self.project = project
        self.since = since
        self.body = body
    }

    /// This run with its warning's text, for a threshold of `threshold` seconds.
    func worded(threshold: TimeInterval, times: TimeWording) -> LongRunning {
        let hours = Int(threshold / 3600)
        return LongRunning(project: project, since: since,
                           body: "Running for over \(hours) hours, since \(times.time(since)). Stop it if it's done.")
    }

    public static func == (lhs: LongRunning, rhs: LongRunning) -> Bool {
        lhs.project == rhs.project && lhs.since == rhs.since
    }
}

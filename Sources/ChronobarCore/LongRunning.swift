import Foundation

/// A timer that just ran past the long-running threshold, for the warning that names it.
public struct LongRunning: Equatable, Sendable {
    public let project: String
    /// When this run of the timer started, before any midnight split.
    public let since: Date

    public init(project: String, since: Date) {
        self.project = project
        self.since = since
    }
}

import Foundation

/// One run of a Label's Timer: from when it started, before any midnight split, until it is paused. Pausing
/// and starting again is a new run. Rebuilt from a Long-running warning's saved Label and start, it still
/// names the run the warning was about.
public struct TimerRun: Hashable, Sendable {
    public let project: String
    /// When this run of the timer started, before any midnight split.
    public let since: Date

    public init(project: String, since: Date) {
        self.project = project
        self.since = since
    }
}

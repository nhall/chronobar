import Foundation

/// What `Tracker.start` did, as an agent would be told it.
public struct StartOutcome: Equatable, Sendable {
    /// The Label with its stored spelling, the name its row is shown under.
    public let project: String
    /// Whether the Label was already running, in which case nothing changed.
    public let alreadyRunning: Bool
    /// The Timer now running for the Label: the one it already had, or the one this start began.
    public let timer: Running
    /// Each Timer "Starting a timer pauses the others" stopped, in the order they started. Empty with the
    /// setting off, or when the Label was already running.
    public let paused: [PausedTimer]
}

/// A Timer a start paused, and the moment its Entry stopped.
public struct PausedTimer: Equatable, Sendable {
    public let timer: Running
    public let end: Date
}

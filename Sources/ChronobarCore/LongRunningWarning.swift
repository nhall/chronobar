import Foundation

/// The Long-running warning for a run that just passed the threshold, worded by `Tracker.tick()`.
public struct LongRunningWarning: Equatable, Sendable {
    /// The run warned about, for the warning's Stop.
    public let run: TimerRun
    /// "Website Redesign is still running".
    public let title: String
    /// "Running for over 4 hours, since 9:00 AM. Stop it if it's done.", with the date on a start that isn't
    /// on Chronobar's today.
    public let body: String
}

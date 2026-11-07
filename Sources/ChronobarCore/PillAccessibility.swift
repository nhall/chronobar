import Foundation

/// The Pill as VoiceOver reads it: one element saying what the Pill shows, whose press opens the Panel.
public struct PillAccessibility: Equatable, Sendable {
    /// The running count and today's Day total: "1 timer running, 1 hour 23 minutes today", "2 timers
    /// running, …" or "Nothing running, …".
    public let label: String

    @MainActor
    public init(tracker: Tracker) {
        let running = switch tracker.timers.count {
        case 0: "Nothing running"
        case 1: "1 timer running"
        case let count: "\(count) timers running"
        }
        label = "\(running), \(DurationFormat.spoken(tracker.dayTotal(tracker.today))) today"
    }
}

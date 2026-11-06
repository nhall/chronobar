import Foundation

/// The Pill as VoiceOver reads it: one element saying what the Pill shows, a press that opens the Panel,
/// and named actions for the square and the Panel.
public struct PillAccessibility: Equatable, Sendable {
    /// What runs and today's Day total: "Website Redesign running, 1 hour 23 minutes today", "2 timers
    /// running, …" or "Nothing running, …".
    public let label: String
    /// The name of the action that does what a click on the square does: Pause, or New Project when the
    /// square opens the ＋ form.
    public let squareAction: String

    public static let openPanelAction = "Open Panel"

    @MainActor
    public init(tracker: Tracker) {
        let running = switch tracker.timers.count {
        case 0: "Nothing running"
        case 1: "\(tracker.timers[0].project) running"
        case let count: "\(count) timers running"
        }
        label = "\(running), \(DurationFormat.spoken(tracker.dayTotal(tracker.today))) today"
        squareAction = switch PillClick.square(tracker: tracker) {
        case .pauseTimers: TimerToggle.name(isRunning: true)
        case .openNewProjectForm: "New Project"
        // The square never opens the Panel; named for what it would do, should that change.
        case .openPanel: Self.openPanelAction
        }
    }
}

/// The name of a ▶/⏸ press, for the Pill's square and a Panel row's button alike.
public enum TimerToggle {
    public static func name(isRunning: Bool) -> String { isRunning ? "Pause" : "Start" }
}

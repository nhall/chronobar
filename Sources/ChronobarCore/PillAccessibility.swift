import Foundation

/// The Pill as VoiceOver reads it: one element saying what the Pill shows, a press that opens the Panel,
/// and named actions for the square and the Panel.
public struct PillAccessibility: Equatable, Sendable {
    /// The Selected Project, its time today and whether it runs: "Website Redesign, 1 hour 23 minutes,
    /// running".
    public let label: String
    /// The name of the action that does what a click on the square does: Pause, Start, or New Project
    /// when the square opens the ＋ form.
    public let squareAction: String

    public static let openPanelAction = "Open Panel"

    @MainActor
    public init(tracker: Tracker) {
        if let project = tracker.selectedProject {
            let time = DurationFormat.spoken(tracker.total(project, on: tracker.today))
            label = "\(project), \(time), \(tracker.isRunning(project) ? "running" : "paused")"
        } else {
            label = tracker.running == nil ? "No Project selected" : "No Project selected, running"
        }
        squareAction = switch PillClick.square(tracker: tracker) {
        case .toggleTimer: TimerToggle.name(isRunning: tracker.running != nil)
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

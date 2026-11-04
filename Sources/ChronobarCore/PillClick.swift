import Foundation

/// The Pill's geometry in points, shared by its drawing and its click zones.
public enum PillMetrics {
    public static let height: CGFloat = 18
    public static let squareWidth: CGFloat = 22
    public static let gap: CGFloat = 2
    public static let cornerRadius: CGFloat = 4
    /// Space between the Pill and the edges of the status item.
    public static let inset: CGFloat = 3
    /// Where the square's click zone ends and the time segment's begins: halfway across the gap.
    public static let squareZoneEnd: CGFloat = inset + squareWidth + gap / 2
}

/// What a click on the Pill does.
public enum PillClick: Equatable {
    case toggleTimer
    case openPanel
    /// ▶ with nothing to start: the Panel's ＋ form.
    case openNewProjectForm

    /// The action for a click `x` points from the status item's leading edge, or with `x` nil for a press
    /// with the pointer off the status item (VoiceOver, the keyboard).
    @MainActor
    public static func action(atX x: Double?, tracker: Tracker) -> PillClick {
        guard let x, x < PillMetrics.squareZoneEnd else { return .openPanel }
        return square(tracker: tracker)
    }

    /// What the square does, from a click or the global shortcut.
    @MainActor
    public static func square(tracker: Tracker) -> PillClick {
        tracker.running == nil && tracker.selectedProject == nil ? .openNewProjectForm : .toggleTimer
    }
}

import Foundation

/// Where the pointer is, for a press on the status item.
public enum PillPointer: Equatable, Sendable {
    /// Over the status item, `x` points from the Pill's leading edge.
    case at(x: CGFloat)
    /// Off the status item: a press from VoiceOver or the keyboard.
    case away

    /// The pointer `x` points from the Pill's leading edge, over the status item when `x` is within
    /// `extent`, the status item's span including its padding. Only `x` counts: a click at the very top of
    /// the screen, or on the status item's edge, is still on it.
    public init(x: CGFloat, within extent: ClosedRange<CGFloat>) {
        self = extent.contains(x) ? .at(x: x) : .away
    }
}

/// What a click on the Pill does.
public enum PillClick: Equatable, Sendable {
    case toggleTimer
    case openPanel
    /// ▶ with nothing to start: the Panel's ＋ form.
    case openNewProjectForm

    /// The action for a press with the pointer at `pointer`.
    @MainActor
    public static func action(at pointer: PillPointer, tracker: Tracker) -> PillClick {
        guard case .at(let x) = pointer, x < PillMetrics.squareZoneEnd else { return .openPanel }
        return square(tracker: tracker)
    }

    /// What the square does, from a click or the global shortcut.
    @MainActor
    public static func square(tracker: Tracker) -> PillClick {
        tracker.canToggle ? .toggleTimer : .openNewProjectForm
    }
}

/// Decides each click on the Pill from where its mouse-down was, so a press that drifts before the
/// mouse-up (easy on a trackpad) does what the segment it began on does.
///
/// With the Panel closed the status item's button sends its action after the mouse-down, which this
/// remembers until then. With the Panel open the button sends no action: a mouse-down on the square acts at
/// once and keeps the Panel open, and one anywhere else closes the Panel.
public struct PillPress: Sendable {
    private var pressed: PillPointer?

    public init() {}

    /// Whether a mouse-down with the Panel open closes it: true unless it is on the square.
    @MainActor
    public static func closesPanel(onPill: Bool, at pointer: PillPointer, tracker: Tracker) -> Bool {
        squareAction(onPill: onPill, at: pointer, tracker: tracker) == nil
    }

    /// A left mouse-down anywhere in the app. Returns the action to run now, with the event dropped, or nil
    /// to let the event through.
    @MainActor
    public mutating func mouseDown(onPill: Bool, at pointer: PillPointer, panelOpen: Bool,
                                   tracker: Tracker) -> PillClick? {
        pressed = onPill && !panelOpen ? pointer : nil
        return panelOpen ? Self.squareAction(onPill: onPill, at: pointer, tracker: tracker) : nil
    }

    /// The status item's button sent its action. `byMouse` is false for a press from VoiceOver or the
    /// keyboard, which opens the Panel wherever the pointer is.
    @MainActor
    public mutating func buttonAction(byMouse: Bool, tracker: Tracker) -> PillClick {
        defer { pressed = nil }
        return PillClick.action(at: byMouse ? pressed ?? .away : .away, tracker: tracker)
    }

    /// The mouse-up of a press on the Pill's cover, which takes the press before the menu bar can, so there
    /// is no button action. `overPill` is whether it was released over the Pill.
    @MainActor
    public mutating func mouseUp(overPill: Bool, tracker: Tracker) -> PillClick? {
        defer { pressed = nil }
        guard overPill, let pressed else { return nil }
        return PillClick.action(at: pressed, tracker: tracker)
    }

    @MainActor
    private static func squareAction(onPill: Bool, at pointer: PillPointer, tracker: Tracker) -> PillClick? {
        guard onPill else { return nil }
        let action = PillClick.action(at: pointer, tracker: tracker)
        return action == .openPanel ? nil : action
    }
}

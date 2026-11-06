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
    /// ⏸: pauses every running timer.
    case pauseTimers
    case openPanel
    /// ▶ with nothing running: the Panel's ＋ form.
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
        tracker.timers.isEmpty ? .openNewProjectForm : .pauseTimers
    }
}

/// Decides each click on the Pill from where its mouse-down was, so a press that drifts before the
/// mouse-up (easy on a trackpad) does what the segment it began on does.
///
/// With the Panel closed the status item's button sends its action after the mouse-down, which this
/// remembers until then. With the Panel open the button sends no action: a mouse-down on the square acts at
/// once and keeps the Panel open, and one anywhere else closes the Panel.
///
/// A press on the Pill with ⌘ held is the start of a ⌘-drag, which moves the status item, so it is never a
/// click: it pauses nothing and opens nothing.
public struct PillPress: Sendable {
    private enum Pressed: Equatable, Sendable {
        /// A click, with the pointer where its mouse-down was.
        case click(PillPointer)
        /// ⌘ was held: not a click.
        case commandDrag
    }

    private var pressed: Pressed?

    public init() {}

    /// Whether a mouse-down with the Panel open closes it: true unless it is on the square.
    @MainActor
    public static func closesPanel(onPill: Bool, at pointer: PillPointer, tracker: Tracker) -> Bool {
        squareAction(onPill: onPill, at: pointer, tracker: tracker) == nil
    }

    /// A left mouse-down anywhere in the app, with or without ⌘ held. Returns the action to run now, with
    /// the event dropped, or nil to let the event through.
    @MainActor
    public mutating func mouseDown(onPill: Bool, at pointer: PillPointer, commandKey: Bool = false,
                                   panelOpen: Bool, tracker: Tracker) -> PillClick? {
        if onPill && commandKey {
            pressed = .commandDrag
            return nil
        }
        pressed = onPill && !panelOpen ? .click(pointer) : nil
        return panelOpen ? Self.squareAction(onPill: onPill, at: pointer, tracker: tracker) : nil
    }

    /// The status item's button sent its action, or nil after a press with ⌘ held. `byMouse` is false for a
    /// press from VoiceOver or the keyboard, which opens the Panel wherever the pointer is.
    @MainActor
    public mutating func buttonAction(byMouse: Bool, tracker: Tracker) -> PillClick? {
        defer { pressed = nil }
        guard byMouse else { return PillClick.action(at: .away, tracker: tracker) }
        switch pressed {
        case .commandDrag: return nil
        case .click(let pointer): return PillClick.action(at: pointer, tracker: tracker)
        case nil: return PillClick.action(at: .away, tracker: tracker)
        }
    }

    /// The mouse-up of a press on the Pill's cover, which takes the press before the menu bar can, so there
    /// is no button action. `overPill` is whether it was released over the Pill.
    @MainActor
    public mutating func mouseUp(overPill: Bool, tracker: Tracker) -> PillClick? {
        defer { pressed = nil }
        guard overPill, case .click(let pointer) = pressed else { return nil }
        return PillClick.action(at: pointer, tracker: tracker)
    }

    @MainActor
    private static func squareAction(onPill: Bool, at pointer: PillPointer, tracker: Tracker) -> PillClick? {
        guard onPill else { return nil }
        let action = PillClick.action(at: pointer, tracker: tracker)
        return action == .openPanel ? nil : action
    }
}

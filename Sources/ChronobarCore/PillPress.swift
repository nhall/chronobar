import Foundation

/// Decides whether a press on the Pill opens the Panel. Every click on the Pill does, wherever on it it
/// lands, and none starts or pauses a timer.
///
/// With the Panel closed the status item's button sends its action after the mouse-down, which this
/// remembers until then. With the Panel open the button sends no action: a mouse-down on the Pill closes
/// the Panel, and its mouse-up leaves it closed.
///
/// A press on the Pill with ⌘ held is the start of a ⌘-drag, which moves the status item, so it is never a
/// click: it opens nothing.
public struct PillPress: Sendable {
    private enum Pressed: Equatable, Sendable {
        case click
        /// ⌘ was held: not a click.
        case commandDrag
    }

    private var pressed: Pressed?

    public init() {}

    /// A left mouse-down anywhere in the app, with or without ⌘ held.
    public mutating func mouseDown(onPill: Bool, commandKey: Bool = false, panelOpen: Bool) {
        if onPill && commandKey {
            pressed = .commandDrag
            return
        }
        pressed = onPill && !panelOpen ? .click : nil
    }

    /// The status item's button sent its action. Returns whether to open the Panel: yes, unless the press
    /// had ⌘ held. `byMouse` is false for a press from VoiceOver or the keyboard, which always opens it.
    public mutating func buttonAction(byMouse: Bool) -> Bool {
        defer { pressed = nil }
        return !byMouse || pressed != .commandDrag
    }

    /// The mouse-up of a press on the Pill's cover, which takes the press before the menu bar can, so there
    /// is no button action. `overPill` is whether it was released over the Pill. Returns whether to open the
    /// Panel.
    public mutating func mouseUp(overPill: Bool) -> Bool {
        defer { pressed = nil }
        return overPill && pressed == .click
    }
}

import AppKit

/// An invisible window over the Pill that takes a press on it before the menu bar can. The menu bar hosts
/// status items itself and draws its highlight behind one on the mouse-down, before the app sees the press,
/// so nothing in the app can stop it; a window of the app's own in front of the menu bar means the menu bar
/// never gets the press. It is only shown while the pointer is on the Pill (`PillCoverArea`).
final class PillCover: NSPanel {
    /// The press's mouse-up, and whether it was over the Pill. Its mouse-down went through the app's event
    /// monitor, as one on the status item does.
    var onMouseUp: ((Bool) -> Void)?

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
                   defer: true)
        contentView = PressView(cover: self)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // Takes clicks although it draws nothing.
        ignoresMouseEvents = false
        level = .statusBar
        // Not in other apps' full-screen spaces, where the menu bar comes and goes: a press there reaches
        // the status item as before.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        setAccessibilityElement(false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func place(at frame: NSRect) {
        guard frame != self.frame || !isVisible else { return }
        setFrame(frame, display: false)
        orderFrontRegardless()
    }

    /// Takes the cover away, unless a press on it is still held and `duringPress` is false.
    func remove(duringPress: Bool = false) {
        guard isVisible, duringPress || !Self.primaryButtonHeld else { return }
        orderOut(nil)
    }

    /// Whether the left (primary) mouse button is down.
    private static var primaryButtonHeld: Bool { NSEvent.pressedMouseButtons & 1 != 0 }

    private final class PressView: NSView {
        unowned let cover: PillCover

        init(cover: PillCover) {
            self.cover = cover
            super.init(frame: .zero)
            // Pointer moves can arrive late or not at all once the pointer leaves the cover, so the cover
            // also goes as soon as the pointer is off it.
            addTrackingArea(NSTrackingArea(
                rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        }

        override func mouseExited(with event: NSEvent) { cover.remove() }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        // A press works whether or not the app is active.
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {}
        override func mouseUp(with event: NSEvent) {
            cover.onMouseUp?(bounds.contains(convert(event.locationInWindow, from: nil)))
        }
    }
}

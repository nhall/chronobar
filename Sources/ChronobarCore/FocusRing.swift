/// How the Panel was opened.
public enum PanelOpening: Equatable, Sendable {
    /// A click on the Pill.
    case pointer
    /// The keyboard or VoiceOver: the global shortcut, or a press on the Pill's accessibility element.
    case keyboard
    /// The app reopened, from a click on its Dock icon, ⌘-Tab, or Full Keyboard Access in the Dock. The
    /// request doesn't say which, so it counts as the keyboard.
    case appReopen
}

/// Whether the Panel draws its focus ring, like CSS `:focus-visible`. Opening the Panel always puts focus
/// on today's date; after a click on the Pill its ring stays hidden until the first key press in the Panel.
public struct FocusRing: Equatable, Sendable {
    public private(set) var isVisible = true

    public init() {}

    public mutating func panelOpened(by opening: PanelOpening) {
        isVisible = opening != .pointer
    }

    /// The Panel was asked to open while already open. From the keyboard that is a key press like one in
    /// the Panel; a click changes nothing.
    public mutating func askedToOpenWhileOpen(by opening: PanelOpening) {
        if opening != .pointer { keyPressed() }
    }

    public mutating func keyPressed() {
        isVisible = true
    }
}

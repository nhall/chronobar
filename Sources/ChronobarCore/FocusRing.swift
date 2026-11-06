/// How the Panel was opened.
public enum PanelOpening: Equatable, Sendable {
    /// A click on the Pill.
    case pointer
    /// The keyboard or VoiceOver: the global shortcut, or a press on the Pill's accessibility element.
    case keyboard
}

/// Whether the Panel draws its focus ring, like CSS `:focus-visible`. Opening the Panel always puts focus
/// on today's date; after a click on the Pill its ring stays hidden until the first key press in the Panel.
public struct FocusRing: Equatable, Sendable {
    public private(set) var isVisible = true

    public init() {}

    public mutating func panelOpened(by opening: PanelOpening) {
        isVisible = opening == .keyboard
    }

    public mutating func keyPressed() {
        isVisible = true
    }
}

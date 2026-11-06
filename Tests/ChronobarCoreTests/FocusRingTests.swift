import Testing
import ChronobarCore

@Suite struct FocusRingTests {
    @Test func aClickOpenHidesTheRing() {
        var ring = FocusRing()
        ring.panelOpened(by: .pointer)
        #expect(!ring.isVisible)
    }

    /// Tab, an arrow or a Panel key.
    @Test func aKeyPressAfterAClickOpenShowsTheRing() {
        var ring = FocusRing()
        ring.panelOpened(by: .pointer)
        ring.keyPressed()
        #expect(ring.isVisible)
    }

    /// The global shortcut, or VoiceOver's press on the Pill, even right after a click open hid it.
    @Test func aKeyboardOpenShowsTheRingStraightAway() {
        var ring = FocusRing()
        ring.panelOpened(by: .pointer)
        ring.panelOpened(by: .keyboard)
        #expect(ring.isVisible)
    }

    /// The Dock icon or ⌘-Tab: the request doesn't say which, and ⌘-Tab is a key press.
    @Test func aReopenOfTheAppShowsTheRing() {
        var ring = FocusRing()
        ring.panelOpened(by: .pointer)
        ring.panelOpened(by: .appReopen)
        #expect(ring.isVisible)
    }

    /// The global shortcut with the Panel already open is a key press like one in the Panel.
    @Test(arguments: [PanelOpening.keyboard, .appReopen])
    func askingFromTheKeyboardWithThePanelOpenShowsTheRing(opening: PanelOpening) {
        var ring = FocusRing()
        ring.panelOpened(by: .pointer)
        ring.askedToOpenWhileOpen(by: opening)
        #expect(ring.isVisible)
    }

    /// A click on the Pill's time with the Panel open is no key press.
    @Test func aClickWithThePanelOpenLeavesTheRingHidden() {
        var ring = FocusRing()
        ring.panelOpened(by: .pointer)
        ring.askedToOpenWhileOpen(by: .pointer)
        #expect(!ring.isVisible)
    }

    /// Each opening starts again: keys pressed while the Panel was last open don't count.
    @Test func eachClickOpenHidesTheRingAgain() {
        var ring = FocusRing()
        ring.panelOpened(by: .keyboard)
        ring.keyPressed()
        ring.panelOpened(by: .pointer)
        #expect(!ring.isVisible)
    }

    /// Nothing hides the ring until a click opens the Panel.
    @Test func theRingShowsUntilAClickOpen() {
        #expect(FocusRing().isVisible)
    }
}

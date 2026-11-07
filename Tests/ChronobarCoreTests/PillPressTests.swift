import Foundation
import Testing
import ChronobarCore

/// Every click on the Pill opens the Panel, wherever on the Pill it lands; none starts or pauses a timer.
@MainActor @Suite struct PillPressTests {
    // MARK: Panel closed: the button's action comes after the mouse-down

    @Test func aClickOnThePillOpensThePanel() {
        var press = PillPress()
        press.mouseDown(onPill: true, panelOpen: false)

        #expect(press.buttonAction(byMouse: true) == true)
    }

    /// VoiceOver or the keyboard press the button with no mouse-down.
    @Test func aPressNotByTheMouseOpensThePanel() {
        var press = PillPress()

        #expect(press.buttonAction(byMouse: false) == true)
    }

    /// The menu bar can send the action without the app seeing the mouse-down.
    @Test func aButtonActionWithNoMouseDownSeenOpensThePanel() {
        var press = PillPress()

        #expect(press.buttonAction(byMouse: true) == true)
    }

    // MARK: Panel open: the mouse-down closes it, and the button sends no action

    /// Its mouse-down closed the Panel; the mouse-up mustn't open it again.
    @Test func aPressOnTheCoverThatClosedThePanelDoesNothingMore() {
        var press = PillPress()
        press.mouseDown(onPill: true, panelOpen: true)

        #expect(press.mouseUp(overPill: true) == false)
    }

    @Test func aMouseDownWithThePanelOpenIsNotKeptForALaterPress() {
        var press = PillPress()
        press.mouseDown(onPill: true, panelOpen: false)

        press.mouseDown(onPill: true, panelOpen: true)

        #expect(press.mouseUp(overPill: true) == false)
    }

    // MARK: The Pill's cover: the press never reaches the menu bar, so the mouse-up ends it

    @Test func aPressOnTheCoverOpensThePanelOnItsMouseUp() {
        var press = PillPress()
        press.mouseDown(onPill: true, panelOpen: false)

        #expect(press.mouseUp(overPill: true) == true)
    }

    /// As with a button, a press let go away from the Pill is called off.
    @Test func aPressOnTheCoverReleasedAwayFromThePillDoesNothing() {
        var press = PillPress()
        press.mouseDown(onPill: true, panelOpen: false)

        #expect(press.mouseUp(overPill: false) == false)
        #expect(press.mouseUp(overPill: true) == false)
    }

    @Test func aMouseDownElsewhereIsNotAPressOnThePill() {
        var press = PillPress()
        press.mouseDown(onPill: true, panelOpen: false)

        press.mouseDown(onPill: false, panelOpen: false)

        #expect(press.mouseUp(overPill: true) == false)
    }

    // MARK: ⌘ held: the press is the start of a ⌘-drag, never a click

    /// With another app frontmost the app can't see ⌘ go down, so the cover can still be over the Pill.
    @Test func aPressWithCommandHeldOnTheCoverDoesNothing() {
        var press = PillPress()
        press.mouseDown(onPill: true, commandKey: true, panelOpen: false)

        #expect(press.mouseUp(overPill: true) == false)
    }

    @Test func aPressWithCommandHeldThroughTheMenuBarDoesNothing() {
        var press = PillPress()
        press.mouseDown(onPill: true, commandKey: true, panelOpen: false)

        #expect(press.buttonAction(byMouse: true) == false)
    }

    /// Each press is decided on its own: one with ⌘ held leaves nothing behind for the next.
    @Test func aPressWithCommandHeldDoesNotStopTheNextClick() {
        var press = PillPress()
        press.mouseDown(onPill: true, commandKey: true, panelOpen: false)
        _ = press.mouseUp(overPill: true)

        press.mouseDown(onPill: true, panelOpen: false)
        #expect(press.mouseUp(overPill: true) == true)
    }
}

import Foundation
import Testing
import ChronobarCore

/// A click on the Pill is decided where its mouse-down was, with the Panel open or closed.
@MainActor @Suite struct PillPressTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()
    let square = PillPointer.at(x: 12)
    let timeSegment = PillPointer.at(x: 40)

    func trackerWithASelectedProject() throws -> Tracker {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.pause()
        return tracker
    }

    // MARK: Panel closed: the button's action comes after the mouse-down

    @Test func aPressOnTheSquareThatDriftsOntoTheTimeSegmentStillToggles() throws {
        let tracker = try trackerWithASelectedProject()
        var press = PillPress()

        #expect(press.mouseDown(onPill: true, at: square, panelOpen: false, tracker: tracker) == nil)
        // The pointer is over the time segment by the mouse-up; only the mouse-down counts.
        #expect(press.buttonAction(byMouse: true, tracker: tracker) == .toggleTimer)
    }

    @Test func aPressOnTheTimeSegmentThatDriftsOntoTheSquareOpensThePanel() throws {
        let tracker = try trackerWithASelectedProject()
        var press = PillPress()

        _ = press.mouseDown(onPill: true, at: timeSegment, panelOpen: false, tracker: tracker)

        #expect(press.buttonAction(byMouse: true, tracker: tracker) == .openPanel)
    }

    /// VoiceOver or the keyboard press the button with no mouse-down, whatever an earlier click left.
    @Test func aPressNotByTheMouseOpensThePanel() throws {
        let tracker = try trackerWithASelectedProject()
        var press = PillPress()
        _ = press.mouseDown(onPill: true, at: square, panelOpen: false, tracker: tracker)

        #expect(press.buttonAction(byMouse: false, tracker: tracker) == .openPanel)
    }

    @Test func eachMouseDownIsUsedOnce() throws {
        let tracker = try trackerWithASelectedProject()
        var press = PillPress()
        _ = press.mouseDown(onPill: true, at: square, panelOpen: false, tracker: tracker)
        _ = press.buttonAction(byMouse: true, tracker: tracker)

        #expect(press.buttonAction(byMouse: true, tracker: tracker) == .openPanel)
    }

    @Test func aMouseDownElsewhereIsNotAPressOnThePill() throws {
        let tracker = try trackerWithASelectedProject()
        var press = PillPress()
        _ = press.mouseDown(onPill: true, at: square, panelOpen: false, tracker: tracker)

        #expect(press.mouseDown(onPill: false, at: square, panelOpen: false, tracker: tracker) == nil)
        #expect(press.buttonAction(byMouse: true, tracker: tracker) == .openPanel)
    }

    // MARK: Panel open: the button sends no action, so the mouse-down decides at once

    @Test func withThePanelOpenTheSquareActsOnItsMouseDownAndKeepsThePanel() throws {
        let tracker = try trackerWithASelectedProject()
        var press = PillPress()

        #expect(!PillPress.closesPanel(onPill: true, at: square, tracker: tracker))
        #expect(press.mouseDown(onPill: true, at: square, panelOpen: true, tracker: tracker) == .toggleTimer)
    }

    @Test func withThePanelOpenTheSquareOpensTheNewProjectFormWithNothingToStart() {
        let tracker = Tracker(clock: clock, storageRoot: root)
        var press = PillPress()

        #expect(press.mouseDown(onPill: true, at: square, panelOpen: true, tracker: tracker)
            == .openNewProjectForm)
    }

    @Test func withThePanelOpenTheTimeSegmentClosesIt() throws {
        let tracker = try trackerWithASelectedProject()
        var press = PillPress()

        #expect(PillPress.closesPanel(onPill: true, at: timeSegment, tracker: tracker))
        #expect(press.mouseDown(onPill: true, at: timeSegment, panelOpen: true, tracker: tracker) == nil)
    }

    @Test func withThePanelOpenAMouseDownElsewhereClosesIt() throws {
        let tracker = try trackerWithASelectedProject()
        var press = PillPress()

        #expect(PillPress.closesPanel(onPill: false, at: square, tracker: tracker))
        #expect(press.mouseDown(onPill: false, at: square, panelOpen: true, tracker: tracker) == nil)
    }

    /// A mouse-down with the Panel open never reaches the button's action, so it isn't kept for one.
    @Test func aMouseDownWithThePanelOpenIsNotKeptForALaterAction() throws {
        let tracker = try trackerWithASelectedProject()
        var press = PillPress()
        _ = press.mouseDown(onPill: true, at: square, panelOpen: false, tracker: tracker)

        _ = press.mouseDown(onPill: true, at: timeSegment, panelOpen: true, tracker: tracker)

        #expect(press.buttonAction(byMouse: true, tracker: tracker) == .openPanel)
    }

    // MARK: The Pill's cover: the press never reaches the menu bar, so the mouse-up ends it

    @Test func aPressOnTheCoverActsOnItsMouseUpFromWhereItBegan() throws {
        let tracker = try trackerWithASelectedProject()
        var press = PillPress()
        _ = press.mouseDown(onPill: true, at: square, panelOpen: false, tracker: tracker)

        #expect(press.mouseUp(overPill: true, tracker: tracker) == .toggleTimer)
    }

    /// Its mouse-down closed the Panel; the mouse-up mustn't open it again.
    @Test func aPressOnTheCoverThatClosedThePanelDoesNothingMore() throws {
        let tracker = try trackerWithASelectedProject()
        var press = PillPress()
        _ = press.mouseDown(onPill: true, at: timeSegment, panelOpen: true, tracker: tracker)

        #expect(press.mouseUp(overPill: true, tracker: tracker) == nil)
    }

    /// As with a button, a press let go away from the Pill is called off.
    @Test func aPressOnTheCoverReleasedAwayFromThePillDoesNothing() throws {
        let tracker = try trackerWithASelectedProject()
        var press = PillPress()
        _ = press.mouseDown(onPill: true, at: square, panelOpen: false, tracker: tracker)

        #expect(press.mouseUp(overPill: false, tracker: tracker) == nil)
        #expect(press.mouseUp(overPill: true, tracker: tracker) == nil)
    }

    // MARK: ⌘ held: the press is the start of a ⌘-drag, never a click

    /// With another app frontmost the app can't see ⌘ go down, so the cover can still be over the Pill.
    @Test func aPressWithCommandHeldOnTheCoverDoesNothing() throws {
        let tracker = try trackerWithASelectedProject()
        var press = PillPress()

        #expect(press.mouseDown(onPill: true, at: square, commandKey: true, panelOpen: false, tracker: tracker)
            == nil)
        #expect(press.mouseUp(overPill: true, tracker: tracker) == nil)
    }

    @Test func aPressWithCommandHeldThroughTheMenuBarDoesNothing() throws {
        let tracker = try trackerWithASelectedProject()
        var press = PillPress()
        _ = press.mouseDown(onPill: true, at: timeSegment, commandKey: true, panelOpen: false, tracker: tracker)

        #expect(press.buttonAction(byMouse: true, tracker: tracker) == nil)
    }

    @Test func withThePanelOpenAPressWithCommandHeldOnTheSquareDoesNothing() throws {
        let tracker = try trackerWithASelectedProject()
        var press = PillPress()

        #expect(press.mouseDown(onPill: true, at: square, commandKey: true, panelOpen: true, tracker: tracker)
            == nil)
    }

    /// Each press is decided on its own: one with ⌘ held leaves nothing behind for the next.
    @Test func aPressWithCommandHeldDoesNotStopTheNextClick() throws {
        let tracker = try trackerWithASelectedProject()
        var press = PillPress()
        _ = press.mouseDown(onPill: true, at: square, commandKey: true, panelOpen: false, tracker: tracker)
        _ = press.mouseUp(overPill: true, tracker: tracker)

        _ = press.mouseDown(onPill: true, at: square, panelOpen: false, tracker: tracker)
        #expect(press.mouseUp(overPill: true, tracker: tracker) == .toggleTimer)
    }
}

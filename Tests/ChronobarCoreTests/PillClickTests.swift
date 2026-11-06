import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct PillClickTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()
    /// A status item 68 points wide, with 8 points of padding either side of it in its window.
    let extent: ClosedRange<CGFloat> = -8...76

    @Test func aClickOnTheSquareTogglesTheSelectedProjectsTimer() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.pause()

        #expect(PillClick.action(at: PillPointer(x: 12, within: extent), tracker: tracker) == .toggleTimer)
    }

    @Test func aClickOnTheTimeSegmentOpensThePanel() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")

        #expect(PillClick.action(at: PillPointer(x: 40, within: extent), tracker: tracker) == .openPanel)
    }

    @Test func withNoSelectedProjectTheSquareOpensTheNewProjectForm() {
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(PillClick.action(at: PillPointer(x: 12, within: extent), tracker: tracker) == .openNewProjectForm)
    }

    /// The square's zone runs from the status item's leading edge, padding included, to halfway across the
    /// gap; the time segment's from there to the trailing edge.
    @Test func edgesAndPaddingBelongToTheNearestSegment() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")

        for x: CGFloat in [-8, 0, 25.9] {
            #expect(PillClick.action(at: PillPointer(x: x, within: extent), tracker: tracker) == .toggleTimer)
        }
        for x: CGFloat in [26, 68, 76] {
            #expect(PillClick.action(at: PillPointer(x: x, within: extent), tracker: tracker) == .openPanel)
        }
    }

    /// A press from VoiceOver or the keyboard, with the pointer elsewhere, has no position on the Pill.
    @Test func aPressWithThePointerOffTheStatusItemOpensThePanel() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")

        #expect(PillPointer(x: -9, within: extent) == .away)
        #expect(PillPointer(x: 77, within: extent) == .away)
        #expect(PillClick.action(at: .away, tracker: tracker) == .openPanel)
        #expect(tracker.running != nil)
    }
}

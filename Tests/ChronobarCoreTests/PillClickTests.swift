import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct PillClickTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func aClickOnTheSquareTogglesTheSelectedProjectsTimer() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.pause()

        #expect(PillClick.action(atX: 12, tracker: tracker) == .toggleTimer)
    }

    @Test func aClickOnTheTimeSegmentOpensThePanel() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")

        #expect(PillClick.action(atX: 40, tracker: tracker) == .openPanel)
    }

    @Test func withNoSelectedProjectTheSquareOpensTheNewProjectForm() {
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(PillClick.action(atX: 12, tracker: tracker) == .openNewProjectForm)
    }

    /// A press from VoiceOver or the keyboard, with the pointer elsewhere, has no position on the Pill.
    @Test func aPressWithThePointerOffThePillOpensThePanel() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")

        #expect(PillClick.action(atX: nil, tracker: tracker) == .openPanel)
        #expect(tracker.running != nil)
    }
}

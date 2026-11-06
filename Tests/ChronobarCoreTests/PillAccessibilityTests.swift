import Foundation
import Testing
import ChronobarCore

/// What VoiceOver reads on the Pill, and the action that does what a click on the square does.
@MainActor @Suite struct PillAccessibilityTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func whileRunningItReadsTheProjectAndItsTimeAndOffersPause() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.advance(83 * 60)
        tracker.tick()

        let pill = PillAccessibility(tracker: tracker)

        #expect(pill.label == "Website Redesign, 1 hour 23 minutes, running")
        #expect(pill.squareAction == "Pause")
    }

    @Test func whilePausedItReadsTheProjectAndItsTimeAndOffersStart() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.advance(45 * 60)
        try tracker.pause()

        let pill = PillAccessibility(tracker: tracker)

        #expect(pill.label == "Website Redesign, 45 minutes, paused")
        #expect(pill.squareAction == "Start")
    }

    /// The square then opens the ＋ form, and the action is named for it.
    @Test func withNoSelectedProjectItSaysSoAndOffersNewProject() {
        let tracker = Tracker(clock: clock, storageRoot: root)

        let pill = PillAccessibility(tracker: tracker)

        #expect(pill.label == "No Project selected")
        #expect(pill.squareAction == "New Project")
    }

    /// Archiving the Selected Project clears the selection and leaves its timer running.
    @Test func afterArchivingTheRunningProjectItSaysATimerRunsAndOffersPause() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.archiveProject("Website Redesign")

        let pill = PillAccessibility(tracker: tracker)

        #expect(pill.label == "No Project selected, running")
        #expect(pill.squareAction == "Pause")
    }
}

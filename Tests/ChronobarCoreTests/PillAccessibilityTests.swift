import Foundation
import Testing
import ChronobarCore

/// What VoiceOver reads on the Pill, and the action that does what a click on the square does.
@MainActor @Suite struct PillAccessibilityTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func withOneTimerItReadsItsProjectAndTodaysTotalAndOffersPause() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Internal", "0:30", on: tracker.today)
        try tracker.start("Website Redesign")
        clock.advance(53 * 60)
        tracker.tick()

        let pill = PillAccessibility(tracker: tracker)

        #expect(pill.label == "Website Redesign running, 1 hour 23 minutes today")
        #expect(pill.squareAction == "Pause")
    }

    @Test func withSeveralTimersItReadsHowManyRun() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.start("Internal")
        clock.advance(30 * 60)
        tracker.tick()

        let pill = PillAccessibility(tracker: tracker)

        #expect(pill.label == "2 timers running, 1 hour today")
        #expect(pill.squareAction == "Pause")
    }

    /// The square then opens the ＋ form, and the action is named for it.
    @Test func withNothingRunningItReadsTodaysTotalAndOffersNewProject() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.advance(45 * 60)
        try tracker.pause()

        let pill = PillAccessibility(tracker: tracker)

        #expect(pill.label == "Nothing running, 45 minutes today")
        #expect(pill.squareAction == "New Project")
    }

    /// An archived Project's timer keeps running, and the Pill still reads it.
    @Test func anArchivedProjectsTimerIsStillRead() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.archiveProject("Website Redesign")

        let pill = PillAccessibility(tracker: tracker)

        #expect(pill.label == "Website Redesign running, 0 minutes today")
        #expect(pill.squareAction == "Pause")
    }
}

import Foundation
import Testing
import ChronobarCore

/// What VoiceOver reads on the Pill: what the square and the time segment show, the running count and
/// today's Day total.
@MainActor @Suite struct PillAccessibilityTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func withOneTimerItReadsTheCountAndTodaysTotal() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Internal", "0:30", on: tracker.today)
        try tracker.start("Website Redesign")
        clock.advance(53 * 60)
        tracker.tick()

        #expect(PillAccessibility(tracker: tracker).label == "1 timer running, 1 hour 23 minutes today")
    }

    /// The total is the Day total across all Labels, which can pass the clock time.
    @Test func withSeveralTimersItReadsHowManyRunAndTheirSummedTotal() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.start("Internal")
        try tracker.start("Client A, Ticket 665")
        clock.advance(30 * 60)
        tracker.tick()

        #expect(PillAccessibility(tracker: tracker).label == "3 timers running, 1 hour 30 minutes today")
    }

    @Test func withNothingRunningItReadsTodaysTotal() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.advance(45 * 60)
        try tracker.pause()

        #expect(PillAccessibility(tracker: tracker).label == "Nothing running, 45 minutes today")
    }

    /// An archived Label's timer keeps running, and the Pill still counts it.
    @Test func anArchivedLabelsTimerIsStillCounted() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.archiveProject("Website Redesign")

        #expect(PillAccessibility(tracker: tracker).label == "1 timer running, 0 minutes today")
    }
}

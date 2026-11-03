import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct TimerTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func startingThenPausingRecordsTheTimeToday() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:30:00")
        try tracker.pause()

        #expect(tracker.running == nil)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 90 * 60)
    }

    @Test func runningTotalTicksUpOnEachTick() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.advance(83 * 60 + 30)
        tracker.tick()

        #expect(tracker.running?.project == "Website Redesign")
        #expect(DurationFormat.hoursMinutes(tracker.total("Website Redesign", on: tracker.today)) == "1:23")
    }

    @Test func toggleResumesTheSelectedProjectAndAddsToItsTotal() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.toggle()
        #expect(tracker.running == nil)
        #expect(tracker.selectedProject == "Website Redesign")

        clock.set("2026-11-03T13:00:00")
        try tracker.toggle()
        #expect(tracker.running?.project == "Website Redesign")
        clock.set("2026-11-03T13:30:00")
        try tracker.toggle()

        #expect(tracker.total("Website Redesign", on: tracker.today) == 90 * 60)
    }

    @Test func toggleWithNoSelectedProjectDoesNothing() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.toggle()

        #expect(tracker.running == nil)
        #expect(tracker.selectedProject == nil)
    }
}

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

    @Test func togglingAStoppedRowsProjectStartsItAndPausesTheOther() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.toggle("Internal")

        #expect(tracker.running?.project == "Internal")
        #expect(!tracker.isRunning("Website Redesign"))
        #expect(tracker.total("Website Redesign", on: tracker.today) == 60 * 60)
    }

    @Test func togglingTheRunningRowsProjectPausesIt() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T09:45:00")
        try tracker.toggle("  website redesign ")

        #expect(tracker.running == nil)
        #expect(tracker.selectedProject == "Website Redesign")
        #expect(tracker.total("Website Redesign", on: tracker.today) == 45 * 60)
    }

    @Test func isRunningMatchesTheProjectWhateverItsCase() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        #expect(!tracker.isRunning("Website Redesign"))
        try tracker.start("Website Redesign")

        #expect(tracker.isRunning("WEBSITE REDESIGN"))
        #expect(!tracker.isRunning("Internal"))
    }

    @Test func startingAProjectLoggedAheadRunsItToday() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let future = Day(year: 2026, month: 11, day: 16)
        try tracker.log("Vacation", "8:00", on: future)

        // Timers run only today: start and toggle take no Day, so a Day other than today never gets a timer.
        try tracker.toggle("Vacation")
        clock.set("2026-11-03T09:30:00")
        tracker.tick()

        #expect(tracker.running?.project == "Vacation")
        #expect(tracker.rows(tracker.today) == [Row(project: "Vacation", total: 30 * 60)])
        #expect(tracker.rows(future) == [Row(project: "Vacation", total: 8 * 60 * 60)])
        #expect(contents(dayFile(root, "2026-11-16"))?.contains(#""start""#) == false)
    }
}

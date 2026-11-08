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

        #expect(tracker.timers.isEmpty)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 90 * 60)
    }

    @Test func runningTotalTicksUpOnEachTick() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.advance(83 * 60 + 30)
        tracker.tick()

        #expect(tracker.timers.newest?.project == "Website Redesign")
        #expect(DurationFormat.hoursMinutes(tracker.total("Website Redesign", on: tracker.today)) == "1:23")
    }

    @Test func restartingAPausedProjectAddsToItsTotal() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.toggle("Website Redesign")
        #expect(tracker.timers.isEmpty)

        clock.set("2026-11-03T13:00:00")
        try tracker.toggle("Website Redesign")
        clock.set("2026-11-03T13:30:00")
        try tracker.toggle("Website Redesign")

        #expect(tracker.rows(tracker.today) == [Row(project: "Website Redesign", total: 90 * 60)])
    }

    @Test func startingAnotherProjectLeavesTheRunningOneRunning() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.start("Internal", source: .agent)
        clock.set("2026-11-03T11:00:00")
        tracker.tick()

        #expect(tracker.timers.map(\.project) == ["Website Redesign", "Internal"])
        #expect(tracker.total("Website Redesign", on: tracker.today) == 2 * 60 * 60)
        #expect(tracker.total("Internal", on: tracker.today) == 60 * 60)
        #expect(tracker.dayTotal(tracker.today) == 3 * 60 * 60)
    }

    @Test func togglingAStoppedRowsProjectStartsItAndLeavesTheOtherRunning() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.toggle("Internal")

        #expect(tracker.isRunning("Internal"))
        #expect(tracker.isRunning("Website Redesign"))
    }

    @Test func pausingOneTimerLeavesTheOthersRunning() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.start("Internal")
        try tracker.start("Mobile App")
        clock.set("2026-11-03T09:30:00")
        try tracker.toggle("internal")
        clock.set("2026-11-03T10:00:00")
        tracker.tick()

        #expect(tracker.timers.map(\.project) == ["Website Redesign", "Mobile App"])
        #expect(tracker.total("Internal", on: tracker.today) == 30 * 60)
        #expect(tracker.total("Mobile App", on: tracker.today) == 60 * 60)
        #expect(contents(dayFile(root, "2026-11-03")) == """
            {
              "date": "2026-11-03",
              "entries": [
                { "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": null, "source": "app" },
                { "project": "Internal", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T09:30:00-05:00", "source": "app" },
                { "project": "Mobile App", "start": "2026-11-03T09:00:00-05:00", "end": null, "source": "app" }
              ]
            }

            """)
    }

    /// With "Starting a timer pauses the others" on, any start pauses every other timer, an agent's too.
    @Test func withTheSettingOnAStartPausesEveryOtherTimer() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.start("Client A, Ticket 665", source: .agent)
        tracker.startPausesOthers = true
        clock.set("2026-11-03T10:00:00")
        try tracker.toggle("Internal")
        clock.set("2026-11-03T10:30:00")
        tracker.tick()

        #expect(tracker.timers.map(\.project) == ["Internal"])
        #expect(tracker.total("Website Redesign", on: tracker.today) == 60 * 60)
        #expect(tracker.total("Client A, Ticket 665", on: tracker.today) == 60 * 60)
        #expect(tracker.total("Internal", on: tracker.today) == 30 * 60)
    }

    /// Starting a running Project is a no-op with the setting on too: the others keep running.
    @Test func withTheSettingOnStartingARunningProjectChangesNothing() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.start("Internal")
        tracker.startPausesOthers = true
        let before = contents(dayFile(root, "2026-11-03"))
        clock.set("2026-11-03T10:00:00")
        try tracker.start("Website Redesign", source: .agent)

        #expect(tracker.timers.map(\.project) == ["Website Redesign", "Internal"])
        #expect(tracker.timers.map(\.start) == [FakeClock("2026-11-03T09:00:00").now, FakeClock("2026-11-03T09:00:00").now])
        #expect(contents(dayFile(root, "2026-11-03")) == before)
    }

    @Test func startingARunningProjectKeepsItsTimerGoing() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        let project = try tracker.start("  website redesign ", source: .agent).label

        #expect(project == "Website Redesign")
        #expect(tracker.timers.map(\.project) == ["Website Redesign"])
        #expect(tracker.timers.map(\.start) == [FakeClock("2026-11-03T09:00:00").now])
        #expect(tracker.timers.map(\.source) == [.app])
        #expect(tracker.total("Website Redesign", on: tracker.today) == 60 * 60)
        #expect(contents(dayFile(root, "2026-11-03"))?.components(separatedBy: #""project""#).count == 2)
    }

    @Test func togglingTheRunningRowsProjectPausesIt() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T09:45:00")
        try tracker.toggle("  website redesign ")

        #expect(tracker.timers.isEmpty)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 45 * 60)
    }

    /// v1 kept the Project ▶ resumed in the settings; nothing uses it now, so a launch removes it.
    @Test func aLaunchRemovesTheStoredSelectedProject() {
        let settings = TestSettings()
        let defaults = settings.fresh()
        defer { settings.remove() }
        defaults.set("Website Redesign", forKey: "selectedProject")

        _ = Tracker(clock: clock, storageRoot: root, defaults: defaults)

        #expect(settings.fresh().object(forKey: "selectedProject") == nil)
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

        #expect(tracker.timers.newest?.project == "Vacation")
        #expect(tracker.rows(tracker.today) == [Row(project: "Vacation", total: 30 * 60)])
        #expect(tracker.rows(future) == [Row(project: "Vacation", total: 8 * 60 * 60)])
        #expect(contents(dayFile(root, "2026-11-16"))?.contains(#""start""#) == false)
    }
}

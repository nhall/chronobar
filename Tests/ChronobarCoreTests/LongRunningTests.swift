import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct LongRunningTests {
    let root = temporaryRoot()

    @Test func aTimerIsReportedOnTheTickItPassesTheThreshold() throws {
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        tracker.longRunningThreshold = 4 * 3600
        try tracker.start("Client A, Ticket 665", source: .agent)

        clock.set("2026-11-03T12:59:59")
        #expect(tracker.ticked().isEmpty)
        clock.set("2026-11-03T13:00:00")
        #expect(tracker.ticked() == [LongRunning(project: "Client A, Ticket 665", since: FakeClock("2026-11-03T09:00:00").now)])
    }

    /// Reported once, however long it then runs, while a timer started later is reported on its own.
    @Test func eachTimerIsReportedOncePerRun() throws {
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        tracker.longRunningThreshold = 2 * 3600
        try tracker.start("Client A, Ticket 665", source: .agent)
        clock.set("2026-11-03T10:00:00")
        try tracker.start("Website Redesign")

        clock.set("2026-11-03T11:00:00")
        #expect(tracker.ticked().map(\.project) == ["Client A, Ticket 665"])
        clock.set("2026-11-03T11:00:01")
        #expect(tracker.ticked().isEmpty)
        clock.set("2026-11-03T12:00:00")
        #expect(tracker.ticked().map(\.project) == ["Website Redesign"])
        clock.set("2026-11-03T18:00:00")
        #expect(tracker.ticked().isEmpty)
        #expect(tracker.timers.count == 2)
        #expect(tracker.total("Client A, Ticket 665", on: tracker.today) == 9 * 3600)
    }

    /// Pausing and starting again is a new run, timed from the new start.
    @Test func restartingATimerResetsItsWarning() throws {
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        tracker.longRunningThreshold = 2 * 3600
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T11:00:00")
        #expect(tracker.ticked().count == 1)
        try tracker.pause("Website Redesign")

        clock.set("2026-11-03T12:00:00")
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T13:59:59")
        #expect(tracker.ticked().isEmpty)
        clock.set("2026-11-03T14:00:00")
        #expect(tracker.ticked() == [LongRunning(project: "Website Redesign", since: FakeClock("2026-11-03T12:00:00").now)])
    }

    @Test func offReportsNothing() throws {
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        tracker.longRunningThreshold = nil
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T21:00:00")
        #expect(tracker.ticked().isEmpty)
        #expect(tracker.isRunning("Website Redesign"))
    }

    /// Turning the warning on, or lowering it, reports a timer already past the new threshold.
    @Test func aThresholdChosenLaterReportsTimersAlreadyPastIt() throws {
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T14:00:00")
        #expect(tracker.ticked().isEmpty)
        tracker.longRunningThreshold = 4 * 3600
        #expect(tracker.ticked().map(\.project) == ["Website Redesign"])
    }

    /// The midnight split doesn't start a new run: 22:00 to 02:00 is four hours.
    @Test func aTimerSplitAtMidnightIsTimedFromItsFirstStart() throws {
        let clock = FakeClock("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        tracker.longRunningThreshold = 4 * 3600
        try tracker.start("Client A, Ticket 665", source: .agent)
        clock.set("2026-11-04T00:30:00")
        #expect(tracker.ticked().isEmpty)
        clock.set("2026-11-04T02:00:00")
        #expect(tracker.ticked() == [LongRunning(project: "Client A, Ticket 665", since: FakeClock("2026-11-03T22:00:00").now)])
        clock.set("2026-11-05T02:00:00")
        #expect(tracker.ticked().isEmpty)
    }

    /// The warning's Stop ends the timer when it is clicked, not when the threshold passed.
    @Test func stoppingAReportedRunStopsItNow() throws {
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        tracker.longRunningThreshold = 2 * 3600
        try tracker.start("Client A, Ticket 665", source: .agent)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T11:00:00")
        let reported = tracker.ticked()

        clock.set("2026-11-03T11:20:00")
        try tracker.pause(reported[0])
        #expect(!tracker.isRunning("Client A, Ticket 665"))
        #expect(tracker.isRunning("Website Redesign"))
        #expect(tracker.total("Client A, Ticket 665", on: tracker.today) == 2 * 3600 + 20 * 60)
    }

    /// A Stop clicked after the timer was paused and started again leaves the new run alone.
    @Test func stoppingAnEndedRunChangesNothing() throws {
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        tracker.longRunningThreshold = 2 * 3600
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T11:00:00")
        let reported = tracker.ticked()
        try tracker.pause("Website Redesign")
        clock.set("2026-11-03T11:10:00")
        try tracker.start("Website Redesign")

        clock.set("2026-11-03T11:20:00")
        try tracker.pause(reported[0])
        #expect(tracker.isRunning("Website Redesign"))
    }

    /// An agent's timer keeps running across a quit; the relaunched app doesn't warn about it again.
    @Test func aRelaunchDoesNotReportARunAgain() throws {
        let settings = TestSettings()
        defer { settings.remove() }
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
        tracker.longRunningThreshold = 2 * 3600
        try tracker.start("Client A, Ticket 665", source: .agent)
        try tracker.start("Website Redesign", source: .agent)
        clock.set("2026-11-03T10:30:00")
        try tracker.pause("Website Redesign")
        try tracker.start("Website Redesign", source: .agent)
        clock.set("2026-11-03T11:00:00")
        #expect(tracker.ticked().map(\.project) == ["Client A, Ticket 665"])

        clock.set("2026-11-03T12:30:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
        relaunched.longRunningThreshold = 2 * 3600
        #expect(relaunched.ticked().map(\.project) == ["Website Redesign"])
    }

    /// Any caller may tick (the Panel opening, an agent's request); the run waits until it is taken.
    @Test func aRunFoundByAnEarlierTickWaitsUntilTaken() throws {
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        tracker.longRunningThreshold = 2 * 3600
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T11:00:00")
        tracker.tick()
        clock.set("2026-11-03T11:00:01")
        tracker.tick()

        #expect(tracker.takeLongRunning().map(\.project) == ["Website Redesign"])
        #expect(tracker.ticked().isEmpty)
    }

    /// A run stopped before the app took it isn't reported: there is nothing left to warn about.
    @Test func aRunStoppedBeforeItIsTakenIsLeftOut() throws {
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        tracker.longRunningThreshold = 2 * 3600
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T11:00:00")
        tracker.tick()
        try tracker.pause("Website Redesign")

        #expect(tracker.takeLongRunning().isEmpty)
    }
}

extension Tracker {
    /// Ticks as the app does each second, returning the runs newly past the threshold.
    func ticked() -> [LongRunning] {
        tick()
        return takeLongRunning()
    }
}

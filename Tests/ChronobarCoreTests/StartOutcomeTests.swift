import Foundation
import Testing
import ChronobarCore

/// What a start says it did: the Label as stored, whether it was already running, the Timer now running
/// for it, and the Timers "Starting a timer pauses the others" stopped.
@MainActor @Suite struct StartOutcomeTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func withTheSettingOnTheOutcomeListsEveryTimerItPausedAndWhenItStopped() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T09:15:00")
        try tracker.start("Client A, Ticket 665", source: .agent)
        tracker.startPausesOthers = true
        clock.set("2026-11-03T10:00:00")

        let outcome = try tracker.start("Internal")

        #expect(outcome.paused.map(\.timer.project) == ["Website Redesign", "Client A, Ticket 665"])
        #expect(outcome.paused.map(\.timer.start) == [clock.date("2026-11-03T09:00:00"), clock.date("2026-11-03T09:15:00")])
        #expect(outcome.paused.map(\.timer.source) == [.app, .agent])
        #expect(outcome.paused.map(\.end) == [clock.date("2026-11-03T10:00:00"), clock.date("2026-11-03T10:00:00")])
        #expect(!outcome.alreadyRunning)
        #expect(outcome.label == "Internal")
        #expect(outcome.timer.project == "Internal")
        #expect(outcome.timer.start == clock.date("2026-11-03T10:00:00"))
        #expect(outcome.timer.source == .app)
        #expect(tracker.timers.map(\.project) == ["Internal"])
    }

    @Test func withTheSettingOffTheOutcomeListsNoPausedTimers() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")

        let outcome = try tracker.start("Internal")

        #expect(outcome.paused.isEmpty)
        #expect(!outcome.alreadyRunning)
        #expect(tracker.timers.map(\.project) == ["Website Redesign", "Internal"])
    }

    @Test func startingARunningLabelIsAlreadyRunningPausesNothingAndKeepsItsStart() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.start("Internal", source: .agent)
        tracker.startPausesOthers = true
        clock.set("2026-11-03T10:00:00")

        let outcome = try tracker.start("Website Redesign", source: .agent)

        #expect(outcome.alreadyRunning)
        #expect(outcome.paused.isEmpty)
        #expect(outcome.timer.project == "Website Redesign")
        #expect(outcome.timer.start == clock.date("2026-11-03T09:00:00"))
        #expect(outcome.timer.source == .app)
        #expect(tracker.timers.map(\.project) == ["Website Redesign", "Internal"])
    }

    @Test func startingUnderADifferentlyCasedNameReturnsTheStoredSpelling() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.pause()
        clock.set("2026-11-03T10:00:00")

        let outcome = try tracker.start("  website REDESIGN ")

        #expect(outcome.label == "Website Redesign")
        #expect(outcome.timer.project == "Website Redesign")
        #expect(!outcome.alreadyRunning)
    }
}

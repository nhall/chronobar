import Foundation
import Testing
import ChronobarCore
import ChronobarOperations

/// `status`: every running timer with its stored start, source and total today, and today's totals.
@MainActor @Suite struct StatusTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func withNothingRunningStatusListsNoTimers() throws {
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let status = try operations.status()

        #expect(status.timers.isEmpty)
        #expect(status.today == DayResult(date: "2026-11-03", totalSeconds: 0, elapsedSeconds: 0))
    }

    @Test func statusListsEachRunningTimerWithItsStartSourceAndTotal() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.start("Internal", source: .agent)
        clock.set("2026-11-03T10:30:00")
        let operations = Operations(tracker: tracker)

        let status = try operations.status()

        #expect(status.timers == [
            TimerResult(label: "Website Redesign", start: clock.date("2026-11-03T09:00:00"), source: .app,
                        totalSeconds: 90 * 60),
            TimerResult(label: "Internal", start: clock.date("2026-11-03T10:00:00"), source: .agent,
                        totalSeconds: 30 * 60),
        ])
        #expect(status.today == DayResult(date: "2026-11-03", totalSeconds: 120 * 60, elapsedSeconds: 90 * 60))
    }

    /// The app may have sat a while since its last tick; status counts up to the clock, not to then.
    @Test func statusCountsUpToTheClock() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T09:45:00")

        let status = try Operations(tracker: tracker).status()

        #expect(status.timers.map(\.totalSeconds) == [45 * 60])
    }
}

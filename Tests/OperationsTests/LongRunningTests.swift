import Foundation
import Testing
import ChronobarCore
import ChronobarOperations

/// Only the app ticks; a timer that passes the long-running threshold around an agent's request must still
/// reach the app's notifier through the app's next tick.
@MainActor @Suite struct LongRunningTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func aTimerPassingTheThresholdDuringARequestIsReportedByTheAppsNextTick() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        tracker.longRunningThreshold = 4 * 3600
        try tracker.start("Client A, Ticket 665")
        clock.set("2026-11-03T13:00:00")

        _ = try Operations(tracker: tracker).status()

        #expect(tracker.tick().map(\.run) == [TimerRun(project: "Client A, Ticket 665", since: clock.date("2026-11-03T09:00:00"))])
        _ = try Operations(tracker: tracker).status()
        #expect(tracker.tick().isEmpty)
    }
}

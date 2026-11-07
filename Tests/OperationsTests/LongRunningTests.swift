import Foundation
import Testing
import ChronobarCore
import ChronobarOperations

/// Every request ticks the Tracker first; a timer that passes the long-running threshold then must still
/// reach the app's notifier.
@MainActor @Suite struct LongRunningTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func aTimerPassingTheThresholdDuringARequestIsStillReportedToTheApp() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        tracker.longRunningThreshold = 4 * 3600
        try tracker.start("Client A, Ticket 665")
        clock.set("2026-11-03T13:00:00")

        _ = try Operations(tracker: tracker).status()
        tracker.tick()

        #expect(tracker.takeLongRunning() == [LongRunning(project: "Client A, Ticket 665", since: clock.date("2026-11-03T09:00:00"))])
        #expect(tracker.takeLongRunning().isEmpty)
    }
}

import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct RecoveryTests {
    let root = temporaryRoot()
    let suite = "ChronobarCoreTests-\(UUID().uuidString)"

    /// Crashed at about 11:00 with Heartbeats every minute: idle since the last one, not since 09:00.
    @Test func recoveryReportsIdleSinceTheLastHeartbeat() throws {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root, defaults: defaults)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:59:00")
        tracker.tick()
        tracker.heartbeat()

        clock.set("2026-11-03T13:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: UserDefaults(suiteName: suite)!)
        #expect(relaunched.recoverAfterLaunch() == FakeClock("2026-11-03T10:59:00").now)
        #expect(relaunched.running?.project == "Website Redesign")
    }

    /// Crashed before the first Heartbeat: idle since the Entry's start, so removing drops all of it.
    @Test func withoutAHeartbeatRecoveryReportsIdleSinceTheEntrysStart() throws {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let clock = FakeClock("2026-11-03T09:00:00")
        try Tracker(clock: clock, storageRoot: root, defaults: defaults).start("Website Redesign")

        clock.set("2026-11-03T13:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: UserDefaults(suiteName: suite)!)
        let since = try #require(relaunched.recoverAfterLaunch())
        #expect(since == FakeClock("2026-11-03T09:00:00").now)
        try relaunched.resolveIdle(since: since, choice: .removeAndStop)

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": []
        }

        """)
        #expect(relaunched.running == nil)
    }

    /// A Heartbeat left by an earlier timer is older than the open Entry, so the Entry's start wins.
    @Test func aHeartbeatFromAnEarlierTimerIsIgnored() throws {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root, defaults: defaults)
        try tracker.start("Internal")
        clock.set("2026-11-03T09:30:00")
        tracker.heartbeat()
        try tracker.pause()
        clock.set("2026-11-03T11:00:00")
        try tracker.start("Website Redesign")

        clock.set("2026-11-03T13:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: UserDefaults(suiteName: suite)!)
        #expect(relaunched.recoverAfterLaunch() == FakeClock("2026-11-03T11:00:00").now)
    }

    @Test func nothingLeftOpenMeansNothingToRecover() throws {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root, defaults: defaults)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        tracker.heartbeat()
        try tracker.pause()

        clock.set("2026-11-03T13:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: UserDefaults(suiteName: suite)!)
        #expect(relaunched.recoverAfterLaunch() == nil)
    }
}

import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct RecoveryTests {
    let root = temporaryRoot()
    let settings = TestSettings()

    /// Crashed at about 11:00 with Heartbeats every minute: idle since the last one, not since 09:00.
    @Test func recoveryReportsIdleSinceTheLastHeartbeat() throws {
        let defaults = settings.fresh()
        defer { settings.remove() }
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root, defaults: defaults)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:59:00")
        tracker.tick()
        tracker.heartbeat()

        clock.set("2026-11-03T13:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
        #expect(relaunched.recoverAfterLaunch() == FakeClock("2026-11-03T10:59:00").now)
        #expect(relaunched.pendingIdle == PendingIdle(since: FakeClock("2026-11-03T10:59:00").now))
        #expect(relaunched.running?.project == "Website Redesign")
    }

    /// Crashed before the first Heartbeat: idle since the Entry's start, so removing drops all of it.
    @Test func withoutAHeartbeatRecoveryReportsIdleSinceTheEntrysStart() throws {
        let defaults = settings.fresh()
        defer { settings.remove() }
        let clock = FakeClock("2026-11-03T09:00:00")
        try Tracker(clock: clock, storageRoot: root, defaults: defaults).start("Website Redesign")

        clock.set("2026-11-03T13:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
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
        let defaults = settings.fresh()
        defer { settings.remove() }
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root, defaults: defaults)
        try tracker.start("Internal")
        clock.set("2026-11-03T09:30:00")
        tracker.heartbeat()
        try tracker.pause()
        clock.set("2026-11-03T11:00:00")
        try tracker.start("Website Redesign")

        clock.set("2026-11-03T13:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
        #expect(relaunched.recoverAfterLaunch() == FakeClock("2026-11-03T11:00:00").now)
    }

    /// Crashed on Tuesday night, relaunched on Thursday morning: the Entry open in Tuesday's file is found,
    /// split across the Days since like a running timer, and removing cuts it at the last Heartbeat.
    @Test func anEntryLeftOpenOnAPastDayIsRecovered() throws {
        let defaults = settings.fresh()
        defer { settings.remove() }
        let clock = FakeClock("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root, defaults: defaults)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T23:30:00")
        tracker.heartbeat()

        clock.set("2026-11-05T09:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
        let since = try #require(relaunched.recoverAfterLaunch())
        #expect(since == FakeClock("2026-11-03T23:30:00").now)
        // Until the alert is answered the timer runs on in today's file, as after waking from sleep.
        #expect(relaunched.running?.project == "Website Redesign")
        #expect(relaunched.today == Day(year: 2026, month: 11, day: 5))
        #expect(relaunched.total("Website Redesign", on: relaunched.today) == 9 * 3600)

        try relaunched.resolveIdle(since: since, choice: .remove)
        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T22:00:00-05:00", "end": "2026-11-03T23:30:00-05:00" }
          ]
        }

        """)
        #expect(contents(dayFile(root, "2026-11-04")) == """
        {
          "date": "2026-11-04",
          "entries": []
        }

        """)
        #expect(contents(dayFile(root, "2026-11-05")) == """
        {
          "date": "2026-11-05",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-05T09:00:00-05:00", "end": null }
          ]
        }

        """)
        #expect(relaunched.running?.start == clock.now)
    }

    /// Without a Heartbeat the past Day's Entry is reported from its start.
    @Test func anEntryLeftOpenOnAPastDayWithoutAHeartbeat() throws {
        let clock = FakeClock("2026-11-03T22:00:00")
        try Tracker(clock: clock, storageRoot: root).start("Website Redesign")

        clock.set("2026-11-04T08:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root)
        #expect(relaunched.recoverAfterLaunch() == FakeClock("2026-11-03T22:00:00").now)
        #expect(relaunched.running?.start == FakeClock("2026-11-04T00:00:00").now)
    }

    /// Crashed at about 10:00, and today's file had a typo at relaunch. Once it's fixed the open Entry is
    /// recovered like any crash: idle since the last Heartbeat, not counted on until the alert is answered.
    @Test func anEntryLeftOpenInTodaysMalformedFileIsRecoveredOnceItParses() throws {
        let defaults = settings.fresh()
        defer { settings.remove() }
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root, defaults: defaults)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        tracker.heartbeat()
        let good = try #require(contents(dayFile(root, "2026-11-03")))
        try "{ oops".write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)

        clock.set("2026-11-03T13:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
        #expect(relaunched.recoverAfterLaunch() == nil)
        #expect(relaunched.running == nil)

        try good.write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        clock.set("2026-11-03T14:00:00")
        relaunched.reload()
        #expect(relaunched.pendingIdle == PendingIdle(since: FakeClock("2026-11-03T10:00:00").now))
        #expect(relaunched.running?.project == "Website Redesign")

        try relaunched.resolveIdle(since: FakeClock("2026-11-03T10:00:00").now, choice: .removeAndStop)
        #expect(relaunched.pendingIdle == nil)
        #expect(relaunched.running == nil)
        #expect(relaunched.total("Website Redesign", on: relaunched.today) == 3600)
    }

    /// Crashed on Tuesday night, and Tuesday's file had a typo at relaunch on Thursday. Once it's fixed and
    /// read, its open Entry is recovered as if found at launch, instead of counting on forever.
    @Test func anEntryLeftOpenInAMalformedPastDayIsRecoveredOnceItParses() throws {
        let defaults = settings.fresh()
        defer { settings.remove() }
        let clock = FakeClock("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root, defaults: defaults)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T23:30:00")
        tracker.heartbeat()
        let good = try #require(contents(dayFile(root, "2026-11-03")))
        try "{ oops".write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)

        clock.set("2026-11-05T09:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
        #expect(relaunched.recoverAfterLaunch() == nil)

        try good.write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        clock.set("2026-11-05T10:00:00")
        relaunched.reload()
        _ = relaunched.weekTotals(containing: relaunched.today)
        relaunched.tick()
        #expect(relaunched.pendingIdle == PendingIdle(since: FakeClock("2026-11-03T23:30:00").now))
        #expect(relaunched.running?.project == "Website Redesign")
        #expect(relaunched.total("Website Redesign", on: Day("2026-11-03")!) == 2 * 3600)

        try relaunched.resolveIdle(since: FakeClock("2026-11-03T23:30:00").now, choice: .removeAndStop)
        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T22:00:00-05:00", "end": "2026-11-03T23:30:00-05:00" }
          ]
        }

        """)
        #expect(relaunched.running == nil)
        #expect(relaunched.dayTotal(relaunched.today) == 0)
    }

    /// As above, but a timer was started after relaunching. The old Entry can't be the timer as well, so it
    /// ends at the end of its Day (before Chronobar launched), and only the time up to there is idle.
    @Test func anEntryFoundOpenWhileAnotherTimerRunsIsClosed() throws {
        let defaults = settings.fresh()
        defer { settings.remove() }
        let clock = FakeClock("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root, defaults: defaults)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T23:30:00")
        tracker.heartbeat()
        let good = try #require(contents(dayFile(root, "2026-11-03")))
        try "{ oops".write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)

        clock.set("2026-11-05T09:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
        relaunched.recoverAfterLaunch()
        try relaunched.start("Internal")

        try good.write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        clock.set("2026-11-05T10:00:00")
        relaunched.reload()
        _ = relaunched.weekTotals(containing: relaunched.today)
        relaunched.tick()
        let midnight = FakeClock("2026-11-04T00:00:00").now
        #expect(relaunched.pendingIdle == PendingIdle(since: FakeClock("2026-11-03T23:30:00").now, until: midnight))
        #expect(relaunched.running?.project == "Internal")
        #expect(relaunched.total("Website Redesign", on: Day("2026-11-03")!) == 2 * 3600)

        try relaunched.resolveIdle(since: FakeClock("2026-11-03T23:30:00").now, until: midnight, choice: .remove)
        #expect(relaunched.total("Website Redesign", on: Day("2026-11-03")!) == 90 * 60)
        #expect(relaunched.running?.project == "Internal")
        #expect(relaunched.running?.start == FakeClock("2026-11-05T09:00:00").now)
        #expect(relaunched.total("Internal", on: relaunched.today) == 3600)
        #expect(relaunched.pendingIdle == nil)
    }

    @Test func nothingLeftOpenMeansNothingToRecover() throws {
        let defaults = settings.fresh()
        defer { settings.remove() }
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root, defaults: defaults)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        tracker.heartbeat()
        try tracker.pause()

        clock.set("2026-11-03T13:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
        #expect(relaunched.recoverAfterLaunch() == nil)
    }
}

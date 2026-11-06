import Foundation
import Testing
import ChronobarCore

/// Idle handling, crash recovery and quitting act on timers started in the app; agents keep working
/// while the user is away, so their timers run on.
@MainActor @Suite struct IdleBySourceTests {
    let root = temporaryRoot()
    let settings = TestSettings()

    @Test func removeCutsAppTimersAndLeavesAgentTimersRunning() throws {
        let clock = FakeClock("2026-11-03T13:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.start("Client A, Ticket 665", source: .agent)
        try tracker.start("Internal")
        clock.set("2026-11-03T15:00:00")
        try tracker.resolveIdle(since: FakeClock("2026-11-03T14:10:00").now, choice: .remove)

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T13:00:00-05:00", "end": "2026-11-03T14:10:00-05:00", "source": "app" },
            { "project": "Client A, Ticket 665", "start": "2026-11-03T13:00:00-05:00", "end": null, "source": "agent" },
            { "project": "Internal", "start": "2026-11-03T13:00:00-05:00", "end": "2026-11-03T14:10:00-05:00", "source": "app" },
            { "project": "Website Redesign", "start": "2026-11-03T15:00:00-05:00", "end": null, "source": "app" },
            { "project": "Internal", "start": "2026-11-03T15:00:00-05:00", "end": null, "source": "app" }
          ]
        }

        """)
        #expect(tracker.timers.map(\.project) == ["Client A, Ticket 665", "Website Redesign", "Internal"])
        #expect(tracker.timers["Client A, Ticket 665"]?.start == FakeClock("2026-11-03T13:00:00").now)
        #expect(tracker.total("Client A, Ticket 665", on: tracker.today) == 2 * 3600)
    }

    /// Back from a bounded stretch (a crash's Idle time ends at the relaunch): the app timers' pieces
    /// after it are closed too, and the agent's timer runs on.
    @Test func removeAndStopStopsEveryAppTimerAndLeavesAgentTimersRunning() throws {
        let clock = FakeClock("2026-11-03T13:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.start("Client A, Ticket 665", source: .agent)
        clock.set("2026-11-03T15:00:00")
        try tracker.resolveIdle(since: FakeClock("2026-11-03T14:00:00").now,
                                until: FakeClock("2026-11-03T14:30:00").now, choice: .removeAndStop)

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T13:00:00-05:00", "end": "2026-11-03T14:00:00-05:00", "source": "app" },
            { "project": "Website Redesign", "start": "2026-11-03T14:30:00-05:00", "end": "2026-11-03T15:00:00-05:00", "source": "app" },
            { "project": "Client A, Ticket 665", "start": "2026-11-03T13:00:00-05:00", "end": null, "source": "agent" }
          ]
        }

        """)
        #expect(tracker.timers.map(\.project) == ["Client A, Ticket 665"])
    }

    @Test func keepLeavesEveryTimerRunning() throws {
        let clock = FakeClock("2026-11-03T13:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.start("Client A, Ticket 665", source: .agent)
        let before = contents(dayFile(root, "2026-11-03"))
        clock.set("2026-11-03T15:00:00")
        try tracker.resolveIdle(since: FakeClock("2026-11-03T14:00:00").now, choice: .keep)

        #expect(contents(dayFile(root, "2026-11-03")) == before)
        #expect(tracker.timers.count == 2)
    }

    /// The user was away for the agents' finished Entries as well, but the agents weren't.
    @Test func removeLeavesFinishedAgentEntriesInTheStretchWhole() throws {
        let clock = FakeClock("2026-11-03T13:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T14:20:00")
        try tracker.start("Client A, Ticket 665", source: .agent)
        clock.set("2026-11-03T14:40:00")
        try tracker.pause("Client A, Ticket 665")
        clock.set("2026-11-03T15:00:00")
        try tracker.resolveIdle(since: FakeClock("2026-11-03T14:10:00").now, choice: .removeAndStop)

        #expect(tracker.total("Client A, Ticket 665", on: tracker.today) == 20 * 60)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 70 * 60)
        #expect(tracker.timers.isEmpty)
    }

    /// Crashed at about 11:00 with both kinds running: the app timer's time since the last Heartbeat is
    /// pending; the agent's timer just keeps running.
    @Test func recoveryReportsIdleForAppTimersSinceTheLastHeartbeat() throws {
        let defaults = settings.fresh()
        defer { settings.remove() }
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root, defaults: defaults)
        try tracker.start("Client A, Ticket 665", source: .agent)
        clock.set("2026-11-03T10:00:00")
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:59:00")
        tracker.heartbeat()

        clock.set("2026-11-03T13:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
        let since = try #require(relaunched.recoverAfterLaunch())
        #expect(since == FakeClock("2026-11-03T10:59:00").now)
        #expect(relaunched.pendingIdle == PendingIdle(since: since))

        try relaunched.resolveIdle(since: since, choice: .removeAndStop)
        #expect(relaunched.timers.map(\.project) == ["Client A, Ticket 665"])
        #expect(relaunched.total("Website Redesign", on: relaunched.today) == 59 * 60)
        #expect(relaunched.total("Client A, Ticket 665", on: relaunched.today) == 4 * 3600)
    }

    /// Without a Heartbeat the app timer is idle since its own start, not the agent's earlier one.
    @Test func withoutAHeartbeatRecoveryReportsIdleSinceTheAppTimersStart() throws {
        let defaults = settings.fresh()
        defer { settings.remove() }
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root, defaults: defaults)
        try tracker.start("Client A, Ticket 665", source: .agent)
        clock.set("2026-11-03T10:00:00")
        try tracker.start("Website Redesign")

        clock.set("2026-11-03T13:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
        #expect(relaunched.recoverAfterLaunch() == FakeClock("2026-11-03T10:00:00").now)
        #expect(relaunched.timers.count == 2)
    }

    /// Only agents' timers were open: nothing to ask about, and they keep counting, across midnight too.
    @Test func agentTimersLeftOpenByACrashKeepRunning() throws {
        let defaults = settings.fresh()
        defer { settings.remove() }
        let clock = FakeClock("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root, defaults: defaults)
        try tracker.start("Client A, Ticket 665", source: .agent)
        clock.set("2026-11-03T23:30:00")
        tracker.heartbeat()

        clock.set("2026-11-04T09:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
        #expect(relaunched.recoverAfterLaunch() == nil)
        #expect(relaunched.pendingIdle == nil)
        #expect(relaunched.timers.map(\.project) == ["Client A, Ticket 665"])
        #expect(relaunched.timers.first?.source == .agent)
        #expect(relaunched.total("Client A, Ticket 665", on: Day("2026-11-03")!) == 2 * 3600)
        #expect(relaunched.total("Client A, Ticket 665", on: relaunched.today) == 9 * 3600)
    }

    /// An agent's Entry left open on a past Day found while other timers run is closed at the end of its
    /// Day, as an app's is, but with no Idle time to ask about.
    @Test func anAgentEntryFoundOpenOnAPastDayWhileAnotherTimerRunsIsClosedWithoutIdleTime() throws {
        let defaults = settings.fresh()
        defer { settings.remove() }
        let clock = FakeClock("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root, defaults: defaults)
        try tracker.start("Client A, Ticket 665", source: .agent)
        let good = try #require(contents(dayFile(root, "2026-11-03")))
        try "{ oops".write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)

        clock.set("2026-11-05T09:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
        relaunched.recoverAfterLaunch()
        try relaunched.start("Internal")

        try good.write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        clock.set("2026-11-05T10:00:00")
        _ = relaunched.weekTotals(containing: relaunched.today)
        relaunched.tick()
        #expect(relaunched.pendingIdle == nil)
        #expect(relaunched.total("Client A, Ticket 665", on: Day("2026-11-03")!) == 2 * 3600)
        #expect(relaunched.timers.map(\.project) == ["Internal"])
    }

    @Test func quitClosesAppTimersAndLeavesAgentEntriesOpen() throws {
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.start("Client A, Ticket 665", source: .agent)
        clock.set("2026-11-03T17:00:00")
        try tracker.quit()

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T17:00:00-05:00", "source": "app" },
            { "project": "Client A, Ticket 665", "start": "2026-11-03T09:00:00-05:00", "end": null, "source": "agent" }
          ]
        }

        """)
    }

    /// The agent's Entry left open by quitting isn't a crash: the next launch has nothing to ask about.
    @Test func afterQuittingTheNextLaunchKeepsTheAgentTimerWithoutAsking() throws {
        let defaults = settings.fresh()
        defer { settings.remove() }
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root, defaults: defaults)
        try tracker.start("Website Redesign")
        try tracker.start("Client A, Ticket 665", source: .agent)
        clock.set("2026-11-03T17:00:00")
        try tracker.quit()

        clock.set("2026-11-03T18:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
        #expect(relaunched.recoverAfterLaunch() == nil)
        #expect(relaunched.timers.map(\.project) == ["Client A, Ticket 665"])
        #expect(relaunched.total("Website Redesign", on: relaunched.today) == 8 * 3600)
    }
}

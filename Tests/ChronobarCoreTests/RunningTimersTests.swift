import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct RunningTimersTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    /// An agent's timer is marked in the Day file, and stays marked once it's closed and read again.
    @Test func anAgentSourceRoundTripsThroughTheDayFile() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Client A, Ticket 665", source: .agent)
        #expect(tracker.timers.map(\.source) == [.agent])
        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Client A, Ticket 665", "start": "2026-11-03T09:00:00-05:00", "end": null, "source": "agent" }
          ]
        }

        """)

        let relaunched = Tracker(clock: clock, storageRoot: root)
        #expect(relaunched.timers["client a, ticket 665"]?.source == .agent)
        clock.set("2026-11-03T10:00:00")
        try relaunched.pause()
        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Client A, Ticket 665", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "agent" }
          ]
        }

        """)
    }

    /// A v1 Day file has no `source`: its Entries are the app's, and a write marks them so.
    @Test func aMissingSourceReadsAsTheApp() throws {
        try writeToday("""
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Internal", "start": "2026-11-03T08:00:00-05:00", "end": null }
          ]
        }

        """)
        let tracker = Tracker(clock: clock, storageRoot: root)
        #expect(tracker.timers.map(\.source) == [.app])

        try tracker.pause()
        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Internal", "start": "2026-11-03T08:00:00-05:00", "end": "2026-11-03T09:00:00-05:00", "source": "app" }
          ]
        }

        """)
    }

    @Test func anUnknownSourceMakesTheFileMalformed() throws {
        try writeToday("""
        { "date": "2026-11-03", "entries": [
          { "project": "Internal", "start": "2026-11-03T08:00:00-05:00", "end": null, "source": "robot" }
        ] }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)
        #expect(tracker.isMalformed(tracker.today))
        #expect(tracker.timers.isEmpty)
    }

    /// Two open Entries, one per Project, as v2 writes them: both run, through a reload and a relaunch.
    @Test func severalOpenEntriesAllRunAndSurviveAReloadAndARelaunch() throws {
        try writeToday(twoOpen)
        let tracker = Tracker(clock: clock, storageRoot: root)
        #expect(tracker.timers.map(\.project) == ["Client A, Ticket 665", "Internal"])
        #expect(tracker.timers.map(\.source) == [.agent, .app])
        #expect(tracker.isRunning("client a, ticket 665") && tracker.isRunning("Internal"))

        clock.set("2026-11-03T09:30:00")
        tracker.reload()
        #expect(tracker.timers.count == 2)
        #expect(tracker.total("Client A, Ticket 665", on: tracker.today) == 90 * 60)
        #expect(tracker.total("Internal", on: tracker.today) == 3600)

        let relaunched = Tracker(clock: clock, storageRoot: root)
        #expect(relaunched.timers == tracker.timers)
        #expect(relaunched.dayTotal(relaunched.today) == 150 * 60)
    }

    /// With "Starting a timer pauses the others" on, a start pauses the others, whoever started them.
    @Test func withTheSettingOnStartingPausesEveryOtherTimer() throws {
        try writeToday(twoOpen)
        let tracker = Tracker(clock: clock, storageRoot: root)
        tracker.startPausesOthers = true
        try tracker.start("Website Redesign")

        #expect(tracker.timers.map(\.project) == ["Website Redesign"])
        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Client A, Ticket 665", "start": "2026-11-03T08:00:00-05:00", "end": "2026-11-03T09:00:00-05:00", "source": "agent" },
            { "project": "Internal", "start": "2026-11-03T08:30:00-05:00", "end": "2026-11-03T09:00:00-05:00", "source": "app" },
            { "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": null, "source": "app" }
          ]
        }

        """)
    }

    /// A row's ⏸ pauses its own timer and leaves the others running.
    @Test func togglingARunningRowPausesOnlyThatTimer() throws {
        try writeToday(twoOpen)
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.toggle("internal")

        #expect(tracker.timers.map(\.project) == ["Client A, Ticket 665"])
        #expect(Tracker(clock: clock, storageRoot: root).timers.map(\.project) == ["Client A, Ticket 665"])
        #expect(tracker.total("Internal", on: tracker.today) == 30 * 60)
    }

    /// At midnight each running timer is split into the new Day with its source.
    @Test func everyRunningTimerRollsOverAtMidnight() throws {
        clock.set("2026-11-03T23:30:00")
        try writeToday(twoOpen)
        let tracker = Tracker(clock: clock, storageRoot: root)
        clock.set("2026-11-04T00:15:00")
        tracker.tick()

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Client A, Ticket 665", "start": "2026-11-03T08:00:00-05:00", "end": "2026-11-04T00:00:00-05:00", "source": "agent" },
            { "project": "Internal", "start": "2026-11-03T08:30:00-05:00", "end": "2026-11-04T00:00:00-05:00", "source": "app" }
          ]
        }

        """)
        #expect(contents(dayFile(root, "2026-11-04")) == """
        {
          "date": "2026-11-04",
          "entries": [
            { "project": "Client A, Ticket 665", "start": "2026-11-04T00:00:00-05:00", "end": null, "source": "agent" },
            { "project": "Internal", "start": "2026-11-04T00:00:00-05:00", "end": null, "source": "app" }
          ]
        }

        """)
        #expect(tracker.timers.map(\.start) == [clock.now - 15 * 60, clock.now - 15 * 60])
        #expect(tracker.dayTotal(tracker.today) == 30 * 60)
    }

    /// Crashed with two timers running: both are recovered, idle since the earliest moment either was last
    /// alive, and removing the idle time restarts both from now with their sources.
    @Test func everyOpenEntryIsRecoveredAfterACrash() throws {
        let settings = TestSettings()
        defer { settings.remove() }
        try writeToday(twoOpen)
        clock.set("2026-11-03T13:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
        #expect(relaunched.recoverAfterLaunch() == FakeClock("2026-11-03T08:00:00").now)

        try relaunched.resolveIdle(since: FakeClock("2026-11-03T10:00:00").now, choice: .remove)
        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Client A, Ticket 665", "start": "2026-11-03T08:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "agent" },
            { "project": "Internal", "start": "2026-11-03T08:30:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "app" },
            { "project": "Client A, Ticket 665", "start": "2026-11-03T13:00:00-05:00", "end": null, "source": "agent" },
            { "project": "Internal", "start": "2026-11-03T13:00:00-05:00", "end": null, "source": "app" }
          ]
        }

        """)
        #expect(relaunched.timers.map(\.source) == [.agent, .app])
        #expect(relaunched.pendingIdle == nil)
    }

    /// Crashed overnight with two timers running: both carry on into today until the alert is answered.
    @Test func everyEntryLeftOpenOnAPastDayIsRecovered() throws {
        try writeToday(twoOpen)
        clock.set("2026-11-04T09:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root)
        #expect(relaunched.recoverAfterLaunch() == FakeClock("2026-11-03T08:00:00").now)
        #expect(relaunched.timers.map(\.project) == ["Client A, Ticket 665", "Internal"])
        #expect(relaunched.timers.map(\.start) == [FakeClock("2026-11-04T00:00:00").now, FakeClock("2026-11-04T00:00:00").now])
    }

    /// Pausing while today's file is broken stops every timer; closing their Entries lands once it's fixed.
    @Test func aPauseOfSeveralTimersWhileTheFileIsBrokenLandsOnceItIsFixed() throws {
        try writeToday(twoOpen)
        let tracker = Tracker(clock: clock, storageRoot: root)
        try "{ oops".write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        tracker.reload()
        #expect(tracker.timers.count == 2)

        try tracker.pause()
        #expect(tracker.timers.isEmpty)
        try twoOpen.write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        tracker.tick()
        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Client A, Ticket 665", "start": "2026-11-03T08:00:00-05:00", "end": "2026-11-03T09:00:00-05:00", "source": "agent" },
            { "project": "Internal", "start": "2026-11-03T08:30:00-05:00", "end": "2026-11-03T09:00:00-05:00", "source": "app" }
          ]
        }

        """)
    }

    /// An agent's timer from 08:00 and the app's from 08:30, both still open.
    private let twoOpen = """
    {
      "date": "2026-11-03",
      "entries": [
        { "project": "Client A, Ticket 665", "start": "2026-11-03T08:00:00-05:00", "end": null, "source": "agent" },
        { "project": "Internal", "start": "2026-11-03T08:30:00-05:00", "end": null }
      ]
    }

    """

    private func writeToday(_ text: String) throws {
        try FileManager.default.createDirectory(
            at: dayFile(root, "2026-11-03").deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
    }
}

import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct IdleTests {
    let root = temporaryRoot()

    @Test func removeEndsTheEntryAtTheIdleStartAndContinuesFromNow() throws {
        let clock = FakeClock("2026-11-03T13:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T15:00:00")
        try tracker.resolveIdle(since: clock.now - 50 * 60, choice: .remove)

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T13:00:00-05:00", "end": "2026-11-03T14:10:00-05:00", "source": "app" },
            { "project": "Website Redesign", "start": "2026-11-03T15:00:00-05:00", "end": null, "source": "app" }
          ]
        }

        """)
        #expect(tracker.running?.project == "Website Redesign")
        #expect(tracker.running?.start == clock.now)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 70 * 60)
    }

    @Test func removeAndStopEndsTheEntryAtTheIdleStartAndStops() throws {
        let clock = FakeClock("2026-11-03T13:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T15:00:00")
        try tracker.resolveIdle(since: clock.now - 50 * 60, choice: .removeAndStop)

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T13:00:00-05:00", "end": "2026-11-03T14:10:00-05:00", "source": "app" }
          ]
        }

        """)
        #expect(tracker.running == nil)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 70 * 60)
    }

    @Test func keepChangesNothing() throws {
        let clock = FakeClock("2026-11-03T13:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        let before = contents(dayFile(root, "2026-11-03"))
        clock.set("2026-11-03T15:00:00")
        try tracker.resolveIdle(since: clock.now - 50 * 60, choice: .keep)

        #expect(contents(dayFile(root, "2026-11-03")) == before)
        #expect(tracker.running?.start == clock.now - 2 * 3600)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 2 * 3600)
    }

    /// Idle at 23:40, back at 00:30: the split Entry of the old Day is cut and the new Day's is deleted.
    @Test func removeAcrossMidnightCutsTheOldDayAndClearsTheNewOne() throws {
        let clock = FakeClock("2026-11-03T23:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-04T00:30:00")
        try tracker.resolveIdle(since: clock.now - 50 * 60, choice: .remove)

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T23:00:00-05:00", "end": "2026-11-03T23:40:00-05:00", "source": "app" }
          ]
        }

        """)
        #expect(contents(dayFile(root, "2026-11-04")) == """
        {
          "date": "2026-11-04",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-04T00:30:00-05:00", "end": null, "source": "app" }
          ]
        }

        """)
        #expect(tracker.today == Day(year: 2026, month: 11, day: 4))
        #expect(tracker.running?.start == clock.now)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 0)
        #expect(tracker.total("Website Redesign", on: Day(year: 2026, month: 11, day: 3)) == 40 * 60)
    }

    /// An overnight timer forgotten across two midnights: only manual Entries survive after the idle start.
    @Test func removeAcrossSeveralMidnightsLeavesManualEntriesAlone() throws {
        let clock = FakeClock("2026-11-03T17:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-05T09:00:00")
        tracker.tick()
        // A hand edit adds a manual Entry to the middle Day while the timer runs.
        try """
        {
          "date": "2026-11-04",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-04T00:00:00-05:00", "end": "2026-11-05T00:00:00-05:00" },
            { "project": "Internal", "seconds": 900, "note": "manual" }
          ]
        }

        """.write(to: dayFile(root, "2026-11-04"), atomically: true, encoding: .utf8)
        try tracker.resolveIdle(since: FakeClock("2026-11-03T18:00:00").now, choice: .removeAndStop)

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T17:00:00-05:00", "end": "2026-11-03T18:00:00-05:00", "source": "app" }
          ]
        }

        """)
        #expect(contents(dayFile(root, "2026-11-04")) == """
        {
          "date": "2026-11-04",
          "entries": [
            { "project": "Internal", "seconds": 900, "note": "manual" }
          ]
        }

        """)
        #expect(contents(dayFile(root, "2026-11-05")) == """
        {
          "date": "2026-11-05",
          "entries": []
        }

        """)
        #expect(tracker.running == nil)
    }

    /// Asleep across two midnights without a tick: the removal still splits first, then cuts every Day.
    @Test func removeRightAfterWakingAcrossSeveralMidnights() throws {
        let clock = FakeClock("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-05T08:00:00")
        try tracker.resolveIdle(since: FakeClock("2026-11-03T22:30:00").now, choice: .remove)

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T22:00:00-05:00", "end": "2026-11-03T22:30:00-05:00", "source": "app" }
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
            { "project": "Website Redesign", "start": "2026-11-05T08:00:00-05:00", "end": null, "source": "app" }
          ]
        }

        """)
        #expect(tracker.running?.start == clock.now)
    }

    /// Other Projects' timed Entries after the idle start go too: the user wasn't there for them either.
    @Test func removeDeletesEveryTimedEntryAfterTheIdleStart() throws {
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        clock.set("2026-11-03T10:00:00")
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T11:00:00")
        try tracker.resolveIdle(since: FakeClock("2026-11-03T09:30:00").now, choice: .removeAndStop)

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Internal", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T09:30:00-05:00", "source": "app" }
          ]
        }

        """)
    }

    @Test func noTimerRunningMeansRemoveOnlyCuts() throws {
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.pause()
        try tracker.resolveIdle(since: FakeClock("2026-11-03T09:45:00").now, choice: .remove)

        #expect(tracker.running == nil)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 45 * 60)
    }

    @Test func aMalformedDayInTheIdleStretchRefusesTheWholeRemoval() throws {
        let clock = FakeClock("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-05T08:00:00")
        tracker.tick()
        try "{ oops".write(to: dayFile(root, "2026-11-04"), atomically: true, encoding: .utf8)
        let before = contents(dayFile(root, "2026-11-03"))

        #expect(throws: (any Error).self) {
            try tracker.resolveIdle(since: FakeClock("2026-11-03T22:30:00").now, choice: .remove)
        }
        #expect(contents(dayFile(root, "2026-11-03")) == before)
        #expect(contents(dayFile(root, "2026-11-04")) == "{ oops")
        #expect(tracker.isMalformed(Day(year: 2026, month: 11, day: 4)))
        #expect(tracker.running?.start == FakeClock("2026-11-05T00:00:00").now)
    }

    /// A refused removal names the malformed Day and keeps the Idle time pending, up to when it was
    /// answered, so it can be asked about again once the file parses without losing the work since.
    @Test func aRefusedRemovalStaysPendingUntilTheFileParses() throws {
        let clock = FakeClock("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-04T08:00:00")
        tracker.tick()
        let good = try #require(contents(dayFile(root, "2026-11-03")))
        try "{ oops".write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        let idleStart = FakeClock("2026-11-03T22:30:00").now

        #expect(throws: MalformedDayFile(day: Day("2026-11-03")!)) {
            try tracker.resolveIdle(since: idleStart, choice: .remove)
        }
        let answered = clock.now
        #expect(tracker.pendingIdle == PendingIdle(since: idleStart, until: answered, blockedBy: Day("2026-11-03")!))

        clock.set("2026-11-04T09:00:00")
        tracker.tick()
        #expect(tracker.pendingIdle?.blockedBy == Day("2026-11-03")!)

        try good.write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        clock.set("2026-11-04T10:00:00")
        tracker.tick()
        #expect(tracker.pendingIdle == PendingIdle(since: idleStart, until: answered))

        try tracker.resolveIdle(since: idleStart, until: answered, choice: .remove)
        #expect(tracker.pendingIdle == nil)
        #expect(tracker.total("Website Redesign", on: Day("2026-11-03")!) == 30 * 60)
        // Worked since the alert was first answered at 08:00, so that time stays.
        #expect(tracker.total("Website Redesign", on: tracker.today) == 2 * 3600)
        #expect(tracker.running?.start == answered)
    }
}

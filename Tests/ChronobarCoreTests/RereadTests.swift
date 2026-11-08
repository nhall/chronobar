import Foundation
import Testing
import ChronobarCore

/// Re-reading today's file and the Label lists catches Core up to now first, so the Panel's opening and an
/// agent's request never need to tick before they re-read.
@MainActor @Suite struct RereadTests {
    let root = temporaryRoot()

    @Test func reReadingAfterMidnightRollsARunningTimerOver() throws {
        let clock = FakeClock("2026-11-03T23:30:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-04T00:15:00")
        tracker.reload()

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T23:30:00-05:00", "end": "2026-11-04T00:00:00-05:00", "source": "app" }
          ]
        }

        """)
        #expect(contents(dayFile(root, "2026-11-04")) == """
        {
          "date": "2026-11-04",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-04T00:00:00-05:00", "end": null, "source": "app" }
          ]
        }

        """)
        #expect(tracker.today == Day("2026-11-04")!)
        #expect(tracker.timers.newest?.start == clock.date("2026-11-04T00:00:00"))
        #expect(tracker.total("Website Redesign", on: Day("2026-11-03")!) == 30 * 60)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 15 * 60)
    }

    /// Paused while today's file had a typo, so closing the Entry waited. Fixing the file is enough.
    @Test func reReadingRetriesADeferredWriteOnceItsDayFileParses() throws {
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        let good = try #require(contents(dayFile(root, "2026-11-03")))
        try "{ oops".write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        clock.set("2026-11-03T10:00:00")
        try tracker.pause()
        #expect(contents(dayFile(root, "2026-11-03")) == "{ oops")

        try good.write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        clock.set("2026-11-03T10:05:00")
        tracker.reload()

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "app" }
          ]
        }

        """)
        #expect(!tracker.isMalformed(tracker.today))
        #expect(tracker.timers.isEmpty)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 3600)
    }

    /// Crashed on Tuesday night, and Tuesday's file had a typo at relaunch on Thursday. Once it's fixed and
    /// read, re-reading recovers its open Entry as if found at launch.
    @Test func reReadingRecoversAnEntryFoundOpenInADayFileThatParsesAgain() throws {
        let settings = TestSettings()
        defer { settings.remove() }
        let clock = FakeClock("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
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
        _ = relaunched.weekTotals(containing: relaunched.today)
        relaunched.reload()

        #expect(relaunched.pendingIdle == PendingIdle(since: clock.date("2026-11-03T23:30:00")))
        #expect(relaunched.timers.newest?.project == "Website Redesign")
        #expect(relaunched.timers.newest?.start == clock.date("2026-11-05T00:00:00"))
        #expect(relaunched.total("Website Redesign", on: Day("2026-11-03")!) == 2 * 3600)
        #expect(relaunched.total("Website Redesign", on: Day("2026-11-04")!) == 24 * 3600)
        #expect(relaunched.total("Website Redesign", on: relaunched.today) == 10 * 3600)
    }

    /// The idle removal was refused while Tuesday's file had a typo. Once it's fixed, re-reading is enough
    /// for the Idle time to be asked about again.
    @Test func reReadingUnblocksPendingIdleTimeOnceItsDayCanBeRead() throws {
        let clock = FakeClock("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-04T08:00:00")
        tracker.tick()
        let good = try #require(contents(dayFile(root, "2026-11-03")))
        try "{ oops".write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        let idleStart = clock.date("2026-11-03T22:30:00")
        #expect(throws: MalformedDayFile(day: Day("2026-11-03")!)) {
            try tracker.resolveIdle(since: idleStart, choice: .remove)
        }
        let answered = clock.now

        clock.set("2026-11-04T09:00:00")
        tracker.reload()
        #expect(tracker.pendingIdle?.blockedBy == Day("2026-11-03")!)
        #expect(tracker.takeIdleQuestion() == nil)

        try good.write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        clock.set("2026-11-04T10:00:00")
        tracker.reload()

        #expect(tracker.pendingIdle == PendingIdle(since: idleStart, until: answered))
        let question = try #require(tracker.takeIdleQuestion())
        #expect(question.subject == IdleSubject(since: idleStart, until: answered, labels: ["Website Redesign"]))
    }
}

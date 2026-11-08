import Foundation
import Testing
import ChronobarCore

/// Changes that cross midnight or touch more than one Day: each Day holds only its own time, and a change
/// across Days is refused whole, changing no file, when one of them won't parse or still has deferred writes.
@MainActor @Suite struct AcrossDaysTests {
    let root = temporaryRoot()

    /// Makes `url` immutable, so it can still be read but never replaced, until `mutable(_:)`.
    private func immutable(_ url: URL) throws {
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: url.path)
    }

    private func mutable(_ url: URL) {
        try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: url.path)
    }

    /// The names in the `days` folder, temporary files included.
    private func dayFolder() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("days").path)) ?? []).sorted()
    }

    // MARK: Daylight saving at midnight

    /// Havana falls back at midnight on 2026-11-01, so that Day is 25 hours long.
    @Test func aTimerRunningThroughAFallBackMidnightGivesEachDayItsOwnTime() throws {
        let clock = FakeClock("2026-10-31T22:00:00", timeZone: "America/Havana")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-02T01:00:00")
        try tracker.pause()

        #expect(tracker.total("Website Redesign", on: Day("2026-10-31")!) == 2 * 3600)
        #expect(tracker.total("Website Redesign", on: Day("2026-11-01")!) == 25 * 3600)
        #expect(tracker.total("Website Redesign", on: Day("2026-11-02")!) == 1 * 3600)
    }

    /// Santiago springs forward at midnight on 2026-09-06, so that Day is 23 hours long.
    @Test func aTimerRunningThroughASpringForwardMidnightGivesEachDayItsOwnTime() throws {
        let clock = FakeClock("2026-09-05T22:00:00", timeZone: "America/Santiago")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-09-07T01:00:00")
        try tracker.pause()

        #expect(tracker.total("Website Redesign", on: Day("2026-09-05")!) == 2 * 3600)
        #expect(tracker.total("Website Redesign", on: Day("2026-09-06")!) == 23 * 3600)
        #expect(tracker.total("Website Redesign", on: Day("2026-09-07")!) == 1 * 3600)
    }

    /// Santiago has no 00:00 on 2026-09-06: the Day starts at 01:00, an hour after 23:00 the night before.
    @Test func anEntryAddedAcrossASpringForwardMidnightIsCutAtTheRealMidnight() throws {
        let clock = FakeClock("2026-09-06T09:00:00", timeZone: "America/Santiago")
        let tracker = Tracker(clock: clock, storageRoot: root)

        let added = try tracker.addEntry("Website Redesign", start: clock.date("2026-09-05T23:00:00"),
                                         end: clock.date("2026-09-06T01:30:00"))

        #expect(added.map(\.start) == [clock.date("2026-09-05T23:00:00"), clock.date("2026-09-06T01:00:00")])
        #expect(contents(dayFile(root, "2026-09-05")) == """
        {
          "date": "2026-09-05",
          "entries": [
            { "project": "Website Redesign", "start": "2026-09-05T23:00:00-04:00", "end": "2026-09-06T01:00:00-03:00", "source": "app" }
          ]
        }

        """)
        #expect(contents(dayFile(root, "2026-09-06")) == """
        {
          "date": "2026-09-06",
          "entries": [
            { "project": "Website Redesign", "start": "2026-09-06T01:00:00-03:00", "end": "2026-09-06T01:30:00-03:00", "source": "app" }
          ]
        }

        """)
        #expect(tracker.total("Website Redesign", on: Day("2026-09-05")!) == 3600)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 30 * 60)
    }

    // MARK: Deferred writes refuse a change across Days

    /// A tracker whose timer ran from 22:00 on 2026-11-03 and was paused at 08:00 the next morning while
    /// today's file wouldn't parse; the file parses again but can't be replaced, so the pause still waits.
    private func todayWithDeferredWrites(_ clock: FakeClock) throws -> Tracker {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-04T08:00:00")
        tracker.tick()
        let good = try #require(contents(dayFile(root, "2026-11-04")))
        try "{ oops".write(to: dayFile(root, "2026-11-04"), atomically: true, encoding: .utf8)
        try tracker.pause()
        try good.write(to: dayFile(root, "2026-11-04"), atomically: true, encoding: .utf8)
        try immutable(dayFile(root, "2026-11-04"))
        tracker.tick()
        return tracker
    }

    @Test func removingIdleTimeIsRefusedWhileADayItCoversHasDeferredWrites() throws {
        let clock = FakeClock("2026-11-03T22:00:00")
        let tracker = try todayWithDeferredWrites(clock)
        #expect(!tracker.isMalformed(Day("2026-11-04")!))
        defer { mutable(dayFile(root, "2026-11-04")) }
        let before = contents(dayFile(root, "2026-11-03"))
        let today = contents(dayFile(root, "2026-11-04"))

        #expect(throws: MalformedDayFile(day: Day("2026-11-04")!)) {
            try tracker.resolveIdle(since: clock.date("2026-11-03T22:30:00"), until: clock.date("2026-11-04T07:00:00"),
                                    choice: .remove)
        }

        #expect(contents(dayFile(root, "2026-11-03")) == before)
        #expect(contents(dayFile(root, "2026-11-04")) == today)
        #expect(tracker.pendingIdle?.blockedBy == Day("2026-11-04")!)
        #expect(dayFolder() == ["2026-11-03.json", "2026-11-04.json"])
    }

    /// A timer running at 23:00 on 2026-11-03 while that Day's file wouldn't parse, rolled over at 08:00 the
    /// next morning; the file parses again but can't be replaced, so closing its Entry at midnight waits.
    private func yesterdayWithDeferredWrites(_ clock: FakeClock) throws -> Tracker {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign", source: .agent)
        clock.set("2026-11-03T23:00:00")
        let good = try #require(contents(dayFile(root, "2026-11-03")))
        try "{ oops".write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        tracker.reload()
        clock.set("2026-11-04T08:00:00")
        tracker.tick()
        try good.write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        try immutable(dayFile(root, "2026-11-03"))
        tracker.tick()
        return tracker
    }

    @Test func aStopReachingBackIntoADayWithDeferredWritesIsRefused() throws {
        let clock = FakeClock("2026-11-03T22:00:00")
        let tracker = try yesterdayWithDeferredWrites(clock)
        #expect(!tracker.isMalformed(Day("2026-11-03")!))
        defer { mutable(dayFile(root, "2026-11-03")) }
        let before = contents(dayFile(root, "2026-11-03"))
        let today = contents(dayFile(root, "2026-11-04"))

        #expect(throws: MalformedDayFile(day: Day("2026-11-03")!)) {
            try tracker.stop("Website Redesign", at: clock.date("2026-11-03T23:30:00"))
        }
        #expect(throws: MalformedDayFile(day: Day("2026-11-03")!)) {
            try tracker.setStart("Website Redesign", at: clock.date("2026-11-04T07:00:00"))
        }

        #expect(contents(dayFile(root, "2026-11-03")) == before)
        #expect(contents(dayFile(root, "2026-11-04")) == today)
        #expect(tracker.timers.map(\.start) == [clock.date("2026-11-04T00:00:00")])
        #expect(dayFolder() == ["2026-11-03.json", "2026-11-04.json"])
    }

    // MARK: Malformed Days

    /// Idle from 22:30 on 2026-11-03 until 08:00 on 2026-11-05, with the Day between malformed at first.
    @Test func removingIdleTimeBlockedByAMalformedDayGoesThroughOnceItParses() throws {
        let clock = FakeClock("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-05T08:00:00")
        tracker.tick()
        let good = try #require(contents(dayFile(root, "2026-11-04")))
        try "{ oops".write(to: dayFile(root, "2026-11-04"), atomically: true, encoding: .utf8)
        let idleStart = clock.date("2026-11-03T22:30:00")
        let before = contents(dayFile(root, "2026-11-03"))

        #expect(throws: MalformedDayFile(day: Day("2026-11-04")!)) {
            try tracker.resolveIdle(since: idleStart, choice: .removeAndStop)
        }
        #expect(contents(dayFile(root, "2026-11-03")) == before)
        #expect(dayFolder() == ["2026-11-03.json", "2026-11-04.json", "2026-11-05.json"])

        try good.write(to: dayFile(root, "2026-11-04"), atomically: true, encoding: .utf8)
        tracker.tick()
        let pending = try #require(tracker.pendingIdle)
        #expect(pending.blockedBy == nil)
        try tracker.resolveIdle(since: pending.since, until: pending.until, choice: .removeAndStop)

        #expect(tracker.total("Website Redesign", on: Day("2026-11-03")!) == 30 * 60)
        #expect(tracker.total("Website Redesign", on: Day("2026-11-04")!) == 0)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 0)
        #expect(tracker.timers.isEmpty)
        #expect(tracker.pendingIdle == nil)
    }

    // MARK: Corrections across Days

    /// Started at 22:00 on 2026-11-03 and left running until 08:00 on 2026-11-05: stopping at 23:30 the
    /// first night ends the run there and removes its pieces on the two Days after.
    @Test func aStopOnARunSplitAcrossTwoMidnightsFollowsItBackToItsStart() throws {
        let clock = FakeClock("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign", source: .agent)
        clock.set("2026-11-05T08:00:00")
        tracker.tick()

        let stopped = try tracker.stop("Website Redesign", at: clock.date("2026-11-03T23:30:00"))

        #expect(stopped == TimedEntry(project: "Website Redesign", start: clock.date("2026-11-03T22:00:00"),
                                      end: clock.date("2026-11-03T23:30:00"), source: .agent))
        #expect(tracker.timers.isEmpty)
        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T22:00:00-05:00", "end": "2026-11-03T23:30:00-05:00", "source": "agent" }
          ]
        }

        """)
        for date in ["2026-11-04", "2026-11-05"] {
            #expect(contents(dayFile(root, date)) == """
            {
              "date": "\(date)",
              "entries": []
            }

            """)
        }
    }

    /// The Label already has time on the second Day, so the Entry across midnight is refused on both.
    @Test func anEntryOverlappingTheLabelsTimeOnTheSecondDayChangesNeitherDay() throws {
        let clock = FakeClock("2026-11-03T09:00:00")
        try write(root, "2026-11-03", #"    { "project": "Website Redesign", "start": "2026-11-03T00:30:00-05:00", "end": "2026-11-03T01:00:00-05:00", "source": "app" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)
        let today = contents(dayFile(root, "2026-11-03"))

        let overlap = #expect(throws: Overlap.self) {
            try tracker.addEntry("Website Redesign", start: clock.date("2026-11-02T23:00:00"),
                                 end: clock.date("2026-11-03T00:45:00"))
        }

        #expect(overlap?.start == clock.date("2026-11-03T00:30:00"))
        #expect(overlap?.end == clock.date("2026-11-03T01:00:00"))
        #expect(contents(dayFile(root, "2026-11-02")) == nil)
        #expect(contents(dayFile(root, "2026-11-03")) == today)
        #expect(dayFolder() == ["2026-11-03.json"])
    }
}

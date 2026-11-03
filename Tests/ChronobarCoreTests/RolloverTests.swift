import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct RolloverTests {
    let root = temporaryRoot()

    @Test func timerRunningAtMidnightSplitsIntoTheNewDay() throws {
        let clock = FakeClock("2026-11-03T23:30:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-04T00:15:00")
        tracker.tick()

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T23:30:00-05:00", "end": "2026-11-04T00:00:00-05:00" }
          ]
        }

        """)
        #expect(contents(dayFile(root, "2026-11-04")) == """
        {
          "date": "2026-11-04",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-04T00:00:00-05:00", "end": null }
          ]
        }

        """)
        #expect(tracker.today == Day(year: 2026, month: 11, day: 4))
        #expect(tracker.running?.project == "Website Redesign")
        #expect(tracker.running?.start == clock.now - 15 * 60)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 15 * 60)
    }

    /// New York falls back at 02:00 on 2026-11-01, so midnight to 03:00 EST is four hours.
    @Test func rolloverIntoADaylightSavingChange() throws {
        let clock = FakeClock("2026-10-31T23:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-01T03:00:00")
        tracker.tick()

        #expect(contents(dayFile(root, "2026-10-31")) == """
        {
          "date": "2026-10-31",
          "entries": [
            { "project": "Website Redesign", "start": "2026-10-31T23:00:00-04:00", "end": "2026-11-01T00:00:00-04:00" }
          ]
        }

        """)
        #expect(contents(dayFile(root, "2026-11-01")) == """
        {
          "date": "2026-11-01",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-01T00:00:00-04:00", "end": null }
          ]
        }

        """)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 4 * 3600)
    }

    /// Santiago springs forward at midnight on 2026-09-06: there is no 00:00, the Day starts at 01:00.
    @Test func rolloverWhenMidnightIsSkipped() throws {
        let clock = FakeClock("2026-09-05T23:30:00", timeZone: "America/Santiago")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-09-06T01:15:00")
        tracker.tick()

        #expect(contents(dayFile(root, "2026-09-05")) == """
        {
          "date": "2026-09-05",
          "entries": [
            { "project": "Website Redesign", "start": "2026-09-05T23:30:00-04:00", "end": "2026-09-06T01:00:00-03:00" }
          ]
        }

        """)
        #expect(contents(dayFile(root, "2026-09-06")) == """
        {
          "date": "2026-09-06",
          "entries": [
            { "project": "Website Redesign", "start": "2026-09-06T01:00:00-03:00", "end": null }
          ]
        }

        """)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 15 * 60)
    }

    /// Havana falls back at midnight on 2026-11-01: 00:00–01:00 happens twice and the Day starts at the first.
    @Test func rolloverWhenMidnightRepeats() throws {
        let clock = FakeClock("2026-10-31T23:30:00", timeZone: "America/Havana")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.advance(2 * 3600)  // 00:30 the second time round
        tracker.tick()

        #expect(contents(dayFile(root, "2026-10-31")) == """
        {
          "date": "2026-10-31",
          "entries": [
            { "project": "Website Redesign", "start": "2026-10-31T23:30:00-04:00", "end": "2026-11-01T00:00:00-04:00" }
          ]
        }

        """)
        #expect(contents(dayFile(root, "2026-11-01")) == """
        {
          "date": "2026-11-01",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-01T00:00:00-04:00", "end": null }
          ]
        }

        """)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 90 * 60)
    }

    /// A Mac asleep across two midnights wakes to one Entry per Day.
    @Test func wakingAfterTwoMidnightsFillsTheDayInBetween() throws {
        let clock = FakeClock("2026-11-03T23:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-05T08:00:00")
        tracker.tick()

        #expect(contents(dayFile(root, "2026-11-04")) == """
        {
          "date": "2026-11-04",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-04T00:00:00-05:00", "end": "2026-11-05T00:00:00-05:00" }
          ]
        }

        """)
        #expect(contents(dayFile(root, "2026-11-05")) == """
        {
          "date": "2026-11-05",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-05T00:00:00-05:00", "end": null }
          ]
        }

        """)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 8 * 3600)
    }

    @Test func pausingAfterMidnightBeforeATickClosesTheNewDaysEntry() throws {
        let clock = FakeClock("2026-11-03T23:30:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-04T00:20:00")
        try tracker.pause()

        #expect(contents(dayFile(root, "2026-11-04")) == """
        {
          "date": "2026-11-04",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-04T00:00:00-05:00", "end": "2026-11-04T00:20:00-05:00" }
          ]
        }

        """)
        #expect(tracker.running == nil)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 20 * 60)
    }

    @Test func pausedPillShowsTheNewDaysTotalAfterMidnight() throws {
        let clock = FakeClock("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T23:00:00")
        try tracker.pause()
        clock.set("2026-11-04T00:01:00")
        tracker.tick()

        #expect(tracker.today == Day(year: 2026, month: 11, day: 4))
        #expect(tracker.selectedProject == "Website Redesign")
        #expect(tracker.total("Website Redesign", on: tracker.today) == 0)
    }
}

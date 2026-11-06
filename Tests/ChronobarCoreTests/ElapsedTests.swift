import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct ElapsedTests {
    let clock = FakeClock("2026-11-03T12:00:00")
    let root = temporaryRoot()
    let past = Day(year: 2026, month: 10, day: 28)

    @Test func overlappingEntriesCountTheirSharedTimeOnce() throws {
        try write(root, "2026-10-28", """
            { "project": "Website Redesign", "start": "2026-10-28T09:00:00-04:00", "end": "2026-10-28T11:00:00-04:00" },
            { "project": "Garden Shed", "start": "2026-10-28T10:00:00-04:00", "end": "2026-10-28T12:00:00-04:00" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)

        // 09:00-12:00, though the Day total is 4 h.
        #expect(tracker.elapsed(past) == 3 * 60 * 60)
        #expect(tracker.dayTotal(past) == 4 * 60 * 60)
    }

    @Test func adjacentEntriesJoinWithoutDoubleCountingTheMomentTheyMeet() throws {
        try write(root, "2026-10-28", """
            { "project": "Website Redesign", "start": "2026-10-28T09:00:00-04:00", "end": "2026-10-28T10:00:00-04:00" },
            { "project": "Garden Shed", "start": "2026-10-28T10:00:00-04:00", "end": "2026-10-28T10:30:00-04:00" },
            { "project": "Internal", "start": "2026-10-28T14:00:00-04:00", "end": "2026-10-28T14:15:00-04:00" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(tracker.elapsed(past) == 105 * 60)
    }

    @Test func anEntryInsideAnotherAddsNothing() throws {
        try write(root, "2026-10-28", """
            { "project": "Website Redesign", "start": "2026-10-28T09:00:00-04:00", "end": "2026-10-28T12:00:00-04:00" },
            { "project": "Garden Shed", "start": "2026-10-28T10:00:00-04:00", "end": "2026-10-28T11:00:00-04:00" },
            { "project": "Internal", "start": "2026-10-28T10:30:00-04:00", "end": "2026-10-28T11:30:00-04:00" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(tracker.elapsed(past) == 3 * 60 * 60)
    }

    @Test func withNoOverlapElapsedTimeMatchesTheDayTotal() throws {
        try write(root, "2026-10-28", """
            { "project": "Website Redesign", "start": "2026-10-28T09:00:00-04:00", "end": "2026-10-28T10:00:00-04:00" },
            { "project": "Garden Shed", "start": "2026-10-28T13:00:00-04:00", "end": "2026-10-28T13:45:00-04:00" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(tracker.elapsed(past) == 105 * 60)
        #expect(tracker.elapsed(past) == tracker.dayTotal(past))
    }

    @Test func manualEntriesCountTowardTheTotalButNotElapsedTime() throws {
        try write(root, "2026-10-28", """
            { "project": "Website Redesign", "start": "2026-10-28T09:00:00-04:00", "end": "2026-10-28T10:00:00-04:00" },
            { "project": "Website Redesign", "seconds": 1800, "note": "manual" },
            { "project": "Garden Shed", "seconds": 900, "note": "adjustment" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(tracker.elapsed(past) == 60 * 60)
        #expect(tracker.dayTotal(past) == 105 * 60)
    }

    @Test func aDayWithOnlyManualEntriesHasNoElapsedTime() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Garden Shed", "2:00", on: tracker.today)

        #expect(tracker.elapsed(tracker.today) == 0)
        #expect(tracker.elapsed(past) == 0)
    }

    @Test func aRunningTimerCountsUpToNow() throws {
        let clock = FakeClock("2026-11-03T09:00:00")
        try write(root, "2026-11-03", """
            { "project": "Website Redesign", "start": "2026-11-03T08:30:00-05:00", "end": "2026-11-03T09:00:00-05:00" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        clock.set("2026-11-03T09:40:00")
        tracker.tick()

        #expect(tracker.elapsed(tracker.today) == 70 * 60)

        clock.set("2026-11-03T10:00:00")
        tracker.tick()

        #expect(tracker.elapsed(tracker.today) == 90 * 60)
    }

    @Test func timersRunningSideBySideCountTheirSharedTimeOnce() throws {
        let clock = FakeClock("2026-11-03T09:00:00")
        // Two open Entries, as a relaunch finds them; the second started while the first ran.
        try write(root, "2026-11-03", """
            { "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": null },
            { "project": "Garden Shed", "start": "2026-11-03T09:30:00-05:00", "end": null }
        """)
        clock.set("2026-11-03T10:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(tracker.dayTotal(tracker.today) == 90 * 60)
        #expect(tracker.elapsed(tracker.today) == 60 * 60)
    }

    @Test func aDayEndingSummerTimeCountsTheClockTimeThatPassed() throws {
        // On 1 Nov 2026 New York falls back at 02:00 EDT to 01:00 EST: 00:30 EDT to 03:00 EST is 3.5 h,
        // though the clock on the wall moves only 2.5 h. The nested Entry is in the repeated hour.
        try write(root, "2026-11-01", """
            { "project": "Website Redesign", "start": "2026-11-01T00:30:00-04:00", "end": "2026-11-01T03:00:00-05:00" },
            { "project": "Garden Shed", "start": "2026-11-01T01:15:00-05:00", "end": "2026-11-01T01:45:00-05:00" },
            { "project": "Internal", "start": "2026-11-01T02:30:00-05:00", "end": "2026-11-01T04:00:00-05:00" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(tracker.elapsed(Day(year: 2026, month: 11, day: 1)) == 4.5 * 60 * 60)
    }

    @Test func theTimeSummaryShowsElapsedTimeBesideEachTotal() throws {
        let clock = FakeClock("2026-11-03T09:00:00")
        clock.calendar.firstWeekday = 2
        // Last week, but this month: 1 h of overlap.
        try write(root, "2026-11-01", """
            { "project": "Website Redesign", "start": "2026-11-01T09:00:00-05:00", "end": "2026-11-01T11:00:00-05:00" },
            { "project": "Garden Shed", "start": "2026-11-01T10:00:00-05:00", "end": "2026-11-01T11:00:00-05:00" }
        """)
        // Yesterday: 30 min timed twice over, plus 15 min logged.
        try write(root, "2026-11-02", """
            { "project": "Website Redesign", "start": "2026-11-02T14:00:00-05:00", "end": "2026-11-02T14:30:00-05:00" },
            { "project": "Garden Shed", "start": "2026-11-02T14:00:00-05:00", "end": "2026-11-02T14:30:00-05:00" },
            { "project": "Internal", "seconds": 900, "note": "manual" }
        """)
        // Last month.
        try write(root, "2026-10-30", """
            { "project": "Website Redesign", "start": "2026-10-30T09:00:00-04:00", "end": "2026-10-30T10:00:00-04:00" }
        """)
        // Today: two timers side by side for 45 min.
        try write(root, "2026-11-03", """
            { "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": null },
            { "project": "Garden Shed", "start": "2026-11-03T09:00:00-05:00", "end": null }
        """)
        clock.set("2026-11-03T09:45:00")
        let tracker = Tracker(clock: clock, storageRoot: root)

        let summary = tracker.summary()
        #expect(summary.today == 90 * 60)
        #expect(summary.elapsed == Summary.Elapsed(today: 45 * 60, yesterday: 30 * 60, week: 75 * 60, month: 195 * 60))
    }
}

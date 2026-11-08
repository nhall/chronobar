import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct SummaryTests {
    let root = temporaryRoot()

    init() throws {
        try write(root, "2026-09-30", #"{ "project": "Website Redesign", "seconds": 7200, "note": "manual" }"#)
        try write(root, "2026-10-26", #"{ "project": "Website Redesign", "seconds": 600, "note": "manual" }"#)
        try write(root, "2026-10-31", """
            { "project": "Website Redesign", "start": "2026-10-31T09:00:00-04:00", "end": "2026-10-31T10:00:00-04:00" },
            { "project": "Internal", "seconds": -900, "note": "adjustment" }
        """)
        try write(root, "2026-11-01", #"{ "project": "Garden Shed", "seconds": 1800, "note": "manual" }"#)
        try write(root, "2026-11-02", #"{ "project": "Garden Shed", "seconds": 900, "note": "manual" }"#)
    }

    @Test func midMonthCountsTodayYesterdayTheWeekAndTheMonth() throws {
        let clock = FakeClock("2026-11-03T09:00:00")
        clock.calendar.firstWeekday = 2
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        clock.set("2026-11-03T09:45:00")
        tracker.tick()

        // Only today's timer is timed; the rest of the week and month was logged.
        #expect(tracker.summary() == Summary(
            today: 45 * 60, yesterday: 15 * 60, week: 60 * 60, month: 90 * 60,
            elapsed: Summary.Elapsed(today: 45 * 60, yesterday: 0, week: 45 * 60, month: 45 * 60)))
    }

    @Test func onTheFirstOfTheMonthYesterdayAndTheWeekReachBackIntoTheLastMonth() {
        let clock = FakeClock("2026-11-01T12:00:00")
        clock.calendar.firstWeekday = 2
        let tracker = Tracker(clock: clock, storageRoot: root)

        // Week Mon 26 Oct - Sun 1 Nov: 10 min + 1 h (Internal's negative total counts as zero) + 30 min.
        // The month is all of November, so it includes the 15 min already in 2 Nov's file.
        // Elapsed time is 31 Oct's timed hour only.
        #expect(tracker.summary() == Summary(
            today: 30 * 60, yesterday: 60 * 60, week: 100 * 60, month: 45 * 60,
            elapsed: Summary.Elapsed(today: 0, yesterday: 60 * 60, week: 60 * 60, month: 0)))
    }

    @Test func eachPeriodNamesItsFirstAndLastDaysEvenAcrossAMonthEnd() {
        let clock = FakeClock("2026-11-01T12:00:00")
        clock.calendar.firstWeekday = 2
        let tracker = Tracker(clock: clock, storageRoot: root)
        func day(_ month: Int, _ day: Int) -> Day { Day(year: 2026, month: month, day: day) }

        #expect(tracker.summaryPeriods() == SummaryPeriods(
            today: SummaryPeriod(first: day(11, 1), last: day(11, 1), total: 30 * 60, elapsed: 0),
            yesterday: SummaryPeriod(first: day(10, 31), last: day(10, 31), total: 60 * 60, elapsed: 60 * 60),
            week: SummaryPeriod(first: day(10, 26), last: day(11, 1), total: 100 * 60, elapsed: 60 * 60),
            month: SummaryPeriod(first: day(11, 1), last: day(11, 30), total: 45 * 60, elapsed: 0)))
    }

    @Test func aSundayWeekStartingOnTheFirstStaysInTheMonth() {
        let clock = FakeClock("2026-11-01T12:00:00")
        clock.calendar.firstWeekday = 1
        let tracker = Tracker(clock: clock, storageRoot: root)

        // Sun 1 - Sat 7 Nov, like the Week strip: 1 Nov and 2 Nov.
        #expect(tracker.summary().week == 45 * 60)
    }

    @Test func onTheLastDayOfTheMonthTheMonthCoversEveryDay() {
        let clock = FakeClock("2026-10-31T12:00:00")
        clock.calendar.firstWeekday = 1
        let tracker = Tracker(clock: clock, storageRoot: root)

        // Not 30 Sep or 1 Nov.
        #expect(tracker.summary().month == 70 * 60)
        #expect(tracker.summary().yesterday == 0)
    }

    @Test func onNewYearsDayYesterdayIsTheLastDayOfTheYearBefore() throws {
        try write(root, "2026-12-31", #"{ "project": "Internal", "seconds": 1200, "note": "manual" }"#)
        let clock = FakeClock("2027-01-01T08:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(tracker.summary().yesterday == 20 * 60)
        #expect(tracker.summary().month == 0)
    }

    @Test func timeLoggedAheadCountsInTheWeekAndTheMonthButNotToday() throws {
        let clock = FakeClock("2026-11-03T09:00:00")
        clock.calendar.firstWeekday = 2
        let tracker = Tracker(clock: clock, storageRoot: root)

        try tracker.log("Vacation", "8:00", on: Day(year: 2026, month: 11, day: 6))
        try tracker.log("Vacation", "8:00", on: Day(year: 2026, month: 11, day: 30))
        try tracker.log("Vacation", "8:00", on: Day(year: 2026, month: 12, day: 1))

        // Week Mon 2 - Sun 8 Nov: 15 min yesterday and 8 h on Friday. The month adds 30 Nov but not 1 Dec.
        #expect(tracker.summary() == Summary(
            today: 0, yesterday: 15 * 60, week: (8 * 60 + 15) * 60, month: (16 * 60 + 45) * 60,
            elapsed: Summary.Elapsed(today: 0, yesterday: 0, week: 0, month: 0)))
    }
}

import Foundation
import Testing
import ChronobarCore
import ChronobarOperations

/// `summary`: the Time Summary, each period with the Days it covers, its total and its Elapsed time.
@MainActor @Suite struct SummaryTests {
    /// A Tuesday; the test calendar's weeks start on Sunday.
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func summaryTotalsTodayYesterdayTheWeekAndTheMonthWithElapsedTime() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "1:00", on: Day(year: 2026, month: 10, day: 31))
        try tracker.log("Website Redesign", "2:00", on: Day(year: 2026, month: 11, day: 2))
        try tracker.log("Internal", "0:30", on: Day(year: 2026, month: 11, day: 8))
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T09:30:00")
        try tracker.start("Internal", source: .agent)
        clock.set("2026-11-03T10:00:00")

        let summary = try Operations(tracker: tracker).summary()

        #expect(summary.today == PeriodResult(first: "2026-11-03", last: "2026-11-03",
                                              totalSeconds: 90 * 60, elapsedSeconds: 60 * 60))
        #expect(summary.yesterday == PeriodResult(first: "2026-11-02", last: "2026-11-02",
                                                  totalSeconds: 120 * 60, elapsedSeconds: 0))
        #expect(summary.week == PeriodResult(first: "2026-11-01", last: "2026-11-07",
                                             totalSeconds: 210 * 60, elapsedSeconds: 60 * 60))
        #expect(summary.month == PeriodResult(first: "2026-11-01", last: "2026-11-30",
                                              totalSeconds: 240 * 60, elapsedSeconds: 60 * 60))
    }
}

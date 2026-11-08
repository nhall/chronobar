import Foundation
import Testing
import ChronobarCore
import ChronobarOperations
@testable import ChronobarCLI

/// The readable text shows rows that add up to the total under them, as the Panel does: 2:08:45 and
/// 1:08:49 show as 2:08 and 1:09 under Total 3:17. The minutes come fitted from Core (`DaySheet`,
/// `WeekSheet`); the text only formats them.
@Suite struct RowsAddUpTextTests {
    let first = 2 * 3600 + 8 * 60 + 45
    let second = 3600 + 8 * 60 + 49

    @Test func aDaysRowsAddUpToItsTotal() {
        let day = DayResult(date: "2026-11-03", totalSeconds: first + second, totalMinutes: 197,
                            elapsedSeconds: 3 * 3600, elapsedMinutes: 180)
        let rows = DayRowsResult(day: day, rows: [
            RowResult(label: "Garden Shed", totalSeconds: first, totalMinutes: 128, running: false),
            RowResult(label: "Two", totalSeconds: second, totalMinutes: 69, running: true),
        ], malformed: false)

        #expect(Output.text(.day(rows)) == """
            2026-11-03
              Garden Shed  2:08
              Two  1:09  running
            Total 3:17 · Clock time 3:00
            """)
    }

    /// Each Day line is that Day's own total, as `day` and the Panel show it; the week total is the sum
    /// of the Day lines, and the Labels' week lines add up to it.
    @Test func aWeeksDaysShowTheirOwnTotalsAndTheLabelsAddUpToTheirSum() {
        func day(_ date: String, _ seconds: Int, clockTime: Int) -> DayResult {
            DayResult(date: date, totalSeconds: seconds, totalMinutes: seconds / 60, elapsedSeconds: clockTime,
                      elapsedMinutes: clockTime / 60)
        }
        // Garden Shed 1:00:30 and Two 1:08:15 on the 1st; 0:30:30 and 0:38:19 on the 2nd.
        let days = [day("2026-11-01", first, clockTime: 2 * 3600), day("2026-11-02", second, clockTime: 3600)]
            + (3...7).map { day("2026-11-0\($0)", 0, clockTime: 0) }
        let week = WeekResult(first: "2026-11-01", last: "2026-11-07", totalSeconds: first + second,
                              totalMinutes: 196, elapsedSeconds: 3 * 3600, elapsedMinutes: 180, days: days,
                              labels: [LabelTotalResult(label: "Garden Shed", totalSeconds: 91 * 60, totalMinutes: 90),
                                       LabelTotalResult(label: "Two", totalSeconds: 106 * 60 + 34, totalMinutes: 106)],
                              malformed: [])

        #expect(Output.text(.week(week)) == """
            Week of 2026-11-01 to 2026-11-07
              2026-11-01  Total 2:08 · Clock time 2:00
              2026-11-02  Total 1:08 · Clock time 1:00
              2026-11-03  Total 0:00 · Clock time 0:00
              2026-11-04  Total 0:00 · Clock time 0:00
              2026-11-05  Total 0:00 · Clock time 0:00
              2026-11-06  Total 0:00 · Clock time 0:00
              2026-11-07  Total 0:00 · Clock time 0:00
            Labels:
              Garden Shed  1:30
              Two  1:46
            Total 3:16 · Clock time 3:00
            """)
    }

    /// The week's clock time is the sum of the Day lines' clock times too, so with no timers side by side
    /// it matches the week total: never "Total 3:16 · Clock time 3:17".
    @Test func aWeeksClockTimeIsTheSumOfItsDayLines() {
        let days = [DayResult(date: "2026-11-01", totalSeconds: first, totalMinutes: 128, elapsedSeconds: first,
                              elapsedMinutes: 128),
                    DayResult(date: "2026-11-02", totalSeconds: second, totalMinutes: 68, elapsedSeconds: second,
                              elapsedMinutes: 68)]
        let week = WeekResult(first: "2026-11-01", last: "2026-11-07", totalSeconds: first + second,
                              totalMinutes: 196, elapsedSeconds: first + second, elapsedMinutes: 196, days: days,
                              labels: [LabelTotalResult(label: "Garden Shed", totalSeconds: first + second,
                                                        totalMinutes: 196)],
                              malformed: [])

        #expect(Output.text(.week(week)) == """
            Week of 2026-11-01 to 2026-11-07
              2026-11-01  Total 2:08 · Clock time 2:08
              2026-11-02  Total 1:08 · Clock time 1:08
            Labels:
              Garden Shed  3:16
            Total 3:16 · Clock time 3:16
            """)
    }
}

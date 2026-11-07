import Foundation
import Testing
import ChronobarCore
import ChronobarOperations
@testable import ChronobarCLI

/// The readable text shows rows that add up to the total under them, as the Panel does: 2:08:45 and
/// 1:08:49 show as 2:08 and 1:09 under Total 3:17.
@Suite struct RowsAddUpTextTests {
    let first = 2 * 3600 + 8 * 60 + 45
    let second = 3600 + 8 * 60 + 49

    @Test func aDaysRowsAddUpToItsTotal() {
        let day = DayResult(date: "2026-11-03", totalSeconds: first + second, elapsedSeconds: 3 * 3600)
        let rows = DayRowsResult(day: day, rows: [
            RowResult(label: "Garden Shed", totalSeconds: first, running: false),
            RowResult(label: "Two", totalSeconds: second, running: true),
        ], malformed: false)

        #expect(Output.text(.day(rows)) == """
            2026-11-03
              Garden Shed  2:08
              Two  1:09  running
            Total 3:17 · Clock time 3:00
            """)
    }

    @Test func aWeeksDaysAndLabelsEachAddUpToTheWeekTotal() {
        func day(_ date: String, _ seconds: Int) -> DayResult {
            DayResult(date: date, totalSeconds: seconds, elapsedSeconds: seconds)
        }
        let days = [day("2026-11-01", first), day("2026-11-02", second)]
            + (3...7).map { day("2026-11-0\($0)", 0) }
        let week = WeekResult(first: "2026-11-01", last: "2026-11-07", totalSeconds: first + second,
                              elapsedSeconds: first + second, days: days,
                              labels: [LabelTotalResult(label: "Garden Shed", totalSeconds: first),
                                       LabelTotalResult(label: "Two", totalSeconds: second)],
                              malformed: [])

        #expect(Output.text(.week(week)) == """
            Week of 2026-11-01 to 2026-11-07
              2026-11-01  Total 2:08 · Clock time 2:08
              2026-11-02  Total 1:09 · Clock time 1:08
              2026-11-03  Total 0:00 · Clock time 0:00
              2026-11-04  Total 0:00 · Clock time 0:00
              2026-11-05  Total 0:00 · Clock time 0:00
              2026-11-06  Total 0:00 · Clock time 0:00
              2026-11-07  Total 0:00 · Clock time 0:00
            Labels:
              Garden Shed  2:08
              Two  1:09
            Total 3:17 · Clock time 3:17
            """)
    }
}

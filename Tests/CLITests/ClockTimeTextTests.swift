import Foundation
import Testing
import ChronobarCore
import ChronobarOperations
@testable import ChronobarCLI

/// The readable text gives each total with its clock time, as the Panel does: "Total 3:17 · Clock time 3:00".
@Suite struct ClockTimeTextTests {
    let day = DayResult(date: "2026-11-03", totalSeconds: 197 * 60, totalMinutes: 197, elapsedSeconds: 180 * 60, elapsedMinutes: 180)

    @Test func statusEndsWithTheDaysTotalAndClockTime() {
        #expect(Output.text(.status(StatusResult(timers: [], today: day))) == """
            Nothing running.
            2026-11-03: Total 3:17 · Clock time 3:00
            """)
    }

    @Test func dayEndsWithTheTotalAndClockTime() {
        let rows = DayRowsResult(day: day, rows: [RowResult(label: "Internal", totalSeconds: 197 * 60, totalMinutes: 197, running: false)],
                                 malformed: false)
        #expect(Output.text(.day(rows)) == """
            2026-11-03
              Internal  3:17
            Total 3:17 · Clock time 3:00
            """)
    }

    @Test func relabelSaysWhereTheTimeWentAndEndsWithTheDaysTotalAndClockTime() {
        let relabeled = RelabelResult(label: "Northwind, Ticket 665", date: "2026-11-03", entries: [],
                                      totalSeconds: 75 * 60, day: day)
        #expect(Output.text(.relabel(relabeled)) == """
            Relabeled as Northwind, Ticket 665 on 2026-11-03: 1:15.
            2026-11-03: Total 3:17 · Clock time 3:00
            """)
    }

    @Test func summaryKeepsEachPeriodsName() {
        let today = PeriodResult(first: "2026-11-03", last: "2026-11-03", totalSeconds: 197 * 60, elapsedSeconds: 180 * 60)
        let none = PeriodResult(first: "2026-11-02", last: "2026-11-02", totalSeconds: 0, elapsedSeconds: 0)
        let week = PeriodResult(first: "2026-11-01", last: "2026-11-07", totalSeconds: 197 * 60, elapsedSeconds: 180 * 60)
        let month = PeriodResult(first: "2026-11-01", last: "2026-11-30", totalSeconds: 197 * 60, elapsedSeconds: 180 * 60)
        #expect(Output.text(.summary(SummaryResult(today: today, yesterday: none, week: week, month: month))) == """
            Today 3:17 · Clock time 3:00  (2026-11-03)
            Yesterday 0:00 · Clock time 0:00  (2026-11-02)
            This week 3:17 · Clock time 3:00  (2026-11-01 to 2026-11-07)
            This month 3:17 · Clock time 3:00  (2026-11-01 to 2026-11-30)
            """)
    }
}

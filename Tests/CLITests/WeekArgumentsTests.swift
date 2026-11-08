import Foundation
import Testing
import ChronobarCore
import ChronobarOperations
@testable import ChronobarCLI

/// `chronobar week [date]`: the week containing the date, else today's.
@Suite struct WeekArgumentsTests {
    @Test func weekWithoutADateIsTodaysWeek() throws {
        #expect(try Invocation(["week"]) == .request(.week(date: nil), json: false, copy: .everyday))
    }

    @Test func weekTakesOneDate() throws {
        #expect(try Invocation(["week", "2026-11-03", "--json"]) == .request(.week(date: "2026-11-03"), json: true,
                                                                              copy: .everyday))
        #expect(throws: OperationError.self) { try Invocation(["week", "2026-11-03", "2026-11-04"]) }
    }

    @Test func weekTextListsTheDaysThenEachLabelsTotal() {
        let week = WeekResult(
            first: "2026-11-01", last: "2026-11-07", totalSeconds: 210 * 60, totalMinutes: 210,
            elapsedSeconds: 3600, elapsedMinutes: 60,
            days: [DayResult(date: "2026-11-01", totalSeconds: 2 * 3600, totalMinutes: 120, elapsedSeconds: 3600,
                             elapsedMinutes: 60),
                   DayResult(date: "2026-11-02", totalSeconds: 90 * 60, totalMinutes: 90, elapsedSeconds: 0,
                             elapsedMinutes: 0)],
            labels: [LabelTotalResult(label: "Website Redesign", totalSeconds: 150 * 60, totalMinutes: 150),
                     LabelTotalResult(label: "Internal", totalSeconds: 3600, totalMinutes: 60)],
            malformed: ["2026-11-02"])

        #expect(Output.text(.week(week)) == """
            Week of 2026-11-01 to 2026-11-07
              2026-11-01  Total 2:00 · Clock time 1:00
              2026-11-02  Total 1:30 · Clock time 0:00  (Day file isn't valid JSON)
            Labels:
              Website Redesign  2:30
              Internal  1:00
            Total 3:30 · Clock time 1:00
            """)
    }
}

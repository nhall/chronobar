import Foundation
import Testing
import ChronobarCore

@Suite struct PanelKeyTests {
    let calendar = FakeClock("2026-11-03T09:00:00").calendar
    /// Tuesday.
    let today = Day(year: 2026, month: 11, day: 3)

    private func day(_ string: String) -> Day { Day(string)! }

    private func change(_ command: PanelCommand, viewing viewed: String?) -> PanelChange {
        command.change(viewing: viewed.map(day), today: today, calendar: calendar)
    }

    @Test func dayKeysMoveTheViewedDayOneDay() {
        #expect(change(.previousDay, viewing: nil) == .view(day("2026-11-02")))
        #expect(change(.nextDay, viewing: nil) == .view(day("2026-11-04")))
    }

    /// Past the strip's first or last Day, the strip moves to the week the new Day is in.
    @Test func dayKeysCrossWeeksAndMonths() {
        #expect(change(.previousDay, viewing: "2026-11-01") == .view(day("2026-10-31")))
        #expect(change(.nextDay, viewing: "2026-12-31") == .view(day("2027-01-01")))
    }

    @Test func weekKeysMoveTheViewedDaySevenDays() {
        #expect(change(.previousWeek, viewing: nil) == .view(day("2026-10-27")))
        #expect(change(.nextWeek, viewing: "2026-10-30") == .view(day("2026-11-06")))
    }

    /// Landing on today, by any key, goes back to following the clock across midnight.
    @Test func reachingTodayFollowsTheClock() {
        #expect(change(.today, viewing: "2026-09-14") == .view(nil))
        #expect(change(.nextDay, viewing: "2026-11-02") == .view(nil))
        #expect(change(.previousWeek, viewing: "2026-11-10") == .view(nil))
    }

    @Test func formKeysOpenTheirFormsAndLeaveTheViewedDay() {
        #expect(change(.newProject, viewing: "2026-09-14") == .openNewProject)
        #expect(change(.timeSummary, viewing: "2026-09-14") == .toggleTimeSummary)
    }

    /// A click on a Day in the strip.
    @Test func viewingADayFollowsTheClockOnlyForToday() {
        #expect(PanelChange.viewing(today, today: today) == .view(nil))
        #expect(PanelChange.viewing(day("2026-11-04"), today: today) == .view(day("2026-11-04")))
    }

    @Test func eachCommandNamesItsKey() {
        #expect(PanelCommand.previousWeek.keyName == "⌘[")
        #expect(PanelCommand.nextWeek.keyName == "⌘]")
        #expect(PanelCommand.previousDay.keyName == "←")
        #expect(PanelCommand.nextDay.keyName == "→")
        #expect(PanelCommand.today.keyName == "⌘T")
        #expect(PanelCommand.newProject.keyName == "⌘N")
        #expect(PanelCommand.timeSummary.keyName == "⌘I")
    }

    @Test func aHelpTagEndsWithItsKey() {
        #expect(PanelCommand.previousWeek.help("Previous week") == "Previous week (⌘[)")
        #expect(PanelCommand.timeSummary.help("Time Summary") == "Time Summary (⌘I)")
    }

    @Test func aHelpTagCanNameSeveralKeys() {
        #expect(PanelCommand.help("Move a Day", keys: .previousDay, .nextDay) == "Move a Day (← →)")
    }
}

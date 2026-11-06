import Foundation
import Testing
import ChronobarCore

/// What VoiceOver reads for a Day in the Week strip: its date, its total, and whether it is today or
/// the viewed Day.
@Suite struct WeekStripAccessibilityTests {
    let calendar = FakeClock("2026-11-03T09:00:00").calendar
    let locale = Locale(identifier: "en_US")
    let today = Day(year: 2026, month: 11, day: 3)

    private func label(_ day: Day, _ total: TimeInterval, viewed: Day) -> String {
        WeekStripAccessibility.label(DayTotal(day: day, total: total), today: today, viewed: viewed,
                                     calendar: calendar, locale: locale)
    }

    @Test func todayWhileViewedSaysBoth() {
        #expect(label(today, 83 * 60, viewed: today) == "Tuesday, November 3, 1 hour 23 minutes, today, viewed")
    }

    @Test func todayWhileAnotherDayIsViewedSaysToday() {
        #expect(label(today, 0, viewed: Day(year: 2026, month: 11, day: 1))
            == "Tuesday, November 3, 0 minutes, today")
    }

    @Test func theViewedDaySaysViewed() {
        let sunday = Day(year: 2026, month: 11, day: 1)
        #expect(label(sunday, 30 * 60, viewed: sunday) == "Sunday, November 1, 30 minutes, viewed")
    }

    @Test func anyOtherDayReadsItsDateAndTotal() {
        #expect(label(Day(year: 2026, month: 11, day: 7), 8 * 3600, viewed: today)
            == "Saturday, November 7, 8 hours")
    }
}

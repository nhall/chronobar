import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct WeekTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    init() throws {
        try write(root, "2026-10-31", #"{ "project": "Website Redesign", "seconds": 3600, "note": "manual" }"#)
        try write(root, "2026-11-01", #"{ "project": "Garden Shed", "seconds": 1800, "note": "manual" }"#)
        try write(root, "2026-11-08", #"{ "project": "Garden Shed", "seconds": 600, "note": "manual" }"#)
    }

    @Test func aSundayWeekRunsSundayToSaturday() throws {
        clock.calendar.firstWeekday = 1
        let tracker = try trackerRunningAnHour()

        #expect(tracker.weekTotals(containing: tracker.today) == [
            DayTotal(day: Day(year: 2026, month: 11, day: 1), total: 30 * 60),
            DayTotal(day: Day(year: 2026, month: 11, day: 2), total: 0),
            DayTotal(day: Day(year: 2026, month: 11, day: 3), total: 60 * 60),
            DayTotal(day: Day(year: 2026, month: 11, day: 4), total: 0),
            DayTotal(day: Day(year: 2026, month: 11, day: 5), total: 0),
            DayTotal(day: Day(year: 2026, month: 11, day: 6), total: 0),
            DayTotal(day: Day(year: 2026, month: 11, day: 7), total: 0),
        ])
    }

    @Test func aMondayWeekRunsMondayToSunday() throws {
        clock.calendar.firstWeekday = 2
        let tracker = try trackerRunningAnHour()

        #expect(tracker.weekTotals(containing: tracker.today) == [
            DayTotal(day: Day(year: 2026, month: 11, day: 2), total: 0),
            DayTotal(day: Day(year: 2026, month: 11, day: 3), total: 60 * 60),
            DayTotal(day: Day(year: 2026, month: 11, day: 4), total: 0),
            DayTotal(day: Day(year: 2026, month: 11, day: 5), total: 0),
            DayTotal(day: Day(year: 2026, month: 11, day: 6), total: 0),
            DayTotal(day: Day(year: 2026, month: 11, day: 7), total: 0),
            DayTotal(day: Day(year: 2026, month: 11, day: 8), total: 10 * 60),
        ])
    }

    @Test func aSaturdayWeekCrossesIntoTheLastMonth() throws {
        clock.calendar.firstWeekday = 7
        let tracker = try trackerRunningAnHour()

        #expect(tracker.weekTotals(containing: tracker.today) == [
            DayTotal(day: Day(year: 2026, month: 10, day: 31), total: 60 * 60),
            DayTotal(day: Day(year: 2026, month: 11, day: 1), total: 30 * 60),
            DayTotal(day: Day(year: 2026, month: 11, day: 2), total: 0),
            DayTotal(day: Day(year: 2026, month: 11, day: 3), total: 60 * 60),
            DayTotal(day: Day(year: 2026, month: 11, day: 4), total: 0),
            DayTotal(day: Day(year: 2026, month: 11, day: 5), total: 0),
            DayTotal(day: Day(year: 2026, month: 11, day: 6), total: 0),
        ])
    }

    @Test func aWeekContainingItsFirstDayStartsThere() throws {
        clock.calendar.firstWeekday = 1
        let tracker = Tracker(clock: clock, storageRoot: root)
        let week = tracker.weekTotals(containing: Day(year: 2026, month: 11, day: 1))

        #expect(week.first == DayTotal(day: Day(year: 2026, month: 11, day: 1), total: 30 * 60))
        #expect(week.last?.day == Day(year: 2026, month: 11, day: 7))
    }

    @Test func aWeekSpanningADayWithNoMidnightHasSevenDays() {
        // Santiago skips 00:00-01:00 on Sunday 2026-09-06.
        let clock = FakeClock("2026-09-08T09:00:00", timeZone: "America/Santiago")
        clock.calendar.firstWeekday = 2
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(tracker.weekTotals(containing: Day(year: 2026, month: 9, day: 6)).map(\.day.description) == [
            "2026-08-31", "2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04", "2026-09-05", "2026-09-06",
        ])
    }

    /// Today from 09:00 to 10:00 on Internal, still running.
    private func trackerRunningAnHour() throws -> Tracker {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        clock.set("2026-11-03T10:00:00")
        tracker.tick()
        return tracker
    }
}

/// Writes a Day file with the given Entry lines, as a hand edit would.
func write(_ root: URL, _ date: String, _ entries: String) throws {
    let url = dayFile(root, date)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "{\n  \"date\": \"\(date)\",\n  \"entries\": [\n\(entries)\n  ]\n}\n"
        .write(to: url, atomically: true, encoding: .utf8)
}

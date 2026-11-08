import Foundation
import Testing
import ChronobarCore

/// The Day sheet and week sheet: what the Panel, `chronobar day` and `chronobar week` show, every figure
/// under a Total adding up to it (ADR 0005).
@MainActor @Suite struct SheetsTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func aDaysRowsAddUpToItsTotal() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Garden Shed")
        clock.set("2026-11-03T11:08:45")
        try tracker.start("Internal")
        try tracker.pause("Garden Shed")
        clock.set("2026-11-03T12:17:34")
        try tracker.pause()

        let sheet = tracker.daySheet(tracker.today)

        // 2:08:45 and 1:08:49 show as 2:08 and 1:09 under Total 3:17.
        #expect(sheet.rows.map(\.project) == ["Garden Shed", "Internal"])
        #expect(sheet.rows.map(\.time) == [Figure(seconds: 7725, minutes: 128), Figure(seconds: 4129, minutes: 69)])
        #expect(sheet.total == Figure(seconds: 11854, minutes: 197))
        #expect(sheet.clockTime == Figure(seconds: 11854, minutes: 197))
        #expect(!sheet.isMalformed)
    }

    @Test func todaysRunningRowsCountUpToNowWithTheirSource() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.start("Internal", source: .agent)
        try tracker.log("Client Call", "0:15", on: tracker.today)
        clock.set("2026-11-03T09:30:00")
        tracker.tick()

        let sheet = tracker.daySheet(tracker.today)

        #expect(sheet.rows.map(\.runningSource) == [.app, .agent, nil])
        #expect(sheet.rows.map(\.isRunning) == [true, true, false])
        #expect(sheet.rows.map(\.time.minutes) == [30, 30, 15])
        #expect(sheet.total == Figure(seconds: 75 * 60, minutes: 75))
        #expect(sheet.clockTime == Figure(seconds: 30 * 60, minutes: 30))
    }

    @Test func aPastDaysRowsNeverRun() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-04T09:00:00")
        tracker.tick()

        let yesterday = tracker.daySheet(tracker.today.adding(days: -1, in: tracker.calendar))

        // Split at midnight: yesterday's part has ended, today's runs.
        #expect(yesterday.rows.map(\.isRunning) == [false])
        #expect(yesterday.rows.map(\.time.minutes) == [15 * 60])
        #expect(tracker.daySheet(tracker.today).rows.map(\.runningSource) == [.app])
    }

    /// The Panel draws each row from the sheet: its apportioned minutes, and an agent's running Timer marked.
    @Test func aSheetsRowIsPresentedWithItsMinutesAndWhoStartedIt() throws {
        try write(root, "2026-11-03", #"{ "project": "Garden Shed", "seconds": 7725, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Two", source: .agent)
        clock.set("2026-11-03T10:08:49")
        tracker.tick()

        let rows = tracker.daySheet(tracker.today).rows.map(RowPresentation.init)

        #expect(rows.map(\.total) == ["2:08", "1:09"])
        #expect(rows.map(\.agentMark) == [nil, "Started by an agent; not paused for idle time"])
        #expect(rows.map(\.toggle) == [.start, .pause])
    }

    @Test func aTieForTheLostMinuteGoesToTheFirstRow() throws {
        try write(root, "2026-11-03", """
            { "project": "Website Redesign", "seconds": 630, "note": "manual" },
            { "project": "Internal", "seconds": 630, "note": "manual" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)

        let sheet = tracker.daySheet(tracker.today)

        // 10:30 and 10:30 under Total 21:00.
        #expect(sheet.rows.map(\.time.minutes) == [11, 10])
        #expect(sheet.total == Figure(seconds: 1260, minutes: 21))
    }

    @Test func aRowAdjustedBelowZeroShowsZeroAndCountsAsZero() throws {
        try write(root, "2026-11-03", """
            { "project": "Website Redesign", "seconds": 3630, "note": "manual" },
            { "project": "Internal", "seconds": 600, "note": "manual" },
            { "project": "Internal", "seconds": -900, "note": "adjustment" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)

        let sheet = tracker.daySheet(tracker.today)

        #expect(sheet.rows.map(\.time) == [Figure(seconds: 3630, minutes: 60), Figure(seconds: 0, minutes: 0)])
        #expect(sheet.total == Figure(seconds: 3630, minutes: 60))
    }

    @Test func aMalformedDayIsFlaggedInItsSheetAndItsWeeksSheet() throws {
        clock.calendar.firstWeekday = 1
        try write(root, "2026-11-02", "not JSON")
        let tracker = Tracker(clock: clock, storageRoot: root)
        let monday = Day(year: 2026, month: 11, day: 2)

        #expect(tracker.daySheet(monday).isMalformed)
        #expect(!tracker.daySheet(tracker.today).isMalformed)
        #expect(tracker.weekSheet(containing: tracker.today).malformed == [monday])
    }

    @Test func aWeekRunsFromTheCalendarsFirstWeekday() {
        clock.calendar.firstWeekday = 2
        let tracker = Tracker(clock: clock, storageRoot: root)

        let week = tracker.weekSheet(containing: tracker.today)

        #expect(week.days.map(\.day.description) == [
            "2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05", "2026-11-06", "2026-11-07", "2026-11-08",
        ])
        #expect(week.first == Day(year: 2026, month: 11, day: 2))
        #expect(week.last == Day(year: 2026, month: 11, day: 8))
    }

    /// The week's Total is the sum of its Day lines as shown, 2:08 and 1:08, so 3:16 rather than its
    /// seconds rounded down, 3:17; the Labels' week lines add up to it.
    @Test func aWeeksLabelLinesAddUpToTheSumOfItsDayLines() throws {
        clock.calendar.firstWeekday = 1
        try write(root, "2026-11-01", """
            { "project": "Garden Shed", "seconds": 3630, "note": "manual" },
            { "project": "Two", "seconds": 4095, "note": "manual" }
        """)
        try write(root, "2026-11-02", """
            { "project": "Two", "seconds": 2299, "note": "manual" },
            { "project": "garden shed", "seconds": 1830, "note": "manual" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)

        let week = tracker.weekSheet(containing: tracker.today)

        #expect(week.days.map(\.total.minutes) == [128, 68, 0, 0, 0, 0, 0])
        #expect(week.total == Figure(seconds: 11854, minutes: 196))
        #expect(week.lines == [
            WeekSheet.Line(project: "Garden Shed", time: Figure(seconds: 5460, minutes: 90)),
            WeekSheet.Line(project: "Two", time: Figure(seconds: 6394, minutes: 106)),
        ])
    }

    @Test func aLabelSpelledDifferentlyAcrossDaysIsOneWeekLineUnderItsStoredSpelling() throws {
        clock.calendar.firstWeekday = 1
        try write(root, "2026-11-01", #"{ "project": "website redesign", "seconds": 600, "note": "manual" }"#)
        try write(root, "2026-11-02", #"{ "project": "Website Redesign", "seconds": 600, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.pinProject("Website Redesign")

        #expect(tracker.weekSheet(containing: tracker.today).lines == [
            WeekSheet.Line(project: "Website Redesign", time: Figure(seconds: 1200, minutes: 20)),
        ])
    }

    @Test func aWeeksClockTimeIsTheSumOfItsDaysClockTimes() throws {
        clock.calendar.firstWeekday = 1
        try write(root, "2026-11-01", """
            { "project": "Internal", "start": "2026-11-01T09:00:00-05:00", "end": "2026-11-01T10:00:30-05:00", "source": "app" }
        """)
        try write(root, "2026-11-02", """
            { "project": "Internal", "start": "2026-11-02T09:00:00-05:00", "end": "2026-11-02T10:00:40-05:00", "source": "app" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)

        let week = tracker.weekSheet(containing: tracker.today)

        // 1:00 and 1:00, though 2:01:10 in all.
        #expect(week.clockTime == Figure(seconds: 7270, minutes: 120))
        #expect(week.total == Figure(seconds: 7270, minutes: 120))
    }

    @Test func aDaysSheetIsTheSameInsideItsWeeksSheet() throws {
        clock.calendar.firstWeekday = 1
        try write(root, "2026-11-02", """
            { "project": "Website Redesign", "seconds": 7725, "note": "manual" },
            { "project": "Internal", "start": "2026-11-02T09:00:00-05:00", "end": "2026-11-02T10:08:49-05:00", "source": "app" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        clock.set("2026-11-03T09:20:15")
        tracker.tick()

        let week = tracker.weekSheet(containing: tracker.today)

        for day in [Day(year: 2026, month: 11, day: 2), tracker.today] {
            #expect(week.days.first { $0.day == day } == tracker.daySheet(day))
        }
    }
}

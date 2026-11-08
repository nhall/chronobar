import Foundation
import Testing
import ChronobarCore
import ChronobarOperations

/// `day`: a Day's rows, one per Label, with the Day total and Elapsed time.
@MainActor @Suite struct DayTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func dayListsEachLabelsRowWithTheDayTotalAndElapsedTime() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.start("Internal", source: .agent)
        clock.set("2026-11-03T10:30:00")
        try tracker.pause("Website Redesign")
        try tracker.log("Client Call", "0:15", on: tracker.today)
        clock.set("2026-11-03T11:00:00")

        let day = try Operations(tracker: tracker).day("2026-11-03")

        #expect(day.rows == [
            RowResult(label: "Website Redesign", totalSeconds: 90 * 60, totalMinutes: 90, running: false),
            RowResult(label: "Internal", totalSeconds: 60 * 60, totalMinutes: 60, running: true),
            RowResult(label: "Client Call", totalSeconds: 15 * 60, totalMinutes: 15, running: false),
        ])
        #expect(day.day == DayResult(date: "2026-11-03", totalSeconds: 165 * 60, totalMinutes: 165, elapsedSeconds: 120 * 60, elapsedMinutes: 120))
        #expect(day.malformed == false)
    }

    /// The minutes the Panel shows, so an agent can quote them: 2:08:45 and 1:08:49 as 2:08 and 1:09
    /// under Total 3:17.
    @Test func dayGivesEachRowTheMinutesThePanelShows() throws {
        try write(root, "2026-11-03", """
            { "project": "Garden Shed", "seconds": 7725, "note": "manual" },
            { "project": "Two", "seconds": 4129, "note": "manual" }
        """)

        let day = try Operations(tracker: Tracker(clock: clock, storageRoot: root)).day()

        #expect(day.rows.map(\.totalMinutes) == [128, 69])
        #expect(day.day.totalMinutes == 197)
        #expect(day.day.elapsedMinutes == 0)
    }

    @Test func dayReadsThePastDayItNames() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "2:00", on: Day(year: 2026, month: 11, day: 2))
        try tracker.start("Internal")
        clock.set("2026-11-03T10:00:00")

        let day = try Operations(tracker: tracker).day("2026-11-02")

        #expect(day.rows == [RowResult(label: "Website Redesign", totalSeconds: 2 * 3600, totalMinutes: 120, running: false)])
        #expect(day.day == DayResult(date: "2026-11-02", totalSeconds: 2 * 3600, totalMinutes: 120, elapsedSeconds: 0, elapsedMinutes: 0))
    }

    /// A timer runs today only, so yesterday's row for the same Label isn't running.
    @Test func aPastDaysRowIsNotRunningWhenItsLabelRunsToday() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "2:00", on: Day(year: 2026, month: 11, day: 2))
        try tracker.start("Website Redesign")

        let day = try Operations(tracker: tracker).day("2026-11-02")

        #expect(day.rows.map(\.running) == [false])
    }

    @Test func withNoDateDayReadsToday() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "2:00", on: Day(year: 2026, month: 11, day: 2))
        try tracker.log("Internal", "0:30", on: tracker.today)

        let day = try Operations(tracker: tracker).day()

        #expect(day.day.date == "2026-11-03")
        #expect(day.rows.map(\.label) == ["Internal"])
    }

    @Test func aDayWithNoTimeHasNoRows() throws {
        let day = try Operations(tracker: Tracker(clock: clock, storageRoot: root)).day("2026-10-01")

        #expect(day.rows.isEmpty)
        #expect(day.day == DayResult(date: "2026-10-01", totalSeconds: 0, totalMinutes: 0, elapsedSeconds: 0, elapsedMinutes: 0))
    }

    @Test(arguments: ["yesterday", "2026-11-31", "2026-13-01", "3 Nov", ""])
    func aDateThatIsNotACalendarDayIsRefused(_ date: String) throws {
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let error = try #require(operations.perform(.day(date: date)).error)

        #expect(error.kind == .invalidDate)
        #expect(error.message.contains("YYYY-MM-DD"))
    }

    @Test func aMalformedDayFileReadsAsEmptyAndSaysSo() throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent("days"), withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: dayFile(root, "2026-11-02"))

        let day = try Operations(tracker: Tracker(clock: clock, storageRoot: root)).day("2026-11-02")

        #expect(day.malformed)
        #expect(day.rows.isEmpty)
    }

    /// Each row is counted in whole seconds and the Day total adds those up, so with two timers running
    /// the rows never come to a second less than the total.
    @Test func theDayTotalIsTheSumOfItsRowsInWholeSeconds() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.start("Internal", source: .agent)
        clock.now += 90.6

        let day = try Operations(tracker: tracker).day(nil)

        #expect(day.rows.map(\.totalSeconds) == [90, 90])
        #expect(day.day.totalSeconds == 180)
    }

    /// Each Day's total, each Label's week total and the week total all add up from the same rows.
    @Test func theWeeksTotalsAddUpFromItsRowsInWholeSeconds() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.start("Internal", source: .agent)
        clock.now += 90.6

        let week = try Operations(tracker: tracker).week(nil)

        #expect(week.days[2] == (try Operations(tracker: tracker).day(nil)).day)
        #expect(week.days[2].totalSeconds == 180)
        #expect(week.labels.map(\.totalSeconds) == [90, 90])
        #expect(week.totalSeconds == 180)
        #expect(week.elapsedSeconds == week.days.map(\.elapsedSeconds).reduce(0, +))
        #expect(week.elapsedSeconds == 90)
    }
}

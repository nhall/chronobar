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
            RowResult(label: "Website Redesign", totalSeconds: 90 * 60, running: false),
            RowResult(label: "Internal", totalSeconds: 60 * 60, running: true),
            RowResult(label: "Client Call", totalSeconds: 15 * 60, running: false),
        ])
        #expect(day.day == DayResult(date: "2026-11-03", totalSeconds: 165 * 60, elapsedSeconds: 120 * 60))
        #expect(day.malformed == false)
    }

    @Test func dayReadsThePastDayItNames() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "2:00", on: Day(year: 2026, month: 11, day: 2))
        try tracker.start("Internal")
        clock.set("2026-11-03T10:00:00")

        let day = try Operations(tracker: tracker).day("2026-11-02")

        #expect(day.rows == [RowResult(label: "Website Redesign", totalSeconds: 2 * 3600, running: false)])
        #expect(day.day == DayResult(date: "2026-11-02", totalSeconds: 2 * 3600, elapsedSeconds: 0))
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
        #expect(day.day == DayResult(date: "2026-10-01", totalSeconds: 0, elapsedSeconds: 0))
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
}

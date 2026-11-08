import Foundation
import Testing
import ChronobarCore
import ChronobarOperations

/// `week`: the week containing a Day, as the Week strip has it: each Day's total and Elapsed time, and
/// each Label's total across the week.
@MainActor @Suite struct WeekTests {
    /// A Tuesday; its week runs Sunday 1 to Saturday 7 November.
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func weekGivesEachDaysTotalsAndEachLabelsWeekTotal() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "2:00", on: Day(year: 2026, month: 11, day: 1))
        try tracker.log("Client A, Ticket 665", "1:00", on: Day(year: 2026, month: 11, day: 2))
        try tracker.log("website redesign", "0:30", on: Day(year: 2026, month: 11, day: 2))
        try tracker.start("Internal")
        clock.set("2026-11-03T10:00:00")

        let week = try Operations(tracker: tracker).week()

        #expect(week.first == "2026-11-01")
        #expect(week.last == "2026-11-07")
        #expect(week.days.map(\.date) == ["2026-11-01", "2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05",
                                          "2026-11-06", "2026-11-07"])
        #expect(week.days.map(\.totalSeconds) == [2 * 3600, 90 * 60, 3600, 0, 0, 0, 0])
        #expect(week.days[2] == DayResult(date: "2026-11-03", totalSeconds: 3600, totalMinutes: 60, elapsedSeconds: 3600, elapsedMinutes: 60))
        #expect(week.labels == [
            LabelTotalResult(label: "Website Redesign", totalSeconds: 150 * 60, totalMinutes: 150),
            LabelTotalResult(label: "Client A, Ticket 665", totalSeconds: 3600, totalMinutes: 60),
            LabelTotalResult(label: "Internal", totalSeconds: 3600, totalMinutes: 60),
        ])
        #expect(week.totalSeconds == 270 * 60)
        #expect(week.elapsedSeconds == 3600)
        #expect(week.malformed.isEmpty)
    }

    /// The week's minutes are the sum of its Day lines', 2:08 and 1:08, so 3:16 though its seconds come
    /// to 3:17; the seconds keep their meaning, and the Labels' minutes add up to the week's.
    @Test func weeksMinutesAreTheSumOfItsDaysMinutes() throws {
        try write(root, "2026-11-01", """
            { "project": "Garden Shed", "seconds": 3630, "note": "manual" },
            { "project": "Two", "seconds": 4095, "note": "manual" }
        """)
        try write(root, "2026-11-02", """
            { "project": "Garden Shed", "seconds": 1830, "note": "manual" },
            { "project": "Two", "seconds": 2299, "note": "manual" }
        """)

        let week = try Operations(tracker: Tracker(clock: clock, storageRoot: root)).week()

        #expect(week.days.map(\.totalMinutes) == [128, 68, 0, 0, 0, 0, 0])
        #expect(week.totalSeconds == 11854)
        #expect(week.totalMinutes == 196)
        #expect(week.elapsedMinutes == 0)
        #expect(week.labels.map(\.totalMinutes) == [90, 106])
    }

    @Test func weekReadsTheWeekContainingTheDateItNames() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "2:00", on: Day(year: 2026, month: 10, day: 28))

        let week = try Operations(tracker: tracker).week("2026-10-28")

        #expect(week.first == "2026-10-25")
        #expect(week.last == "2026-10-31")
        #expect(week.labels == [LabelTotalResult(label: "Website Redesign", totalSeconds: 2 * 3600, totalMinutes: 120)])
    }

    @Test func weekNamesTheDayFilesThatWontParse() throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent("days"), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: dayFile(root, "2026-11-02"))
        let tracker = Tracker(clock: clock, storageRoot: root)

        let week = try Operations(tracker: tracker).week()

        #expect(week.malformed == ["2026-11-02"])
    }

    @Test func anImpossibleDateIsRefused() {
        let tracker = Tracker(clock: clock, storageRoot: root)

        let error = Operations(tracker: tracker).perform(.week(date: "2026-11-31")).error

        #expect(error?.kind == .invalidDate)
    }

    @Test func weekGoesOverTheWire() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Internal", "1:00", on: tracker.today)
        let operations = Operations(tracker: tracker)

        let line = operations.respond(to: Data(#"{"op":"week","date":"2026-11-03"}"#.utf8))
        let response = try Wire.response(from: line)

        guard case .success(.week(let week)) = response else { throw Unexpected() }
        #expect(week.labels == [LabelTotalResult(label: "Internal", totalSeconds: 3600, totalMinutes: 60)])
        let text = String(decoding: line, as: UTF8.self)
        #expect(text.contains(#""op":"week""#))
        #expect(text.contains(#""labels":[{"label":"Internal","total_minutes":60,"total_seconds":3600}]"#))
        #expect(text.contains(#""malformed":[]"#))
    }
}

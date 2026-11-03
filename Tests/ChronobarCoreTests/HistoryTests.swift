import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct HistoryTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func aPastDayShowsTheRowsInItsOwnFile() throws {
        try write("2026-10-28", """
            { "project": "Website Redesign", "start": "2026-10-28T09:00:00-04:00", "end": "2026-10-28T11:30:00-04:00" },
            { "project": "Garden Shed", "seconds": 900, "note": "manual" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        clock.set("2026-11-03T10:00:00")
        tracker.tick()
        let past = Day(year: 2026, month: 10, day: 28)

        #expect(tracker.rows(past) == [
            Row(project: "Website Redesign", total: 150 * 60),
            Row(project: "Garden Shed", total: 15 * 60),
        ])
        #expect(tracker.total("Internal", on: past) == 0)
        #expect(tracker.dayTotal(past) == 165 * 60)
        #expect(tracker.rows(tracker.today) == [Row(project: "Internal", total: 60 * 60)])
    }

    @Test func reloadPicksUpAHandEditToAPastDay() throws {
        try write("2026-10-28", """
            { "project": "Website Redesign", "seconds": 3600, "note": "manual" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)
        let past = Day(year: 2026, month: 10, day: 28)
        #expect(tracker.dayTotal(past) == 60 * 60)

        try write("2026-10-28", """
            { "project": "Website Redesign", "seconds": 7200, "note": "manual" }
        """)
        tracker.reload()

        #expect(tracker.dayTotal(past) == 2 * 60 * 60)
    }

    @Test func aMalformedPastDayHasNoRows() throws {
        try write("2026-10-28", "{ oops")
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(tracker.rows(Day(year: 2026, month: 10, day: 28)).isEmpty)
    }

    /// Writes a Day file with the given Entry lines, as a hand edit would.
    private func write(_ date: String, _ entries: String) throws {
        let url = dayFile(root, date)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "{\n  \"date\": \"\(date)\",\n  \"entries\": [\n\(entries)\n  ]\n}\n"
            .write(to: url, atomically: true, encoding: .utf8)
    }
}

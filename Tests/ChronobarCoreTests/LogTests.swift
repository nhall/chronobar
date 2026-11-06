import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct LogTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()
    let past = Day(year: 2026, month: 10, day: 28)
    let future = Day(year: 2026, month: 11, day: 16)

    @Test func loggingToAPastDayLeavesTodaysTotalsAlone() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        clock.set("2026-11-03T10:00:00")
        tracker.tick()

        try tracker.log("Garden Shed", "1:30", on: past)

        #expect(tracker.rows(tracker.today) == [Row(project: "Internal", total: 60 * 60)])
        #expect(tracker.running?.project == "Internal")
        #expect(tracker.rows(past) == [Row(project: "Garden Shed", total: 90 * 60)])
        clock.set("2026-11-03T10:30:00")
        tracker.tick()
        #expect(tracker.total("Internal", on: tracker.today) == 90 * 60)
    }

    @Test func loggingWritesAManualEntryWithoutStartingATimer() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)

        try tracker.log("Website Redesign", "45", on: tracker.today)

        #expect(tracker.running == nil)
        #expect(tracker.selectedProject == nil)
        #expect(tracker.rows(tracker.today) == [Row(project: "Website Redesign", total: 45 * 60)])
        #expect(tracker.projects.isEmpty)
        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "seconds": 2700, "note": "manual" }
          ]
        }

        """)
    }

    @Test func loggingToAPastDayWritesThatDaysFile() throws {
        try write(root, "2026-10-28", #"{ "project": "Website Redesign", "seconds": 600, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)

        try tracker.log("website redesign ", "0:15", on: past)

        #expect(tracker.rows(past) == [Row(project: "Website Redesign", total: 25 * 60)])
        #expect(contents(dayFile(root, "2026-11-03")) == nil)
        #expect(contents(dayFile(root, "2026-10-28")) == """
        {
          "date": "2026-10-28",
          "entries": [
            { "project": "Website Redesign", "seconds": 600, "note": "manual" },
            { "project": "Website Redesign", "seconds": 900, "note": "manual" }
          ]
        }

        """)
    }

    @Test(arguments: ["", "abc", "+15", "-10", "0", "0:00"])
    func loggingRejectsAnythingButAPositiveDuration(text: String) throws {
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(throws: InvalidDuration(text: text)) { try tracker.log("Garden Shed", text, on: tracker.today) }

        #expect(tracker.projects.isEmpty)
        #expect(contents(dayFile(root, "2026-11-03")) == nil)
    }

    @Test func loggingAheadWritesThatDaysFileInTheSameFormat() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")

        try tracker.log("Vacation", "8:00", on: future)

        #expect(tracker.rows(future) == [Row(project: "Vacation", total: 8 * 60 * 60)])
        #expect(tracker.rows(tracker.today) == [Row(project: "Internal", total: 0)])
        #expect(tracker.running?.project == "Internal")
        #expect(tracker.selectedProject == "Internal")
        #expect(contents(dayFile(root, "2026-11-16")) == """
        {
          "date": "2026-11-16",
          "entries": [
            { "project": "Vacation", "seconds": 28800, "note": "manual" }
          ]
        }

        """)
    }
}

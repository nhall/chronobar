import Foundation
import Testing
import ChronobarCore

/// Relabeling: moving all of a Label's time on one Day to another Label.
@MainActor @Suite struct RelabelTests {
    let clock = FakeClock("2026-11-03T12:00:00")
    let root = temporaryRoot()

    @Test func relabelingAStoppedRowMovesEveryEntryOfTheLabelOnThatDay() throws {
        try write(root, "2026-11-03", """
            { "project": "Northwnd", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "agent" },
            { "project": "Internal", "start": "2026-11-03T10:00:00-05:00", "end": "2026-11-03T10:30:00-05:00", "source": "app" },
            { "project": "northwnd", "seconds": 900, "note": "manual" },
            { "project": "Northwnd", "seconds": -300, "note": "adjustment" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)

        try tracker.relabel("Northwnd", to: " Northwind, Ticket 665 ", on: tracker.today)

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Northwind, Ticket 665", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "agent" },
            { "project": "Internal", "start": "2026-11-03T10:00:00-05:00", "end": "2026-11-03T10:30:00-05:00", "source": "app" },
            { "project": "Northwind, Ticket 665", "seconds": 900, "note": "manual" },
            { "project": "Northwind, Ticket 665", "seconds": -300, "note": "adjustment" }
          ]
        }

        """)
        #expect(tracker.rows(tracker.today) == [Row(project: "Northwind, Ticket 665", total: 70 * 60),
                                                Row(project: "Internal", total: 30 * 60)])
    }

    @Test func theSameLabelOnOtherDaysKeepsItsName() throws {
        try write(root, "2026-11-02", #"    { "project": "Northwnd", "seconds": 3600, "note": "manual" }"#)
        try write(root, "2026-11-03", #"    { "project": "Northwnd", "seconds": 1800, "note": "manual" }"#)
        let before = contents(dayFile(root, "2026-11-03"))
        let tracker = Tracker(clock: clock, storageRoot: root)

        try tracker.relabel("Northwnd", to: "Northwind", on: Day(year: 2026, month: 11, day: 2))

        #expect(tracker.rows(Day(year: 2026, month: 11, day: 2)) == [Row(project: "Northwind", total: 3600)])
        #expect(contents(dayFile(root, "2026-11-03")) == before)
    }

    @Test func aRelabelReturnsWhatItStoredAndLeavesTheDaysTotalAndClockTime() throws {
        try write(root, "2026-11-03", """
            { "project": "Northwnd", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "agent" },
            { "project": "Internal", "start": "2026-11-03T09:30:00-05:00", "end": "2026-11-03T10:30:00-05:00", "source": "app" },
            { "project": "Northwnd", "seconds": 900, "note": "manual" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)
        let (total, clockTime) = (tracker.dayTotal(tracker.today), tracker.elapsed(tracker.today))

        let relabeled = try tracker.relabel("northwnd", to: "Northwind", on: tracker.today)

        #expect(relabeled == Relabeling(
            project: "Northwind", day: tracker.today,
            entries: [TimedEntry(project: "Northwind", start: clock.date("2026-11-03T09:00:00"),
                                 end: clock.date("2026-11-03T10:00:00"), source: .agent)],
            total: 75 * 60))
        #expect(tracker.dayTotal(tracker.today) == total)
        #expect(tracker.elapsed(tracker.today) == clockTime)
    }

    @Test func theNewLabelIsWrittenUnderItsStoredSpelling() throws {
        try "Northwind, Ticket 665\n".write(to: projectsFile(root), atomically: true, encoding: .utf8)
        try write(root, "2026-11-03", #"    { "project": "Northwnd", "seconds": 1800, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)

        let relabeled = try tracker.relabel("Northwnd", to: "northwind, ticket 665", on: tracker.today)

        #expect(relabeled.project == "Northwind, Ticket 665")
        #expect(contents(dayFile(root, "2026-11-03"))?.contains(#""project": "Northwind, Ticket 665""#) == true)
    }

    @Test func anEmptyNewLabelIsRefusedAndChangesNothing() throws {
        try write(root, "2026-11-03", #"    { "project": "Northwnd", "seconds": 1800, "note": "manual" }"#)
        let before = contents(dayFile(root, "2026-11-03"))
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(throws: EmptyProjectName.self) { try tracker.relabel("Northwnd", to: "  ", on: tracker.today) }

        #expect(contents(dayFile(root, "2026-11-03")) == before)
    }

    @Test func aLabelWithNoEntriesOnThatDayIsRefused() throws {
        try write(root, "2026-11-02", #"    { "project": "Northwnd", "seconds": 1800, "note": "manual" }"#)
        try write(root, "2026-11-03", #"    { "project": "Internal", "seconds": 1800, "note": "manual" }"#)
        let before = contents(dayFile(root, "2026-11-03"))
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(throws: NoTimeOnDay(project: "Northwnd", day: tracker.today)) {
            try tracker.relabel(" Northwnd ", to: "Northwind", on: tracker.today)
        }

        #expect(contents(dayFile(root, "2026-11-03")) == before)
    }
}

import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct RowsTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func withTheSettingOnStartingAnotherProjectPausesTheRunningOne() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        tracker.startPausesOthers = true
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.start("Internal")
        clock.set("2026-11-03T10:15:00")
        tracker.tick()

        #expect(tracker.timers.newest?.project == "Internal")
        #expect(tracker.total("Website Redesign", on: tracker.today) == 60 * 60)
        #expect(tracker.total("Internal", on: tracker.today) == 15 * 60)
        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "app" },
            { "project": "Internal", "start": "2026-11-03T10:00:00-05:00", "end": null, "source": "app" }
          ]
        }

        """)
    }

    @Test func rowsListEachProjectWithTimeTodayInTheOrderFirstStarted() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.start("Internal")
        clock.set("2026-11-03T10:20:00")
        tracker.tick()

        #expect(tracker.rows(tracker.today) == [
            Row(project: "Website Redesign", total: 80 * 60),
            Row(project: "Internal", total: 20 * 60),
        ])
    }

    /// The ＋ form sits under the rows, so a Project it adds belongs at the bottom, just above it.
    @Test func aProjectLoggedFromThePlusFormGetsTheLastRow() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.pause()
        try tracker.log("Internal", "0:30", on: tracker.today)
        try tracker.log("Garden Shed", "15", on: tracker.today)

        #expect(tracker.rows(tracker.today) == [
            Row(project: "Website Redesign", total: 60 * 60),
            Row(project: "Internal", total: 30 * 60),
            Row(project: "Garden Shed", total: 15 * 60),
        ])
    }

    @Test func restartingAProjectAddsToItsRow() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.toggle("Website Redesign")
        try tracker.start("Internal")
        clock.set("2026-11-03T10:30:00")
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T11:00:00")
        try tracker.pause()

        #expect(tracker.rows(tracker.today) == [
            Row(project: "Website Redesign", total: 90 * 60),
            Row(project: "Internal", total: 60 * 60),
        ])
    }

    @Test func anEmptyDayHasNoRowsAndAZeroTotal() {
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(tracker.rows(tracker.today).isEmpty)
        #expect(tracker.dayTotal(tracker.today) == 0)
    }

    @Test func dayTotalIsTheSumOfTheRowsShown() throws {
        try FileManager.default.createDirectory(
            at: dayFile(root, "2026-11-03").deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T07:00:00-05:00", "end": "2026-11-03T08:00:00-05:00" },
            { "project": "Internal", "seconds": -900, "note": "adjustment" },
            { "project": "Garden Shed", "seconds": 1800, "note": "manual" }
          ]
        }
        """.write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)

        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T09:15:00")
        tracker.tick()

        #expect(tracker.rows(tracker.today) == [
            Row(project: "Website Redesign", total: 75 * 60),
            Row(project: "Internal", total: 0),
            Row(project: "Garden Shed", total: 30 * 60),
        ])
        #expect(tracker.dayTotal(tracker.today) == 105 * 60)
    }

    /// Hand edits can spell a Project differently. Names match case-insensitively after trimming, so each
    /// Project is still one Row, shown with the Project list's spelling (else the first one in the file).
    @Test func differentlySpelledEntriesShareOneRow() throws {
        try "Website Redesign\n".write(to: projectsFile(root), atomically: true, encoding: .utf8)
        try write(root, "2026-11-03", """
            { "project": "website redesign", "start": "2026-11-03T08:00:00-05:00", "end": "2026-11-03T08:30:00-05:00" },
            { "project": "Internal", "seconds": 900, "note": "manual" },
            { "project": " Website Redesign ", "seconds": 600, "note": "manual" },
            { "project": "INTERNAL", "seconds": 300, "note": "manual" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(tracker.rows(tracker.today) == [
            Row(project: "Website Redesign", total: 40 * 60),
            Row(project: "Internal", total: 20 * 60),
        ])
        #expect(tracker.total("WEBSITE REDESIGN", on: tracker.today) == 40 * 60)

        try tracker.start("website redesign")
        clock.set("2026-11-03T09:30:00")
        try tracker.pause()
        #expect(tracker.rows(tracker.today).first == Row(project: "Website Redesign", total: 70 * 60))

        try tracker.adjust("internal", "1:00", on: tracker.today)
        #expect(tracker.rows(tracker.today).last == Row(project: "Internal", total: 60 * 60))
        #expect(tracker.dayTotal(tracker.today) == 130 * 60)
    }

    /// Rows count whole seconds, and the Day total is their sum, so what each shows adds up.
    @Test func rowsCountWholeSecondsAndTheDayTotalAddsThemUp() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.start("Internal")
        clock.advance(90.6)
        tracker.tick()

        #expect(tracker.rows(tracker.today) == [
            Row(project: "Website Redesign", total: 90),
            Row(project: "Internal", total: 90),
        ])
        #expect(tracker.dayTotal(tracker.today) == 180)
    }
}

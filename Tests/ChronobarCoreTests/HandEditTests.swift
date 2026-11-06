import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct HandEditTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()
    let today = Day("2026-11-03")!

    @Test func reloadPicksUpAHandEdit() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.pause()

        write("""
        { "date": "2026-11-03", "entries": [
          { "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T09:30:00-05:00" },
          { "project": "Internal", "seconds": 900, "note": "manual" }
        ] }
        """)
        tracker.reload()

        #expect(tracker.rows(today) == [
            Row(project: "Website Redesign", total: 1800),
            Row(project: "Internal", total: 900),
        ])
    }

    @Test func aWriteKeepsAnEditMadeSinceTheLastRead() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        write("""
        { "date": "2026-11-03", "entries": [
          { "project": "Internal", "seconds": 900, "note": "manual" },
          { "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": null }
        ] }
        """)

        clock.set("2026-11-03T10:00:00")
        try tracker.pause()

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Internal", "seconds": 900, "note": "manual" },
            { "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "app" }
          ]
        }

        """)
    }

    @Test func aMalformedFileIsFlaggedAndLeftUntouched() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        #expect(!tracker.isMalformed(today))

        write(Self.malformed)
        tracker.reload()

        #expect(tracker.isMalformed(today))
        #expect(throws: (any Error).self) { try tracker.start("Website Redesign") }
        #expect(tracker.running == nil)
        #expect(contents(dayFile(root, "2026-11-03")) == Self.malformed)

        write(#"{ "date": "2026-11-03", "entries": [] }"#)
        tracker.reload()
        #expect(!tracker.isMalformed(today))
    }

    @Test func aRunningTimerKeepsRunningWhenItsFileBreaks() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        write(Self.malformed)
        tracker.reload()

        clock.set("2026-11-03T10:00:00")
        tracker.tick()

        #expect(tracker.running?.project == "Website Redesign")
        #expect(tracker.total("Website Redesign", on: today) == 3600)
        #expect(throws: (any Error).self) { try tracker.start("Internal") }
        #expect(tracker.running?.project == "Website Redesign")
        #expect(contents(dayFile(root, "2026-11-03")) == Self.malformed)
    }

    @Test func aPauseWhileTheFileIsBrokenLandsOnTheTickAfterItIsFixed() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        write(Self.malformed)
        tracker.reload()

        clock.set("2026-11-03T10:00:00")
        try tracker.pause()
        clock.set("2026-11-03T10:05:00")
        tracker.tick()

        #expect(tracker.running == nil)
        #expect(tracker.total("Website Redesign", on: today) == 3600)
        #expect(contents(dayFile(root, "2026-11-03")) == Self.malformed)

        write(Self.fixed)
        clock.set("2026-11-03T10:06:00")
        tracker.tick()
        #expect(contents(dayFile(root, "2026-11-03")) == Self.fixedAndPaused)

        // Lands once: later ticks leave the file alone.
        write(Self.fixed)
        tracker.tick()
        #expect(contents(dayFile(root, "2026-11-03")) == Self.fixed)
    }

    @Test func aPauseWhileTheFileIsBrokenLandsWhenThePanelReloads() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        write(Self.malformed)
        tracker.reload()
        clock.set("2026-11-03T10:00:00")
        try tracker.pause()

        write(Self.fixed)
        clock.set("2026-11-03T10:06:00")
        tracker.reload()

        #expect(contents(dayFile(root, "2026-11-03")) == Self.fixedAndPaused)
        #expect(!tracker.isMalformed(today))
        #expect(tracker.running == nil)
        #expect(tracker.rows(today) == [
            Row(project: "Internal", total: 900),
            Row(project: "Website Redesign", total: 3600),
        ])
    }

    @Test func aStartAfterTheFixLandsTheDeferredPauseFirst() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        write(Self.malformed)
        tracker.reload()
        clock.set("2026-11-03T10:00:00")
        try tracker.pause()

        write(Self.fixed)
        clock.set("2026-11-03T10:06:00")
        try tracker.start("Internal")

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Internal", "seconds": 900, "note": "manual" },
            { "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "app" },
            { "project": "Internal", "start": "2026-11-03T10:06:00-05:00", "end": null, "source": "app" }
          ]
        }

        """)
    }

    @Test func aMidnightSplitIntoABrokenFileLandsOnceItIsFixed() throws {
        clock.set("2026-11-03T23:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        write(Self.malformed)
        tracker.reload()

        clock.set("2026-11-04T00:30:00")
        tracker.tick()

        #expect(tracker.running?.project == "Website Redesign")
        #expect(tracker.total("Website Redesign", on: Day("2026-11-04")!) == 1800)
        #expect(contents(dayFile(root, "2026-11-03")) == Self.malformed)

        write(#"""
        { "date": "2026-11-03", "entries": [
          { "project": "Website Redesign", "start": "2026-11-03T23:00:00-05:00", "end": null }
        ] }
        """#)
        tracker.tick()

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T23:00:00-05:00", "end": "2026-11-04T00:00:00-05:00", "source": "app" }
          ]
        }

        """)
        #expect(tracker.running?.project == "Website Redesign")
    }

    /// The new Day's file is already broken at midnight: the timer runs on into it in memory.
    @Test func aMidnightSplitIntoABrokenNewDayKeepsTheTimerRunning() throws {
        clock.set("2026-11-03T23:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        write(Self.malformed, "2026-11-04")

        clock.set("2026-11-04T00:30:00")
        tracker.tick()

        #expect(tracker.running?.project == "Website Redesign")
        #expect(tracker.total("Website Redesign", on: Day("2026-11-04")!) == 1800)
        #expect(tracker.total("Website Redesign", on: Day("2026-11-03")!) == 3600)
        #expect(tracker.isMalformed(Day("2026-11-04")!))
    }

    @Test func aMalformedPastDayIsFlaggedAndLeftUntouched() throws {
        let past = Day("2026-10-28")!
        let broken = #"{ "date": "2026-10-28", "entries": [ { "project": "Internal", "start": "9am" } ] }"#
        write(broken, "2026-10-28")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.pause()

        // Starting a new name looked for a past spelling, which read and flagged the past Day, as viewing
        // it does; nothing writes to it.
        #expect(tracker.isMalformed(past))
        #expect(tracker.weekTotals(containing: past).first { $0.day == past }?.total == 0)
        #expect(tracker.isMalformed(past))
        #expect(!tracker.isMalformed(today))
        #expect(tracker.rows(past).isEmpty)
        tracker.reload()
        _ = tracker.summary()
        #expect(tracker.dayTotal(past) == 0)
        #expect(tracker.isMalformed(past))
        #expect(contents(dayFile(root, "2026-10-28")) == broken)

        write(#"{ "date": "2026-10-28", "entries": [ { "project": "Internal", "seconds": 900, "note": "manual" } ] }"#, "2026-10-28")
        tracker.reload()
        #expect(tracker.dayTotal(past) == 900)
        #expect(!tracker.isMalformed(past))
    }

    @Test func aDeferredWriteToYesterdayUpdatesItsTotalsButNotToday() throws {
        clock.set("2026-11-03T23:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        write(Self.malformed)
        tracker.reload()
        clock.set("2026-11-04T00:30:00")
        tracker.tick()
        let yesterday = Day("2026-11-03")!
        let newToday = Day("2026-11-04")!

        // Yesterday is read (and cached) while its midnight close is still queued.
        #expect(tracker.dayTotal(yesterday) == 0)
        #expect(tracker.isMalformed(yesterday))

        write(#"""
        { "date": "2026-11-03", "entries": [
          { "project": "Website Redesign", "start": "2026-11-03T23:00:00-05:00", "end": null }
        ] }
        """#)
        tracker.tick()

        #expect(tracker.dayTotal(yesterday) == 3600)
        #expect(!tracker.isMalformed(yesterday))
        #expect(tracker.today == newToday)
        #expect(tracker.running?.project == "Website Redesign")
        #expect(tracker.rows(newToday) == [Row(project: "Website Redesign", total: 1800)])

        tracker.reload()
        #expect(tracker.dayTotal(yesterday) == 3600)
        #expect(tracker.rows(newToday) == [Row(project: "Website Redesign", total: 1800)])
    }

    private static let fixed = #"""
    { "date": "2026-11-03", "entries": [
      { "project": "Internal", "seconds": 900, "note": "manual" },
      { "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": null }
    ] }
    """#

    private static let fixedAndPaused = """
    {
      "date": "2026-11-03",
      "entries": [
        { "project": "Internal", "seconds": 900, "note": "manual" },
        { "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "app" }
      ]
    }

    """

    private static let malformed = #"{ "date": "2026-11-03", "entries": [ { "project": "Internal", "start": "9am" } ] }"#

    private func write(_ text: String, _ date: String = "2026-11-03") {
        let url = dayFile(root, date)
        try! FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! text.write(to: url, atomically: true, encoding: .utf8)
    }
}

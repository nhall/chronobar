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
            { "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00" }
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
            { "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00" },
            { "project": "Internal", "start": "2026-11-03T10:06:00-05:00", "end": null }
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
            { "project": "Website Redesign", "start": "2026-11-03T23:00:00-05:00", "end": "2026-11-04T00:00:00-05:00" }
          ]
        }

        """)
        #expect(tracker.running?.project == "Website Redesign")
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
        { "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00" }
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

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

    private static let malformed = #"{ "date": "2026-11-03", "entries": [ { "project": "Internal", "start": "9am" } ] }"#

    private func write(_ text: String, _ date: String = "2026-11-03") {
        let url = dayFile(root, date)
        try! FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! text.write(to: url, atomically: true, encoding: .utf8)
    }
}

import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct DayFileTests {
    let clock = FakeClock("2026-11-03T09:02:11")
    let root = temporaryRoot()

    @Test func runningEntryIsWrittenWithANullEnd() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T09:02:11-05:00", "end": null }
          ]
        }

        """)
    }

    @Test func pausedEntriesAreWrittenClosedInOrder() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:47:30")
        try tracker.pause()
        clock.set("2026-11-03T13:15:00")
        try tracker.start("Website Redesign")

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T09:02:11-05:00", "end": "2026-11-03T10:47:30-05:00" },
            { "project": "Website Redesign", "start": "2026-11-03T13:15:00-05:00", "end": null }
          ]
        }

        """)
    }

    @Test func runningTimerSurvivesARelaunch() throws {
        try Tracker(clock: clock, storageRoot: root).start("Website Redesign")
        clock.set("2026-11-03T10:02:11")

        let relaunched = Tracker(clock: clock, storageRoot: root)
        #expect(relaunched.running?.project == "Website Redesign")
        #expect(relaunched.selectedProject == "Website Redesign")
        #expect(relaunched.total("Website Redesign", on: relaunched.today) == 3600)

        clock.set("2026-11-03T10:32:11")
        try relaunched.toggle()
        #expect(relaunched.running == nil)
        #expect(relaunched.total("Website Redesign", on: relaunched.today) == 90 * 60)
    }

    @Test func handWrittenFileRoundTripsThroughAWrite() throws {
        let original = """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T07:00:00-05:00", "end": "2026-11-03T08:00:00-05:00" },
            { "project": "Internal", "seconds": 900, "note": "manual" },
            { "project": "Website Redesign", "seconds": -600, "note": "adjustment" }
          ]
        }

        """
        try FileManager.default.createDirectory(
            at: dayFile(root, "2026-11-03").deletingLastPathComponent(), withIntermediateDirectories: true)
        try original.write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)

        let tracker = Tracker(clock: clock, storageRoot: root)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 50 * 60)
        #expect(tracker.total("Internal", on: tracker.today) == 15 * 60)

        try tracker.start("Internal")
        clock.set("2026-11-03T09:32:11")
        try tracker.pause()

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T07:00:00-05:00", "end": "2026-11-03T08:00:00-05:00" },
            { "project": "Internal", "seconds": 900, "note": "manual" },
            { "project": "Website Redesign", "seconds": -600, "note": "adjustment" },
            { "project": "Internal", "start": "2026-11-03T09:02:11-05:00", "end": "2026-11-03T09:32:11-05:00" }
          ]
        }

        """)
        #expect(tracker.total("Internal", on: tracker.today) == 45 * 60)
    }

    @Test func totalIsClampedAtZero() throws {
        try FileManager.default.createDirectory(
            at: dayFile(root, "2026-11-03").deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        { "date": "2026-11-03", "entries": [ { "project": "Internal", "seconds": -900, "note": "adjustment" } ] }
        """.write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)

        let tracker = Tracker(clock: clock, storageRoot: root)
        #expect(tracker.total("Internal", on: tracker.today) == 0)
    }
}

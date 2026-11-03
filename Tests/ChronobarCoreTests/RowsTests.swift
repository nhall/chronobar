import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct RowsTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func startingAnotherProjectPausesTheRunningOne() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.start("Internal")
        clock.set("2026-11-03T10:15:00")
        tracker.tick()

        #expect(tracker.running?.project == "Internal")
        #expect(tracker.total("Website Redesign", on: tracker.today) == 60 * 60)
        #expect(tracker.total("Internal", on: tracker.today) == 15 * 60)
        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00" },
            { "project": "Internal", "start": "2026-11-03T10:00:00-05:00", "end": null }
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
            Row(project: "Website Redesign", total: 60 * 60),
            Row(project: "Internal", total: 20 * 60),
        ])
    }
}

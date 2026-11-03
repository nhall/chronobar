import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct IdleTests {
    let root = temporaryRoot()

    @Test func removeEndsTheEntryAtTheIdleStartAndContinuesFromNow() throws {
        let clock = FakeClock("2026-11-03T13:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T15:00:00")
        try tracker.resolveIdle(since: clock.now - 50 * 60, choice: .remove)

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T13:00:00-05:00", "end": "2026-11-03T14:10:00-05:00" },
            { "project": "Website Redesign", "start": "2026-11-03T15:00:00-05:00", "end": null }
          ]
        }

        """)
        #expect(tracker.running?.project == "Website Redesign")
        #expect(tracker.running?.start == clock.now)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 70 * 60)
    }
}

import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct RolloverTests {
    let root = temporaryRoot()

    @Test func timerRunningAtMidnightSplitsIntoTheNewDay() throws {
        let clock = FakeClock("2026-11-03T23:30:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-04T00:15:00")
        tracker.tick()

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T23:30:00-05:00", "end": "2026-11-04T00:00:00-05:00" }
          ]
        }

        """)
        #expect(contents(dayFile(root, "2026-11-04")) == """
        {
          "date": "2026-11-04",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-04T00:00:00-05:00", "end": null }
          ]
        }

        """)
        #expect(tracker.today == Day(year: 2026, month: 11, day: 4))
        #expect(tracker.running?.project == "Website Redesign")
        #expect(tracker.running?.start == clock.now - 15 * 60)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 15 * 60)
    }
}

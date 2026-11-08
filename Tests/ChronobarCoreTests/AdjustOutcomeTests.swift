import Foundation
import Testing
import ChronobarCore

/// What an adjustment tells its caller it did: the Label as stored, the Day, and the Total before and after.
@MainActor @Suite struct AdjustOutcomeTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    /// A Tracker with an hour of Website Redesign today, from 7:00 to 8:00.
    func trackerWithAnHour() throws -> Tracker {
        try write(root, "2026-11-03", """
            { "project": "Website Redesign", "start": "2026-11-03T07:00:00-05:00", "end": "2026-11-03T08:00:00-05:00" }
        """)
        return Tracker(clock: clock, storageRoot: root)
    }

    @Test func aRelativeChangeReturnsTotalsFifteenMinutesApart() throws {
        let tracker = try trackerWithAnHour()

        let adjustment = try tracker.adjust("Website Redesign", "+15", on: tracker.today)

        #expect(adjustment == Adjustment(project: "Website Redesign", day: tracker.today,
                                         before: 60 * 60, after: 75 * 60))
        #expect(adjustment.change == 15 * 60)
    }

    @Test func anAdjustmentToTheCurrentTotalReturnsEqualTotalsAndWritesNothing() throws {
        let tracker = try trackerWithAnHour()
        let before = contents(dayFile(root, "2026-11-03"))

        let adjustment = try tracker.adjust("Website Redesign", "1:00", on: tracker.today)

        #expect(adjustment == Adjustment(project: "Website Redesign", day: tracker.today,
                                         before: 60 * 60, after: 60 * 60))
        #expect(adjustment.change == 0)
        #expect(contents(dayFile(root, "2026-11-03")) == before)
    }

    @Test func anAdjustmentReturnsTheRowsStoredSpellingNotTheTypedOne() throws {
        let tracker = try trackerWithAnHour()

        let adjustment = try tracker.adjust("  website redesign ", "1:30", on: tracker.today)

        #expect(adjustment.project == "Website Redesign")
        #expect(adjustment.after == 90 * 60)
    }

    /// A running timer's Total has a fraction of a second; the outcome shows it floored, as Chronobar does.
    @Test func totalsAreFlooredToWholeSeconds() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T09:10:00")
        clock.advance(0.6)

        let adjustment = try tracker.adjust("Website Redesign", "+5", on: tracker.today)

        #expect(adjustment.before == 10 * 60)
        #expect(adjustment.after == 15 * 60)
    }
}

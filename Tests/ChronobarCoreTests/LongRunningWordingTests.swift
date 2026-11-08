import Foundation
import Testing
import ChronobarCore

/// The Long-running warning as the user reads it, on Chronobar's calendar.
///
/// The test clock here is Tokyo time in `en_US_POSIX`, so its time zone differs from the test machine's
/// and the dates fall on Chronobar's Days rather than the Mac's. Its times put a narrow no-break space
/// (`\u{202F}`) before AM and PM.
@MainActor @Suite struct LongRunningWordingTests {
    let root = temporaryRoot()

    @Test func aRunStartedTodayNamesTheLabelTheHoursAndTheTime() throws {
        let clock = FakeClock("2026-11-04T09:00:00", timeZone: "Asia/Tokyo")
        let tracker = Tracker(clock: clock, storageRoot: root)
        tracker.longRunningThreshold = 2 * 3600
        try tracker.start("Website Redesign")

        clock.set("2026-11-04T11:00:00")
        let warning = try #require(tracker.tick().first)
        #expect(warning.title == "Website Redesign is still running")
        #expect(warning.body == "Running for over 2 hours, since 9:00\u{202F}AM. Stop it if it's done.")
    }

    /// Started at 22:00 Tokyo time and warned about at 02:00 the next morning: the start shows its date, so
    /// it isn't mistaken for this morning.
    @Test func aRunStartedOnAnotherDayShowsTheDate() throws {
        let clock = FakeClock("2026-11-03T22:00:00", timeZone: "Asia/Tokyo")
        let tracker = Tracker(clock: clock, storageRoot: root)
        tracker.longRunningThreshold = 4 * 3600
        try tracker.start("Client A, Ticket 665", source: .agent)

        clock.set("2026-11-04T02:00:00")
        let warning = try #require(tracker.tick().first)
        #expect(warning.title == "Client A, Ticket 665 is still running")
        #expect(warning.body
                == "Running for over 4 hours, since Nov 3, 2026 at 10:00\u{202F}PM. Stop it if it's done.")
    }
}

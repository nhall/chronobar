import Foundation
import Testing
import ChronobarCore

/// What VoiceOver announces after the global shortcut, which works from any app.
@MainActor @Suite struct ShortcutAnnouncementTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    /// The shortcut opens the Panel and touches no timer, so it says so and reads what the Pill shows.
    @Test func itAnnouncesThePanelWithWhatRuns() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.start("Internal")
        clock.advance(30 * 60)
        tracker.tick()

        #expect(ShortcutAnnouncement.text(tracker: tracker) == "Panel opened. 2 timers running, 1 hour today")
    }

    @Test func withNothingRunningItAnnouncesThePanelAndTodaysTotal() {
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(ShortcutAnnouncement.text(tracker: tracker) == "Panel opened. Nothing running, 0 minutes today")
    }
}

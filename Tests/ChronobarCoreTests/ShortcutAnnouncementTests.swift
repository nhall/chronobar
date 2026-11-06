import Foundation
import Testing
import ChronobarCore

/// What VoiceOver announces after the global shortcut, which otherwise acts without a sound.
@MainActor @Suite struct ShortcutAnnouncementTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func pausingAnnouncesWhichProjectPaused() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.advance(60)
        let before = tracker.timers

        try tracker.pause()

        #expect(ShortcutAnnouncement.text(for: .pauseTimers, before: before, after: tracker)
            == "Paused Website Redesign")
    }

    @Test func pausingSeveralAnnouncesHowManyPaused() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.start("Internal")
        let before = tracker.timers

        try tracker.pause()

        #expect(ShortcutAnnouncement.text(for: .pauseTimers, before: before, after: tracker)
            == "Paused 2 timers")
    }

    /// With nothing running the shortcut opens the ＋ form instead.
    @Test func withNothingRunningItAnnouncesTheNewProjectForm() {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let action = PillClick.square(tracker: tracker)

        #expect(ShortcutAnnouncement.text(for: action, before: tracker.timers, after: tracker) == "New Project")
    }

    /// Archiving the running Project leaves its timer running for the shortcut to pause.
    @Test func pausingAnArchivedProjectAnnouncesItPaused() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.archiveProject("Website Redesign")
        let before = tracker.timers

        try tracker.pause()

        #expect(ShortcutAnnouncement.text(for: .pauseTimers, before: before, after: tracker)
            == "Paused Website Redesign")
    }
}

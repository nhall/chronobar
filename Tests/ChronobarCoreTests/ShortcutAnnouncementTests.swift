import Foundation
import Testing
import ChronobarCore

/// What VoiceOver announces after the global shortcut, which otherwise acts without a sound.
@MainActor @Suite struct ShortcutAnnouncementTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func startingTheSelectedProjectAnnouncesItStarted() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.advance(60)
        try tracker.pause()
        let before = tracker.running

        try tracker.toggle()

        #expect(ShortcutAnnouncement.text(for: .toggleTimer, before: before, after: tracker)
            == "Started Website Redesign")
    }

    @Test func pausingAnnouncesWhichProjectPaused() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.advance(60)
        let before = tracker.running

        try tracker.toggle()

        #expect(ShortcutAnnouncement.text(for: .toggleTimer, before: before, after: tracker)
            == "Paused Website Redesign")
    }

    /// With no Selected Project the shortcut opens the ＋ form instead.
    @Test func withNoSelectedProjectItAnnouncesTheNewProjectForm() {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let action = PillClick.square(tracker: tracker)

        #expect(ShortcutAnnouncement.text(for: action, before: nil, after: tracker) == "New Project")
    }

    /// Core refuses to start a timer while today's file is malformed; the shortcut beeps instead.
    @Test func aRefusedStartAnnouncesNothing() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.pause()
        try "{ not json".write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        tracker.reload()
        let before = tracker.running

        #expect(throws: (any Error).self) { try tracker.toggle() }

        #expect(ShortcutAnnouncement.text(for: .toggleTimer, before: before, after: tracker) == nil)
    }

    /// Archiving the running Project clears the selection and leaves its timer running for the shortcut
    /// to pause.
    @Test func pausingAnArchivedProjectAnnouncesItPaused() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.archiveProject("Website Redesign")
        let before = tracker.running

        try tracker.toggle()

        #expect(ShortcutAnnouncement.text(for: .toggleTimer, before: before, after: tracker)
            == "Paused Website Redesign")
    }
}

import Foundation
import Testing
import ChronobarCore

/// A start or added Entry whose Day file can't be saved changes nothing: no timer paused, no Project taken
/// off `archived.txt`.
@MainActor @Suite struct FailedWriteTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    /// Makes the `days` folder read-only, so no Day file can be saved, until `writable()`.
    private func readOnlyDays() throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: days.path)
    }

    private func writable() {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: days.path)
    }

    private var days: URL { root.appendingPathComponent("days") }

    @Test func aStartThatCantBeSavedLeavesTheArchivedListAlone() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.archiveProject("Internal")
        try readOnlyDays()
        defer { writable() }

        #expect(throws: (any Error).self) { try tracker.start("Internal") }

        #expect(contents(archivedFile(root)) == "Internal\n")
        #expect(tracker.archived == ["Internal"])
    }

    @Test func aStartThatCantBeSavedLeavesTheOtherTimersRunning() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        tracker.startPausesOthers = true
        let before = contents(dayFile(root, "2026-11-03"))
        try readOnlyDays()
        defer { writable() }
        clock.set("2026-11-03T10:00:00")

        #expect(throws: (any Error).self) { try tracker.start("Internal") }

        #expect(tracker.timers.map(\.project) == ["Website Redesign"])
        #expect(contents(dayFile(root, "2026-11-03")) == before)
    }

    @Test func anEntryThatCantBeSavedLeavesTheArchivedListAlone() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.archiveProject("Internal")
        clock.set("2026-11-03T12:00:00")
        try readOnlyDays()
        defer { writable() }

        #expect(throws: (any Error).self) {
            try tracker.addEntry("Internal", start: clock.date("2026-11-03T10:00:00"), end: clock.date("2026-11-03T11:00:00"))
        }

        #expect(contents(archivedFile(root)) == "Internal\n")
        #expect(tracker.archived == ["Internal"])
    }
}

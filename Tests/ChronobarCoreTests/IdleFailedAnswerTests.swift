import Foundation
import Testing
import ChronobarCore

/// An answer to the idle question whose removal can't be saved still answers it: the alert isn't shown
/// again for the same Idle time, as it would be every second while the timer runs.
@MainActor @Suite struct IdleFailedAnswerTests {
    let root = temporaryRoot()

    /// Makes the `days` folder read-only, so no Day file can be saved, until `writable()`.
    private func readOnlyDays() throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: days.path)
    }

    private func writable() {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: days.path)
    }

    private var days: URL { root.appendingPathComponent("days") }

    @Test func aRemovalThatCantBeSavedIsNotAskedAgain() throws {
        let clock = FakeClock("2026-11-03T13:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T14:00:00")
        tracker.reportAway()
        clock.set("2026-11-03T14:30:00")
        tracker.reportBack()
        let question = try #require(tracker.takeIdleQuestion())
        try readOnlyDays()
        defer { writable() }

        #expect(throws: (any Error).self) {
            try tracker.resolveIdle(since: question.since, until: question.until, choice: .remove)
        }

        clock.advance(1)
        tracker.tick()
        #expect(tracker.takeIdleQuestion() == nil)
        writable()
        clock.advance(1)
        tracker.tick()
        #expect(tracker.takeIdleQuestion() == nil)
        #expect(tracker.timers.map(\.project) == ["Website Redesign"])
    }
}

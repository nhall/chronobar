import Foundation
import Testing
import ChronobarCore

/// The idle alert as the user reads it: the question's message on Chronobar's calendar, the three
/// buttons, and the refusal when a malformed Day stops the removal.
///
/// The test clock's calendar is New York time in `en_US_POSIX`, whose times put a narrow no-break space
/// (`\u{202F}`) before AM and PM.
@MainActor @Suite struct IdleWordingTests {
    let root = temporaryRoot()

    @Test func idleTimeRunningUpToNowSaysSinceWhenAndThatTheTimerIsStillRunning() throws {
        let clock = FakeClock("2026-11-03T13:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T14:10:00")
        tracker.reportAway()
        clock.set("2026-11-03T14:30:00")
        tracker.reportBack()

        let question = try #require(tracker.takeIdleQuestion())
        #expect(question.message == "You've been idle since 2:10\u{202F}PM. Website Redesign is still running.")
    }

    /// Shortly after midnight in Tokyo: the time is on Chronobar's today in its own time zone, whatever the
    /// Mac's.
    @Test func timesAreOnChronobarsTimeZoneAndToday() throws {
        let clock = FakeClock("2026-11-04T00:05:00", timeZone: "Asia/Tokyo")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-04T00:10:00")
        tracker.reportAway()
        clock.set("2026-11-04T00:30:00")
        tracker.reportBack()

        let question = try #require(tracker.takeIdleQuestion())
        #expect(question.message == "You've been idle since 12:10\u{202F}AM. Website Redesign is still running.")
    }

    @Test func twoTimersAreNamedTogether() throws {
        let clock = FakeClock("2026-11-03T13:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.start("Internal")
        clock.set("2026-11-03T14:10:00")
        tracker.reportAway()
        clock.set("2026-11-03T14:30:00")
        tracker.reportBack()

        let question = try #require(tracker.takeIdleQuestion())
        #expect(question.message
                == "You've been idle since 2:10\u{202F}PM. Website Redesign and Internal are still running.")
    }

    /// Crashed at about 11:00 with the Heartbeat; the timer was stopped after relaunching, before the alert.
    @Test func withNoTimerRunningItNamesNone() throws {
        let settings = TestSettings()
        defer { settings.remove() }
        let clock = FakeClock("2026-11-03T09:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:59:00")
        tracker.heartbeat()

        clock.set("2026-11-03T13:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
        relaunched.recoverAfterLaunch()
        try relaunched.pause()

        let question = try #require(relaunched.takeIdleQuestion())
        #expect(question.message == "You've been idle since 10:59\u{202F}AM.")
    }

    /// Away from 22:30 on 2026-11-03 until 08:00 on 2026-11-05, with the Day between malformed at first:
    /// asked again once it parses, ending where the refusal was answered.
    @Test func idleTimeThatEndedEarlierSaysFromWhenToWhenWithTheDateOnAnotherDay() throws {
        let clock = FakeClock("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T22:30:00")
        tracker.reportAway()
        clock.set("2026-11-05T08:00:00")
        tracker.tick()
        let good = try #require(contents(dayFile(root, "2026-11-04")))
        try "{ oops".write(to: dayFile(root, "2026-11-04"), atomically: true, encoding: .utf8)
        tracker.reportBack()
        let question = try #require(tracker.takeIdleQuestion())
        _ = try? tracker.resolveIdle(since: question.since, until: question.until, choice: .remove)
        try good.write(to: dayFile(root, "2026-11-04"), atomically: true, encoding: .utf8)
        clock.set("2026-11-05T08:10:00")
        tracker.tick()

        let again = try #require(tracker.takeIdleQuestion())
        #expect(again.message == "You were idle from Nov 3, 2026 at 10:30\u{202F}PM to 8:00\u{202F}AM. "
                + "Website Redesign is running.")
    }

    @Test func theButtonsAreRemoveRemoveAndStopAndKeep() {
        #expect(IdleChoice.remove.title == "Remove idle time")
        #expect(IdleChoice.removeAndStop.title == "Remove & stop")
        #expect(IdleChoice.keep.title == "Keep")
    }

    @Test func aRefusedRemovalNamesTheDayAndItsFile() throws {
        let clock = FakeClock("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T22:30:00")
        tracker.reportAway()
        clock.set("2026-11-05T08:00:00")
        tracker.tick()
        try "{ oops".write(to: dayFile(root, "2026-11-04"), atomically: true, encoding: .utf8)
        tracker.reportBack()
        let question = try #require(tracker.takeIdleQuestion())
        let error = try #require(throws: MalformedDayFile.self) {
            try tracker.resolveIdle(since: question.since, until: question.until, choice: .remove)
        }

        let refusal = tracker.idleRefusal(error)
        #expect(refusal.title == "The idle time wasn't removed")
        #expect(refusal.text == "The file for Wednesday, November 4, 2026 (days/2026-11-04.json) can't be read, "
                + "so it can't be changed. Fix it by hand in the data folder and you'll be asked again. Until "
                + "then the idle time still counts.")
    }
}

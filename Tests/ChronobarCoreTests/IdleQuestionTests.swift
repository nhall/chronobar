import Foundation
import Testing
import ChronobarCore

/// When Core asks about Idle time: the reports the app sends (away, back, input inactivity), folded with
/// the Idle time Core holds after a crash or a refused removal, into at most one idle question at a time.
@MainActor @Suite struct IdleQuestionTests {
    let root = temporaryRoot()

    @Test func sleepThenLockThenWakeAsksAboutTheTimeSinceTheSleep() throws {
        let clock = FakeClock("2026-11-03T13:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T14:00:00")
        tracker.reportAway()
        clock.set("2026-11-03T14:05:00")
        tracker.reportAway()
        clock.set("2026-11-03T14:30:00")
        tracker.reportBack()

        let question = try #require(tracker.takeIdleQuestion())
        #expect(question.since == clock.date("2026-11-03T14:00:00"))
        #expect(question.until == nil)
        #expect(question.labels == ["Website Redesign"])
    }

    @Test func goingAwayWithOnlyAgentsTimersRunningAsksNothing() throws {
        let clock = FakeClock("2026-11-03T13:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal", source: .agent)
        clock.set("2026-11-03T14:00:00")
        tracker.reportAway()
        clock.set("2026-11-03T14:30:00")
        tracker.reportBack()

        #expect(tracker.takeIdleQuestion() == nil)
    }

    @Test func inputInactivityPastTheThresholdAsksAboutTheTimeSinceTheLastInput() throws {
        let clock = FakeClock("2026-11-03T13:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        tracker.idleThreshold = 15 * 60
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T14:30:00")
        tracker.reportInput(idleFor: 14 * 60)
        #expect(tracker.takeIdleQuestion() == nil)
        tracker.reportInput(idleFor: 20 * 60)

        let question = try #require(tracker.takeIdleQuestion())
        #expect(question.since == clock.date("2026-11-03T14:10:00"))
        #expect(question.until == nil)
        #expect(question.labels == ["Website Redesign"])
    }

    @Test func inputInactivityWithTheThresholdOffAsksNothing() throws {
        let clock = FakeClock("2026-11-03T13:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        tracker.idleThreshold = nil
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T16:00:00")
        tracker.reportInput(idleFor: 2 * 3600)

        #expect(tracker.takeIdleQuestion() == nil)
    }

    @Test func whileAQuestionIsOutANewReportAsksNoSecond() throws {
        let clock = FakeClock("2026-11-03T13:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T14:00:00")
        tracker.reportAway()
        clock.set("2026-11-03T14:30:00")
        tracker.reportBack()
        let question = try #require(tracker.takeIdleQuestion())

        tracker.reportAway()
        clock.set("2026-11-03T15:00:00")
        tracker.reportBack()
        #expect(tracker.takeIdleQuestion() == nil)

        try tracker.resolveIdle(since: question.since, until: question.until, choice: .remove)
        #expect(tracker.takeIdleQuestion() == nil)
    }

    @Test func afterKeepNothingIsAskedUntilANewReport() throws {
        let clock = FakeClock("2026-11-03T13:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        tracker.idleThreshold = 15 * 60
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T14:30:00")
        tracker.reportInput(idleFor: 20 * 60)
        let question = try #require(tracker.takeIdleQuestion())
        try tracker.resolveIdle(since: question.since, until: question.until, choice: .keep)
        clock.advance(1)
        tracker.tick()
        #expect(tracker.takeIdleQuestion() == nil)

        clock.set("2026-11-03T15:00:00")
        tracker.reportInput(idleFor: 16 * 60)
        let next = try #require(tracker.takeIdleQuestion())
        #expect(next.since == clock.date("2026-11-03T14:44:00"))
        #expect(tracker.total("Website Redesign", on: tracker.today) == 2 * 3600)
    }

    /// Away from 22:30 on 2026-11-03 until 08:00 on 2026-11-05, with the Day between malformed at first.
    @Test func aRemovalRefusedByAMalformedDayIsAskedAgainOnceItParsesEndingWhereItWasAnswered() throws {
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
        #expect(throws: MalformedDayFile(day: Day("2026-11-04")!)) {
            try tracker.resolveIdle(since: question.since, until: question.until, choice: .remove)
        }

        clock.set("2026-11-05T08:05:00")
        tracker.tick()
        #expect(tracker.takeIdleQuestion() == nil)

        try good.write(to: dayFile(root, "2026-11-04"), atomically: true, encoding: .utf8)
        clock.set("2026-11-05T08:10:00")
        tracker.tick()
        let again = try #require(tracker.takeIdleQuestion())
        #expect(again == IdleQuestion(since: clock.date("2026-11-03T22:30:00"),
                                      until: clock.date("2026-11-05T08:00:00"), labels: ["Website Redesign"]))
        #expect(tracker.takeIdleQuestion() == nil)

        try tracker.resolveIdle(since: again.since, until: again.until, choice: .keep)
        #expect(tracker.takeIdleQuestion() == nil)
    }

    @Test func aReportWhileARemovalIsBlockedAsksNothingUntilTheFileParses() throws {
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

        clock.set("2026-11-05T09:00:00")
        tracker.reportAway()
        clock.set("2026-11-05T09:30:00")
        tracker.reportBack()
        #expect(tracker.takeIdleQuestion() == nil)

        try good.write(to: dayFile(root, "2026-11-04"), atomically: true, encoding: .utf8)
        tracker.tick()
        let again = try #require(tracker.takeIdleQuestion())
        #expect(again == IdleQuestion(since: clock.date("2026-11-03T22:30:00"), until: nil,
                                      labels: ["Website Redesign"]))
    }

    @Test func idleTimeReportedForATimerStoppedBeforeTheAlertIsNeverAskedAbout() throws {
        let clock = FakeClock("2026-11-03T13:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T14:00:00")
        tracker.reportAway()
        clock.set("2026-11-03T14:30:00")
        tracker.reportBack()
        try tracker.pause()
        #expect(tracker.takeIdleQuestion() == nil)

        clock.set("2026-11-03T15:00:00")
        try tracker.start("Internal")
        #expect(tracker.takeIdleQuestion() == nil)
    }

    /// Crashed at about 11:00 with the Heartbeat, then slept from 13:10 to 13:40 before the alert.
    @Test func aWakeFoldedWithIdleTimeHeldAfterACrashGivesOneQuestionFromTheEarlierStart() throws {
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
        clock.set("2026-11-03T13:10:00")
        relaunched.reportAway()
        clock.set("2026-11-03T13:40:00")
        relaunched.reportBack()

        let question = try #require(relaunched.takeIdleQuestion())
        #expect(question == IdleQuestion(since: clock.date("2026-11-03T10:59:00"), until: nil,
                                         labels: ["Website Redesign"]))
        try relaunched.resolveIdle(since: question.since, until: question.until, choice: .removeAndStop)
        #expect(relaunched.takeIdleQuestion() == nil)
        #expect(relaunched.total("Website Redesign", on: relaunched.today) == 119 * 60)
    }

    /// As in the recovery suite: an Entry left open in a malformed Day is found once the file parses while
    /// another timer runs, and closed at midnight, so the Idle time it holds ends there. Input inactivity
    /// that runs up to now then wins.
    @Test func idleTimeRunningUpToNowWinsOverIdleTimeThatEndedEarlier() throws {
        let settings = TestSettings()
        defer { settings.remove() }
        let clock = FakeClock("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T23:30:00")
        tracker.heartbeat()
        let good = try #require(contents(dayFile(root, "2026-11-03")))
        try "{ oops".write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)

        clock.set("2026-11-05T09:00:00")
        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: settings.fresh())
        relaunched.idleThreshold = 15 * 60
        relaunched.recoverAfterLaunch()
        try relaunched.start("Internal")
        try good.write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        clock.set("2026-11-05T10:00:00")
        relaunched.reload()
        _ = relaunched.weekTotals(containing: relaunched.today)
        relaunched.reportInput(idleFor: 20 * 60)

        let question = try #require(relaunched.takeIdleQuestion())
        #expect(question == IdleQuestion(since: clock.date("2026-11-03T23:30:00"), until: nil, labels: ["Internal"]))
    }

    /// Crashed at about 11:00 with the Heartbeat; the timer was stopped after relaunching, before the alert.
    @Test func afterACrashWithNoTimerRunningTheHeldIdleTimeIsStillAskedAbout() throws {
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
        #expect(question == IdleQuestion(since: clock.date("2026-11-03T10:59:00"), until: nil, labels: []))
    }
}

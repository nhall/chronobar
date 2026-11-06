import Foundation
import Testing
import ChronobarCore
import ChronobarOperations

/// `start`: an `agent` timer, echoed as stored, leaving other timers alone.
@MainActor @Suite struct StartTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func startingALabelRecordsAnAgentTimerAndEchoesIt() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let operations = Operations(tracker: tracker)

        let started = try operations.start("Website Redesign")

        #expect(started.timer == TimerResult(label: "Website Redesign", start: clock.date("2026-11-03T09:00:00"),
                                             source: .agent, totalSeconds: 0))
        #expect(!started.alreadyRunning)
        #expect(started.paused.isEmpty)
        #expect(contents(dayFile(root, "2026-11-03")).contains(
            #"{ "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": null, "source": "agent" }"#))
        #expect(tracker.timers.map(\.source) == [.agent])
    }

    @Test func startingARunningLabelKeepsItsTimerAndSaysSo() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T09:30:00")

        let started = try Operations(tracker: tracker).start("website redesign ")

        #expect(started.alreadyRunning)
        #expect(started.timer == TimerResult(label: "Website Redesign", start: clock.date("2026-11-03T09:00:00"),
                                             source: .app, totalSeconds: 30 * 60))
        #expect(tracker.timers.count == 1)
    }

    @Test func startingLeavesOtherTimersRunning() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        clock.set("2026-11-03T09:30:00")

        let started = try Operations(tracker: tracker).start("Website Redesign")

        #expect(started.paused.isEmpty)
        #expect(tracker.timers.map(\.project) == ["Internal", "Website Redesign"])
        #expect(started.today == DayResult(date: "2026-11-03", totalSeconds: 30 * 60, elapsedSeconds: 30 * 60))
    }

    @Test func withPausesTheOthersOnStartingEchoesTheEntriesItClosed() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        tracker.startPausesOthers = true
        try tracker.start("Internal")
        clock.set("2026-11-03T09:30:00")

        let started = try Operations(tracker: tracker).start("Website Redesign")

        #expect(started.paused == [
            EntryResult(label: "Internal", start: clock.date("2026-11-03T09:00:00"),
                        end: clock.date("2026-11-03T09:30:00"), source: .app, totalSeconds: 30 * 60),
        ])
        #expect(tracker.timers.map(\.project) == ["Website Redesign"])
    }

    @Test func aBlankLabelIsRefused() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)

        let error = Operations(tracker: tracker).perform(.start(label: "   ")).error

        #expect(error?.kind == .invalidLabel)
        #expect(tracker.timers.isEmpty)
    }

    @Test func aMalformedDayFileRefusesTheStart() throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent("days"), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: dayFile(root, "2026-11-03"))
        let tracker = Tracker(clock: clock, storageRoot: root)

        let error = Operations(tracker: tracker).perform(.start(label: "Website Redesign")).error

        #expect(error?.kind == .malformedFile)
        #expect(error?.message.contains("days/2026-11-03.json") == true)
        #expect(contents(dayFile(root, "2026-11-03")) == "not json")
    }
}

import Foundation
import Testing
import ChronobarCore
import ChronobarOperations

/// `stop`: a named timer, or with no Label the only running one; otherwise an error listing the timers.
@MainActor @Suite struct StopTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func stoppingALabelClosesItsEntryAndEchoesIt() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let operations = Operations(tracker: tracker)
        _ = try operations.start("Website Redesign")
        try tracker.start("Internal")
        clock.set("2026-11-03T10:15:00")

        let stopped = try operations.stop("website redesign")

        #expect(stopped.entry == EntryResult(label: "Website Redesign", start: clock.date("2026-11-03T09:00:00"),
                                             end: clock.date("2026-11-03T10:15:00"), source: .agent,
                                             totalSeconds: 75 * 60))
        #expect(stopped.running.map(\.label) == ["Internal"])
        #expect(stopped.today == DayResult(date: "2026-11-03", totalSeconds: 150 * 60, totalMinutes: 150, elapsedSeconds: 75 * 60, elapsedMinutes: 75))
        #expect(contents(dayFile(root, "2026-11-03")).contains(
            #""start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:15:00-05:00", "source": "agent" }"#))
        #expect(tracker.timers.map(\.project) == ["Internal"])
    }

    @Test func theTotalCountsEarlierEntriesForTheLabel() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let operations = Operations(tracker: tracker)
        _ = try operations.start("Website Redesign")
        clock.set("2026-11-03T09:30:00")
        _ = try operations.stop("Website Redesign")
        clock.set("2026-11-03T13:00:00")
        _ = try operations.start("Website Redesign")
        clock.set("2026-11-03T13:10:00")

        #expect(try operations.stop().entry.totalSeconds == 40 * 60)
    }

    @Test func withNoLabelStopTakesTheOnlyRunningTimer() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        clock.set("2026-11-03T09:20:00")

        let stopped = try Operations(tracker: tracker).stop()

        #expect(stopped.entry.label == "Internal")
        #expect(stopped.entry.source == .app)
        #expect(stopped.running.isEmpty)
        #expect(tracker.timers.isEmpty)
    }

    @Test func withNoLabelAndSeveralRunningStopFailsListingThemAndStopsNothing() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        clock.set("2026-11-03T09:20:00")
        try tracker.start("Website Redesign", source: .agent)

        let error = try #require(Operations(tracker: tracker).perform(.stop(label: nil)).error)

        #expect(error.kind == .ambiguous)
        #expect(error.running?.map(\.label) == ["Internal", "Website Redesign"])
        #expect(error.message.contains("Internal") && error.message.contains("Website Redesign"))
        #expect(tracker.timers.count == 2)
    }

    @Test func withNoLabelAndNothingRunningStopFails() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)

        let error = try #require(Operations(tracker: tracker).perform(.stop(label: nil)).error)

        #expect(error.kind == .nothingRunning)
        #expect(error.running == [])
    }

    @Test func stoppingALabelThatIsNotRunningFailsListingTheRunningOnes() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")

        let error = try #require(Operations(tracker: tracker).perform(.stop(label: "Website Redesign")).error)

        #expect(error.kind == .notRunning)
        #expect(error.running?.map(\.label) == ["Internal"])
        #expect(tracker.timers.count == 1)
    }

    @Test func aBlankLabelIsRefused() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")

        let error = Operations(tracker: tracker).perform(.stop(label: " ")).error

        #expect(error?.kind == .invalidLabel)
        #expect(tracker.timers.count == 1)
    }
}

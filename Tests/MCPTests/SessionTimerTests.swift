import Foundation
import Testing
import MCP
import ChronobarCore
import ChronobarOperations
@testable import ChronobarCLI

/// "Stop the timer": `stop` and `set_start` without a Label act on the timer this session started, and
/// with several or none running, ask by listing the running timers.
@MainActor @Suite struct SessionTimerTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func stopWithoutALabelStopsTheTimerThisSessionStarted() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        let mcp = session(Operations(tracker: tracker), clock)
        _ = try mcp.result("start", ["label": "Website Redesign"])
        clock.set("2026-11-03T10:00:00")

        let stopped = try mcp.result("stop")

        #expect(stopped["entry"]?.objectValue?["label"] == "Website Redesign")
        #expect(tracker.timers.map(\.project) == ["Internal"])
    }

    @Test func setStartWithoutALabelMovesTheTimerThisSessionStarted() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        let mcp = session(Operations(tracker: tracker), clock)
        _ = try mcp.result("start", ["label": "Website Redesign"])
        clock.set("2026-11-03T10:00:00")

        let moved = try mcp.result("set_start", ["at": "2026-11-03T08:45:00-05:00"])

        #expect(moved["timer"]?.objectValue?["label"] == "Website Redesign")
        #expect(moved["timer"]?.objectValue?["start"] == "2026-11-03T08:45:00-05:00")
    }

    @Test func withSeveralOfItsTimersRunningStopAsksListingTheRunningTimers() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        let mcp = session(Operations(tracker: tracker), clock)
        _ = try mcp.result("start", ["label": "Website Redesign"])
        _ = try mcp.result("start", ["label": "Client A, Ticket 665"])

        let error = try #require(mcp.error("stop"))

        #expect(error.kind == "ambiguous")
        #expect(error.running == ["Internal", "Website Redesign", "Client A, Ticket 665"])
        #expect(error.text.contains("Website Redesign, Client A, Ticket 665"))
        #expect(tracker.timers.count == 3)
    }

    @Test func withNoneOfItsTimersRunningStopAsksListingTheRunningTimers() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        let mcp = session(Operations(tracker: tracker), clock)

        let error = try #require(mcp.error("stop"))

        #expect(error.kind == "no_session_timer")
        #expect(error.running == ["Internal"])
        #expect(error.text.contains("Internal"))
        #expect(tracker.timers.map(\.project) == ["Internal"])
    }

    @Test func withNothingRunningStopSaysSo() throws {
        let mcp = session(Operations(tracker: Tracker(clock: clock, storageRoot: root)), clock)

        let error = try #require(mcp.error("set_start", ["at": "2026-11-03T08:45:00-05:00"]))

        #expect(error.kind == "nothing_running")
        #expect(error.running == [])
    }

    @Test func aTimerStoppedElsewhereIsNoLongerTheSessionsDefault() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let mcp = session(Operations(tracker: tracker), clock)
        _ = try mcp.result("start", ["label": "Website Redesign"])
        _ = try mcp.result("start", ["label": "Client A, Ticket 665"])
        try tracker.pause("Website Redesign")

        let stopped = try mcp.result("stop")

        #expect(stopped["entry"]?.objectValue?["label"] == "Client A, Ticket 665")
    }

    @Test func aTimerTheSessionStoppedIsNoLongerItsDefault() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let mcp = session(Operations(tracker: tracker), clock)
        _ = try mcp.result("start", ["label": "Website Redesign"])
        _ = try mcp.result("stop")
        // Started again from the Panel: the user's timer now, not the session's.
        try tracker.start("Website Redesign")

        #expect(mcp.error("stop")?.kind == "no_session_timer")
    }

    /// A start that found the Label already running didn't start it, so the timer stays someone else's.
    @Test func startingALabelThatAlreadyRunsDoesNotMakeItTheSessions() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        let mcp = session(Operations(tracker: tracker), clock)
        _ = try mcp.result("start", ["label": "internal"])

        #expect(mcp.error("stop")?.kind == "no_session_timer")
        #expect(tracker.timers.map(\.project) == ["Internal"])
    }

    /// Starting its own running timer again keeps it the session's.
    @Test func startingItsOwnRunningTimerAgainKeepsItTheSessions() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let mcp = session(Operations(tracker: tracker), clock)
        _ = try mcp.result("start", ["label": "Internal"])
        _ = try mcp.result("start", ["label": "internal"])

        #expect(try mcp.result("stop")["entry"]?.objectValue?["label"] == "Internal")
    }

    @Test func eachSessionDefaultsToItsOwnTimer() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let operations = Operations(tracker: tracker)
        let first = session(operations, clock), second = session(operations, clock)
        _ = try first.result("start", ["label": "Website Redesign"])
        _ = try second.result("start", ["label": "Client A, Ticket 665"])

        #expect(try second.result("stop")["entry"]?.objectValue?["label"] == "Client A, Ticket 665")
        #expect(try first.result("stop")["entry"]?.objectValue?["label"] == "Website Redesign")
    }

    @Test func aSessionCanStopAnyTimerByName() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        let mcp = session(Operations(tracker: tracker), clock)

        #expect(try mcp.result("stop", ["label": "Internal"])["entry"]?.objectValue?["label"] == "Internal")
        #expect(tracker.timers.isEmpty)
    }

    // MARK: Relabeled timers

    @Test func aTimerTheSessionStartedAndThenRelabeledIsStillItsOwn() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        let mcp = session(Operations(tracker: tracker), clock)
        _ = try mcp.result("start", ["label": "Northwnd"])
        clock.set("2026-11-03T10:00:00")
        let relabeled = try mcp.result("relabel", ["label": "northwnd", "new_label": "Northwind"])
        #expect(relabeled["timer"]?.objectValue?["label"] == "Northwind")

        let moved = try mcp.result("set_start", ["at": "2026-11-03T08:45:00-05:00"])
        let stopped = try mcp.result("stop")

        #expect(moved["timer"]?.objectValue?["label"] == "Northwind")
        #expect(stopped["entry"]?.objectValue?["label"] == "Northwind")
        #expect(tracker.timers.map(\.project) == ["Internal"])
    }

    @Test func aCapitalisationFixTheSessionMadeKeepsItsTimerItsOwn() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        let mcp = session(Operations(tracker: tracker), clock)
        _ = try mcp.result("start", ["label": "northwind"])
        _ = try mcp.result("relabel", ["label": "northwind", "new_label": "Northwind"])

        #expect(try mcp.result("stop")["entry"]?.objectValue?["label"] == "Northwind")
    }

    @Test func relabelingSomeoneElsesTimerDoesNotMakeItTheSessions() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Northwnd")
        let mcp = session(Operations(tracker: tracker), clock)
        _ = try mcp.result("relabel", ["label": "Northwnd", "new_label": "Northwind"])

        #expect(mcp.error("stop")?.kind == "no_session_timer")
        #expect(tracker.timers.map(\.project) == ["Northwind"])
    }

    @Test func aTimerRelabeledOutsideTheSessionIsNoLongerItsOwn() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let operations = Operations(tracker: tracker)
        let mcp = session(operations, clock), other = session(operations, clock)
        _ = try mcp.result("start", ["label": "Northwnd"])
        _ = try mcp.result("start", ["label": "Website Redsign"])
        try tracker.relabel("Northwnd", to: "Northwind", on: tracker.today)
        _ = try other.result("relabel", ["label": "Website Redsign", "new_label": "Website Redesign"])

        #expect(mcp.error("stop")?.kind == "no_session_timer")
        // Started again under the old Label from the Panel: the user's timer, not the session's.
        try tracker.start("Northwnd")
        #expect(mcp.error("stop")?.kind == "no_session_timer")
        #expect(tracker.timers.map(\.project) == ["Northwind", "Website Redesign", "Northwnd"])
    }

    @Test func closingTheSessionLeavesItsTimersRunning() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let operations = Operations(tracker: tracker)
        do {
            let mcp = session(operations, clock)
            _ = try mcp.result("start", ["label": "Website Redesign"])
        }
        clock.set("2026-11-03T10:00:00")

        let status = try session(operations, clock).result("status")

        #expect(status["timers"]?.arrayValue?.first?.objectValue?["label"] == "Website Redesign")
        #expect(status["timers"]?.arrayValue?.first?.objectValue?["total_seconds"] == .int(60 * 60))
    }
}

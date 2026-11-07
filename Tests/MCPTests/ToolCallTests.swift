import Foundation
import Testing
import MCP
import ChronobarCore
import ChronobarOperations
@testable import ChronobarCLI

/// A tool call is the operation of the same name, its arguments the request's keys. The result carries the
/// operation's result as structured content; a refusal is a tool error with the message and, where it helps,
/// the running timers.
@MainActor @Suite struct ToolCallTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func aToolResultCarriesTheOperationsResult() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let mcp = session(Operations(tracker: tracker), clock)

        let started = try mcp.result("start", ["label": "Website Redesign"])

        #expect(started["timer"] == ["label": "Website Redesign", "start": "2026-11-03T09:00:00-05:00",
                                     "source": "agent", "total_seconds": 0])
        #expect(started["already_running"] == false)
        #expect(started["today"] == ["date": "2026-11-03", "total_seconds": 0, "elapsed_seconds": 0])
        #expect(tracker.timers.map(\.project) == ["Website Redesign"])
    }

    @Test func weekGivesEachLabelsTotalForTheWeek() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "2:00", on: Day(year: 2026, month: 11, day: 1))
        try tracker.log("Website Redesign", "0:30", on: tracker.today)
        let mcp = session(Operations(tracker: tracker), clock)

        let week = try mcp.result("week", ["date": "2026-11-03"])

        #expect(week["labels"] == [["label": "Website Redesign", "total_seconds": 9000]])
        #expect(week["first"] == "2026-11-01")
    }

    @Test func theTextGivesTheExactResultToo() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let mcp = session(Operations(tracker: tracker), clock)

        let result = mcp.call("start", arguments: ["label": "Website Redesign"])

        #expect(result.isError != true)
        #expect(result.content.contains { content in
            guard case .text(let text, _, _) = content else { return false }
            return text.contains(#""start":"2026-11-03T09:00:00-05:00""#)
        })
    }

    @Test func timesAreGivenAsISO8601() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let mcp = session(Operations(tracker: tracker), clock)
        _ = try mcp.result("start", ["label": "Website Redesign"])
        clock.set("2026-11-03T10:00:00")

        let stopped = try mcp.result("stop", ["label": "Website Redesign", "at": "2026-11-03T09:40:00-05:00"])

        #expect(stopped["entry"]?.objectValue?["end"] == "2026-11-03T09:40:00-05:00")
        #expect(stopped["entry"]?.objectValue?["total_seconds"] == .int(40 * 60))
    }

    @Test func aRefusalIsAToolErrorWithItsMessage() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let mcp = session(Operations(tracker: tracker), clock)

        let error = try #require(mcp.error("add_entry", ["label": "Website Redesign",
                                                         "start": "2026-11-03T08:00:00-05:00",
                                                         "end": "2026-11-03T07:00:00-05:00"]))

        #expect(error.kind == "end_before_start")
        #expect(!error.text.isEmpty)
        #expect(error.text == error.structuredContent?.objectValue?["message"]?.stringValue)
    }

    @Test func aRefusalAboutTimersListsTheRunningOnes() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        let mcp = session(Operations(tracker: tracker), clock)

        let error = try #require(mcp.error("stop", ["label": "Website Redesign"]))

        #expect(error.kind == "not_running")
        #expect(error.running == ["Internal"])
        #expect(error.text.contains("Internal"))
    }

    @Test func aRefusalsTextGivesTheWholeErrorToo() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        let mcp = session(Operations(tracker: tracker), clock)

        let error = try #require(mcp.error("stop", ["label": "Website Redesign"]))

        // Some clients show the model only the text, not the structured content.
        #expect(error.content.contains { content in
            guard case .text(let text, _, _) = content else { return false }
            return text.contains(#""kind":"not_running""#) && text.contains(#""start":"2026-11-03T09:00:00-05:00""#)
        })
    }

    @Test func aMissingArgumentIsAToolError() throws {
        let mcp = session(Operations(tracker: Tracker(clock: clock, storageRoot: root)), clock)

        let error = try #require(mcp.error("start"))

        #expect(error.kind == "invalid_request")
        #expect(error.text.contains("label"))
    }

    @Test func aTimeWithoutAnOffsetIsAToolError() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        let mcp = session(Operations(tracker: tracker), clock)

        let error = try #require(mcp.error("stop", ["label": "Internal", "at": "14:40"]))

        #expect(error.kind == "invalid_request")
        #expect(tracker.timers.map(\.project) == ["Internal"])
    }

    @Test func anUnknownToolIsAToolError() throws {
        let mcp = session(Operations(tracker: Tracker(clock: clock, storageRoot: root)), clock)

        #expect(mcp.error("restart")?.kind == "unknown_operation")
    }

    @Test func anAppThatCantBeReachedIsAToolError() throws {
        struct Refused: Error {}
        let mcp = MCPSession { _ in throw Refused() }

        let error = try #require(mcp.error("status"))

        #expect(error.kind == "app_unreachable")
    }

    @Test func everyToolReachesItsOperation() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let mcp = session(Operations(tracker: tracker), clock)
        _ = try mcp.result("start", ["label": "Website Redesign"])
        clock.set("2026-11-03T10:00:00")

        #expect(try mcp.result("status")["timers"]?.arrayValue?.count == 1)
        #expect(try mcp.result("set_start", ["label": "Website Redesign", "at": "2026-11-03T08:30:00-05:00"])["timer"]?
            .objectValue?["start"] == "2026-11-03T08:30:00-05:00")
        #expect(try mcp.result("add_entry", ["label": "Internal", "duration": "0:30"])["label"] == "Internal")
        #expect(try mcp.result("adjust", ["label": "Internal", "input": "+15"])["total_seconds"] == .int(45 * 60))
        #expect(try mcp.result("day", ["date": "2026-11-03"])["rows"]?.arrayValue?.count == 2)
        #expect(try mcp.result("summary")["today"]?.objectValue?["total_seconds"] == .int((90 + 45) * 60))
        #expect(try mcp.result("labels", ["query": "web"])["labels"]?.arrayValue?.count == 1)
        #expect(try mcp.result("pin", ["label": "Internal"])["label"] == "Internal")
        #expect(try mcp.result("archive", ["label": "Internal"])["label"] == "Internal")
        #expect(try mcp.result("stop", ["label": "Website Redesign"])["entry"]?.objectValue?["label"] == "Website Redesign")
    }
}

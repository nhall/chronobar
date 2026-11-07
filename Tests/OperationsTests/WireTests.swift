import Foundation
import Testing
import ChronobarCore
import ChronobarOperations

/// One request line in, one response line out, as the socket carries them.
@MainActor @Suite struct WireTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    private func respond(_ line: String, _ operations: Operations? = nil) throws -> [String: Any] {
        let operations = operations ?? Operations(tracker: Tracker(clock: clock, storageRoot: root))
        let reply = operations.respond(to: Data(line.utf8))
        #expect(reply.last == UInt8(ascii: "\n"))
        #expect(!reply.dropLast().contains(UInt8(ascii: "\n")))
        let object = try JSONSerialization.jsonObject(with: reply)
        return try #require(object as? [String: Any])
    }

    @Test func aStartLineAnswersWithTimesAsTheDayFileStoresThem() throws {
        let reply = try respond(#"{"op": "start", "label": "Website Redesign"}"#)

        #expect(reply["ok"] as? Bool == true)
        #expect(reply["op"] as? String == "start")
        let result = try #require(reply["result"] as? [String: Any])
        let timer = try #require(result["timer"] as? [String: Any])
        #expect(timer["label"] as? String == "Website Redesign")
        #expect(timer["start"] as? String == "2026-11-03T09:00:00-05:00")
        #expect(timer["source"] as? String == "agent")
        #expect(timer["total_seconds"] as? Int == 0)
        #expect(result["already_running"] as? Bool == false)
    }

    @Test func anErrorAnswersWithItsKindMessageAndTheRunningTimers() throws {
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))
        _ = try respond(#"{"op": "start", "label": "Internal"}"#, operations)
        _ = try respond(#"{"op": "start", "label": "Website Redesign"}"#, operations)

        let reply = try respond(#"{"op": "stop"}"#, operations)

        #expect(reply["ok"] as? Bool == false)
        let error = try #require(reply["error"] as? [String: Any])
        #expect(error["kind"] as? String == "ambiguous")
        #expect((error["message"] as? String)?.isEmpty == false)
        let running = try #require(error["running"] as? [[String: Any]])
        #expect(running.map { $0["label"] as? String } == ["Internal", "Website Redesign"])
    }

    @Test func aLineThatIsNotJSONIsAnInvalidRequest() throws {
        let reply = try respond("start Website Redesign")

        #expect(reply["ok"] as? Bool == false)
        #expect((reply["error"] as? [String: Any])?["kind"] as? String == "invalid_request")
    }

    @Test func aStartWithoutALabelIsAnInvalidRequestNamingIt() throws {
        let reply = try respond(#"{"op": "start"}"#)

        let error = try #require(reply["error"] as? [String: Any])
        #expect(error["kind"] as? String == "invalid_request")
        #expect((error["message"] as? String)?.contains("label") == true)
    }

    @Test func anOperationItDoesNotKnowIsNamedInTheError() throws {
        let reply = try respond(#"{"op": "rewind"}"#)

        let error = try #require(reply["error"] as? [String: Any])
        #expect(error["kind"] as? String == "unknown_operation")
        #expect((error["message"] as? String)?.contains("rewind") == true)
    }

    /// What the `chronobar` command does with the line it sends and the line it gets back.
    @Test func theCommandLineReadsBackWhatTheAppAnswered() throws {
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))
        let request = Wire.encode(Request.start(label: "Website Redesign"))
        #expect(request.last == UInt8(ascii: "\n"))

        let response = try Wire.response(from: operations.respond(to: request))

        guard case .start(let started) = try response.success() else { throw Unexpected() }
        #expect(started.timer.start == clock.date("2026-11-03T09:00:00"))
        #expect(started.timer.source == .agent)

        let failure = try Wire.response(from: operations.respond(to: Wire.encode(Request.stop(label: "Internal"))))
        #expect(failure.error?.kind == .notRunning)
    }
}

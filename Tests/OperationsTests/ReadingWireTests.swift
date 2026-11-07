import Foundation
import Testing
import ChronobarCore
import ChronobarOperations

/// The reading and list operations over the wire, as the `chronobar` command sends and reads them.
@MainActor @Suite struct ReadingWireTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test(arguments: [
        Request.day(date: "2026-11-02"), .day(date: nil), .summary, .labels(query: "web"), .labels(query: nil),
        .pin(label: "Website Redesign"), .archive(label: "Website Redesign"),
    ])
    func eachRequestReadsBackAsTheResultTheAppSent(_ request: Request) throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "1:00", on: Day(year: 2026, month: 11, day: 2))
        let operations = Operations(tracker: tracker)
        let line = Wire.encode(request)
        #expect(try Wire.request(from: line).get() == request)

        let reply = operations.respond(to: line)
        let result = try Wire.response(from: reply).success()

        #expect(result.operation == request.operation)
    }

    @Test func aDayLineAnswersWithSnakeCaseTotals() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "1:00", on: tracker.today)
        let reply = Operations(tracker: tracker).respond(to: Data(#"{"op": "day", "date": "2026-11-03"}"#.utf8))

        let object = try #require(try JSONSerialization.jsonObject(with: reply) as? [String: Any])
        let result = try #require(object["result"] as? [String: Any])
        let rows = try #require(result["rows"] as? [[String: Any]])
        #expect(rows.first?["label"] as? String == "Website Redesign")
        #expect(rows.first?["total_seconds"] as? Int == 3600)
        #expect((result["day"] as? [String: Any])?["elapsed_seconds"] as? Int == 0)
    }

    @Test func aPinWithoutALabelIsAnInvalidRequest() throws {
        let reply = Operations(tracker: Tracker(clock: clock, storageRoot: root))
            .respond(to: Data(#"{"op": "pin"}"#.utf8))

        let object = try #require(try JSONSerialization.jsonObject(with: reply) as? [String: Any])
        #expect((object["error"] as? [String: Any])?["kind"] as? String == "invalid_request")
    }
}

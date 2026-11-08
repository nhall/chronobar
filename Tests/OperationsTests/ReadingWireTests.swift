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
        #expect(rows.first?["total_minutes"] as? Int == 60)
        let day = try #require(result["day"] as? [String: Any])
        #expect(day["elapsed_seconds"] as? Int == 0)
        #expect(day["total_minutes"] as? Int == 60)
        #expect(day["elapsed_minutes"] as? Int == 0)
    }

    @Test func aWeekLineAnswersWithSnakeCaseMinutes() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "1:00", on: tracker.today)
        let reply = Operations(tracker: tracker).respond(to: Data(#"{"op": "week", "date": "2026-11-03"}"#.utf8))

        let object = try #require(try JSONSerialization.jsonObject(with: reply) as? [String: Any])
        let result = try #require(object["result"] as? [String: Any])
        #expect(result["total_minutes"] as? Int == 60)
        #expect(result["elapsed_minutes"] as? Int == 0)
        let days = try #require(result["days"] as? [[String: Any]])
        #expect(days.map { $0["total_minutes"] as? Int } == [0, 0, 60, 0, 0, 0, 0])
        #expect(days.map { $0["elapsed_minutes"] as? Int } == [0, 0, 0, 0, 0, 0, 0])
        let labels = try #require(result["labels"] as? [[String: Any]])
        #expect(labels.first?["total_minutes"] as? Int == 60)
    }

    @Test func aWeekReadsBackAsTheResultTheAppSent() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "1:00", on: tracker.today)
        let operations = Operations(tracker: tracker)
        let sent = try operations.week("2026-11-03")

        let reply = operations.respond(to: Wire.encode(.week(date: "2026-11-03")))

        guard case .week(let week) = try Wire.response(from: reply).success() else { throw Unexpected() }
        #expect(week == sent)
    }

    @Test func aPinWithoutALabelIsAnInvalidRequest() throws {
        let reply = Operations(tracker: Tracker(clock: clock, storageRoot: root))
            .respond(to: Data(#"{"op": "pin"}"#.utf8))

        let object = try #require(try JSONSerialization.jsonObject(with: reply) as? [String: Any])
        #expect((object["error"] as? [String: Any])?["kind"] as? String == "invalid_request")
    }
}

import Foundation
import Testing
import MCP
import ChronobarCore
import ChronobarOperations
@testable import ChronobarCLI

/// Every tool declares an output schema, and every result it gives matches it: each tool is called on real
/// Days, with its optional fields both present and left out, and the result checked against the schema.
@MainActor @Suite struct OutputSchemaTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func everyToolHasAnObjectOutputSchema() {
        #expect(Set(MCPTools.all.map(\.name)) == Set(MCPOutputSchemas.byTool.keys))
        for tool in MCPTools.all {
            #expect(tool.outputSchema?.objectValue?["type"] == "object", "\(tool.name)")
        }
    }

    @Test func everyToolsResultsMatchItsOutputSchema() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let mcp = session(Operations(tracker: tracker), clock)
        var checked: Set<String> = []
        func check(_ tool: String, _ arguments: [String: Value] = [:]) throws {
            let result = try mcp.result(tool, arguments)
            let schema = try #require(MCPOutputSchemas.byTool[tool])
            let problems = SchemaCheck.problems(.object(result), schema, at: tool)
            #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
            checked.insert(tool)
        }

        try check("start", ["label": "Website Redesign"])
        try check("status")
        clock.set("2026-11-03T10:00:00")
        try check("set_start", ["label": "Website Redesign", "at": "2026-11-03T08:30:00-05:00"])
        try check("stop", ["label": "Website Redesign", "at": "2026-11-03T09:40:00-05:00"])
        try check("start", ["label": "Northwind"])
        try check("add_entry", ["label": "Internal", "start": "2026-11-03T07:00:00-05:00",
                                "end": "2026-11-03T07:30:00-05:00"])
        try check("add_entry", ["label": "Internal", "duration": "0:15"])
        try check("adjust", ["label": "Internal", "input": "+10"])
        try check("relabel", ["label": "Northwind", "new_label": "Northwind, Ticket 665"])
        try check("relabel", ["label": "Website Redesign", "new_label": "Website"])
        try check("day")
        try check("week")
        try check("summary")
        try check("labels")
        try check("labels", ["query": "North"])
        try check("pin", ["label": "Internal"])
        try check("archive", ["label": "Internal"])

        #expect(checked == Set(MCPOutputSchemas.byTool.keys))
    }

    /// The check above would pass anything if the checker found nothing; it finds each kind of mismatch.
    @Test func theCheckerFindsAResultThatDoesntMatch() throws {
        let schema = try #require(MCPOutputSchemas.byTool["archive"])
        let good: [String: Value] = ["label": "Internal", "already_archived": false, "unpinned": true, "running": false]
        #expect(SchemaCheck.problems(.object(good), schema, at: "archive").isEmpty)

        var missing = good
        missing["running"] = nil
        var extra = good
        extra["note"] = "x"
        var wrongType = good
        wrongType["unpinned"] = "yes"
        for bad in [missing, extra, wrongType] {
            #expect(!SchemaCheck.problems(.object(bad), schema, at: "archive").isEmpty)
        }

        let status = try #require(MCPOutputSchemas.byTool["status"])
        let today: Value = ["date": "2026-11-03", "total_seconds": 0, "total_minutes": 0,
                            "elapsed_seconds": 0, "elapsed_minutes": 0]
        let badSource: Value = ["timers": [["label": "A", "start": "2026-11-03T09:00:00-05:00",
                                            "source": "phone", "total_seconds": 0]], "today": today]
        let badTime: Value = ["timers": [["label": "A", "start": "9am", "source": "app", "total_seconds": 0]],
                              "today": today]
        #expect(!SchemaCheck.problems(badSource, status, at: "status").isEmpty)
        #expect(!SchemaCheck.problems(badTime, status, at: "status").isEmpty)
    }
}

/// The JSON Schema keywords the output schemas use: type, properties, required, additionalProperties,
/// items, enum, pattern and format date-time.
enum SchemaCheck {
    static func problems(_ value: Value, _ schema: Value, at path: String) -> [String] {
        guard let schema = schema.objectValue else { return ["\(path): the schema isn't an object"] }
        if let allowed = schema["enum"]?.arrayValue, !allowed.contains(value) {
            return ["\(path): \(value) isn't one of \(allowed)"]
        }
        switch (schema["type"]?.stringValue, value) {
        case ("object", .object(let object)):
            let properties = schema["properties"]?.objectValue ?? [:]
            var problems = (schema["required"]?.arrayValue ?? []).compactMap(\.stringValue)
                .filter { object[$0] == nil }.map { "\(path).\($0): missing" }
            for (key, member) in object {
                if let property = properties[key] {
                    problems += Self.problems(member, property, at: "\(path).\(key)")
                } else if schema["additionalProperties"] == false {
                    problems.append("\(path).\(key): not in the schema")
                }
            }
            return problems
        case ("array", .array(let items)):
            guard let item = schema["items"] else { return [] }
            return items.enumerated().flatMap { Self.problems($1, item, at: "\(path)[\($0)]") }
        case ("string", .string(let text)):
            if let pattern = schema["pattern"]?.stringValue, text.range(of: pattern, options: .regularExpression) == nil {
                return ["\(path): \"\(text)\" doesn't match \(pattern)"]
            }
            if schema["format"] == "date-time",
               (try? Date.ISO8601FormatStyle(timeZoneSeparator: .colon).parse(text)) == nil {
                return ["\(path): \"\(text)\" isn't an ISO 8601 date-time"]
            }
            return []
        case ("integer", .int), ("boolean", .bool):
            return []
        case (let type, _):
            return ["\(path): \(value) isn't of type \(type ?? "?")"]
        }
    }
}

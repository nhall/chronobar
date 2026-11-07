import Foundation
import Testing
import MCP
@testable import ChronobarCLI

/// The tools `chronobar mcp` lists: one per operation, each with a JSON Schema for its arguments.
@Suite struct ToolListTests {
    @Test func everyOperationIsATool() {
        #expect(MCPTools.all.map(\.name) == ["status", "start", "stop", "set_start", "add_entry", "adjust",
                                                 "day", "summary", "labels", "archive", "pin"])
    }

    @Test func everyToolHasADescriptionAndAnObjectSchema() {
        for tool in MCPTools.all {
            #expect(!(tool.description ?? "").isEmpty, "\(tool.name)")
            let schema = tool.inputSchema.objectValue
            #expect(schema?["type"] == "object", "\(tool.name)")
            #expect(schema?["properties"]?.objectValue != nil, "\(tool.name)")
            #expect(schema?["additionalProperties"] == false, "\(tool.name)")
        }
    }

    @Test func requiredArgumentsAreMarkedRequired() {
        func required(_ name: String) -> [String] {
            let tool = MCPTools.all.first { $0.name == name }
            return tool?.inputSchema.objectValue?["required"]?.arrayValue?.compactMap(\.stringValue) ?? []
        }
        #expect(required("status") == [])
        #expect(required("start") == ["label"])
        #expect(required("stop") == [])
        #expect(required("set_start") == ["at"])
        #expect(required("add_entry") == ["label"])
        #expect(required("adjust") == ["label", "input"])
        #expect(required("day") == [])
        #expect(required("labels") == [])
        #expect(required("archive") == ["label"])
        #expect(required("pin") == ["label"])
    }

    @Test func readingToolsAreMarkedReadOnly() {
        let readOnly = MCPTools.all.filter { $0.annotations.readOnlyHint == true }.map(\.name)
        #expect(readOnly == ["status", "day", "summary", "labels"])
    }
}

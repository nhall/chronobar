import Foundation
import Testing
import ChronobarCore
import ChronobarOperations
@testable import ChronobarCLI

/// `chronobar mcp` runs the MCP server, for the everyday copy or with `--dev` the development one.
@Suite struct MCPArgumentsTests {
    @Test func mcpRunsTheServer() throws {
        #expect(try Invocation(["mcp"]) == .mcp(copy: .everyday))
    }

    @Test func devPicksTheDevelopmentCopy() throws {
        #expect(try Invocation(["--dev", "mcp"]) == .mcp(copy: .development))
        #expect(try Invocation(["mcp", "--dev"]) == .mcp(copy: .development))
    }

    @Test func mcpTakesNoArguments() {
        #expect(throws: OperationError.self) { try Invocation(["mcp", "now"]) }
        #expect(throws: OperationError.self) { try Invocation(["mcp", "--json"]) }
    }
}

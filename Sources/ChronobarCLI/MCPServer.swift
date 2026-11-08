import Foundation
import MCP
import ChronobarCore
import ChronobarOperations

/// `chronobar mcp`: an MCP server on standard input and output, tools only, one per operation. Each MCP
/// client session launches its own, so one process is one session. Every tool call opens a fresh connection
/// to the app (launching it if needed), so a restarted app is picked up on the next call. Standard output
/// carries only the protocol. Not covered by `swift test` beyond `MCPSession`; the README's checklist tries
/// it by hand.
enum MCPServer {
    /// The version the server reports to clients.
    static let version = "2.0.1"

    static let instructions = """
        Chronobar times work by Label: free text such as "Client A, Ticket 665". Several timers can run at \
        once, one per Label. stop and set_start without a label act on the timer this session started. Times \
        are ISO 8601 with an offset; convert what the user says ("2:40") to one in their time zone first. \
        total_seconds adds up every Label's time; elapsed_seconds is what Chronobar shows the user as "Clock \
        time": the time when any timer was running, overlapping timers counted once, without time logged by \
        hand (duration or adjust). Call it clock time when you tell the user. Beside the seconds, Day and \
        week totals, day's rows and week's labels give total_minutes (and totals elapsed_minutes): the hours \
        and minutes the Panel shows, which add up to the total under them. Quote those to the user (128 minutes is "2:08"), and use the seconds for arithmetic.
        """

    @MainActor
    static func run(_ copy: BuildVariant.Copy) async throws {
        let session = MCPSession { request in try connect(to: copy).send(request) }
        let server = Server(name: "chronobar", version: version, title: copy.name, instructions: instructions,
                            capabilities: .init(tools: .init(listChanged: false)))
        await server.withMethodHandler(ListTools.self) { _ in ListTools.Result(tools: MCPTools.all) }
        await server.withMethodHandler(CallTool.self) { parameters in
            await session.call(parameters.name, arguments: parameters.arguments)
        }
        try await server.start(transport: StdioTransport())
        await server.waitUntilCompleted()
    }
}

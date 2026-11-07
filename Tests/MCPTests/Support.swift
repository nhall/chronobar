import Foundation
import MCP
import ChronobarCore
import ChronobarOperations
@testable import ChronobarCLI

/// A clock the test moves by hand.
final class FakeClock: TimeSource {
    var now: Date
    var calendar: Calendar

    /// `"2026-11-03T09:00:00"` is read as local time in `timeZone`.
    init(_ local: String, timeZone: String = "America/New_York") {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        self.calendar = calendar
        self.now = FakeClock.date(local, calendar)
    }

    func set(_ local: String) { now = FakeClock.date(local, calendar) }

    private static func date(_ local: String, _ calendar: Calendar) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: local)!
    }
}

/// A fresh storage root under the system temp folder.
func temporaryRoot() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("MCPTests-\(UUID().uuidString)", isDirectory: true)
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// An MCP session talking to `operations` the way `chronobar mcp` talks to the app: each request as a
/// wire line, answered with a wire line. `clock` gives the time zone the results are written in.
@MainActor func session(_ operations: Operations, _ clock: FakeClock) -> MCPSession {
    MCPSession(timeZone: clock.calendar.timeZone) { request in
        try Wire.response(from: operations.respond(to: Wire.encode(request)))
    }
}

/// A tool result a test expected to succeed was an error.
struct ToolFailed: Error {
    let result: CallTool.Result
}

extension MCPSession {
    /// Calls `tool` and returns its structured result, throwing if it is an error.
    func result(_ tool: String, _ arguments: [String: Value] = [:]) throws -> [String: Value] {
        let result = call(tool, arguments: arguments)
        guard result.isError != true, let object = result.structuredContent?.objectValue else {
            throw ToolFailed(result: result)
        }
        return object
    }

    /// Calls `tool` and returns its error, or nil if it succeeded.
    func error(_ tool: String, _ arguments: [String: Value] = [:]) -> CallTool.Result? {
        let result = call(tool, arguments: arguments)
        return result.isError == true ? result : nil
    }
}

extension CallTool.Result {
    /// The first text block.
    var text: String {
        for case .text(let text, _, _) in content { return text }
        return ""
    }

    /// The structured error's `kind`.
    var kind: String? { structuredContent?.objectValue?["kind"]?.stringValue }

    /// The Labels in the structured error's `running`.
    var running: [String]? {
        structuredContent?.objectValue?["running"]?.arrayValue?.compactMap { $0.objectValue?["label"]?.stringValue }
    }
}

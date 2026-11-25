import Foundation
import MCP
import ChronobarCore
import ChronobarOperations

/// One MCP session's end of `chronobar mcp`: turns tool calls into requests to the app and its answers into
/// tool results. It remembers the Labels the session started, so `stop` and `set_start` without a Label act
/// on the session's own timer rather than whichever runs. The memory lives only as long as the process:
/// closing the session forgets it and leaves every timer running.
@MainActor
final class MCPSession {
    /// Sends a request to the app and returns its answer; throws if the app can't be reached.
    typealias Send = @MainActor (ChronobarOperations.Request) throws -> ChronobarOperations.Response

    private let send: Send
    /// The time zone results' times are written in.
    private let timeZone: TimeZone
    /// The Labels this session started, as stored, oldest first. A start that found the Label already
    /// running didn't start it, so it isn't noted.
    private var started: [String] = []

    init(timeZone: TimeZone = .current, send: @escaping Send) {
        self.timeZone = timeZone
        self.send = send
    }

    /// Carries out `tool`, the operation of the same name, with `arguments` as the request's keys.
    func call(_ tool: String, arguments: [String: Value]?) -> CallTool.Result {
        do throws(OperationError) {
            let request = try withSessionLabel(try Self.request(tool, arguments ?? [:]))
            let result = try perform(request).get()
            remember(result)
            return self.result(result)
        } catch {
            return result(error)
        }
    }

    /// `request` with the session's Label filled in, for a `stop` or `set_start` that names none.
    private func withSessionLabel(_ request: ChronobarOperations.Request) throws(OperationError)
        -> ChronobarOperations.Request {
        switch request {
        case .stop(nil, let at): .stop(label: try sessionLabel(to: "stop"), at: at)
        case .setStart(nil, let at): .setStart(label: try sessionLabel(to: "move"), at: at)
        default: request
        }
    }

    /// The one running timer this session started. With several or none, an error listing every running
    /// timer, so the agent can ask which one; `verb` says what the request would do to it.
    private func sessionLabel(to verb: String) throws(OperationError) -> String {
        guard case .status(let status) = try perform(.status).get() else {
            throw OperationError(.failed, "Chronobar answered status with another operation's result.")
        }
        let running = status.timers
        // Forget timers stopped elsewhere, so one started again from the Panel isn't taken for the session's.
        started.removeAll { label in !running.contains { ProjectName.matches($0.label, label) } }
        let mine = running.filter { timer in started.contains { ProjectName.matches(timer.label, $0) } }
        return try UnnamedTimer.label(among: mine, running: running, to: verb, session: true)
    }

    /// Notes the Label a `start` started, not one it found already running, forgets the one a `stop`
    /// stopped, and follows one of the session's timers that its own `relabel` moved to another Label.
    /// A timer relabeled elsewhere isn't followed, so it stops being the session's.
    private func remember(_ result: OperationResult) {
        switch result {
        case .start(let started) where !started.alreadyRunning
            && !self.started.contains(where: { ProjectName.matches($0, started.timer.label) }):
            self.started.append(started.timer.label)
        case .stop(let stopped):
            started.removeAll { ProjectName.matches($0, stopped.entry.label) }
        case .relabel(let relabeled):
            guard let timer = relabeled.timer,
                  let index = started.firstIndex(where: { ProjectName.matches($0, relabeled.oldLabel) })
            else { break }
            started[index] = timer.label
        default: break
        }
    }

    /// The request a tool call makes, read as the socket reads a request line, so both check arguments alike.
    private static func request(_ tool: String, _ arguments: [String: Value]) throws(OperationError)
        -> ChronobarOperations.Request {
        guard MCPTools.all.contains(where: { $0.name == tool }) else {
            throw OperationError(.unknownOperation, "Chronobar has no tool named \"\(tool)\".")
        }
        var object = arguments
        object["op"] = .string(tool)
        guard let line = try? JSONEncoder().encode(Value.object(object)) else {
            throw OperationError(.invalidRequest, "The arguments can't be read as JSON.")
        }
        return try Wire.request(from: line).get()
    }

    /// Sends `request`, turning a failure to reach the app into an `appUnreachable` answer.
    private func perform(_ request: ChronobarOperations.Request) -> ChronobarOperations.Response {
        do {
            return try send(request)
        } catch let error as OperationError {
            return .failure(error)
        } catch {
            return .failure(OperationError(.appUnreachable, "Chronobar couldn't be reached: \(error)"))
        }
    }

    /// `result` as structured content, and as the same JSON in text for clients that only read text.
    private func result(_ result: OperationResult) -> CallTool.Result {
        let structured = wire(.success(result), "result")
        return CallTool.Result(content: [.text(text: Output.text(result), annotations: nil, _meta: nil),
                                         .text(text: Self.json(structured), annotations: nil, _meta: nil)],
                               structuredContent: Optional(structured), isError: false)
    }

    /// `error` as a tool error: its message as text, then the whole error (kind, message, running timers) as
    /// JSON in text. Not as structured content: that must match the tool's output schema, the shape of its
    /// result, and some clients check an error's structured content against it too and reject the error.
    private func result(_ error: OperationError) -> CallTool.Result {
        let structured = wire(.failure(error), "error")
        return CallTool.Result(content: [.text(text: error.message, annotations: nil, _meta: nil),
                                         .text(text: Self.json(structured), annotations: nil, _meta: nil)],
                               structuredContent: nil, isError: true)
    }

    /// `key` of `response`'s wire envelope: the JSON the socket and `chronobar --json` give.
    private func wire(_ response: ChronobarOperations.Response, _ key: String) -> Value {
        let line = Wire.encode(response, timeZone: timeZone)
        let envelope = try? JSONDecoder().decode(Value.self, from: line)
        return envelope?.objectValue?[key] ?? .null
    }

    private static func json(_ value: Value) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(value)).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }
}

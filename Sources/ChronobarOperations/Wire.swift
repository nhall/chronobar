import Foundation
import ChronobarCore

/// The JSON the socket carries: one object per line each way, a request and then its response.
///
///     {"op": "stop", "label": "Website Redesign"}
///     {"ok": true, "op": "stop", "result": {"entry": {"label": …, "start": "2026-11-03T09:00:00-05:00", …}, …}}
///     {"ok": false, "error": {"kind": "not_running", "message": …, "running": […]}}
///
/// Keys are snake_case; times are ISO 8601 with a UTC offset, to the second, as in the Day files.
public enum Wire {
    /// A request line, or the `invalidRequest` or `unknownOperation` error to answer it with.
    public static func request(from line: Data) -> Result<Request, OperationError> {
        do {
            return .success(try decoder().decode(Request.self, from: line))
        } catch let error as OperationError {
            return .failure(error)
        } catch DecodingError.keyNotFound(let key, _) {
            return .failure(OperationError(.invalidRequest, "The request has no \"\(key.stringValue)\"."))
        } catch DecodingError.typeMismatch(_, let context) {
            let key = context.codingPath.last?.stringValue ?? "request"
            return .failure(OperationError(.invalidRequest, "The request's \"\(key)\" has the wrong type."))
        } catch DecodingError.dataCorrupted(let context) where !context.codingPath.isEmpty {
            let key = context.codingPath.last!.stringValue
            return .failure(OperationError(.invalidRequest, "The request's \"\(key)\": \(context.debugDescription)."))
        } catch {
            return .failure(OperationError(.invalidRequest,
                                           #"The request isn't a JSON object such as {"op": "status"}."#))
        }
    }

    /// `request` as one line, newline included.
    public static func encode(_ request: Request) -> Data {
        line(try! encoder(timeZone: .current).encode(request))
    }

    /// `response` as one line, newline included, with times in `timeZone`.
    public static func encode(_ response: Response, timeZone: TimeZone) -> Data {
        let envelope = switch response {
        case .success(let result): Envelope(ok: true, op: result.operation, result: result, error: nil)
        case .failure(let error): Envelope(ok: false, op: nil, result: nil, error: error)
        }
        return line(try! encoder(timeZone: timeZone).encode(envelope))
    }

    /// The response in a line the app sent back.
    public static func response(from line: Data) throws -> Response {
        let envelope = try decoder().decode(Envelope.self, from: line)
        if envelope.ok, let result = envelope.result { return .success(result) }
        if let error = envelope.error { return .failure(error) }
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "A response with no result or error."))
    }

    private struct Envelope: Codable {
        let ok: Bool
        let op: String?
        let result: OperationResult?
        let error: OperationError?

        private enum CodingKeys: String, CodingKey {
            case ok, op, result, error
        }

        init(ok: Bool, op: String?, result: OperationResult?, error: OperationError?) {
            self.ok = ok
            self.op = op
            self.result = result
            self.error = error
        }

        /// `result`'s shape depends on `op`.
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            ok = try container.decode(Bool.self, forKey: .ok)
            op = try container.decodeIfPresent(String.self, forKey: .op)
            error = try container.decodeIfPresent(OperationError.self, forKey: .error)
            guard container.contains(.result) else {
                result = nil
                return
            }
            result = switch op {
            case "status": .status(try container.decode(StatusResult.self, forKey: .result))
            case "start": .start(try container.decode(StartResult.self, forKey: .result))
            case "stop": .stop(try container.decode(StopResult.self, forKey: .result))
            case "set_start": .setStart(try container.decode(SetStartResult.self, forKey: .result))
            case "add_entry": .addEntry(try container.decode(AddEntryResult.self, forKey: .result))
            case "adjust": .adjust(try container.decode(AdjustResult.self, forKey: .result))
            case "day": .day(try container.decode(DayRowsResult.self, forKey: .result))
            case "summary": .summary(try container.decode(SummaryResult.self, forKey: .result))
            case "labels": .labels(try container.decode(LabelsResult.self, forKey: .result))
            case "pin": .pin(try container.decode(PinResult.self, forKey: .result))
            case "archive": .archive(try container.decode(ArchiveResult.self, forKey: .result))
            default: nil
            }
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(ok, forKey: .ok)
            try container.encodeIfPresent(op, forKey: .op)
            try container.encodeIfPresent(error, forKey: .error)
            switch result {
            case .status(let result): try container.encode(result, forKey: .result)
            case .start(let result): try container.encode(result, forKey: .result)
            case .stop(let result): try container.encode(result, forKey: .result)
            case .setStart(let result): try container.encode(result, forKey: .result)
            case .addEntry(let result): try container.encode(result, forKey: .result)
            case .adjust(let result): try container.encode(result, forKey: .result)
            case .day(let result): try container.encode(result, forKey: .result)
            case .summary(let result): try container.encode(result, forKey: .result)
            case .labels(let result): try container.encode(result, forKey: .result)
            case .pin(let result): try container.encode(result, forKey: .result)
            case .archive(let result): try container.encode(result, forKey: .result)
            case nil: break
            }
        }
    }

    private static func line(_ json: Data) -> Data { json + Data("\n".utf8) }

    private static func encoder(timeZone: TimeZone) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let style = Date.ISO8601FormatStyle(timeZoneSeparator: .colon, timeZone: timeZone)
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(style))
        }
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = try? Date.ISO8601FormatStyle(timeZoneSeparator: .colon).parse(text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "\(text) isn't an ISO 8601 time with an offset, such as 2026-11-03T14:40:00-05:00")
            }
            return date
        }
        return decoder
    }
}

extension Operations {
    /// Answers one request line with one response line, newline included, with times in the Day files'
    /// time zone. What `ChannelServer` calls for each line it reads.
    public func respond(to line: Data) -> Data {
        let response = switch Wire.request(from: line) {
        case .success(let request): perform(request)
        case .failure(let error): Response.failure(error)
        }
        return Wire.encode(response, timeZone: timeZone)
    }
}

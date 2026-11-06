import Foundation

/// One named operation from outside the app. On the wire it is a JSON object naming the operation in
/// `op`, with its arguments beside it: `{"op": "start", "label": "Website Redesign"}`.
public enum Request: Equatable, Sendable {
    /// The running timers and today's totals.
    case status
    /// Starts a timer for `label`, or keeps the one it has.
    case start(label: String)
    /// Stops `label`'s timer; with no Label, the only running one.
    case stop(label: String?)
    /// A Day's rows and totals; with no date, today's. `date` is `YYYY-MM-DD`.
    case day(date: String?)
    /// The Time Summary: today, yesterday, this week and this month.
    case summary
    /// The ＋ form's suggestions containing `query`; with no query, all of them.
    case labels(query: String?)
    /// Pins `label`, so it is always suggested.
    case pin(label: String)
    /// Archives `label`: unpins it and hides it from the suggestions, keeping its time.
    case archive(label: String)

    /// The name in `op`.
    public var operation: String {
        switch self {
        case .status: "status"
        case .start: "start"
        case .stop: "stop"
        case .day: "day"
        case .summary: "summary"
        case .labels: "labels"
        case .pin: "pin"
        case .archive: "archive"
        }
    }
}

extension Request: Codable {
    private enum CodingKeys: String, CodingKey {
        case op, label
        case date, query
    }

    /// Throws `OperationError` `unknownOperation` for an `op` it doesn't know; a missing or mistyped
    /// argument is a `DecodingError`, which `Wire.request(from:)` turns into `invalidRequest`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let op = try container.decode(String.self, forKey: .op)
        switch op {
        case "status": self = .status
        case "start": self = .start(label: try container.decode(String.self, forKey: .label))
        case "stop": self = .stop(label: try container.decodeIfPresent(String.self, forKey: .label))
        case "day": self = .day(date: try container.decodeIfPresent(String.self, forKey: .date))
        case "summary": self = .summary
        case "labels": self = .labels(query: try container.decodeIfPresent(String.self, forKey: .query))
        case "pin": self = .pin(label: try container.decode(String.self, forKey: .label))
        case "archive": self = .archive(label: try container.decode(String.self, forKey: .label))
        default: throw OperationError(.unknownOperation, "Unknown operation \"\(op)\".")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(operation, forKey: .op)
        switch self {
        case .status, .summary: break
        case .start(let label): try container.encode(label, forKey: .label)
        case .stop(let label): try container.encodeIfPresent(label, forKey: .label)
        case .day(let date): try container.encodeIfPresent(date, forKey: .date)
        case .labels(let query): try container.encodeIfPresent(query, forKey: .query)
        case .pin(let label), .archive(let label): try container.encode(label, forKey: .label)
        }
    }
}

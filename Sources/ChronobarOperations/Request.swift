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

    /// The name in `op`.
    public var operation: String {
        switch self {
        case .status: "status"
        case .start: "start"
        case .stop: "stop"
        }
    }
}

extension Request: Codable {
    private enum CodingKeys: String, CodingKey {
        case op, label
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
        default: throw OperationError(.unknownOperation, "Unknown operation \"\(op)\".")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(operation, forKey: .op)
        switch self {
        case .status: break
        case .start(let label): try container.encode(label, forKey: .label)
        case .stop(let label): try container.encodeIfPresent(label, forKey: .label)
        }
    }
}

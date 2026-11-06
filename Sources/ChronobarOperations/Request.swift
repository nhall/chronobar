import Foundation
import ChronobarCore

/// One named operation from outside the app. On the wire it is a JSON object naming the operation in
/// `op`, with its arguments beside it: `{"op": "start", "label": "Website Redesign"}`.
public enum Request: Equatable, Sendable {
    /// The running timers and today's totals.
    case status
    /// Starts a timer for `label`, or keeps the one it has.
    case start(label: String)
    /// Stops `label`'s timer at `at` (nil: now); with no Label, the only running one.
    case stop(label: String?, at: Date? = nil)
    /// Moves the start of `label`'s timer to `at`; with no Label, the only running one's.
    case setStart(label: String?, at: Date)
    /// Adds a finished Entry for `label`, without starting a timer.
    case addEntry(label: String, span: EntrySpan)
    /// Sets `label`'s total on `day` (nil: today) to `input` (`1:15`) or changes it by `input` (`+15`, `-10`).
    case adjust(label: String, input: String, day: Day? = nil)

    /// The name in `op`.
    public var operation: String {
        switch self {
        case .status: "status"
        case .start: "start"
        case .stop: "stop"
        case .setStart: "set_start"
        case .addEntry: "add_entry"
        case .adjust: "adjust"
        }
    }
}

/// What `add_entry` adds: a timed Entry from a start to an end, or a duration on a Day as a manual Entry.
public enum EntrySpan: Equatable, Sendable {
    case times(start: Date, end: Date)
    /// `duration` as typed (`1:30`, `45`), on `day` (nil: today).
    case duration(String, day: Day?)
}

extension Request: Codable {
    private enum CodingKeys: String, CodingKey {
        case op, label, at, start, end, duration, day, input
    }

    /// Throws `OperationError` `unknownOperation` for an `op` it doesn't know; a missing or mistyped
    /// argument is a `DecodingError`, which `Wire.request(from:)` turns into `invalidRequest`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let op = try container.decode(String.self, forKey: .op)
        switch op {
        case "status": self = .status
        case "start": self = .start(label: try container.decode(String.self, forKey: .label))
        case "stop":
            self = .stop(label: try container.decodeIfPresent(String.self, forKey: .label),
                         at: try container.decodeIfPresent(Date.self, forKey: .at))
        case "set_start":
            self = .setStart(label: try container.decodeIfPresent(String.self, forKey: .label),
                             at: try container.decode(Date.self, forKey: .at))
        case "add_entry":
            let label = try container.decode(String.self, forKey: .label)
            if let duration = try container.decodeIfPresent(String.self, forKey: .duration) {
                self = .addEntry(label: label, span: .duration(duration, day: try Self.day(in: container)))
            } else {
                self = .addEntry(label: label, span: .times(start: try container.decode(Date.self, forKey: .start),
                                                            end: try container.decode(Date.self, forKey: .end)))
            }
        case "adjust":
            self = .adjust(label: try container.decode(String.self, forKey: .label),
                           input: try container.decode(String.self, forKey: .input),
                           day: try Self.day(in: container))
        default: throw OperationError(.unknownOperation, "Unknown operation \"\(op)\".")
        }
    }

    /// `day` as `YYYY-MM-DD`, if present.
    private static func day(in container: KeyedDecodingContainer<CodingKeys>) throws -> Day? {
        guard let text = try container.decodeIfPresent(String.self, forKey: .day) else { return nil }
        guard let day = Day(text) else {
            throw DecodingError.dataCorruptedError(forKey: .day, in: container,
                                                   debugDescription: "\(text) isn't a date such as 2026-11-03")
        }
        return day
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(operation, forKey: .op)
        switch self {
        case .status: break
        case .start(let label): try container.encode(label, forKey: .label)
        case .stop(let label, let at):
            try container.encodeIfPresent(label, forKey: .label)
            try container.encodeIfPresent(at, forKey: .at)
        case .setStart(let label, let at):
            try container.encodeIfPresent(label, forKey: .label)
            try container.encode(at, forKey: .at)
        case .addEntry(let label, .times(let start, let end)):
            try container.encode(label, forKey: .label)
            try container.encode(start, forKey: .start)
            try container.encode(end, forKey: .end)
        case .addEntry(let label, .duration(let duration, let day)):
            try container.encode(label, forKey: .label)
            try container.encode(duration, forKey: .duration)
            try container.encodeIfPresent(day?.description, forKey: .day)
        case .adjust(let label, let input, let day):
            try container.encode(label, forKey: .label)
            try container.encode(input, forKey: .input)
            try container.encodeIfPresent(day?.description, forKey: .day)
        }
    }
}

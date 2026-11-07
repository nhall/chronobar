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
    /// Sets `label`'s total on `date` (nil: today) to `input` (`1:15`) or changes it by `input` (`+15`,
    /// `-10`). `date` is `YYYY-MM-DD`.
    case adjust(label: String, input: String, date: String? = nil)
    /// A Day's rows and totals; with no date, today's. `date` is `YYYY-MM-DD`.
    case day(date: String?)
    /// The week containing `date` (nil: today), as the Week strip has it: each Day's totals and each
    /// Label's total across the week. `date` is `YYYY-MM-DD`.
    case week(date: String?)
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
        case .setStart: "set_start"
        case .addEntry: "add_entry"
        case .adjust: "adjust"
        case .day: "day"
        case .week: "week"
        case .summary: "summary"
        case .labels: "labels"
        case .pin: "pin"
        case .archive: "archive"
        }
    }
}

/// What `add_entry` adds: a timed Entry from a start to an end, or a duration on a Day as a manual Entry.
public enum EntrySpan: Equatable, Sendable {
    case times(start: Date, end: Date)
    /// `duration` as typed (`1:30`, `45`), on `date` (`YYYY-MM-DD`; nil: today).
    case duration(String, date: String?)
}

extension Request: Codable {
    private enum CodingKeys: String, CodingKey {
        case op, label
        case date, query
        case at, start, end, duration, input
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
                let date = try container.decodeIfPresent(String.self, forKey: .date)
                self = .addEntry(label: label, span: .duration(duration, date: date))
            } else {
                self = .addEntry(label: label, span: .times(start: try container.decode(Date.self, forKey: .start),
                                                            end: try container.decode(Date.self, forKey: .end)))
            }
        case "adjust":
            self = .adjust(label: try container.decode(String.self, forKey: .label),
                           input: try container.decode(String.self, forKey: .input),
                           date: try container.decodeIfPresent(String.self, forKey: .date))
        case "day": self = .day(date: try container.decodeIfPresent(String.self, forKey: .date))
        case "week": self = .week(date: try container.decodeIfPresent(String.self, forKey: .date))
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
        case .addEntry(let label, .duration(let duration, let date)):
            try container.encode(label, forKey: .label)
            try container.encode(duration, forKey: .duration)
            try container.encodeIfPresent(date, forKey: .date)
        case .adjust(let label, let input, let date):
            try container.encode(label, forKey: .label)
            try container.encode(input, forKey: .input)
            try container.encodeIfPresent(date, forKey: .date)
        case .day(let date), .week(let date): try container.encodeIfPresent(date, forKey: .date)
        case .labels(let query): try container.encodeIfPresent(query, forKey: .query)
        case .pin(let label), .archive(let label): try container.encode(label, forKey: .label)
        }
    }
}

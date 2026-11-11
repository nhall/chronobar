import Foundation
import ChronobarCore

/// What a request returns, one case per `Request` case. Totals are whole seconds; times are what the Day
/// file stores, so an agent can confirm exactly what was recorded.
public enum OperationResult: Equatable, Sendable {
    case status(StatusResult)
    case start(StartResult)
    case stop(StopResult)
    case setStart(SetStartResult)
    case addEntry(AddEntryResult)
    case adjust(AdjustResult)
    case relabel(RelabelResult)
    case day(DayRowsResult)
    case week(WeekResult)
    case summary(SummaryResult)
    case labels(LabelsResult)
    case pin(PinResult)
    case archive(ArchiveResult)

    /// The operation this answers, as `Request.operation` names it.
    public var operation: String {
        switch self {
        case .status: "status"
        case .start: "start"
        case .stop: "stop"
        case .setStart: "set_start"
        case .addEntry: "add_entry"
        case .adjust: "adjust"
        case .relabel: "relabel"
        case .day: "day"
        case .week: "week"
        case .summary: "summary"
        case .labels: "labels"
        case .pin: "pin"
        case .archive: "archive"
        }
    }
}

/// A request's answer: its result, or why it changed nothing.
public typealias Response = Result<OperationResult, OperationError>

/// A running timer.
public struct TimerResult: Codable, Equatable, Sendable {
    /// The Label as stored, which may be spelled differently from the request.
    public let label: String
    public let start: Date
    public let source: EntrySource
    /// The Label's total today, counted up to now.
    public let totalSeconds: Int

    public init(label: String, start: Date, source: EntrySource, totalSeconds: Int) {
        self.label = label
        self.start = start
        self.source = source
        self.totalSeconds = totalSeconds
    }
}

/// A timed Entry a request just closed or added.
public struct EntryResult: Codable, Equatable, Sendable {
    public let label: String
    public let start: Date
    public let end: Date
    public let source: EntrySource
    /// The Label's total on the Entry's Day, with this Entry: today, unless a correction reached back.
    public let totalSeconds: Int

    public init(label: String, start: Date, end: Date, source: EntrySource, totalSeconds: Int) {
        self.label = label
        self.start = start
        self.end = end
        self.source = source
        self.totalSeconds = totalSeconds
    }
}

/// A Day's totals: the Day total across every Label, and the Elapsed time.
public struct DayResult: Codable, Equatable, Sendable {
    /// `YYYY-MM-DD`, as in the Day file's name.
    public let date: String
    public let totalSeconds: Int
    /// The Day total and Clock time in whole minutes, rounded down, as the Panel's Total line shows them.
    public let totalMinutes: Int
    public let elapsedSeconds: Int
    public let elapsedMinutes: Int

    public init(date: String, totalSeconds: Int, totalMinutes: Int, elapsedSeconds: Int, elapsedMinutes: Int) {
        self.date = date
        self.totalSeconds = totalSeconds
        self.totalMinutes = totalMinutes
        self.elapsedSeconds = elapsedSeconds
        self.elapsedMinutes = elapsedMinutes
    }
}

public struct StatusResult: Codable, Equatable, Sendable {
    /// In the order they started.
    public let timers: [TimerResult]
    public let today: DayResult

    public init(timers: [TimerResult], today: DayResult) {
        self.timers = timers
        self.today = today
    }
}

public struct StartResult: Codable, Equatable, Sendable {
    /// The Label's timer: the new one, or the one it already had.
    public let timer: TimerResult
    /// Whether the Label was running before, so nothing changed.
    public let alreadyRunning: Bool
    /// Timers this start paused, with "Starting a timer pauses the others" on.
    public let paused: [EntryResult]
    public let today: DayResult

    public init(timer: TimerResult, alreadyRunning: Bool, paused: [EntryResult], today: DayResult) {
        self.timer = timer
        self.alreadyRunning = alreadyRunning
        self.paused = paused
        self.today = today
    }
}

public struct StopResult: Codable, Equatable, Sendable {
    /// The Entry the stop closed.
    public let entry: EntryResult
    /// The timers still running.
    public let running: [TimerResult]
    public let today: DayResult

    public init(entry: EntryResult, running: [TimerResult], today: DayResult) {
        self.entry = entry
        self.running = running
        self.today = today
    }
}

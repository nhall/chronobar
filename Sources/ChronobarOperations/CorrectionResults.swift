import Foundation

public struct SetStartResult: Codable, Equatable, Sendable {
    /// The Label's timer with its new start: today's midnight if the start moved to an earlier Day.
    public let timer: TimerResult
    /// For a start before today's midnight, the finished Entries the run now has on the Days before,
    /// oldest first; otherwise empty.
    public let earlier: [EntryResult]
    public let today: DayResult

    public init(timer: TimerResult, earlier: [EntryResult], today: DayResult) {
        self.timer = timer
        self.earlier = earlier
        self.today = today
    }
}

public struct AddEntryResult: Codable, Equatable, Sendable {
    /// The Label as stored, which may be spelled differently from the request.
    public let label: String
    /// For a start and end, the timed Entries stored, one per Day it covers, oldest first; else empty.
    public let entries: [EntryResult]
    /// For a duration, the manual Entry stored; else nil.
    public let manual: ManualEntryResult?
    /// The totals of each Day written, oldest first.
    public let days: [DayResult]

    public init(label: String, entries: [EntryResult], manual: ManualEntryResult?, days: [DayResult]) {
        self.label = label
        self.entries = entries
        self.manual = manual
        self.days = days
    }
}

/// A duration a request added as a manual Entry.
public struct ManualEntryResult: Codable, Equatable, Sendable {
    /// `YYYY-MM-DD`, the Day it was added to.
    public let date: String
    public let seconds: Int
    /// The Label's total on that Day, with this Entry.
    public let totalSeconds: Int

    public init(date: String, seconds: Int, totalSeconds: Int) {
        self.date = date
        self.seconds = seconds
        self.totalSeconds = totalSeconds
    }
}

public struct AdjustResult: Codable, Equatable, Sendable {
    /// The Label as stored, which may be spelled differently from the request.
    public let label: String
    /// `YYYY-MM-DD`, the Day adjusted.
    public let date: String
    /// How much the Label's total changed; 0 if it already had that total.
    public let changeSeconds: Int
    /// The Label's new total on that Day.
    public let totalSeconds: Int
    public let day: DayResult

    public init(label: String, date: String, changeSeconds: Int, totalSeconds: Int, day: DayResult) {
        self.label = label
        self.date = date
        self.changeSeconds = changeSeconds
        self.totalSeconds = totalSeconds
        self.day = day
    }
}

public struct RelabelResult: Codable, Equatable, Sendable {
    /// The new Label as stored, which may be spelled differently from the request.
    public let label: String
    /// `YYYY-MM-DD`, the Day relabeled.
    public let date: String
    /// The timed Entries now under the new Label on that Day, oldest first; manual Entries and
    /// adjustments count only in `totalSeconds`.
    public let entries: [EntryResult]
    /// The new Label's total on that Day: the old Label's, moved whole.
    public let totalSeconds: Int
    public let day: DayResult

    public init(label: String, date: String, entries: [EntryResult], totalSeconds: Int, day: DayResult) {
        self.label = label
        self.date = date
        self.entries = entries
        self.totalSeconds = totalSeconds
        self.day = day
    }
}

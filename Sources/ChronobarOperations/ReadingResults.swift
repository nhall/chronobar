import Foundation
import ChronobarCore

/// One Label's row on a Day, as the Panel lists it.
public struct RowResult: Codable, Equatable, Sendable {
    /// The Label as the row shows it.
    public let label: String
    /// The Label's total on the Day, never below zero; a running timer counted up to now.
    public let totalSeconds: Int
    /// The minutes the row shows: its share of the Day total's minutes, so the rows add up to it. Can be a
    /// minute more than `totalSeconds` rounded down.
    public let totalMinutes: Int
    /// Whether the Label's timer is running.
    public let running: Bool

    public init(label: String, totalSeconds: Int, totalMinutes: Int, running: Bool) {
        self.label = label
        self.totalSeconds = totalSeconds
        self.totalMinutes = totalMinutes
        self.running = running
    }
}

/// One period of the Time Summary: the Days it covers, the sum of their Day totals and of their Elapsed
/// time.
public struct PeriodResult: Codable, Equatable, Sendable {
    /// The first and last Day, `YYYY-MM-DD`; the same for a single Day.
    public let first: String
    public let last: String
    public let totalSeconds: Int
    public let elapsedSeconds: Int

    public init(first: String, last: String, totalSeconds: Int, elapsedSeconds: Int) {
        self.first = first
        self.last = last
        self.totalSeconds = totalSeconds
        self.elapsedSeconds = elapsedSeconds
    }
}

/// The (i) Time Summary.
public struct SummaryResult: Codable, Equatable, Sendable {
    public let today: PeriodResult
    public let yesterday: PeriodResult
    /// Today's week, as in the Week strip.
    public let week: PeriodResult
    /// Today's calendar month.
    public let month: PeriodResult

    public init(today: PeriodResult, yesterday: PeriodResult, week: PeriodResult, month: PeriodResult) {
        self.today = today
        self.yesterday = yesterday
        self.week = week
        self.month = month
    }
}

/// A suggested Label.
public struct LabelResult: Codable, Equatable, Sendable {
    public let label: String
    /// Whether it is a Pinned Label, suggested whether used lately or not.
    public let pinned: Bool

    public init(label: String, pinned: Bool) {
        self.label = label
        self.pinned = pinned
    }
}

/// What a query names, as starting or pinning it would spell it.
public struct LabelMatchResult: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// One of the suggestions.
        case suggested
        /// Archived: left out of the suggestions until it is started, logged or pinned again.
        case archived
        /// Left out of the suggestions because it has no time in the last 30 Days.
        case unused
        /// No Label yet: starting it creates one.
        case new
    }

    public let kind: Kind
    /// The existing Label; nil for a new one.
    public let label: String?

    public init(kind: Kind, label: String?) {
        self.kind = kind
        self.label = label
    }
}

public struct LabelsResult: Codable, Equatable, Sendable {
    /// The suggestions containing the query, ignoring case: an exact match first, then those starting with
    /// it, then the rest, the most recently used first within each.
    public let labels: [LabelResult]
    /// The Label the query names exactly, ignoring case; nil with no query.
    public let match: LabelMatchResult?

    public init(labels: [LabelResult], match: LabelMatchResult?) {
        self.labels = labels
        self.match = match
    }
}

public struct PinResult: Codable, Equatable, Sendable {
    /// The Label as `projects.txt` now spells it.
    public let label: String
    /// Whether it was pinned before, so nothing changed.
    public let alreadyPinned: Bool
    /// Every Pinned Label, in `projects.txt` order.
    public let pinned: [String]

    public init(label: String, alreadyPinned: Bool, pinned: [String]) {
        self.label = label
        self.alreadyPinned = alreadyPinned
        self.pinned = pinned
    }
}

public struct ArchiveResult: Codable, Equatable, Sendable {
    /// The Label as `archived.txt` spells it.
    public let label: String
    /// Whether it was archived before, so nothing changed.
    public let alreadyArchived: Bool
    /// Whether archiving took it off the Pinned Labels.
    public let unpinned: Bool
    /// Whether its timer runs; archiving leaves it running.
    public let running: Bool

    public init(label: String, alreadyArchived: Bool, unpinned: Bool, running: Bool) {
        self.label = label
        self.alreadyArchived = alreadyArchived
        self.unpinned = unpinned
        self.running = running
    }
}

/// One Label's total across several Days.
public struct LabelTotalResult: Codable, Equatable, Sendable {
    /// The Label as its first row in the Days shows it.
    public let label: String
    /// The sum of the Label's total on each Day, each rounded down to the second.
    public let totalSeconds: Int
    /// The minutes the Label's week line shows: its share of the week's `totalMinutes`, so the Labels'
    /// lines add up to it.
    public let totalMinutes: Int

    public init(label: String, totalSeconds: Int, totalMinutes: Int) {
        self.label = label
        self.totalSeconds = totalSeconds
        self.totalMinutes = totalMinutes
    }
}

/// A week, as the Week strip has it, Sunday to Saturday or as the calendar starts weeks.
public struct WeekResult: Codable, Equatable, Sendable {
    /// The first and last Day, `YYYY-MM-DD`.
    public let first: String
    public let last: String
    /// The sum of the Days' totals, and of their Elapsed time.
    public let totalSeconds: Int
    /// The sum of the Days' `totalMinutes`, so the Day lines add up to the week's: a few minutes less than
    /// `totalSeconds` rounded down at most.
    public let totalMinutes: Int
    public let elapsedSeconds: Int
    /// The sum of the Days' `elapsedMinutes`.
    public let elapsedMinutes: Int
    /// Each of the seven Days with its Day total and Elapsed time, first to last.
    public let days: [DayResult]
    /// One per Label with Entries in the week, in the order each first appears, with its week total.
    public let labels: [LabelTotalResult]
    /// The Days whose file won't parse, so they read as empty; `YYYY-MM-DD`.
    public let malformed: [String]

    public init(first: String, last: String, totalSeconds: Int, totalMinutes: Int, elapsedSeconds: Int,
                elapsedMinutes: Int, days: [DayResult], labels: [LabelTotalResult], malformed: [String]) {
        self.first = first
        self.last = last
        self.totalSeconds = totalSeconds
        self.totalMinutes = totalMinutes
        self.elapsedSeconds = elapsedSeconds
        self.elapsedMinutes = elapsedMinutes
        self.days = days
        self.labels = labels
        self.malformed = malformed
    }
}

public struct DayRowsResult: Codable, Equatable, Sendable {
    /// The Day's date with its Day total and Elapsed time.
    public let day: DayResult
    /// One per Label with Entries on the Day, in the order each first appears in the Day file.
    public let rows: [RowResult]
    /// Whether the Day file won't parse, so it reads as empty and Chronobar won't change it until it's
    /// fixed by hand.
    public let malformed: Bool

    public init(day: DayResult, rows: [RowResult], malformed: Bool) {
        self.day = day
        self.rows = rows
        self.malformed = malformed
    }
}

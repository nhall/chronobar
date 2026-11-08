import Foundation

/// Why a request changed nothing. Returned, never thrown across the boundary: on the wire it is
/// `{"ok": false, "error": {"kind": …, "message": …, "running": […]}}`.
public struct OperationError: Error, Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// Not JSON, or an operation missing an argument or with one of the wrong type.
        case invalidRequest = "invalid_request"
        case unknownOperation = "unknown_operation"
        /// A Label that is empty once trimmed.
        case invalidLabel = "invalid_label"
        /// `archive` named a Label with no time, not pinned and not archived.
        case unknownLabel = "unknown_label"
        /// A date that isn't a calendar Day written `YYYY-MM-DD`.
        case invalidDate = "invalid_date"
        /// `stop` or `set_start` named a Label with no running timer.
        case notRunning = "not_running"
        /// `stop` or `set_start` without a Label, and no timer runs.
        case nothingRunning = "nothing_running"
        /// `stop` or `set_start` without a Label, and several timers run; `running` lists them.
        case ambiguous
        /// A time after now, or a duration on a Day after today: time that hasn't happened.
        case futureTime = "future_time"
        /// An end that isn't after its start.
        case endBeforeStart = "end_before_start"
        /// The Label already has time in that stretch, which would count twice.
        case overlap
        /// A duration or total that isn't `1:30`, `45`, `+15` or `-10`, or a duration that isn't positive.
        case invalidDuration = "invalid_duration"
        /// A Day file, `projects.txt` or `archived.txt` won't parse, so Chronobar won't write it until it's
        /// fixed by hand.
        case malformedFile = "malformed_file"
        /// `stop` or `set_start` from an MCP session without a Label, and none of the timers that session
        /// started is running, though others are; `running` lists them. Only `chronobar mcp` reports this.
        case noSessionTimer = "no_session_timer"
        /// The app couldn't be reached or launched. Only the `chronobar` command reports this.
        case appUnreachable = "app_unreachable"
        /// The app answered with a reply the command can't read: it is older than the command, as when it
        /// kept running through an upgrade. Only the `chronobar` command and `chronobar mcp` report this.
        case versionMismatch = "version_mismatch"
        /// The `chronobar` command was called with arguments it doesn't take. Only it reports this.
        case usage
        /// Anything else, such as a write the disk refused.
        case failed
    }

    public let kind: Kind
    /// One or two sentences for a person, naming what to do next where there is something.
    public let message: String
    /// The running timers, where knowing them helps pick one: `notRunning`, `nothingRunning`, `ambiguous`,
    /// `noSessionTimer`.
    public let running: [TimerResult]?

    public init(_ kind: Kind, _ message: String, running: [TimerResult]? = nil) {
        self.kind = kind
        self.message = message
        self.running = running
    }
}

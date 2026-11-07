import Foundation
import ChronobarCore

/// Which timer a `stop` or `set_start` that names no Label acts on, for Operations (any running timer) and
/// an MCP session (the timers it started) alike: the only one, else an error listing every running timer
/// so the agent or user can say which.
public enum UnnamedTimer {
    /// The Label of the one timer in `candidates`, out of every timer `running`. `session` says the
    /// candidates are the ones an MCP session started; `verb` says what the request would do to the timer.
    public static func label(
        among candidates: [TimerResult], running: [TimerResult], to verb: String, session: Bool = false
    ) throws(OperationError) -> String {
        switch candidates.count {
        case 1:
            return candidates[0].label
        case 0 where running.isEmpty:
            throw OperationError(.nothingRunning, "No timer is running.", running: [])
        case 0:
            throw OperationError(.noSessionTimer, "No timer this session started is running, so say which to "
                                 + "\(verb)." + runningList(running), running: running)
        default:
            let several = session
                ? "This session started \(candidates.count) running timers "
                    + "(\(candidates.map(\.label).joined(separator: ", ")))"
                : "\(candidates.count) timers are running"
            throw OperationError(.ambiguous, "\(several), so say which to \(verb)." + runningList(running),
                                 running: running)
        }
    }

    /// " Running: A, B." naming `running`, or "" with none.
    public static func runningList(_ running: [TimerResult]) -> String {
        running.isEmpty ? "" : " Running: \(running.map(\.label).joined(separator: ", "))."
    }
}

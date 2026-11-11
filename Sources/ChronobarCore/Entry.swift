import Foundation

/// One stretch of tracked time on one Day for one Project.
public enum Entry: Equatable, Sendable {
    /// `end` is nil while the Entry runs; at most one per Project is open.
    case timed(project: String, start: Date, end: Date?, source: EntrySource = .app)
    /// A signed number of seconds from a typed duration or an adjustment.
    case manual(project: String, seconds: Int, note: ManualNote)

    public var project: String {
        switch self {
        case .timed(let project, _, _, _), .manual(let project, _, _): project
        }
    }

    /// The timer this Entry is, if it's still open.
    var openTimer: Running? {
        if case .timed(let project, let start, nil, let source) = self {
            return Running(project: project, start: start, source: source)
        }
        return nil
    }

    /// This Entry ended at `end` if it's open, else unchanged.
    func closed(at end: Date) -> Entry {
        guard let timer = openTimer else { return self }
        return .timed(project: timer.project, start: timer.start, end: end, source: timer.source)
    }

    /// This Entry filed under `project` instead, its time and Source unchanged.
    func relabeled(_ project: String) -> Entry {
        switch self {
        case .timed(_, let start, let end, let source): .timed(project: project, start: start, end: end, source: source)
        case .manual(_, let seconds, let note): .manual(project: project, seconds: seconds, note: note)
        }
    }

    /// Seconds this Entry counts, with a running Entry counted up to `now`.
    func seconds(asOf now: Date) -> TimeInterval {
        switch self {
        case .timed(_, let start, let end, _): max(0, (end ?? now).timeIntervalSince(start))
        case .manual(_, let seconds, _): TimeInterval(seconds)
        }
    }
}

/// Who started a timed Entry, so idle handling and crash recovery can tell the two apart.
public enum EntrySource: String, Codable, Sendable {
    /// The Pill, the Panel or the global shortcut. A Day file Entry without a `source` is one of these.
    case app
    /// MCP or the command line.
    case agent
}

/// The fixed marker on a manual Entry. Not a user note.
public enum ManualNote: String, Sendable {
    case manual
    case adjustment
}

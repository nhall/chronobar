import Foundation

/// One stretch of tracked time on one Day for one Project.
public enum Entry: Equatable, Sendable {
    /// `end` is nil only for the single running Entry.
    case timed(project: String, start: Date, end: Date?)
    /// A signed number of seconds from a typed duration or an adjustment.
    case manual(project: String, seconds: Int, note: ManualNote)

    public var project: String {
        switch self {
        case .timed(let project, _, _), .manual(let project, _, _): project
        }
    }

    /// Seconds this Entry counts, with a running Entry counted up to `now`.
    func seconds(asOf now: Date) -> TimeInterval {
        switch self {
        case .timed(_, let start, let end): max(0, (end ?? now).timeIntervalSince(start))
        case .manual(_, let seconds, _): TimeInterval(seconds)
        }
    }
}

/// The fixed marker on a manual Entry. Not a user note.
public enum ManualNote: String, Sendable {
    case manual
    case adjustment
}

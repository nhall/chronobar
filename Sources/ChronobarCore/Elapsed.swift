import Foundation

extension Entry {
    /// The clock time covered by at least one of `entries`' timed Entries, a running one counted up to
    /// `now`: the length of the union of their intervals. Manual Entries don't count.
    static func elapsed(_ entries: [Entry], asOf now: Date) -> TimeInterval {
        let intervals = entries.compactMap { entry -> (start: Date, end: Date)? in
            guard case .timed(_, let start, let stored, _) = entry else { return nil }
            let end = stored ?? now
            return end > start ? (start, end) : nil
        }.sorted { $0.start < $1.start }
        var total: TimeInterval = 0
        var covered: (start: Date, end: Date)?
        for interval in intervals {
            if let current = covered, interval.start <= current.end {
                covered = (current.start, max(current.end, interval.end))
            } else {
                if let current = covered { total += current.end.timeIntervalSince(current.start) }
                covered = interval
            }
        }
        if let current = covered { total += current.end.timeIntervalSince(current.start) }
        return total
    }
}

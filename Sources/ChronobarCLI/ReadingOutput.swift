import ChronobarOperations

/// The text for the reading and list operations.
extension Output {
    /// A Day's rows, then its totals.
    static func rows(_ result: DayRowsResult) -> String {
        var lines = [result.day.date]
        if result.malformed {
            lines += ["  The Day file (days/\(result.day.date).json) isn't valid JSON; fix it by hand."]
        } else if result.rows.isEmpty {
            lines += ["  No time."]
        }
        lines += result.rows.map { row in
            "  \(row.label)  \(total(row.totalSeconds))\(row.running ? "  running" : "")"
        }
        lines += ["Total: \(total(result.day.totalSeconds)) · \(total(result.day.elapsedSeconds)) elapsed"]
        return lines.joined(separator: "\n")
    }

    /// The suggestions a line each, then what the query names if the suggestions leave it out.
    static func list(_ result: LabelsResult) -> String {
        var lines = result.labels.map { "\($0.label)\($0.pinned ? "  (pinned)" : "")" }
        switch result.match {
        case let match? where match.kind == .archived: lines += ["\(match.label ?? "") is archived; starting it brings it back."]
        case let match? where match.kind == .unused: lines += ["\(match.label ?? "") has no time in the last 30 days."]
        case let match? where match.kind == .new && lines.isEmpty: lines += ["No Label matches; starting it creates one."]
        case nil where lines.isEmpty: lines += ["No Labels yet."]
        default: break
        }
        return lines.joined(separator: "\n")
    }

    static func pinnedText(_ result: PinResult) -> String {
        result.alreadyPinned ? "\(result.label) was already pinned." : "Pinned \(result.label)."
    }

    static func archivedText(_ result: ArchiveResult) -> String {
        var text = result.alreadyArchived ? "\(result.label) was already archived." : "Archived \(result.label)."
        if result.running { text += " Its timer is still running." }
        return text
    }

    /// The Time Summary, a line per period.
    static func periods(_ summary: SummaryResult) -> String {
        [("Today", summary.today), ("Yesterday", summary.yesterday), ("This week", summary.week),
         ("This month", summary.month)].map { name, period in
            let days = period.first == period.last ? period.first : "\(period.first) to \(period.last)"
            return "\(name): \(total(period.totalSeconds)) · \(total(period.elapsedSeconds)) elapsed  (\(days))"
        }.joined(separator: "\n")
    }
}

import Foundation
import ChronobarCore
import ChronobarOperations

/// The text for the reading and list operations.
extension Output {
    /// A Day's rows, then its totals. The rows' minutes add up to the total (`RowMinutes`).
    static func rows(_ result: DayRowsResult) -> String {
        var lines = [result.day.date]
        if result.malformed {
            lines += ["  The Day file (days/\(result.day.date).json) isn't valid JSON; fix it by hand."]
        } else if result.rows.isEmpty {
            lines += ["  No time."]
        }
        let minutes = RowMinutes(seconds: result.rows.map { TimeInterval($0.totalSeconds) }).rows
        lines += zip(result.rows, minutes).map { row, minutes in
            "  \(row.label)  \(DurationFormat.hoursMinutes(minutes: minutes))\(row.running ? "  running" : "")"
        }
        lines += [totals(result.day.totalSeconds, clockTime: result.day.elapsedSeconds)]
        return lines.joined(separator: "\n")
    }

    /// A week's Days with their totals, then each Label's week total, then the week's totals.
    static func weekText(_ result: WeekResult) -> String {
        var lines = ["Week of \(result.first) to \(result.last)"]
        // Each Day line is the Day's own total, as `day` and the Panel show it. The week total is the sum
        // of the Day lines, and so is its clock time; the Labels' lines add up to the week total.
        lines += result.days.map { day in
            let malformed = result.malformed.contains(day.date) ? "  (Day file isn't valid JSON)" : ""
            return "  \(day.date)  \(totals(day.totalSeconds, clockTime: day.elapsedSeconds))\(malformed)"
        }
        let weekMinutes = result.days.map { $0.totalSeconds / 60 }.reduce(0, +)
        let weekClockMinutes = result.days.map { $0.elapsedSeconds / 60 }.reduce(0, +)
        let labelMinutes = RowMinutes(seconds: result.labels.map { TimeInterval($0.totalSeconds) },
                                      total: weekMinutes).rows
        lines += ["Labels:"] + (result.labels.isEmpty ? ["  No time."] : zip(result.labels, labelMinutes).map {
            label, minutes in "  \(label.label)  \(DurationFormat.hoursMinutes(minutes: minutes))"
        })
        lines += [totals(weekMinutes * 60, clockTime: weekClockMinutes * 60)]
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
            return "\(totals(period.totalSeconds, clockTime: period.elapsedSeconds, name: name))  (\(days))"
        }.joined(separator: "\n")
    }
}

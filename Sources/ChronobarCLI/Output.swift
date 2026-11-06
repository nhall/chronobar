import Foundation
import ChronobarCore
import ChronobarOperations

/// The readable text for a result: times in local `HH:MM`, totals in `H:MM` as the Panel shows them.
enum Output {
    static func text(_ result: OperationResult) -> String {
        switch result {
        case .status(let status):
            let timers = status.timers.isEmpty ? "Nothing running." : "Running:\n" + list(status.timers)
            return timers + "\n" + day(status.today)
        case .start(let started):
            let timer = started.timer
            var lines = [started.alreadyRunning
                ? "\(timer.label) was already running, since \(clock(timer.start)) (\(total(timer.totalSeconds)) today)."
                : "Started \(timer.label) at \(clock(timer.start))."]
            lines += started.paused.map(paused)
            return (lines + [day(started.today)]).joined(separator: "\n")
        case .stop(let stopped):
            let entry = stopped.entry
            var lines = ["Stopped \(entry.label) at \(clock(entry.end)), started \(clock(entry.start)) "
                         + "(\(total(entry.totalSeconds)) today)."]
            if !stopped.running.isEmpty { lines += ["Still running:", list(stopped.running)] }
            return (lines + [day(stopped.today)]).joined(separator: "\n")
        case .day(let day): return rows(day)
        case .summary(let summary): return periods(summary)
        case .labels(let labels): return list(labels)
        case .pin(let pinned): return pinnedText(pinned)
        case .archive(let archived): return archivedText(archived)
        }
    }

    private static func list(_ timers: [TimerResult]) -> String {
        timers.map { timer in
            let by = timer.source == .agent ? ", started by an agent" : ""
            return "  \(timer.label)  \(total(timer.totalSeconds))  since \(clock(timer.start))\(by)"
        }.joined(separator: "\n")
    }

    private static func paused(_ entry: EntryResult) -> String {
        "Paused \(entry.label) at \(clock(entry.end)) (\(total(entry.totalSeconds)) today)."
    }

    private static func day(_ day: DayResult) -> String {
        "Today: \(total(day.totalSeconds)) · \(total(day.elapsedSeconds)) elapsed"
    }

    static func total(_ seconds: Int) -> String { DurationFormat.hoursMinutes(TimeInterval(seconds)) }

    private static func clock(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "en_GB")).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }
}

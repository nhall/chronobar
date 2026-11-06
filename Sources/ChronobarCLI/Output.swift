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
        case .setStart(let moved):
            let timer = moved.timer
            let start = moved.earlier.first?.start ?? timer.start
            var lines = ["\(timer.label) now started at \(clock(start))\(onDay(start)) (\(total(timer.totalSeconds)) today)."]
            lines += moved.earlier.map { "  \(entry($0)) on \(date($0.start))" }
            return (lines + [day(moved.today)]).joined(separator: "\n")
        case .addEntry(let added):
            var lines: [String]
            if let manual = added.manual {
                lines = ["Added \(total(manual.seconds)) to \(added.label) on \(manual.date) "
                         + "(\(total(manual.totalSeconds)) that day)."]
            } else {
                lines = ["Added \(added.label):"] + added.entries.map { "  \(entry($0)) on \(date($0.start))" }
            }
            return (lines + added.days.map(day)).joined(separator: "\n")
        case .adjust(let adjusted):
            let change = adjusted.changeSeconds == 0 ? "unchanged"
                : (adjusted.changeSeconds > 0 ? "+" : "-") + total(abs(adjusted.changeSeconds))
            return "\(adjusted.label) on \(adjusted.date): \(total(adjusted.totalSeconds)) (\(change)).\n"
                + day(adjusted.day)
        }
    }

    /// "09:00–10:15 (1:15 that day)" for a finished Entry.
    private static func entry(_ entry: EntryResult) -> String {
        "\(clock(entry.start))–\(clock(entry.end)) (\(total(entry.totalSeconds)) that day)"
    }

    /// " on YYYY-MM-DD" for a time before today, else "".
    private static func onDay(_ time: Date) -> String {
        Calendar.current.isDateInToday(time) ? "" : " on \(date(time))"
    }

    private static func date(_ time: Date) -> String {
        time.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
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
        let name = day.date == date(Date()) ? "Today" : day.date
        return "\(name): \(total(day.totalSeconds)) · \(total(day.elapsedSeconds)) elapsed"
    }

    private static func total(_ seconds: Int) -> String { DurationFormat.hoursMinutes(TimeInterval(seconds)) }

    private static func clock(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "en_GB")).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }
}

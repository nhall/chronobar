import Foundation
import ChronobarCore

/// The one request/response API the `chronobar` command and MCP share: named operations mapped to Core,
/// answering with structured results and errors. Runs in the app, the only writer of the data folder;
/// `ChannelServer` brings it requests from the socket. Timers it starts are the `agent`'s.
@MainActor
public final class Operations {
    let tracker: Tracker

    public init(tracker: Tracker) {
        self.tracker = tracker
    }

    /// The time zone the Day files' times are written in, and so the results'.
    var timeZone: TimeZone { tracker.calendar.timeZone }

    /// Carries out `request`. Never throws: anything Core refuses comes back as an `OperationError`.
    public func perform(_ request: Request) -> Response {
        // As when the Panel opens: roll over past midnight first, then pick up hand edits to today's file
        // and the Label lists.
        tracker.tick()
        tracker.reload()
        do throws(OperationError) {
            switch request {
            case .status: return .success(.status(status()))
            case .start(let label): return .success(.start(try start(label)))
            case .stop(let label, nil): return .success(.stop(try stop(label)))
            case .stop(let label, let end?): return .success(.stop(try stop(label, at: end)))
            case .setStart(let label, let start): return .success(.setStart(try setStart(label, at: start)))
            case .addEntry(let label, let span): return .success(.addEntry(try addEntry(label, span)))
            case .adjust(let label, let input, let date): return .success(.adjust(try adjust(label, input, on: date)))
            case .day(let date): return .success(.day(try day(date)))
            case .week(let date): return .success(.week(try week(date)))
            case .summary: return .success(.summary(summary()))
            case .labels(let query): return .success(.labels(labels(query)))
            case .pin(let label): return .success(.pin(try pin(label)))
            case .archive(let label): return .success(.archive(try archive(label)))
            }
        } catch {
            return .failure(error)
        }
    }

    private func status() -> StatusResult {
        StatusResult(timers: runningTimers(), today: todayResult())
    }

    private func start(_ label: String) throws(OperationError) -> StartResult {
        let before = tracker.timers
        let project = try core { try tracker.start(label, source: .agent) }
        let paused = before.filter { !tracker.isRunning($0.project) }.map { closed($0, at: tracker.now) }
        guard let timer = runningTimers().first(where: { ProjectName.matches($0.label, project) }) else {
            throw OperationError(.failed, "\(project) didn't start.")
        }
        return StartResult(timer: timer, alreadyRunning: before.contains(project), paused: paused,
                           today: todayResult())
    }

    private func stop(_ label: String?) throws(OperationError) -> StopResult {
        let label = try namedOrOnlyRunning(label)
        guard let timer = try core({ try tracker.pause(label) }) else {
            throw OperationError(.notRunning, "\(label) isn't running.\(runningList())", running: runningTimers())
        }
        return StopResult(entry: closed(timer, at: tracker.now), running: runningTimers(), today: todayResult())
    }

    /// `label` trimmed; refused if that leaves nothing.
    func named(_ label: String) throws(OperationError) -> String {
        let label = ProjectName.trimmed(label)
        guard !label.isEmpty else { throw emptyLabel }
        return label
    }

    /// `label` trimmed, or for a request that names none, the Label of the one running timer. `verb` says
    /// what the request would do to it, for the error with several running.
    func namedOrOnlyRunning(_ label: String?, to verb: String = "stop") throws(OperationError) -> String {
        if let label { return try named(label) }
        let running = runningTimers()
        return try UnnamedTimer.label(among: running, running: running, to: verb)
    }

    /// " Running: A, B." naming the running timers, or "" with none.
    func runningList() -> String { UnnamedTimer.runningList(runningTimers()) }

    private var emptyLabel: OperationError {
        OperationError(.invalidLabel, "The Label is empty. Give the timer a name.")
    }

    /// `timer` as the Entry it became when it stopped at `end`.
    func closed(_ timer: Running, at end: Date) -> EntryResult {
        EntryResult(label: timer.project, start: timer.start, end: end, source: timer.source,
                    totalSeconds: totalSeconds(timer.project, on: tracker.today))
    }

    /// Runs a Core call, turning what it throws into an `OperationError`.
    func core<T>(_ call: () throws -> T) throws(OperationError) -> T {
        do {
            return try call()
        } catch is EmptyProjectName {
            throw emptyLabel
        } catch let error as MalformedDayFile {
            throw malformed(error.day)
        } catch is MalformedFileError {
            throw malformed()
        } catch {
            throw correctionError(error)
                ?? OperationError(.failed, "Chronobar couldn't save the change: \(error.localizedDescription)")
        }
    }

    /// Which file is malformed: `day`'s Day file, else today's, else one of the Label lists.
    private func malformed(_ day: Day? = nil) -> OperationError {
        let day = day ?? (tracker.isMalformed(tracker.today) ? tracker.today : nil)
        let file = if let day {
            day == tracker.today
                ? "Today's Day file (days/\(day).json) isn't valid JSON"
                : "The Day file days/\(day).json isn't valid JSON"
        } else {
            "projects.txt or archived.txt isn't UTF-8 text"
        }
        return OperationError(.malformedFile, "\(file), so Chronobar won't change it. Fix it by hand, then try again.")
    }

    func runningTimers() -> [TimerResult] {
        tracker.timers.map { timer in
            TimerResult(label: timer.project, start: timer.start, source: timer.source,
                        totalSeconds: totalSeconds(timer.project, on: tracker.today))
        }
    }

    func todayResult() -> DayResult { dayResult(tracker.today) }

    /// `label`'s total on `day` in whole seconds.
    func totalSeconds(_ label: String, on day: Day) -> Int { seconds(tracker.total(label, on: day)) }

    /// Whole seconds, rounded down like every total Chronobar shows.
    func seconds(_ interval: TimeInterval) -> Int { Int(interval.rounded(.down)) }
}

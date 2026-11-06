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
            case .stop(let label): return .success(.stop(try stop(label)))
            case .day(let date): return .success(.day(try day(date)))
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
        let label = if let label { try named(label) } else { try onlyRunningLabel() }
        guard let timer = try core({ try tracker.pause(label) }) else {
            throw OperationError(.notRunning, "\(label) isn't running.\(runningList())", running: runningTimers())
        }
        return StopResult(entry: closed(timer, at: tracker.now), running: runningTimers(), today: todayResult())
    }

    /// `label` trimmed; refused if that leaves nothing.
    private func named(_ label: String) throws(OperationError) -> String {
        let label = ProjectName.trimmed(label)
        guard !label.isEmpty else { throw emptyLabel }
        return label
    }

    /// The Label of the one running timer, for a request that names none.
    private func onlyRunningLabel() throws(OperationError) -> String {
        switch tracker.timers.count {
        case 0: throw OperationError(.nothingRunning, "No timer is running.", running: [])
        case 1: return tracker.timers[0].project
        default:
            throw OperationError(.ambiguous, "\(tracker.timers.count) timers are running, so say which to stop."
                                 + runningList(), running: runningTimers())
        }
    }

    /// " Running: A, B." naming the running timers, or "" with none.
    private func runningList() -> String {
        tracker.timers.isEmpty ? "" : " Running: \(tracker.timers.map(\.project).joined(separator: ", "))."
    }

    private var emptyLabel: OperationError {
        OperationError(.invalidLabel, "The Label is empty. Give the timer a name.")
    }

    /// `timer` as the Entry it became when it stopped at `end`.
    private func closed(_ timer: Running, at end: Date) -> EntryResult {
        EntryResult(label: timer.project, start: timer.start, end: end, source: timer.source,
                    totalSeconds: seconds(tracker.total(timer.project, on: tracker.today)))
    }

    /// Runs a Core call, turning what it throws into an `OperationError`.
    func core<T>(_ call: () throws -> T) throws(OperationError) -> T {
        do {
            return try call()
        } catch is EmptyProjectName {
            throw emptyLabel
        } catch is MalformedFileError {
            throw malformed()
        } catch {
            throw OperationError(.failed, "Chronobar couldn't save the change: \(error.localizedDescription)")
        }
    }

    /// Which file is malformed: today's Day file, else one of the Label lists.
    private func malformed() -> OperationError {
        let file = tracker.isMalformed(tracker.today)
            ? "Today's Day file (days/\(tracker.today).json) isn't valid JSON"
            : "projects.txt or archived.txt isn't UTF-8 text"
        return OperationError(.malformedFile, "\(file), so Chronobar won't change it. Fix it by hand, then try again.")
    }

    private func runningTimers() -> [TimerResult] {
        tracker.timers.map { timer in
            TimerResult(label: timer.project, start: timer.start, source: timer.source,
                        totalSeconds: seconds(tracker.total(timer.project, on: tracker.today)))
        }
    }

    private func todayResult() -> DayResult {
        let today = tracker.today
        return DayResult(date: today.description, totalSeconds: seconds(tracker.dayTotal(today)),
                         elapsedSeconds: seconds(tracker.elapsed(today)))
    }

    /// Whole seconds, rounded down like every total Chronobar shows.
    func seconds(_ interval: TimeInterval) -> Int { Int(interval.rounded(.down)) }
}

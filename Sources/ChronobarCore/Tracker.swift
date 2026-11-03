import Foundation
import Observation

/// The running timer.
public struct Running: Equatable, Sendable {
    public let project: String
    public let start: Date
}

/// Core's single entry point: the timer, totals and the Day files behind them.
@MainActor @Observable
public final class Tracker {
    public private(set) var running: Running?
    public private(set) var selectedProject: String?
    /// The clock's time at the last command or `tick()`. Totals of a running timer count up to here.
    public private(set) var now: Date

    @ObservationIgnored private let clock: TimeSource
    private var todayEntries: [Entry] = []

    public init(clock: TimeSource, storageRoot: URL) throws {
        self.clock = clock
        self.now = clock.now
    }

    public var today: Day { Day(containing: now, in: clock.calendar) }

    public func start(_ project: String) throws {
        now = clock.now
        todayEntries.append(.timed(project: project, start: now, end: nil))
        running = Running(project: project, start: now)
        selectedProject = project
    }

    public func pause() throws {
        now = clock.now
        guard let running else { return }
        todayEntries = todayEntries.map { entry in
            if case .timed(let project, let start, nil) = entry {
                return .timed(project: project, start: start, end: now)
            }
            return entry
        }
        self.running = nil
    }

    /// Pauses the running timer, or starts the Selected Project. Does nothing with no Selected Project;
    /// the UI opens the ＋ form instead.
    public func toggle() throws {
        if running != nil {
            try pause()
        } else if let selectedProject {
            try start(selectedProject)
        }
    }

    /// Called every second by the UI so running totals advance.
    public func tick() {
        now = clock.now
    }

    /// The Project's total on `day`, never below zero.
    public func total(_ project: String, on day: Day) -> TimeInterval {
        let raw = todayEntries
            .filter { $0.project == project }
            .reduce(0) { $0 + $1.seconds(asOf: now) }
        return max(0, raw)
    }
}

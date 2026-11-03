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
    @ObservationIgnored private let store: DayStore
    private var todayEntries: [Entry] = []
    /// The Day `todayEntries` came from. It lags `today` from midnight until the next `tick()` or command.
    @ObservationIgnored private var loadedDay: Day

    /// Reads today's file. An open Entry there is the running timer, so a timer survives a relaunch.
    public init(clock: TimeSource, storageRoot: URL) {
        self.clock = clock
        self.store = DayStore(root: storageRoot)
        self.now = clock.now
        self.loadedDay = Day(containing: clock.now, in: clock.calendar)
        reload()
    }

    /// Re-reads today's file. A file that won't parse reads as empty; writes to it are refused.
    public func reload() {
        now = clock.now
        loadedDay = today
        todayEntries = (try? store.load(today)) ?? []
        running = todayEntries.lazy.compactMap { entry -> Running? in
            if case .timed(let project, let start, nil) = entry { return Running(project: project, start: start) }
            return nil
        }.first
        if let running { selectedProject = running.project }
    }

    public var today: Day { Day(containing: now, in: clock.calendar) }

    /// Starts a timer for `project`, pausing any running one first.
    public func start(_ project: String) throws {
        try pause()
        try updateToday { $0.append(.timed(project: project, start: now, end: nil)) }
        running = Running(project: project, start: now)
        selectedProject = project
    }

    public func pause() throws {
        now = clock.now
        rollOver()
        guard running != nil else { return }
        try updateToday { Self.close(&$0, at: now) }
        running = nil
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

    /// Called every second by the UI so running totals advance, and on wake. Rolls over to a new Day.
    public func tick() {
        now = clock.now
        rollOver()
    }

    /// The Project's total on `day`, never below zero.
    public func total(_ project: String, on day: Day) -> TimeInterval {
        let raw = todayEntries
            .filter { $0.project == project }
            .reduce(0) { $0 + $1.seconds(asOf: now) }
        return max(0, raw)
    }

    /// After midnight, splits a running timer at the start of each new Day so every Day's file holds only
    /// that Day's time, then loads today. A file that won't parse keeps its open Entry (#9 retries).
    private func rollOver() {
        guard loadedDay != today else { return }
        while let running, loadedDay < today {
            let midnight = clock.calendar.dateInterval(of: .day, for: running.start)!.end
            let next = Day(containing: midnight, in: clock.calendar)
            try? update(loadedDay) { Self.close(&$0, at: midnight) }
            try? update(next) { $0.append(.timed(project: running.project, start: midnight, end: nil)) }
            loadedDay = next
            self.running = Running(project: running.project, start: midnight)
        }
        reload()
    }

    /// Ends every open Entry at `end`.
    private static func close(_ entries: inout [Entry], at end: Date) {
        entries = entries.map { entry in
            if case .timed(let project, let start, nil) = entry {
                return .timed(project: project, start: start, end: end)
            }
            return entry
        }
    }

    private func updateToday(_ change: (inout [Entry]) -> Void) throws {
        try update(today, change)
    }

    /// Re-reads `day`'s file, applies `change` and writes it back.
    private func update(_ day: Day, _ change: (inout [Entry]) -> Void) throws {
        var entries = try store.load(day)
        change(&entries)
        try store.save(day, entries, timeZone: clock.calendar.timeZone)
        todayEntries = entries
    }
}

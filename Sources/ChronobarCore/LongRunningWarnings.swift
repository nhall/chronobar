import Foundation

/// The runs already given a Long-running warning, saved in the settings store so a relaunch doesn't warn
/// about them again. Tracker asks it on each tick which runs are now due one.
struct LongRunningWarnings {
    /// The runs warned about that were still running when last asked.
    private var warned: [TimerRun]
    /// Each warned run relabeled since its warning, to the run it goes on as now.
    private var shown: [TimerRun: TimerRun] = [:]
    private let defaults: UserDefaults?

    /// The key the warned runs have always been saved under, so warnings given before an upgrade stay given.
    private static let key = "longRunningWarned"

    /// Reads the runs warned about before the last quit.
    init(defaults: UserDefaults?) {
        self.defaults = defaults
        let saved = defaults?.array(forKey: Self.key) as? [[String: Any]] ?? []
        warned = saved.compactMap { run in
            guard let project = run["project"] as? String, let since = run["since"] as? Date else { return nil }
            return TimerRun(project: project, since: since)
        }
    }

    /// The runs in `running` that have run for `threshold` by `now` and weren't warned about yet, marked
    /// warned so each is returned once. Runs no longer running are forgotten, since a run never starts
    /// again. Nothing is due while `threshold` is nil (Off).
    mutating func due(among running: [TimerRun], at now: Date, threshold: TimeInterval?) -> [TimerRun] {
        guard let threshold else { return [] }
        let passed = running.filter { now.timeIntervalSince($0.since) >= threshold && !warned.contains($0) }
        guard !passed.isEmpty else { return [] }
        warned = warned.filter(running.contains) + passed
        save()
        return passed
    }

    /// `run` goes on as `new`, as when its Timer was relabeled: if `run` was warned about, `new` counts as
    /// warned about too, so it isn't warned about again, and a warning shown for it now stands for `new`.
    mutating func rekey(_ run: TimerRun, to new: TimerRun) {
        guard run != new, let index = warned.firstIndex(of: run) else { return }
        warned[index] = new
        save()
        shown = shown.mapValues { $0 == run ? new : $0 }
        shown[run] = new
        shown = shown.filter { $0.key != $0.value }
    }

    /// The run a warning shown for `run` now stands for: `run` itself, or the run it went on as through
    /// relabels since. Remembered until quit; a warning still on screen after a relaunch stands for its
    /// own run only.
    func current(_ run: TimerRun) -> TimerRun { shown[run] ?? run }

    /// Writes the warned runs to the settings store, for the next launch.
    private func save() {
        defaults?.set(warned.map { ["project": $0.project, "since": $0.since] }, forKey: Self.key)
    }
}

import Foundation

/// Who has been given the long-running warning: the runs already warned about, saved in the settings store
/// so a relaunch doesn't warn about them again. Tracker asks it on each tick which runs are now due.
struct LongRunningWarnings {
    /// The runs warned about that were still running when last asked.
    private var warned: [LongRunning]
    private let defaults: UserDefaults?

    /// The key the warned runs have always been saved under, so warnings given before an upgrade stay given.
    private static let key = "longRunningWarned"

    /// Reads the runs warned about before the last quit.
    init(defaults: UserDefaults?) {
        self.defaults = defaults
        let saved = defaults?.array(forKey: Self.key) as? [[String: Any]] ?? []
        warned = saved.compactMap { run in
            guard let project = run["project"] as? String, let since = run["since"] as? Date else { return nil }
            return LongRunning(project: project, since: since)
        }
    }

    /// The runs in `running` that have run for `threshold` by `now` and weren't warned about yet, marked
    /// warned so each is returned once. Runs no longer running are forgotten, since a run never starts
    /// again. Nothing is due while `threshold` is nil (Off).
    mutating func due(among running: [LongRunning], at now: Date, threshold: TimeInterval?) -> [LongRunning] {
        guard let threshold else { return [] }
        let passed = running.filter { now.timeIntervalSince($0.since) >= threshold && !warned.contains($0) }
        guard !passed.isEmpty else { return [] }
        warned = warned.filter(running.contains) + passed
        defaults?.set(warned.map { ["project": $0.project, "since": $0.since] }, forKey: Self.key)
        return passed
    }
}

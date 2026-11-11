/// What a relabel stored: the old Label and the new one, as stored, the Day, the new Label's timed Entries
/// there, oldest first, its Total on that Day, floored to whole seconds as Chronobar shows it, and its Timer
/// if one runs. After a merge, those Entries and that Total include the time the new Label had already.
/// Relabeling to the same Label with the same spelling stores nothing and returns the row as it was.
public struct Relabeling: Equatable, Sendable {
    /// The old Label as its row showed it, so a caller can follow a Timer it knew by that Label.
    public let oldProject: String
    public let project: String
    public let day: Day
    /// Every timed Entry of the new Label on the Day, moved or already its own, a running Timer's open one
    /// ending at nil; manual ones and adjustments count only in `total`.
    public let entries: [TimedEntry]
    /// Whole seconds.
    public let total: Int
    /// The new Label's running Timer: a relabeled running row's, with its start and Source kept.
    public let timer: Running?

    public init(oldProject: String, project: String, day: Day, entries: [TimedEntry], total: Int,
                timer: Running? = nil) {
        self.oldProject = oldProject
        self.project = project
        self.day = day
        self.entries = entries
        self.total = total
        self.timer = timer
    }
}

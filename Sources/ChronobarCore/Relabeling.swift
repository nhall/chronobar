/// What a relabel stored: the new Label, as stored, the Day, the timed Entries it moved there, oldest
/// first, the new Label's Total on that Day, floored to whole seconds as Chronobar shows it, and its Timer
/// if one runs. Relabeling to the same Label with the same spelling stores nothing and returns the row as
/// it was.
public struct Relabeling: Equatable, Sendable {
    public let project: String
    public let day: Day
    /// The moved timed Entries, a running Timer's open one ending at nil; manual ones and adjustments
    /// count only in `total`.
    public let entries: [TimedEntry]
    /// Whole seconds.
    public let total: Int
    /// The new Label's running Timer: a relabeled running row's, with its start and Source kept.
    public let timer: Running?

    public init(project: String, day: Day, entries: [TimedEntry], total: Int, timer: Running? = nil) {
        self.project = project
        self.day = day
        self.entries = entries
        self.total = total
        self.timer = timer
    }
}

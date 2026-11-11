/// What a row's Label field says while the typed name is another row's Label on the viewed Day: Return
/// would merge the two rows, which relabeling back can't undo, so the field warns first. "merges with
/// Northwind (1:00)".
public struct MergeHint: Equatable, Sendable {
    /// The row the edited one would merge into, as the Panel shows it.
    public let project: String
    /// That row's total as the Panel shows it: "1:00".
    public let total: String

    public var text: String { "merges with \(project) (\(total))" }

    public init(project: String, total: String) {
        self.project = project
        self.total = total
    }

    /// The row of `rows` that `typed` names, matched as Labels are (capitals and surrounding spaces aside);
    /// nil if none does, or if it names `editing`, the row being relabeled, which is never a merge.
    public init?(typed: String, editing: String, rows: [DaySheet.Row]) {
        guard !ProjectName.matches(typed, editing),
              let row = rows.first(where: { ProjectName.matches($0.project, typed) }) else { return nil }
        self.init(project: row.project, total: DurationFormat.hoursMinutes(minutes: row.time.minutes))
    }
}

/// Whether the ＋ form shows the Projects matching its Project field. Picking a suggestion hides them;
/// any other change to the field shows them again.
public struct SuggestionVisibility: Equatable, Sendable {
    public private(set) var isShown = true
    private var picked: String?

    public init() {}

    /// A suggestion was clicked: the field now holds it, so the suggestions hide.
    public mutating func pick(_ project: String) {
        picked = project
        isShown = false
    }

    /// The Project field changed to `name`, whether by typing or by a pick filling it in.
    public mutating func nameChanged(to name: String) {
        guard name != picked else { return }
        picked = nil
        isShown = true
    }
}

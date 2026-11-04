/// Whether the ＋ form lists the Projects matching what's typed in its Project field. Picking a suggestion
/// closes the list; typing anything else in the field reopens it.
public struct SuggestionList: Equatable, Sendable {
    public private(set) var isOpen = true
    private var picked: String?

    public init() {}

    /// A suggestion was clicked: the field now holds it, so the list closes.
    public mutating func pick(_ project: String) {
        picked = project
        isOpen = false
    }

    /// The Project field changed to `text`, whether by typing or by the pick filling it in.
    public mutating func typed(_ text: String) {
        guard text != picked else { return }
        picked = nil
        isOpen = true
    }
}

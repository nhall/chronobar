/// The list of suggested Labels under the ＋ form's Label field: which names it shows, whether it is open
/// and which name is highlighted. The app draws it; this decides what typing, a key or a click does.
public struct SuggestionList: Equatable, Sendable {
    /// The suggestions for `filter`, in the order `Tracker.suggestions(for:)` ranks them.
    public private(set) var items: [String] = []
    public private(set) var isOpen = false
    /// The index in `items` of the name ↓ and ↑ moved to, if any.
    public private(set) var highlighted: Int?
    /// What was last typed or set: the suggestions are for it. Moving through the list shows other names
    /// in the field but keeps this.
    public private(set) var filter = ""

    public init() {}

    /// Text was typed into the field: `suggestions` are the suggestions for it. The list opens while
    /// anything matches what isn't blank, and closes otherwise. Nothing is highlighted, so Return acts on
    /// what was typed.
    public mutating func typed(_ text: String, suggestions: [String]) {
        filter = text
        items = suggestions
        highlighted = nil
        isOpen = !ProjectName.trimmed(text).isEmpty && !items.isEmpty
    }

    /// The form set the field's text (emptied it after Start, Log or Archive): `suggestions` are the
    /// suggestions for it, and it is the new filter. The list stays open or closed, unless emptied.
    public mutating func set(_ text: String, suggestions: [String]) {
        filter = text
        items = suggestions
        highlighted = nil
        if items.isEmpty { close() }
    }

    /// ▾ next to the field: opens the list with every suggestion for what was typed, or closes it.
    public mutating func toggle() {
        if isOpen { close() } else { isOpen = !items.isEmpty }
    }

    /// What VoiceOver says as ↓ and ↑ move, focus staying in the field: "Client B, 2 of 3".
    public var spokenHighlight: String? {
        highlighted.map { "\(items[$0]), \($0 + 1) of \(items.count)" }
    }

    /// The suggestions for what was typed changed under the list (a Label pinned or archived from it): the
    /// highlight stays on the name it was on, if still listed, and an emptied list closes.
    public mutating func reload(_ suggestions: [String]) {
        guard suggestions != items else { return }
        let name = highlighted.map { items[$0] }
        items = suggestions
        highlighted = name.flatMap(items.firstIndex(of:))
        if items.isEmpty { close() }
    }

    public enum Key: Equatable, Sendable {
        case down, up, `return`, escape
    }

    /// What the field does after a key.
    public enum Outcome: Equatable, Sendable {
        /// Not the list's key: the field or the Panel acts on it as usual.
        case ignored
        /// The list took the key and the field stays as it is.
        case handled
        /// The field shows this name, the list stays open.
        case show(String)
        /// The name was picked: the field holds it and the list has closed. Nothing starts yet.
        case pick(String)
        /// Return with nothing highlighted: the form's Start or Log.
        case submit
    }

    /// Closes the list, as when focus leaves the field.
    public mutating func close() {
        isOpen = false
        highlighted = nil
    }

    public mutating func press(_ key: Key) -> Outcome {
        switch key {
        case .down:
            if !isOpen {
                isOpen = !items.isEmpty
                return .handled
            }
            let next = highlighted.map { $0 + 1 } ?? 0
            guard items.indices.contains(next) else { return .handled }
            return highlight(next)
        case .up:
            guard isOpen else { return .ignored }
            guard let current = highlighted else { return .handled }
            return highlight(current == 0 ? nil : current - 1)
        case .return:
            let picked = highlighted.map { items[$0] }
            close()
            return picked.map(Outcome.pick) ?? .submit
        case .escape:
            guard isOpen else { return .ignored }
            close()
            return .handled
        }
    }

    /// The name on a row of the list, or nil for no row (a table's -1 for a click off its rows).
    public func label(atRow row: Int) -> String? {
        items.indices.contains(row) ? items[row] : nil
    }

    /// A click on a row picks its name, as Return on it does: returns the name for the field to hold.
    public mutating func click(row: Int) -> String? {
        guard let label = label(atRow: row) else { return nil }
        close()
        return label
    }

    /// An item of the menu a right-click on a row opens.
    public struct MenuItem: Equatable, Sendable {
        public enum Action: Equatable, Sendable { case pin, archive }
        public let action: Action
        public let label: String

        public var title: String {
            switch action {
            case .pin: "Pin “\(label)”"
            case .archive: "Archive “\(label)”"
            }
        }
    }

    /// The right-click menu for a row's Label: Pin unless it is pinned, then Archive.
    public static func menu(for label: String, isPinned: Bool) -> [MenuItem] {
        (isPinned ? [] : [MenuItem(action: .pin, label: label)]) + [MenuItem(action: .archive, label: label)]
    }

    /// Moves the highlight; the field shows the name, or what was typed with nothing highlighted.
    private mutating func highlight(_ index: Int?) -> Outcome {
        highlighted = index
        return .show(index.map { items[$0] } ?? filter)
    }
}

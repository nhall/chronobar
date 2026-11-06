import Foundation

/// What a key equivalent in the Panel does.
public enum PanelCommand: Equatable, Sendable {
    case previousWeek
    case nextWeek
    case previousDay
    case nextDay
    case today
    /// The ＋ form.
    case newProject
    /// The (i) Time Summary.
    case timeSummary

    /// The Day to view after this command from `viewed`, or nil for one that doesn't change the viewed Day.
    public func day(from viewed: Day, today: Day, calendar: Calendar) -> Day? {
        switch self {
        case .previousWeek: viewed.adding(days: -7, in: calendar)
        case .nextWeek: viewed.adding(days: 7, in: calendar)
        case .previousDay: viewed.adding(days: -1, in: calendar)
        case .nextDay: viewed.adding(days: 1, in: calendar)
        case .today: today
        case .newProject, .timeSummary: nil
        }
    }

    /// The command's key as menus write it: "⌘[" or "←".
    public var keyName: String {
        switch self {
        case .previousWeek: "⌘["
        case .nextWeek: "⌘]"
        case .previousDay: "←"
        case .nextDay: "→"
        case .today: "⌘T"
        case .newProject: "⌘N"
        case .timeSummary: "⌘I"
        }
    }

    /// A control's help tag, naming the key that does the same: "Previous week (⌘[)".
    public func help(_ text: String) -> String {
        "\(text) (\(keyName))"
    }
}

/// The Panel's key equivalents.
public enum PanelKey {
    /// A key as the Panel sees it, without its modifiers.
    public enum Key: Equatable, Sendable {
        case leftArrow
        case rightArrow
        /// The key's character ignoring modifiers, such as `t` or `[`.
        case character(String)

        /// Caps Lock capitalizes a letter even with ⌘ held.
        var lowercased: Key {
            if case .character(let character) = self { return .character(character.lowercased()) }
            return self
        }
    }

    public struct Modifiers: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let shift = Modifiers(rawValue: 1 << 1)
        public static let option = Modifiers(rawValue: 1 << 2)
        public static let control = Modifiers(rawValue: 1 << 3)
    }

    /// The command for `key` pressed with `modifiers`, or nil to let the key through. `editingText` is
    /// whether a text field has focus.
    public static func command(for key: Key, modifiers: Modifiers, editingText: Bool) -> PanelCommand? {
        switch (key.lowercased, modifiers) {
        case (.character("["), .command): .previousWeek
        case (.character("]"), .command): .nextWeek
        case (.character("t"), .command): .today
        case (.character("n"), .command): .newProject
        case (.character("i"), .command): .timeSummary
        case (.leftArrow, []) where !editingText: .previousDay
        case (.rightArrow, []) where !editingText: .nextDay
        default: nil
        }
    }
}

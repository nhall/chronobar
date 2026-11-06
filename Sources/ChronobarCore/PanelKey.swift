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

    /// What this command does to the Panel while it views `viewed`, nil following today.
    public func change(viewing viewed: Day?, today: Day, calendar: Calendar) -> PanelChange {
        let day = viewed ?? today
        return switch self {
        case .previousWeek: .viewing(day.adding(days: -7, in: calendar), today: today)
        case .nextWeek: .viewing(day.adding(days: 7, in: calendar), today: today)
        case .previousDay: .viewing(day.adding(days: -1, in: calendar), today: today)
        case .nextDay: .viewing(day.adding(days: 1, in: calendar), today: today)
        case .today: .view(nil)
        case .newProject: .openNewProject
        case .timeSummary: .toggleTimeSummary
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
        Self.help(text, keys: self)
    }

    /// A control's help tag naming several keys that do the same: "Move a Day (← →)".
    public static func help(_ text: String, keys commands: PanelCommand...) -> String {
        "\(text) (\(commands.map(\.keyName).joined(separator: " ")))"
    }
}

/// A change to what the Panel shows, from one of its key equivalents or controls.
public enum PanelChange: Equatable, Sendable {
    /// View this Day; nil follows today, including across midnight.
    case view(Day?)
    /// Open the ＋ form, with focus in its Project field.
    case openNewProject
    /// Open or close the (i) Time Summary.
    case toggleTimeSummary

    /// View `day`, past or future; today itself goes back to following the clock.
    public static func viewing(_ day: Day, today: Day) -> PanelChange {
        .view(day == today ? nil : day)
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

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

/// The Panel's key equivalents. Like a menu's, they follow the keyboard layout: ⌘[ is ⌘ with whatever
/// types `[`, such as ⌘⌥5 on German, and ⌘T is ⌘ with the key that types `t` there.
public enum PanelKey {
    /// The arrows' key codes (`kVK_LeftArrow`, `kVK_RightArrow`), the same keys on every layout.
    static let leftArrow: UInt16 = 0x7B
    static let rightArrow: UInt16 = 0x7C

    public struct Modifiers: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let shift = Modifiers(rawValue: 1 << 1)
        public static let option = Modifiers(rawValue: 1 << 2)
        public static let control = Modifiers(rawValue: 1 << 3)
    }

    /// What the key at a key code types on the keyboard layout in use with `Modifiers` held, ⌘ included,
    /// ignoring Caps Lock; nil or empty for nothing. With ⌘ held a layout can type something else, as
    /// Russian types US letters.
    public typealias Layout = (_ keyCode: UInt16, _ modifiers: Modifiers) -> String?

    /// The command for the key at `keyCode` pressed with `modifiers`, or nil to let the key through.
    /// `editingText` is whether a text field has focus.
    ///
    /// The ⌘ keys go by the character the press types, so ⇧ or ⌥ count when the layout needs them for
    /// that character and make it someone else's key when it doesn't: ⌘⌥5 is ⌘[ on German, while ⌘⇧T
    /// and ⌘⌥[ pass through on US even where the layout still types `t` or `[` with them held.
    public static func command(
        keyCode: UInt16, modifiers: Modifiers, layout: Layout, editingText: Bool
    ) -> PanelCommand? {
        switch (keyCode, modifiers) {
        case (leftArrow, []): return editingText ? nil : .previousDay
        case (rightArrow, []): return editingText ? nil : .nextDay
        default: break
        }
        guard modifiers.contains(.command), !modifiers.contains(.control),
              let character = layout(keyCode, modifiers) else { return nil }
        for modifier: Modifiers in [.shift, .option] where modifiers.contains(modifier) {
            if layout(keyCode, modifiers.subtracting(modifier)) == character { return nil }
        }
        return switch character {
        case "[": .previousWeek
        case "]": .nextWeek
        case "t": .today
        case "n": .newProject
        case "i": .timeSummary
        default: nil
        }
    }
}

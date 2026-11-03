import Foundation
import Observation

/// The color of the Pill's square, the today circle and the running row while a timer runs.
public enum RunningColor: String, CaseIterable, Sendable {
    /// Follows the accent color in System Settings.
    case accent
    case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, gray
}

/// The Settings window's choices, kept in `UserDefaults`.
@MainActor @Observable
public final class Preferences {
    public var runningColor: RunningColor {
        didSet { defaults.set(runningColor.rawValue, forKey: Keys.runningColor) }
    }
    public var showInDock: Bool {
        didSet { defaults.set(showInDock, forKey: Keys.showInDock) }
    }
    /// The Panel's one-time Start at login hint was dismissed or acted on.
    public var loginHintDismissed: Bool {
        didSet { defaults.set(loginHintDismissed, forKey: Keys.loginHintDismissed) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let runningColor = "runningColor"
        static let showInDock = "showInDock"
        static let loginHintDismissed = "loginHintDismissed"
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
        runningColor = defaults.string(forKey: Keys.runningColor).flatMap(RunningColor.init) ?? .accent
        showInDock = defaults.object(forKey: Keys.showInDock) as? Bool ?? true
        loginHintDismissed = defaults.bool(forKey: Keys.loginHintDismissed)
    }
}

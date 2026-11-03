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
    /// Whether a stretch with no keyboard or mouse input raises the idle alert. Sleep and lock always do.
    public var detectsInputIdle: Bool {
        didSet { defaults.set(detectsInputIdle, forKey: Keys.detectsInputIdle) }
    }
    /// Minutes without input before the idle alert, at least 1.
    public var idleThresholdMinutes: Int {
        didSet { defaults.set(idleThresholdMinutes, forKey: Keys.idleThresholdMinutes) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let runningColor = "runningColor"
        static let showInDock = "showInDock"
        static let loginHintDismissed = "loginHintDismissed"
        static let detectsInputIdle = "detectsInputIdle"
        static let idleThresholdMinutes = "idleThresholdMinutes"
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
        runningColor = defaults.string(forKey: Keys.runningColor).flatMap(RunningColor.init) ?? .accent
        showInDock = defaults.object(forKey: Keys.showInDock) as? Bool ?? true
        loginHintDismissed = defaults.bool(forKey: Keys.loginHintDismissed)
        detectsInputIdle = defaults.object(forKey: Keys.detectsInputIdle) as? Bool ?? true
        idleThresholdMinutes = (defaults.object(forKey: Keys.idleThresholdMinutes) as? Int).flatMap { $0 >= 1 ? $0 : nil } ?? 15
    }
}

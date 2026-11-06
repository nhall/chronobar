import Foundation
import Observation

/// The color of the Pill's square, the today circle and the running row while a timer runs.
public enum RunningColor: String, CaseIterable, Sendable {
    /// Follows the accent color in System Settings.
    case accent
    case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, gray
}

/// How long without keyboard or mouse input before the idle alert. Sleep and lock raise it either way.
public enum IdleThreshold: Hashable, Sendable {
    case off
    case minutes(Int)

    /// The Settings pop-up's choices, in menu order.
    public static let presets: [IdleThreshold] = [.off] + [5, 10, 15, 20, 30, 45, 60].map(minutes)
    public static let standard = IdleThreshold.minutes(15)

    /// nil when off.
    public var minutes: Int? {
        if case .minutes(let minutes) = self { minutes } else { nil }
    }

    /// The preset nearest a stored value, a tie going to the longer one. 0 or less is Off.
    public init(snapping minutes: Int) {
        guard minutes > 0 else { self = .off; return }
        let steps = Self.presets.compactMap(\.minutes)
        let nearest = steps.min { a, b in
            let (da, db) = (abs(a - minutes), abs(b - minutes))
            return da != db ? da < db : a > b
        }!
        self = .minutes(nearest)
    }
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
    /// Stored as minutes, 0 for Off. Saving drops the old on/off key so it can't turn detection back off.
    public var idleThreshold: IdleThreshold {
        didSet {
            defaults.set(idleThreshold.minutes ?? 0, forKey: Keys.idleThresholdMinutes)
            defaults.removeObject(forKey: Keys.detectsInputIdle)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let runningColor = "runningColor"
        static let showInDock = "showInDock"
        static let loginHintDismissed = "loginHintDismissed"
        /// Written by builds before the pop-up; false there means Off.
        static let detectsInputIdle = "detectsInputIdle"
        static let idleThresholdMinutes = "idleThresholdMinutes"
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
        runningColor = defaults.string(forKey: Keys.runningColor).flatMap(RunningColor.init) ?? .accent
        showInDock = defaults.object(forKey: Keys.showInDock) as? Bool ?? true
        loginHintDismissed = defaults.bool(forKey: Keys.loginHintDismissed)
        idleThreshold = if defaults.object(forKey: Keys.detectsInputIdle) as? Bool == false {
            .off
        } else {
            (defaults.object(forKey: Keys.idleThresholdMinutes) as? Int).map(IdleThreshold.init(snapping:)) ?? .standard
        }
    }
}

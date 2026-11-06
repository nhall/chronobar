/// How the app asks macOS to bring it to the front, under cooperative activation (macOS 14 and later).
///
/// macOS turns down a plain request (`NSApp.activate()`) unless it comes from something the user did in
/// the app. A click on the Pill that reaches the status item through the menu bar doesn't count, and
/// neither does the idle alert or leaving the Dock. The app then thinks it is active while another app
/// keeps the keyboard and the menu bar: the first click in the Panel activates it for real and closes the
/// ⚙ menu that click opened (#23), and the idle alert and Settings stay behind. Taking over from the app
/// in front (`NSRunningApplication.activate(from:options:)`) is honoured in each of those cases.
public enum Activation: Equatable, Sendable {
    /// Take over from the app in front, by its process ID.
    case takeOver(from: Int32)
    /// The app is in front already, or nothing is.
    case plain

    /// `frontmost` is the process ID of the app in front, if any; `current` is this app's.
    public static func request(frontmost: Int32?, current: Int32) -> Activation {
        guard let frontmost, frontmost != current else { return .plain }
        return .takeOver(from: frontmost)
    }
}

import SwiftUI

/// Settings is the app's only scene, and SwiftUI shows it as the initial window when the app finishes
/// launching (`AppWindowsController.showInitialWindow`, seen on macOS 27), so Settings opened by itself at
/// every launch. From macOS 15 its launch behavior can be suppressed; ⚙ › Settings… and ⌘, still open it.
/// A scene can't take a modifier on only some OS versions, so macOS 14 gets its own `App`, and closes the
/// Settings window SwiftUI opens at launch instead (`LaunchSettingsCloser`).
@main
enum ChronobarMain {
    static func main() {
        if #available(macOS 15, *) {
            ChronobarApp.main()
        } else {
            AppDelegate.closesSettingsShownAtLaunch = true
            ChronobarApp14.main()
        }
    }
}

@available(macOS 15, *)
struct ChronobarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        ChronobarSettings(appDelegate: appDelegate)
            .defaultLaunchBehavior(.suppressed)
    }
}

/// macOS 14 has no launch behavior to set, so its Settings scene is left as it is and the window it opens
/// at launch is closed (`LaunchSettingsCloser`, started by `AppDelegate`).
struct ChronobarApp14: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        ChronobarSettings(appDelegate: appDelegate)
    }
}

private struct ChronobarSettings: Scene {
    let appDelegate: AppDelegate

    var body: some Scene {
        Settings {
            SettingsView(preferences: appDelegate.preferences, loginItem: appDelegate.loginItem)
        }
    }
}

/// On macOS 14 only, closes the Settings window SwiftUI shows by itself at launch. It watches from launch
/// until the first key press or click in the app, which is how someone asks for Settings (⌘, or ⚙ ›
/// Settings… in the Panel), or until `watchFor` has passed, and closes only SwiftUI's Settings window.
@MainActor
final class LaunchSettingsCloser {
    /// The identifier SwiftUI gives its Settings window.
    private static let settingsWindowIdentifier = "com_apple_SwiftUI_Settings_window"
    /// How long after launch starts a Settings window can still be SwiftUI's own.
    private static let watchFor: TimeInterval = 3

    private var observers: [NSObjectProtocol] = []
    private var eventMonitor: Any?
    private var deadline: Timer?

    init() {
        let center = NotificationCenter.default
        for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didBecomeKeyNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let window = note.object as? NSWindow
                MainActor.assumeIsolated { self?.closeIfSettings(window) }
            })
        }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { [weak self] event in
            MainActor.assumeIsolated { self?.stop() }
            return event
        }
        let deadline = Timer(timeInterval: Self.watchFor, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }
        RunLoop.main.add(deadline, forMode: .common)
        self.deadline = deadline
    }

    private func closeIfSettings(_ window: NSWindow?) {
        guard let window, window.isVisible,
              window.identifier?.rawValue == Self.settingsWindowIdentifier else { return }
        window.close()
    }

    func stop() {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
        deadline?.invalidate()
        deadline = nil
    }
}

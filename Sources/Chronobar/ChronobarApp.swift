import SwiftUI

/// Settings is the app's only scene, and SwiftUI shows it as the initial window when the app finishes
/// launching (`AppWindowsController.showInitialWindow`, seen on macOS 27), so Settings opened by itself at
/// every launch. From macOS 15 its launch behavior can be suppressed; ⚙ › Settings… and ⌘, still open it.
/// A scene can't take a modifier on only some OS versions, so macOS 14 gets its own `App`.
@main
enum ChronobarMain {
    static func main() {
        if #available(macOS 15, *) {
            ChronobarApp.main()
        } else {
            ChronobarSonomaApp.main()
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

/// macOS 14 has no launch behavior to set, so its Settings scene is left as it is.
struct ChronobarSonomaApp: App {
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

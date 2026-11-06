import SwiftUI

@main
struct ChronobarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(preferences: appDelegate.preferences, loginItem: appDelegate.loginItem)
        }
    }
}

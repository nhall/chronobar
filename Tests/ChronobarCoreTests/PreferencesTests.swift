import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct PreferencesTests {
    let suite = "ChronobarCoreTests-\(UUID().uuidString)"

    @Test func aFirstLaunchUsesTheAccentColorShowsInTheDockAndOffersTheLoginHint() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let preferences = Preferences(defaults: defaults)
        #expect(preferences.runningColor == .accent)
        #expect(preferences.showInDock)
        #expect(!preferences.loginHintDismissed)
    }

    @Test func choicesSurviveARelaunch() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let preferences = Preferences(defaults: defaults)
        preferences.runningColor = .teal
        preferences.showInDock = false
        preferences.loginHintDismissed = true

        let relaunched = Preferences(defaults: UserDefaults(suiteName: suite)!)
        #expect(relaunched.runningColor == .teal)
        #expect(!relaunched.showInDock)
        #expect(relaunched.loginHintDismissed)
    }

    @Test func anUnknownStoredColorFallsBackToTheAccentColor() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("chartreuse", forKey: "runningColor")

        #expect(Preferences(defaults: defaults).runningColor == .accent)
    }

    @Test func theChoicesAreTheAccentColorThenTheNamedSystemColors() {
        #expect(RunningColor.allCases.map(\.rawValue) == [
            "accent", "red", "orange", "yellow", "green", "mint", "teal",
            "cyan", "blue", "indigo", "purple", "pink", "gray",
        ])
    }
}

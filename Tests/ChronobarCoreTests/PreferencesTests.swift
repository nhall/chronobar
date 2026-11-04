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

    @Test func inputIdleIsDetectedAfterFifteenMinutesByDefault() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(Preferences(defaults: defaults).idleThreshold == .minutes(15))
    }

    @Test func theIdleChoicesAreOffThenFiveToSixtyMinutes() {
        #expect(IdleThreshold.presets == [.off] + [5, 10, 15, 20, 30, 45, 60].map(IdleThreshold.minutes))
    }

    @Test func theIdleThresholdSurvivesARelaunch() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let preferences = Preferences(defaults: defaults)
        preferences.idleThreshold = .minutes(45)
        #expect(Preferences(defaults: UserDefaults(suiteName: suite)!).idleThreshold == .minutes(45))

        preferences.idleThreshold = .off
        #expect(Preferences(defaults: UserDefaults(suiteName: suite)!).idleThreshold == .off)
    }

    @Test(arguments: [
        (5, 5), (60, 60),
        // Between two choices: the nearer one, a tie going to the longer.
        (7, 5), (8, 10), (12, 10), (13, 15), (25, 30), (37, 30), (38, 45), (52, 45), (53, 60),
        // Outside the range.
        (1, 5), (480, 60),
    ])
    func aStoredIdleThresholdSnapsToTheNearestChoice(stored: Int, snapped: Int) {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(stored, forKey: "idleThresholdMinutes")

        #expect(Preferences(defaults: defaults).idleThreshold == .minutes(snapped))
    }

    @Test(arguments: [0, -5])
    func aStoredIdleThresholdOfZeroOrLessIsOff(stored: Int) {
        #expect(IdleThreshold(snapping: stored) == .off)
    }

    /// Earlier builds had a separate toggle next to a 1 to 480 minute stepper.
    @Test func theOldDetectionToggleTurnedOffMeansOff() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: "detectsInputIdle")
        defaults.set(30, forKey: "idleThresholdMinutes")

        #expect(Preferences(defaults: defaults).idleThreshold == .off)
    }

    @Test func theOldDetectionToggleTurnedOnKeepsTheSnappedThreshold() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "detectsInputIdle")
        defaults.set(90, forKey: "idleThresholdMinutes")

        #expect(Preferences(defaults: defaults).idleThreshold == .minutes(60))
    }

    /// Otherwise the old toggle, still stored as off, would win over the new choice at the next launch.
    @Test func choosingAThresholdAfterTheOldToggleWasOffSticks() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: "detectsInputIdle")

        Preferences(defaults: defaults).idleThreshold = .minutes(20)
        #expect(Preferences(defaults: UserDefaults(suiteName: suite)!).idleThreshold == .minutes(20))
    }

    @Test func theChoicesAreTheAccentColorThenTheNamedSystemColors() {
        #expect(RunningColor.allCases.map(\.rawValue) == [
            "accent", "red", "orange", "yellow", "green", "mint", "teal",
            "cyan", "blue", "indigo", "purple", "pink", "gray",
        ])
    }
}

import Foundation
import Testing

/// The tests' settings stores live and die in the temp folder, never in ~/Library/Preferences.
@Suite struct TestSettingsTests {
    @Test func aFreshStoreReadsBackWhatAnEarlierOneSaved() {
        let settings = TestSettings()
        defer { settings.remove() }

        settings.fresh().set("teal", forKey: "runningColor")
        #expect(settings.fresh().string(forKey: "runningColor") == "teal")
    }

    @Test func storesAreIsolatedFromEachOther() {
        let first = TestSettings(), second = TestSettings()
        defer { first.remove(); second.remove() }

        first.fresh().set("teal", forKey: "runningColor")
        #expect(second.fresh().string(forKey: "runningColor") == nil)
    }

    @Test func removingLeavesNothingBehind() {
        let preferences = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences", isDirectory: true)
        let before = Set((try? FileManager.default.contentsOfDirectory(atPath: preferences.path)) ?? [])

        let settings = TestSettings()
        let defaults = settings.fresh()
        defaults.set("teal", forKey: "runningColor")
        defaults.set(Date(), forKey: "lastAlive")
        defaults.synchronize()
        #expect(FileManager.default.fileExists(atPath: settings.directory.path))
        settings.remove()

        #expect(!FileManager.default.fileExists(atPath: settings.directory.path))
        let after = Set((try? FileManager.default.contentsOfDirectory(atPath: preferences.path)) ?? [])
        #expect(after.subtracting(before).filter { $0.hasPrefix("ChronobarCoreTests") }.isEmpty)
    }
}

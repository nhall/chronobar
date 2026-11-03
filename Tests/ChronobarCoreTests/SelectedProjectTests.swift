import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct SelectedProjectTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()
    let suite = "ChronobarCoreTests-\(UUID().uuidString)"

    @Test func theLastStartedProjectIsSelectedAfterARelaunch() throws {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let tracker = Tracker(clock: clock, storageRoot: root, defaults: defaults)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.start("Internal")
        clock.set("2026-11-03T10:30:00")
        try tracker.pause()

        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: UserDefaults(suiteName: suite)!)
        #expect(relaunched.running == nil)
        #expect(relaunched.selectedProject == "Internal")
    }

    @Test func aTimerLeftRunningIsSelectedOverTheStoredProject() throws {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("Garden Shed", forKey: "selectedProject")

        try Tracker(clock: clock, storageRoot: root).start("Website Redesign")

        let relaunched = Tracker(clock: clock, storageRoot: root, defaults: defaults)
        #expect(relaunched.selectedProject == "Website Redesign")
    }
}

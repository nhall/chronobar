import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct ProjectListTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func startingANewNameCreatesAProject() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.start("Internal")

        #expect(tracker.projects == ["Website Redesign", "Internal"])
        #expect(contents(projectsFile(root)) == "Website Redesign\nInternal\n")
    }

    @Test func namesMatchIgnoringCaseAndSurroundingSpacesAndKeepTheStoredSpelling() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        clock.set("2026-11-03T10:00:00")
        try tracker.start("  internal ")
        clock.set("2026-11-03T10:30:00")
        try tracker.pause()

        #expect(tracker.projects == ["Internal"])
        #expect(tracker.selectedProject == "Internal")
        #expect(tracker.total("Internal", on: tracker.today) == 90 * 60)
        #expect(try tracker.addProject("INTERNAL") == "Internal")
        #expect(contents(projectsFile(root)) == "Internal\n")
    }
}

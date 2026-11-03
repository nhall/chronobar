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

    @Test func handEditsToTheProjectListArePickedUp() throws {
        try "Website Redesign\n\n  Internal  \n".write(to: projectsFile(root), atomically: true, encoding: .utf8)
        let tracker = Tracker(clock: clock, storageRoot: root)
        #expect(tracker.projects == ["Website Redesign", "Internal"])

        try "Internal\nMobile App\n".write(to: projectsFile(root), atomically: true, encoding: .utf8)
        tracker.reload()
        #expect(tracker.projects == ["Internal", "Mobile App"])

        try tracker.start("Annual Report")
        #expect(contents(projectsFile(root)) == "Internal\nMobile App\nAnnual Report\n")
    }

    @Test func archivingRemovesTheProjectButKeepsItsHistory() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.start("Internal")
        clock.set("2026-11-03T10:15:00")
        try tracker.pause()
        let history = contents(dayFile(root, "2026-11-03"))

        try tracker.archiveProject("website redesign ")

        #expect(tracker.projects == ["Internal"])
        #expect(contents(projectsFile(root)) == "Internal\n")
        #expect(contents(dayFile(root, "2026-11-03")) == history)
        #expect(Tracker(clock: clock, storageRoot: root).total("Website Redesign", on: tracker.today) == 3600)
    }

    @Test func archivingTheSelectedProjectClearsTheSelectionButLeavesItRunning() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")

        try tracker.archiveProject("Website Redesign")
        #expect(tracker.selectedProject == nil)
        #expect(tracker.running?.project == "Website Redesign")

        tracker.reload()
        #expect(tracker.selectedProject == nil)
        #expect(tracker.running?.project == "Website Redesign")

        clock.set("2026-11-03T10:30:00")
        try tracker.toggle()
        #expect(tracker.running == nil)
        #expect(tracker.selectedProject == nil)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 90 * 60)
        #expect(tracker.projects == [])
    }

    @Test func archivingAnotherProjectKeepsTheSelection() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        try tracker.start("Website Redesign")
        try tracker.archiveProject("Internal")

        #expect(tracker.selectedProject == "Website Redesign")
    }
}

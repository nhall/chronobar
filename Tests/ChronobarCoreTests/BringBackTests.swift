import Foundation
import Testing
import ChronobarCore

/// Putting time under an Archived Label, or pinning it, brings it back in the same save as that change, so
/// the Archived file and the suggestions agree once it lands, and neither changes when it's refused.
@MainActor @Suite struct BringBackTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    /// Mobile App on the Archived Labels, with a finished Entry on a past Day so it has stored time.
    private func archivedMobileApp() throws {
        try FileManager.default.createDirectory(
            at: dayFile(root, "2026-09-01").deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
            {
              "date": "2026-09-01",
              "entries": [
                { "project": "mobile app", "start": "2026-09-01T08:00:00-05:00", "end": "2026-09-01T08:30:00-05:00", "source": "app" }
              ]
            }

            """.write(to: dayFile(root, "2026-09-01"), atomically: true, encoding: .utf8)
        try "Mobile App\n".write(to: archivedFile(root), atomically: true, encoding: .utf8)
    }

    @Test func aStartRefusedByAMalformedTodayLeavesTheLabelArchived() throws {
        try archivedMobileApp()
        try "{ not a day".write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(throws: (any Error).self) { try tracker.start("mobile app") }

        #expect(contents(archivedFile(root)) == "Mobile App\n")
        #expect(tracker.archived == ["Mobile App"])
        #expect(!tracker.suggestions(for: "").contains("Mobile App"))
        #expect(tracker.timers.isEmpty)
    }

    @Test func startingAnArchivedLabelBringsItBackInTheSameSave() throws {
        try archivedMobileApp()
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(try tracker.start("MOBILE APP").label == "Mobile App")

        #expect(contents(archivedFile(root)) == "")
        #expect(tracker.timers.newest?.project == "Mobile App")
        #expect(tracker.archived == [])
        #expect(tracker.suggestions(for: "") == ["Mobile App"])
        #expect(tracker.match("mobile app") == .active("Mobile App"))
    }

    @Test func loggingAnArchivedLabelBringsItBackInTheSameSave() throws {
        try archivedMobileApp()
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(try tracker.log(" mobile APP ", "0:30", on: tracker.today).project == "Mobile App")

        #expect(contents(archivedFile(root)) == "")
        #expect(tracker.total("Mobile App", on: tracker.today) == 30 * 60)
        #expect(tracker.archived == [])
        #expect(tracker.suggestions(for: "mob") == ["Mobile App"])
    }

    @Test func addingATimedEntryForAnArchivedLabelBringsItBackInTheSameSave() throws {
        try archivedMobileApp()
        let tracker = Tracker(clock: clock, storageRoot: root)

        let stored = try tracker.addEntry("mobile app", start: clock.date("2026-11-03T08:00:00"),
                                          end: clock.date("2026-11-03T08:45:00"))

        #expect(stored.map(\.project) == ["Mobile App"])
        #expect(contents(archivedFile(root)) == "")
        #expect(tracker.total("Mobile App", on: tracker.today) == 45 * 60)
        #expect(tracker.archived == [])
        #expect(tracker.suggestions(for: "") == ["Mobile App"])
    }

    @Test func pinningAnArchivedLabelBringsItBackAndPinsIt() throws {
        try archivedMobileApp()
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(try tracker.pinProject("mobile app") == "Mobile App")

        #expect(contents(archivedFile(root)) == "")
        #expect(contents(projectsFile(root)) == "Mobile App\n")
        #expect(tracker.archived == [])
        #expect(tracker.projects == ["Mobile App"])
        #expect(tracker.suggestions(for: "") == ["Mobile App"])
    }

    @Test func pinningAnArchivedLabelChangesNeitherFileWhenTheArchivedFileCantBeReplaced() throws {
        try archivedMobileApp()
        try "Internal\n".write(to: projectsFile(root), atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: archivedFile(root).path)
        defer { try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: archivedFile(root).path) }
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(throws: (any Error).self) { try tracker.pinProject("mobile app") }

        #expect(contents(archivedFile(root)) == "Mobile App\n")
        #expect(contents(projectsFile(root)) == "Internal\n")
        #expect(tracker.archived == ["Mobile App"])
        #expect(tracker.projects == ["Internal"])
        #expect(tracker.suggestions(for: "") == ["Internal"])
    }
}

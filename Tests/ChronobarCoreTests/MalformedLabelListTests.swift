import Foundation
import Testing
import ChronobarCore

/// A Label list that won't parse refuses a write, naming which list so the user knows which file to fix.
@MainActor @Suite struct MalformedLabelListTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()
    let notUTF8 = Data([0x49, 0x6E, 0xFF, 0xFE, 0x0A])

    @Test func aMalformedPinnedLabelsFileRefusesAStartNamingIt() throws {
        try notUTF8.write(to: projectsFile(root))
        let tracker = Tracker(clock: clock, storageRoot: root)

        let error = try #require(throws: MalformedLabelList.self) { try tracker.start("Internal") }

        #expect(error == MalformedLabelList(list: .pinned))
        #expect(error.fileName == "projects.txt")
        #expect(tracker.timers.isEmpty)
    }

    @Test func aMalformedArchivedLabelsFileRefusesAStartNamingIt() throws {
        try notUTF8.write(to: archivedFile(root))
        let tracker = Tracker(clock: clock, storageRoot: root)

        let error = try #require(throws: MalformedLabelList.self) { try tracker.start("Internal") }

        #expect(error == MalformedLabelList(list: .archived))
        #expect(error.fileName == "archived.txt")
        #expect(tracker.timers.isEmpty)
    }
}

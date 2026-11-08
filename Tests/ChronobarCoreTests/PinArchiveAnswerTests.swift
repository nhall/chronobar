import Foundation
import Testing
import ChronobarCore

/// What Tracker answers about pinning and archiving, so Operations and the Panel ask instead of searching
/// the Pinned and Archived Labels themselves.
@MainActor @Suite struct PinArchiveAnswerTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func whetherALabelIsPinnedIgnoresCaseAndSurroundingSpaces() throws {
        try "Website Redesign\n".write(to: projectsFile(root), atomically: true, encoding: .utf8)
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(tracker.isPinned("Website Redesign"))
        #expect(tracker.isPinned("  website REDESIGN "))
        #expect(!tracker.isPinned("Website"))
        #expect(!tracker.isPinned("Internal"))
    }

    @Test func archiveReturnsTheStoredSpellingForANameTypedInAnotherCase() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.pause()

        #expect(try tracker.archiveProject("  website REDESIGN ") == "Website Redesign")
        #expect(try tracker.archiveProject("WEBSITE redesign") == "Website Redesign")
        #expect(contents(archivedFile(root)) == "Website Redesign\n")
    }
}

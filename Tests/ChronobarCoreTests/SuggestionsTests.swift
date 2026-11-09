import Foundation
import Testing
import ChronobarCore

/// The ＋ form's suggestions: Projects used in the last 30 days plus Pinned ones, minus archived ones.
@MainActor @Suite struct SuggestionsTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func startingANewNameSuggestsItWithoutPinningIt() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Client A, Ticket 665")

        #expect(tracker.suggestions(for: "") == ["Client A, Ticket 665"])
        #expect(tracker.projects == [])
        #expect(contents(projectsFile(root)) == nil)
    }

    /// Today and the 29 Days before it count; time logged ahead doesn't.
    @Test func onlyProjectsUsedInTheLast30DaysAreSuggested() throws {
        try write(root, "2026-10-04", #"    { "project": "Aged Out", "seconds": 600, "note": "manual" }"#)
        try write(root, "2026-10-05", #"    { "project": "Oldest Kept", "seconds": 600, "note": "manual" }"#)
        try write(root, "2026-11-02", #"    { "project": "Yesterday", "seconds": 600, "note": "manual" }"#)
        try write(root, "2026-11-20", #"    { "project": "Ahead", "seconds": 600, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(tracker.suggestions(for: "") == ["Yesterday", "Oldest Kept"])
        #expect(tracker.match("aged out") == .unused("Aged Out"))
        #expect(tracker.match("oldest kept") == .active("Oldest Kept"))
    }

    @Test func aProjectAgesOutWhenTheDaysMoveOn() throws {
        try write(root, "2026-10-05", #"    { "project": "Oldest Kept", "seconds": 600, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)
        #expect(tracker.suggestions(for: "") == ["Oldest Kept"])

        clock.set("2026-11-04T09:00:00")
        tracker.tick()
        #expect(tracker.suggestions(for: "") == [])
    }

    @Test func pinnedProjectsAreSuggestedAfterRecentOnesWithoutUse() throws {
        try "Internal\nPrint Shop\n".write(to: projectsFile(root), atomically: true, encoding: .utf8)
        try write(root, "2026-11-02", """
            { "project": "Client A, Ticket 665", "seconds": 600, "note": "manual" },
            { "project": "print shop", "seconds": 600, "note": "manual" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(tracker.suggestions(for: "") == ["Print Shop", "Client A, Ticket 665", "Internal"])
        #expect(tracker.suggestions(for: "in") == ["Internal", "Print Shop"])
    }

    @Test func pinningAddsTheProjectToTheProjectListWithItsStoredSpelling() throws {
        try write(root, "2026-09-01", #"    { "project": "Garden Shed", "seconds": 600, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)
        #expect(tracker.suggestions(for: "") == [])

        #expect(try tracker.pinProject(" garden SHED") == "Garden Shed")
        #expect(try tracker.pinProject("Garden Shed") == "Garden Shed")

        #expect(tracker.projects == ["Garden Shed"])
        #expect(contents(projectsFile(root)) == "Garden Shed\n")
        #expect(tracker.suggestions(for: "") == ["Garden Shed"])
    }

    @Test func archivingUnpinsAndHidesTheProjectButKeepsItsHistory() throws {
        try "Internal\nPrint Shop\n".write(to: projectsFile(root), atomically: true, encoding: .utf8)
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Client A, Ticket 665")
        clock.set("2026-11-03T10:00:00")
        try tracker.pause()
        let history = contents(dayFile(root, "2026-11-03"))

        try tracker.archiveProject("client a, ticket 665 ")
        try tracker.archiveProject("INTERNAL")
        try tracker.archiveProject("Internal")

        #expect(tracker.suggestions(for: "") == ["Print Shop"])
        #expect(tracker.projects == ["Print Shop"])
        #expect(tracker.archived == ["Client A, Ticket 665", "Internal"])
        #expect(contents(projectsFile(root)) == "Print Shop\n")
        #expect(contents(archivedFile(root)) == "Client A, Ticket 665\nInternal\n")
        #expect(contents(dayFile(root, "2026-11-03")) == history)
        #expect(tracker.total("Client A, Ticket 665", on: tracker.today) == 3600)
        #expect(tracker.match("client a, ticket 665") == .archived("Client A, Ticket 665"))
    }

    @Test func archivingARunningProjectLeavesItRunning() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        try tracker.archiveProject("Internal")

        #expect(tracker.isRunning("Internal"))
        #expect(tracker.suggestions(for: "") == [])
    }

    @Test func startingAnArchivedProjectRevivesItWithItsStoredSpelling() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Garden Shed", "15", on: tracker.today)
        try tracker.archiveProject("garden shed")

        #expect(try tracker.start(" GARDEN shed").project == "Garden Shed")

        #expect(tracker.archived == [])
        #expect(contents(archivedFile(root)) == "")
        #expect(tracker.projects == [])
        #expect(tracker.suggestions(for: "") == ["Garden Shed"])
        #expect(tracker.rows(tracker.today).map(\.project) == ["Garden Shed"])
    }

    /// An archived name with no time in the window, typed on another Day, still comes back as archived.
    @Test func loggingAnArchivedProjectRevivesItWithTheArchivedSpelling() throws {
        try "Mobile App\n".write(to: archivedFile(root), atomically: true, encoding: .utf8)
        let tracker = Tracker(clock: clock, storageRoot: root)
        #expect(tracker.match("mobile app") == .archived("Mobile App"))

        #expect(try tracker.log("MOBILE APP", "0:30", on: Day("2026-11-02")!).project == "Mobile App")

        #expect(tracker.archived == [])
        #expect(tracker.match("mobile app") == .active("Mobile App"))
    }

    @Test func pinningAnArchivedProjectUnarchivesIt() throws {
        try "Mobile App\n".write(to: archivedFile(root), atomically: true, encoding: .utf8)
        let tracker = Tracker(clock: clock, storageRoot: root)

        try tracker.pinProject("mobile app")

        #expect(tracker.projects == ["Mobile App"])
        #expect(tracker.archived == [])
        #expect(tracker.suggestions(for: "") == ["Mobile App"])
    }

    @Test func handEditsToTheArchivedListArePickedUpOnReload() throws {
        try "Internal\nPrint Shop\n".write(to: projectsFile(root), atomically: true, encoding: .utf8)
        try "\n  internal  \n\n".write(to: archivedFile(root), atomically: true, encoding: .utf8)
        let tracker = Tracker(clock: clock, storageRoot: root)
        #expect(tracker.archived == ["internal"])
        #expect(tracker.suggestions(for: "") == ["Print Shop"])

        try "Print Shop\n".write(to: archivedFile(root), atomically: true, encoding: .utf8)
        tracker.reload()
        #expect(tracker.suggestions(for: "") == ["Internal"])

        try tracker.archiveProject("Mobile App")
        #expect(contents(archivedFile(root)) == "Print Shop\nMobile App\n")
    }

    @Test func anArchivedListThatIsNotUTF8IsNeverOverwritten() throws {
        let bytes = Data([0x49, 0x6E, 0xFF, 0xFE, 0x0A])
        try bytes.write(to: archivedFile(root))
        try "Internal\n".write(to: projectsFile(root), atomically: true, encoding: .utf8)
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(throws: (any Error).self) { try tracker.archiveProject("Internal") }
        #expect(throws: (any Error).self) { try tracker.pinProject("Mobile App") }
        #expect(throws: (any Error).self) { try tracker.start("Internal") }
        #expect(try Data(contentsOf: archivedFile(root)) == bytes)
        #expect(contents(projectsFile(root)) == "Internal\n")
        #expect(tracker.timers.isEmpty)
    }
}

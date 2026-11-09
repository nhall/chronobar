import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct ProjectListTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func namesMatchIgnoringCaseAndSurroundingSpacesAndKeepTheStoredSpelling() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        clock.set("2026-11-03T10:00:00")
        try tracker.start("  internal ")
        clock.set("2026-11-03T10:30:00")
        try tracker.pause()

        #expect(tracker.projects == [])
        #expect(tracker.total("Internal", on: tracker.today) == 90 * 60)
        #expect(try tracker.pinProject("INTERNAL") == "Internal")
        #expect(contents(projectsFile(root)) == "Internal\n")
    }

    @Test func handEditsToTheProjectListArePickedUp() throws {
        try "Website Redesign\n\n  Internal  \n".write(to: projectsFile(root), atomically: true, encoding: .utf8)
        let tracker = Tracker(clock: clock, storageRoot: root)
        #expect(tracker.projects == ["Website Redesign", "Internal"])

        try "Internal\nMobile App\n".write(to: projectsFile(root), atomically: true, encoding: .utf8)
        tracker.reload()
        #expect(tracker.projects == ["Internal", "Mobile App"])

        try tracker.pinProject("Annual Report")
        #expect(contents(projectsFile(root)) == "Internal\nMobile App\nAnnual Report\n")
    }

    @Test func archivingRemovesTheProjectButKeepsItsHistory() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.toggle("Website Redesign")
        try tracker.start("Internal")
        clock.set("2026-11-03T10:15:00")
        try tracker.pause()
        let history = contents(dayFile(root, "2026-11-03"))

        try tracker.archiveProject("website redesign ")

        #expect(tracker.archived == ["Website Redesign"])
        #expect(tracker.suggestions(for: "") == ["Internal"])
        #expect(contents(dayFile(root, "2026-11-03")) == history)
        #expect(Tracker(clock: clock, storageRoot: root).total("Website Redesign", on: tracker.today) == 3600)
    }

    @Test func archivingARunningProjectLeavesItRunning() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")

        try tracker.archiveProject("Website Redesign")
        #expect(tracker.timers.newest?.project == "Website Redesign")

        tracker.reload()
        #expect(tracker.timers.newest?.project == "Website Redesign")
        #expect(Tracker(clock: clock, storageRoot: root).timers.newest?.project == "Website Redesign")

        clock.set("2026-11-03T10:30:00")
        try tracker.toggle("Website Redesign")
        #expect(tracker.timers.isEmpty)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 90 * 60)
        #expect(tracker.projects == [])
    }

    @Test func pinningAnArchivedNameRevivesItWithItsStoredSpelling() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.pause()
        try tracker.archiveProject("Website Redesign")

        #expect(try tracker.pinProject(" website REDESIGN") == "Website Redesign")
        #expect(tracker.projects == ["Website Redesign"])
        #expect(contents(projectsFile(root)) == "Website Redesign\n")
    }

    @Test func suggestionsAreActiveProjectsMatchingWhatIsTypedPrefixesFirst() throws {
        try "Print Shop\nMobile App\nInternal\nAnnual Report\n"
            .write(to: projectsFile(root), atomically: true, encoding: .utf8)
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.archiveProject("Annual Report")

        #expect(tracker.suggestions(for: "") == ["Print Shop", "Mobile App", "Internal"])
        #expect(tracker.suggestions(for: " in") == ["Internal", "Print Shop"])
        #expect(tracker.suggestions(for: "APP") == ["Mobile App"])
        #expect(tracker.suggestions(for: "report") == [])
    }

    @Test func suggestionsListTheMostRecentlyUsedProjectsFirst() throws {
        try "Print Shop\nMobile App\nInternal\nAnnual Report\nGarden Shed\n"
            .write(to: projectsFile(root), atomically: true, encoding: .utf8)
        try write(root, "2026-10-27", #"    { "project": "annual report", "seconds": 600, "note": "manual" }"#)
        try write(root, "2026-11-02", """
            { "project": "Internal", "seconds": 600, "note": "manual" },
            { "project": "Mobile App", "seconds": 600, "note": "manual" }
        """)
        // Time logged ahead isn't a recent use.
        try write(root, "2026-11-20", #"    { "project": "Garden Shed", "seconds": 600, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Annual Report", "15", on: tracker.today)

        #expect(tracker.suggestions(for: "") == ["Annual Report", "Mobile App", "Internal", "Print Shop", "Garden Shed"])
        #expect(tracker.suggestions(for: "p") == ["Print Shop", "Annual Report", "Mobile App"])
    }

    @Test func anExactMatchRanksFirstAheadOfMoreRecentLongerNames() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("test")
        clock.set("2026-11-03T09:10:00")
        try tracker.start("test 2")
        clock.set("2026-11-03T09:20:00")
        try tracker.start("test 3")

        #expect(tracker.suggestions(for: "") == ["test 3", "test 2", "test"])
        #expect(tracker.suggestions(for: " TEST") == ["test", "test 3", "test 2"])
        #expect(tracker.suggestions(for: "est") == ["test 3", "test 2", "test"])
    }

    @Test func aTypedNameIsNewActiveUnusedOrArchivedWithItsStoredSpelling() throws {
        try write(root, "2026-09-28", #"    { "project": "Garden Shed", "seconds": 600, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        try tracker.start("test 3")

        #expect(tracker.match("  ") == nil)
        #expect(tracker.match("test") == .new)
        #expect(tracker.match(" INTERNAL") == .active("Internal"))
        #expect(tracker.match("garden shed") == .unused("Garden Shed"))

        try tracker.archiveProject("Internal")
        #expect(tracker.match("internal") == .archived("Internal"))
    }

    @Test func aTypedNameOnTheArchivedLabelsIsArchivedAndOneWithOnlyOldTimeIsUnused() throws {
        try write(root, "2026-09-28", """
            { "project": "Garden Shed", "seconds": 600, "note": "manual" },
            { "project": "mobile app", "seconds": 600, "note": "manual" }
        """)
        try "Mobile App\n".write(to: archivedFile(root), atomically: true, encoding: .utf8)
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(tracker.match(" MOBILE app") == .archived("Mobile App"))
        #expect(tracker.match("garden SHED ") == .unused("Garden Shed"))
    }

    /// The ＋ form asks on every keystroke and redraw, so the data folder is listed once until the next
    /// reload: a Day file added by hand shows up when the Panel next opens.
    @Test func aDayFileAddedByHandIsFoundAfterTheNextReload() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        #expect(tracker.match("Garden Shed") == .new)

        try write(root, "2026-09-28", #"    { "project": "Garden Shed", "seconds": 600, "note": "manual" }"#)
        #expect(tracker.match("Garden Shed") == .new)

        tracker.reload()
        #expect(tracker.match("Garden Shed") == .unused("Garden Shed"))
    }

    /// Chronobar's own writes to a Day with no file yet count at once, without a reload.
    @Test func aDayFirstWrittenByLoggingCountsStraightAway() throws {
        try "Print Shop\nInternal\n".write(to: projectsFile(root), atomically: true, encoding: .utf8)
        let tracker = Tracker(clock: clock, storageRoot: root)
        #expect(tracker.suggestions(for: "") == ["Print Shop", "Internal"])

        try tracker.log("Internal", "15", on: Day("2026-10-30")!)
        #expect(tracker.suggestions(for: "") == ["Internal", "Print Shop"])
        try tracker.archiveProject("Internal")
        #expect(tracker.match("internal") == .archived("Internal"))
    }

    @Test func aBlankNameIsRefused() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        #expect(throws: EmptyProjectName.self) { try tracker.start("   ") }
        #expect(tracker.timers.isEmpty)
        #expect(contents(projectsFile(root)) == nil)
    }

    @Test func aProjectListThatIsNotUTF8IsNeverOverwritten() throws {
        let bytes = Data([0x49, 0x6E, 0xFF, 0xFE, 0x0A])
        try bytes.write(to: projectsFile(root))
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(throws: (any Error).self) { try tracker.start("Internal") }
        #expect(throws: (any Error).self) { try tracker.archiveProject("Internal") }
        #expect(try Data(contentsOf: projectsFile(root)) == bytes)
        #expect(tracker.timers.isEmpty)
    }

    @Test func aNameFromAPastDayRevivesWithThatDaysSpelling() throws {
        try FileManager.default.createDirectory(
            at: dayFile(root, "2026-10-28").deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        { "date": "2026-10-28", "entries": [ { "project": "Mobile App", "seconds": 900, "note": "manual" } ] }
        """.write(to: dayFile(root, "2026-10-28"), atomically: true, encoding: .utf8)

        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("mobile app")
        clock.set("2026-11-03T09:30:00")
        tracker.tick()

        #expect(tracker.suggestions(for: "") == ["Mobile App"])
        #expect(tracker.timers.newest?.project == "Mobile App")
        #expect(tracker.total("Mobile App", on: tracker.today) == 30 * 60)
    }

    /// Looking for a past spelling skips a malformed Day, but flags it like any other read.
    @Test func aMalformedPastDayIsSkippedAndFlaggedWhenLookingForAName() throws {
        try write(root, "2026-11-02", #"    { "project": "garden shed", "start": "9am" }"#)
        try write(root, "2026-11-01", #"    { "project": "Garden Shed", "seconds": 600, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(try tracker.pinProject("GARDEN SHED") == "Garden Shed")
        #expect(tracker.isMalformed(Day("2026-11-02")!))
    }

    /// Start returns the name its row is shown under, so the Panel can scroll to that row: the stored
    /// spelling, not what was typed.
    @Test func startReturnsTheNameTheRowIsShownUnder() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")

        let project = try tracker.start("  website REDESIGN").project

        #expect(project == "Website Redesign")
        #expect(tracker.rows(tracker.today).map(\.project) == ["Website Redesign"])
    }

    /// Log on another Day returns the spelling an archived Project is revived with, as its row shows it.
    @Test func logReturnsTheNameARevivedProjectsRowIsShownUnder() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Garden Shed")
        clock.set("2026-11-03T10:00:00")
        try tracker.pause()
        try tracker.archiveProject("Garden Shed")
        let yesterday = Day("2026-11-02")!

        let project = try tracker.log("GARDEN shed", "0:30", on: yesterday).project

        #expect(project == "Garden Shed")
        #expect(tracker.rows(yesterday).map(\.project) == ["Garden Shed"])
    }
}

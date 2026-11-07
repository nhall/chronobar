import Foundation
import Testing
import ChronobarCore
import ChronobarOperations

/// `pin` and `archive`, as the right-click menu on a suggestion does them.
@MainActor @Suite struct PinArchiveTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    private var projectsFile: URL { root.appendingPathComponent("projects.txt") }
    private var archivedFile: URL { root.appendingPathComponent("archived.txt") }

    @Test func pinningAddsTheLabelToProjectsTxtSpelledAsItsEntries() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "1:00", on: Day(year: 2026, month: 9, day: 1))
        let operations = Operations(tracker: tracker)

        let pinned = try operations.pin("website redesign")

        #expect(pinned == PinResult(label: "Website Redesign", alreadyPinned: false, pinned: ["Website Redesign"]))
        #expect(contents(projectsFile) == "Website Redesign\n")
        #expect(try operations.labels().labels == [LabelResult(label: "Website Redesign", pinned: true)])
    }

    @Test func pinningAPinnedLabelChangesNothing() throws {
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))
        try operations.pin("Internal")

        let pinned = try operations.pin("INTERNAL")

        #expect(pinned == PinResult(label: "Internal", alreadyPinned: true, pinned: ["Internal"]))
        #expect(contents(projectsFile) == "Internal\n")
    }

    /// Pinning is how a Label is kept in the suggestions before it has any time.
    @Test func pinningAnUnknownLabelPinsItAsTyped() throws {
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let pinned = try operations.pin("  Internal meeting ")

        #expect(pinned.label == "Internal meeting")
        #expect(try operations.labels().labels == [LabelResult(label: "Internal meeting", pinned: true)])
    }

    @Test func pinningAnArchivedLabelBringsItBack() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "1:00", on: tracker.today)
        try tracker.archiveProject("Website Redesign")
        let operations = Operations(tracker: tracker)

        try operations.pin("Website Redesign")

        #expect(contents(archivedFile) == "")
        #expect(try operations.labels("Website Redesign").match == LabelMatchResult(kind: .suggested,
                                                                                    label: "Website Redesign"))
    }

    @Test func archivingUnpinsTheLabelAndHidesItFromSuggestionsKeepingItsTime() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "1:00", on: tracker.today)
        try tracker.pinProject("Website Redesign")
        let operations = Operations(tracker: tracker)

        let archived = try operations.archive("website redesign")

        #expect(archived == ArchiveResult(label: "Website Redesign", alreadyArchived: false, unpinned: true,
                                          running: false))
        #expect(contents(projectsFile) == "")
        #expect(contents(archivedFile) == "Website Redesign\n")
        #expect(try operations.labels().labels.isEmpty)
        #expect(try operations.day().rows == [RowResult(label: "Website Redesign", totalSeconds: 3600, running: false)])
    }

    /// As in the Panel, archiving leaves a running timer running.
    @Test func archivingARunningLabelLeavesItsTimerRunning() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        let operations = Operations(tracker: tracker)

        let archived = try operations.archive("Website Redesign")

        #expect(archived.running)
        #expect(try operations.status().timers.map(\.label) == ["Website Redesign"])
    }

    @Test func archivingAnArchivedLabelChangesNothing() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "1:00", on: tracker.today)
        let operations = Operations(tracker: tracker)
        try operations.archive("Website Redesign")

        let archived = try operations.archive("Website Redesign")

        #expect(archived == ArchiveResult(label: "Website Redesign", alreadyArchived: true, unpinned: false,
                                          running: false))
        #expect(contents(archivedFile) == "Website Redesign\n")
    }

    /// The Panel only archives Labels it lists, so a typo can't fill `archived.txt` with names never used.
    @Test func archivingAnUnknownLabelIsRefusedAndChangesNothing() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "1:00", on: tracker.today)
        let operations = Operations(tracker: tracker)

        let error = try #require(operations.perform(.archive(label: "Website Redesing")).error)

        #expect(error.kind == .unknownLabel)
        #expect(error.message.contains("Website Redesing"))
        #expect(!FileManager.default.fileExists(atPath: archivedFile.path))
    }

    @Test(arguments: [Request.pin(label: "  "), .archive(label: "")])
    func aBlankLabelIsRefused(_ request: Request) throws {
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        #expect(operations.perform(request).error?.kind == .invalidLabel)
    }

    @Test(arguments: [Request.pin(label: "Internal"), .archive(label: "Website Redesign")])
    func aLabelListThatIsNotUTF8IsLeftAlone(_ request: Request) throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "1:00", on: tracker.today)
        let bytes = Data([0x57, 0xFF, 0xFE, 0x0A])
        try bytes.write(to: projectsFile)
        let operations = Operations(tracker: tracker)

        let error = try #require(operations.perform(request).error)

        #expect(error.kind == .malformedFile)
        #expect(error.message.contains("projects.txt"))
        #expect(try Data(contentsOf: projectsFile) == bytes)
    }
}

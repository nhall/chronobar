import Foundation
import Testing
import ChronobarCore

/// Relabeling: moving all of a Label's time on one Day to another Label.
@MainActor @Suite struct RelabelTests {
    let clock = FakeClock("2026-11-03T12:00:00")
    let root = temporaryRoot()

    @Test func relabelingAStoppedRowMovesEveryEntryOfTheLabelOnThatDay() throws {
        try write(root, "2026-11-03", """
            { "project": "Northwnd", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "agent" },
            { "project": "Internal", "start": "2026-11-03T10:00:00-05:00", "end": "2026-11-03T10:30:00-05:00", "source": "app" },
            { "project": "northwnd", "seconds": 900, "note": "manual" },
            { "project": "Northwnd", "seconds": -300, "note": "adjustment" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)

        try tracker.relabel("Northwnd", to: " Northwind, Ticket 665 ", on: tracker.today)

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Northwind, Ticket 665", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "agent" },
            { "project": "Internal", "start": "2026-11-03T10:00:00-05:00", "end": "2026-11-03T10:30:00-05:00", "source": "app" },
            { "project": "Northwind, Ticket 665", "seconds": 900, "note": "manual" },
            { "project": "Northwind, Ticket 665", "seconds": -300, "note": "adjustment" }
          ]
        }

        """)
        #expect(tracker.rows(tracker.today) == [Row(project: "Northwind, Ticket 665", total: 70 * 60),
                                                Row(project: "Internal", total: 30 * 60)])
    }

    @Test func theSameLabelOnOtherDaysKeepsItsName() throws {
        try write(root, "2026-11-02", #"    { "project": "Northwnd", "seconds": 3600, "note": "manual" }"#)
        try write(root, "2026-11-03", #"    { "project": "Northwnd", "seconds": 1800, "note": "manual" }"#)
        let before = contents(dayFile(root, "2026-11-03"))
        let tracker = Tracker(clock: clock, storageRoot: root)

        try tracker.relabel("Northwnd", to: "Northwind", on: Day(year: 2026, month: 11, day: 2))

        #expect(tracker.rows(Day(year: 2026, month: 11, day: 2)) == [Row(project: "Northwind", total: 3600)])
        #expect(contents(dayFile(root, "2026-11-03")) == before)
    }

    @Test func aRelabelReturnsWhatItStoredAndLeavesTheDaysTotalAndClockTime() throws {
        try write(root, "2026-11-03", """
            { "project": "Northwnd", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "agent" },
            { "project": "Internal", "start": "2026-11-03T09:30:00-05:00", "end": "2026-11-03T10:30:00-05:00", "source": "app" },
            { "project": "Northwnd", "seconds": 900, "note": "manual" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)
        let (total, clockTime) = (tracker.dayTotal(tracker.today), tracker.elapsed(tracker.today))

        let relabeled = try tracker.relabel("northwnd", to: "Northwind", on: tracker.today)

        #expect(relabeled == Relabeling(
            project: "Northwind", day: tracker.today,
            entries: [TimedEntry(project: "Northwind", start: clock.date("2026-11-03T09:00:00"),
                                 end: clock.date("2026-11-03T10:00:00"), source: .agent)],
            total: 75 * 60))
        #expect(tracker.dayTotal(tracker.today) == total)
        #expect(tracker.elapsed(tracker.today) == clockTime)
    }

    @Test func theNewLabelIsWrittenUnderItsStoredSpelling() throws {
        try "Northwind, Ticket 665\n".write(to: projectsFile(root), atomically: true, encoding: .utf8)
        try write(root, "2026-11-03", #"    { "project": "Northwnd", "seconds": 1800, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)

        let relabeled = try tracker.relabel("Northwnd", to: "northwind, ticket 665", on: tracker.today)

        #expect(relabeled.project == "Northwind, Ticket 665")
        #expect(contents(dayFile(root, "2026-11-03"))?.contains(#""project": "Northwind, Ticket 665""#) == true)
    }

    @Test func anEmptyNewLabelIsRefusedAndChangesNothing() throws {
        try write(root, "2026-11-03", #"    { "project": "Northwnd", "seconds": 1800, "note": "manual" }"#)
        let before = contents(dayFile(root, "2026-11-03"))
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(throws: EmptyProjectName.self) { try tracker.relabel("Northwnd", to: "  ", on: tracker.today) }

        #expect(contents(dayFile(root, "2026-11-03")) == before)
    }

    @Test func aLabelWithNoEntriesOnThatDayIsRefused() throws {
        try write(root, "2026-11-02", #"    { "project": "Northwnd", "seconds": 1800, "note": "manual" }"#)
        try write(root, "2026-11-03", #"    { "project": "Internal", "seconds": 1800, "note": "manual" }"#)
        let before = contents(dayFile(root, "2026-11-03"))
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(throws: NoTimeOnDay(project: "Northwnd", day: tracker.today)) {
            try tracker.relabel(" Northwnd ", to: "Northwind", on: tracker.today)
        }

        #expect(contents(dayFile(root, "2026-11-03")) == before)
    }

    @Test func theSameLabelWithTheSameSpellingSucceedsWithoutChangingAnything() throws {
        try "Northwind\n".write(to: projectsFile(root), atomically: true, encoding: .utf8)
        try write(root, "2026-11-03", """
            { "project": "northwind", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "app" }
        """)
        let before = contents(dayFile(root, "2026-11-03"))
        let tracker = Tracker(clock: clock, storageRoot: root)

        let relabeled = try tracker.relabel("Northwind", to: " Northwind ", on: tracker.today)

        #expect(relabeled == Relabeling(
            project: "Northwind", day: tracker.today,
            entries: [TimedEntry(project: "northwind", start: clock.date("2026-11-03T09:00:00"),
                                 end: clock.date("2026-11-03T10:00:00"), source: .app)],
            total: 3600))
        #expect(contents(dayFile(root, "2026-11-03")) == before)
    }

    // MARK: Merging

    @Test func relabelingIntoALabelWithTimeThatDayMergesTheRowsAndKeepsTheDaysTotalAndClockTime() throws {
        try write(root, "2026-11-03", """
            { "project": "Northwind", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "app" },
            { "project": "Northwnd", "start": "2026-11-03T10:30:00-05:00", "end": "2026-11-03T11:00:00-05:00", "source": "agent" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)
        let (total, clockTime) = (tracker.dayTotal(tracker.today), tracker.elapsed(tracker.today))

        let relabeled = try tracker.relabel("Northwnd", to: "northwind", on: tracker.today)

        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Northwind", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "app" },
            { "project": "Northwind", "start": "2026-11-03T10:30:00-05:00", "end": "2026-11-03T11:00:00-05:00", "source": "agent" }
          ]
        }

        """)
        #expect(tracker.rows(tracker.today) == [Row(project: "Northwind", total: 90 * 60)])
        #expect(relabeled == Relabeling(
            project: "Northwind", day: tracker.today,
            entries: [TimedEntry(project: "Northwind", start: clock.date("2026-11-03T09:00:00"),
                                 end: clock.date("2026-11-03T10:00:00"), source: .app),
                      TimedEntry(project: "Northwind", start: clock.date("2026-11-03T10:30:00"),
                                 end: clock.date("2026-11-03T11:00:00"), source: .agent)],
            total: 90 * 60))
        #expect(tracker.dayTotal(tracker.today) == total)
        #expect(tracker.elapsed(tracker.today) == clockTime)
    }

    @Test func manualEntriesAlwaysMerge() throws {
        try write(root, "2026-11-03", """
            { "project": "Northwind", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "app" },
            { "project": "Northwind", "seconds": 600, "note": "manual" },
            { "project": "Northwnd", "seconds": 7200, "note": "manual" },
            { "project": "Northwnd", "seconds": -300, "note": "adjustment" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)

        try tracker.relabel("Northwnd", to: "Northwind", on: tracker.today)

        #expect(tracker.rows(tracker.today) == [Row(project: "Northwind", total: (60 + 10 + 120 - 5) * 60)])
    }

    @Test func aMergeWhoseTimedEntriesOverlapIsRefusedNamingTheNewLabelsEntryAndChangesNothing() throws {
        try write(root, "2026-11-03", """
            { "project": "Northwnd", "start": "2026-11-03T08:00:00-05:00", "end": "2026-11-03T08:30:00-05:00", "source": "app" },
            { "project": "Northwind", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "app" },
            { "project": "Northwnd", "start": "2026-11-03T09:45:00-05:00", "end": "2026-11-03T10:15:00-05:00", "source": "agent" }
        """)
        let before = contents(dayFile(root, "2026-11-03"))
        let tracker = Tracker(clock: clock, storageRoot: root)

        let overlap = #expect(throws: Overlap.self) {
            try tracker.relabel("Northwnd", to: "Northwind", on: tracker.today)
        }

        #expect(overlap?.project == "Northwind")
        #expect(overlap?.start == clock.date("2026-11-03T09:00:00"))
        #expect(overlap?.end == clock.date("2026-11-03T10:00:00"))
        #expect(contents(dayFile(root, "2026-11-03")) == before)
    }

    @Test func entriesThatOnlyTouchEndToStartMerge() throws {
        try write(root, "2026-11-03", """
            { "project": "Northwind", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "app" },
            { "project": "Northwnd", "start": "2026-11-03T10:00:00-05:00", "end": "2026-11-03T10:30:00-05:00", "source": "app" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)

        try tracker.relabel("Northwnd", to: "Northwind", on: tracker.today)

        #expect(tracker.rows(tracker.today) == [Row(project: "Northwind", total: 90 * 60)])
    }

    @Test func aMergeIntoALabelRunningThatDayIsRefusedForNow() throws {
        try write(root, "2026-11-03", #"    { "project": "Northwnd", "seconds": 1800, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Northwind")
        clock.set("2026-11-03T13:00:00")
        let before = contents(dayFile(root, "2026-11-03"))

        #expect(throws: UnsupportedRelabel(project: "Northwind", reason: .mergeIntoRunning)) {
            try tracker.relabel("Northwnd", to: "northwind", on: tracker.today)
        }

        #expect(contents(dayFile(root, "2026-11-03")) == before)
        #expect(tracker.isRunning("Northwind"))
    }

    @Test func aMergeOnAnEarlierDayIntoALabelRunningTodayGoesAhead() throws {
        try write(root, "2026-11-02", """
            { "project": "Northwind", "seconds": 3600, "note": "manual" },
            { "project": "Northwnd", "seconds": 1800, "note": "manual" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Northwind")

        try tracker.relabel("Northwnd", to: "Northwind", on: Day(year: 2026, month: 11, day: 2))

        #expect(tracker.rows(Day(year: 2026, month: 11, day: 2)) == [Row(project: "Northwind", total: 90 * 60)])
        #expect(tracker.isRunning("Northwind"))
    }

    // MARK: Capitalisation and spacing

    @Test func aCapitalisationOrSpacingFixWritesTheNewSpellingToThatDaysEntries() throws {
        try write(root, "2026-11-02", #"    { "project": "northwind", "seconds": 3600, "note": "manual" }"#)
        try write(root, "2026-11-03", """
            { "project": "northwind", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "app" },
            { "project": "NORTHWIND ", "seconds": 1800, "note": "manual" }
        """)
        let before = contents(dayFile(root, "2026-11-02"))
        let tracker = Tracker(clock: clock, storageRoot: root)

        let relabeled = try tracker.relabel("northwind", to: " Northwind ", on: tracker.today)

        #expect(relabeled.project == "Northwind")
        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Northwind", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:00:00-05:00", "source": "app" },
            { "project": "Northwind", "seconds": 1800, "note": "manual" }
          ]
        }

        """)
        #expect(tracker.rows(tracker.today) == [Row(project: "Northwind", total: 90 * 60)])
        #expect(contents(dayFile(root, "2026-11-02")) == before)
    }

    @Test func aFixOnAPinnedLabelRewritesItsPinnedSpellingSoEveryDayShowsIt() throws {
        try "Internal\nnorthwind\n".write(to: projectsFile(root), atomically: true, encoding: .utf8)
        try write(root, "2026-11-02", #"    { "project": "northwind", "seconds": 3600, "note": "manual" }"#)
        try write(root, "2026-11-03", #"    { "project": "northwind", "seconds": 1800, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)

        let relabeled = try tracker.relabel("northwind", to: "Northwind", on: tracker.today)

        #expect(relabeled.project == "Northwind")
        #expect(contents(projectsFile(root)) == "Internal\nNorthwind\n")
        #expect(tracker.projects == ["Internal", "Northwind"])
        #expect(tracker.rows(tracker.today) == [Row(project: "Northwind", total: 1800)])
        #expect(tracker.rows(Day(year: 2026, month: 11, day: 2)) == [Row(project: "Northwind", total: 3600)])
    }

    @Test func aFixOnAnArchivedLabelRewritesItsArchivedSpellingAndLeavesItArchived() throws {
        try "Mobile App\nnorthwind\n".write(to: archivedFile(root), atomically: true, encoding: .utf8)
        try write(root, "2026-11-03", #"    { "project": "northwind", "seconds": 1800, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)

        let relabeled = try tracker.relabel("northwind", to: "Northwind", on: tracker.today)

        #expect(relabeled.project == "Northwind")
        #expect(contents(archivedFile(root)) == "Mobile App\nNorthwind\n")
        #expect(tracker.archived == ["Mobile App", "Northwind"])
        #expect(tracker.rows(tracker.today) == [Row(project: "Northwind", total: 1800)])
    }

    @Test func aFixWhosePinnedFileCantBeReplacedChangesNeitherFile() throws {
        try "northwind\n".write(to: projectsFile(root), atomically: true, encoding: .utf8)
        try write(root, "2026-11-03", #"    { "project": "northwind", "seconds": 1800, "note": "manual" }"#)
        let before = contents(dayFile(root, "2026-11-03"))
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: projectsFile(root).path)
        defer { try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: projectsFile(root).path) }
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(throws: (any Error).self) { try tracker.relabel("northwind", to: "Northwind", on: tracker.today) }

        #expect(contents(projectsFile(root)) == "northwind\n")
        #expect(contents(dayFile(root, "2026-11-03")) == before)
        #expect(tracker.rows(tracker.today) == [Row(project: "northwind", total: 1800)])
    }

    // MARK: Pinned and Archived Labels

    @Test func relabelingOntoAnArchivedLabelBringsItBackInTheSameSave() throws {
        try "Mobile App\n".write(to: archivedFile(root), atomically: true, encoding: .utf8)
        try write(root, "2026-11-03", #"    { "project": "Mobile", "seconds": 1800, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)

        let relabeled = try tracker.relabel("Mobile", to: "mobile app", on: tracker.today)

        #expect(relabeled.project == "Mobile App")
        #expect(contents(archivedFile(root)) == "")
        #expect(tracker.archived == [])
        #expect(tracker.suggestions(for: "mob") == ["Mobile App"])
    }

    @Test func relabelingOntoAnArchivedLabelChangesNeitherFileWhenTheArchivedFileCantBeReplaced() throws {
        try "Mobile App\n".write(to: archivedFile(root), atomically: true, encoding: .utf8)
        try write(root, "2026-11-03", #"    { "project": "Mobile", "seconds": 1800, "note": "manual" }"#)
        let before = contents(dayFile(root, "2026-11-03"))
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: archivedFile(root).path)
        defer { try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: archivedFile(root).path) }
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(throws: (any Error).self) { try tracker.relabel("Mobile", to: "mobile app", on: tracker.today) }

        #expect(contents(archivedFile(root)) == "Mobile App\n")
        #expect(contents(dayFile(root, "2026-11-03")) == before)
        #expect(tracker.archived == ["Mobile App"])
    }

    @Test func theOldLabelStaysPinnedOrArchived() throws {
        try "Northwnd\n".write(to: projectsFile(root), atomically: true, encoding: .utf8)
        try "Internl\n".write(to: archivedFile(root), atomically: true, encoding: .utf8)
        try write(root, "2026-11-03", """
            { "project": "Northwnd", "seconds": 1800, "note": "manual" },
            { "project": "Internl", "seconds": 900, "note": "manual" }
        """)
        let tracker = Tracker(clock: clock, storageRoot: root)

        try tracker.relabel("Northwnd", to: "Northwind", on: tracker.today)
        try tracker.relabel("Internl", to: "Internal", on: tracker.today)

        #expect(contents(projectsFile(root)) == "Northwnd\n")
        #expect(contents(archivedFile(root)) == "Internl\n")
        #expect(tracker.projects == ["Northwnd"])
        #expect(tracker.archived == ["Internl"])
    }

    @Test func aMalformedLabelListRefusesARelabelNamingItAndChangesNothing() throws {
        try Data([0x49, 0x6E, 0xFF, 0xFE, 0x0A]).write(to: archivedFile(root))
        try write(root, "2026-11-03", #"    { "project": "northwind", "seconds": 1800, "note": "manual" }"#)
        let before = contents(dayFile(root, "2026-11-03"))
        let tracker = Tracker(clock: clock, storageRoot: root)

        for name in ["Northwind", "Internal"] {
            #expect(throws: MalformedLabelList(list: .archived)) {
                try tracker.relabel("northwind", to: name, on: tracker.today)
            }
        }

        #expect(contents(dayFile(root, "2026-11-03")) == before)
    }

    // MARK: Not yet supported

    @Test func relabelingARunningTimerIsRefusedForNow() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Northwnd")
        clock.set("2026-11-03T13:00:00")
        let before = contents(dayFile(root, "2026-11-03"))

        #expect(throws: UnsupportedRelabel(project: "Northwnd", reason: .running)) {
            try tracker.relabel("northwnd", to: "Northwind", on: tracker.today)
        }

        #expect(contents(dayFile(root, "2026-11-03")) == before)
        #expect(tracker.isRunning("Northwnd"))
    }

    @Test func aCapitalisationFixOfARunningTimerIsRefusedForNow() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("northwind")
        let before = contents(dayFile(root, "2026-11-03"))

        #expect(throws: UnsupportedRelabel(project: "northwind", reason: .running)) {
            try tracker.relabel("northwind", to: "Northwind", on: tracker.today)
        }

        #expect(contents(dayFile(root, "2026-11-03")) == before)
        #expect(tracker.timers.newest?.project == "northwind")
    }

    @Test func relabelingTheEarlierPieceOfARunStillRunningIsRefusedForNow() throws {
        clock.set("2026-11-02T23:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Northwnd")
        clock.set("2026-11-03T01:00:00")
        tracker.tick()
        let before = contents(dayFile(root, "2026-11-02"))

        #expect(throws: UnsupportedRelabel(project: "Northwnd", reason: .running)) {
            try tracker.relabel("Northwnd", to: "Northwind", on: Day(year: 2026, month: 11, day: 2))
        }

        #expect(contents(dayFile(root, "2026-11-02")) == before)
    }

    @Test func aRowOfALabelThatIsRunningTodayCanBeRelabeledOnAnEarlierDay() throws {
        try write(root, "2026-11-02", #"    { "project": "Northwnd", "seconds": 1800, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Northwnd")

        try tracker.relabel("Northwnd", to: "Northwind", on: Day(year: 2026, month: 11, day: 2))

        #expect(tracker.rows(Day(year: 2026, month: 11, day: 2)) == [Row(project: "Northwind", total: 1800)])
        #expect(tracker.isRunning("Northwnd"))
    }

    // MARK: All or nothing

    @Test func aDayWhoseFileWontParseIsRefusedAndNamed() throws {
        try write(root, "2026-11-02", #"    { "project": "Northwnd", "seconds": 1800, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)
        _ = tracker.rows(Day(year: 2026, month: 11, day: 2))
        try "{ oops".write(to: dayFile(root, "2026-11-02"), atomically: true, encoding: .utf8)

        for name in ["Northwind", "Northwnd"] {
            #expect(throws: MalformedDayFile(day: Day(year: 2026, month: 11, day: 2))) {
                try tracker.relabel("Northwnd", to: name, on: Day(year: 2026, month: 11, day: 2))
            }
        }

        #expect(contents(dayFile(root, "2026-11-02")) == "{ oops")
    }

    @Test func aDayWithWritesWaitingIsRefusedAndNamed() throws {
        try write(root, "2026-11-03", #"    { "project": "Northwnd", "seconds": 1800, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        let good = try #require(contents(dayFile(root, "2026-11-03")))
        try "{ oops".write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        try tracker.pause()
        try good.write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: dayFile(root, "2026-11-03").path)
        defer {
            try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: dayFile(root, "2026-11-03").path)
        }

        #expect(throws: MalformedDayFile(day: tracker.today)) {
            try tracker.relabel("Northwnd", to: "Northwind", on: tracker.today)
        }

        #expect(contents(dayFile(root, "2026-11-03")) == good)
    }
}

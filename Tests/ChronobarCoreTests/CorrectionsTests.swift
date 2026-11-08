import Foundation
import Testing
import ChronobarCore

/// Fixing recordings after the fact: stop at an earlier time, move a timer's start, add a finished Entry.
@MainActor @Suite struct CorrectionsTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func stoppingAtAnEarlierTimeEndsTheEntryThere() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign", source: .agent)
        clock.set("2026-11-03T11:00:00")

        let stopped = try tracker.stop("website redesign", at: clock.date("2026-11-03T10:15:00"))

        #expect(stopped == TimedEntry(project: "Website Redesign", start: clock.date("2026-11-03T09:00:00"),
                                      end: clock.date("2026-11-03T10:15:00"), source: .agent))
        #expect(tracker.timers.isEmpty)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 75 * 60)
        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": "2026-11-03T10:15:00-05:00", "source": "agent" }
          ]
        }

        """)
    }

    @Test func stoppingInTheFutureIsRefusedAndChangesNothing() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        let before = contents(dayFile(root, "2026-11-03"))

        #expect(throws: FutureTime.self) { try tracker.stop("Website Redesign", at: clock.date("2026-11-03T10:01:00")) }

        #expect(tracker.isRunning("Website Redesign"))
        #expect(contents(dayFile(root, "2026-11-03")) == before)
    }

    @Test func stoppingBeforeTheTimerStartedIsRefusedAndChangesNothing() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        let before = contents(dayFile(root, "2026-11-03"))

        for end in ["2026-11-03T08:59:00", "2026-11-03T09:00:00"] {
            #expect(throws: EndBeforeStart.self) { try tracker.stop("Website Redesign", at: clock.date(end)) }
        }

        #expect(tracker.isRunning("Website Redesign"))
        #expect(contents(dayFile(root, "2026-11-03")) == before)
    }

    @Test func stoppingALabelThatIsNotRunningIsRefused() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")

        #expect(throws: NotRunning(project: "Website Redesign")) {
            try tracker.stop(" Website Redesign ", at: clock.date("2026-11-03T09:00:00"))
        }
        #expect(tracker.isRunning("Internal"))
    }

    @Test func stoppingAfterMidnightKeepsEachDaysTimeOnItsOwnDay() throws {
        clock.set("2026-11-03T23:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign", source: .agent)
        clock.set("2026-11-04T01:00:00")

        let stopped = try tracker.stop("Website Redesign", at: clock.date("2026-11-04T00:30:00"))

        #expect(stopped.start == clock.date("2026-11-04T00:00:00"))
        #expect(tracker.total("Website Redesign", on: Day(year: 2026, month: 11, day: 3)) == 60 * 60)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 30 * 60)
        #expect(contents(dayFile(root, "2026-11-04"))?.contains(
            #""start": "2026-11-04T00:00:00-05:00", "end": "2026-11-04T00:30:00-05:00", "source": "agent" }"#) == true)
    }

    @Test func stoppingBackBeforeMidnightRemovesTheTimeAfterIt() throws {
        clock.set("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign", source: .agent)
        try tracker.start("Internal")
        clock.set("2026-11-04T08:00:00")
        tracker.tick()

        let stopped = try tracker.stop("Website Redesign", at: clock.date("2026-11-03T23:30:00"))

        #expect(stopped == TimedEntry(project: "Website Redesign", start: clock.date("2026-11-03T22:00:00"),
                                      end: clock.date("2026-11-03T23:30:00"), source: .agent))
        #expect(tracker.timers.map(\.project) == ["Internal"])
        #expect(tracker.total("Website Redesign", on: Day(year: 2026, month: 11, day: 3)) == 90 * 60)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 0)
        #expect(tracker.rows(tracker.today).map(\.project) == ["Internal"])
    }

    @Test func stoppingAtATimeIsRefusedWhileADayItWritesIsMalformed() throws {
        clock.set("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-04T08:00:00")
        tracker.tick()
        try "not json".write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)
        let today = contents(dayFile(root, "2026-11-04"))

        #expect(throws: MalformedDayFile(day: Day(year: 2026, month: 11, day: 3))) {
            try tracker.stop("Website Redesign", at: clock.date("2026-11-03T23:30:00"))
        }

        #expect(tracker.isRunning("Website Redesign"))
        #expect(contents(dayFile(root, "2026-11-04")) == today)
        #expect(contents(dayFile(root, "2026-11-03")) == "not json")
    }

    // MARK: Set start

    @Test(arguments: ["2026-11-03T08:15:00", "2026-11-03T09:30:00"])
    func settingTheStartMovesTheRunningTimersStart(start: String) throws {
        try write(root, "2026-11-03", #"    { "project": "Internal", "seconds": 600, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign", source: .agent)
        clock.set("2026-11-03T10:00:00")

        let run = try tracker.setStart("website redesign", at: clock.date(start))

        #expect(run == [TimedEntry(project: "Website Redesign", start: clock.date(start), end: nil, source: .agent)])
        #expect(tracker.timers.map(\.start) == [clock.date(start)])
        #expect(tracker.total("Website Redesign", on: tracker.today) == clock.now.timeIntervalSince(clock.date(start)))
        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Internal", "seconds": 600, "note": "manual" },
            { "project": "Website Redesign", "start": "\(start)-05:00", "end": null, "source": "agent" }
          ]
        }

        """)
    }

    @Test func settingTheStartInTheFutureIsRefused() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        let before = contents(dayFile(root, "2026-11-03"))

        #expect(throws: FutureTime.self) { try tracker.setStart("Website Redesign", at: clock.date("2026-11-03T09:05:00")) }

        #expect(tracker.timers.map(\.start) == [clock.date("2026-11-03T09:00:00")])
        #expect(contents(dayFile(root, "2026-11-03")) == before)
    }

    @Test func settingTheStartOfALabelThatIsNotRunningIsRefused() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(throws: NotRunning(project: "Website Redesign")) {
            try tracker.setStart("Website Redesign", at: clock.date("2026-11-03T08:00:00"))
        }
        #expect(tracker.timers.isEmpty)
    }

    @Test func settingTheStartBeforeMidnightPutsThatTimeOnTheDayBefore() throws {
        clock.set("2026-11-04T00:30:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign", source: .agent)
        clock.set("2026-11-04T01:00:00")

        let run = try tracker.setStart("Website Redesign", at: clock.date("2026-11-03T23:15:00"))

        #expect(run.map(\.start) == [clock.date("2026-11-03T23:15:00"), clock.date("2026-11-04T00:00:00")])
        #expect(run.map(\.end) == [clock.date("2026-11-04T00:00:00"), nil])
        #expect(tracker.timers.map(\.start) == [clock.date("2026-11-04T00:00:00")])
        #expect(tracker.total("Website Redesign", on: Day(year: 2026, month: 11, day: 3)) == 45 * 60)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 60 * 60)
        #expect(contents(dayFile(root, "2026-11-03"))?.contains(
            #""start": "2026-11-03T23:15:00-05:00", "end": "2026-11-04T00:00:00-05:00", "source": "agent" }"#) == true)
    }

    @Test func settingTheStartAfterMidnightTakesTheTimeOffTheDayBefore() throws {
        clock.set("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-04T08:00:00")
        tracker.tick()

        _ = try tracker.setStart("Website Redesign", at: clock.date("2026-11-04T07:00:00"))

        #expect(tracker.total("Website Redesign", on: Day(year: 2026, month: 11, day: 3)) == 0)
        #expect(tracker.rows(Day(year: 2026, month: 11, day: 3)).isEmpty)
        #expect(tracker.timers.map(\.start) == [clock.date("2026-11-04T07:00:00")])
        #expect(tracker.total("Website Redesign", on: tracker.today) == 60 * 60)
    }

    @Test func settingTheStartOverTheLabelsEarlierTimeIsRefused() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.pause("Website Redesign")
        clock.set("2026-11-03T11:00:00")
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T12:00:00")
        let before = contents(dayFile(root, "2026-11-03"))

        #expect(throws: Overlap.self) { try tracker.setStart("Website Redesign", at: clock.date("2026-11-03T09:30:00")) }

        #expect(contents(dayFile(root, "2026-11-03")) == before)
        _ = try tracker.setStart("Website Redesign", at: clock.date("2026-11-03T10:00:00"))
        #expect(tracker.total("Website Redesign", on: tracker.today) == 3 * 60 * 60)
    }

    // MARK: Add an Entry

    @Test func addingAnEntryByTimesWritesAFinishedEntry() throws {
        try write(root, "2026-11-02", #"    { "project": "Website Redesign", "seconds": 600, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)

        let added = try tracker.addEntry(" website redesign ", start: clock.date("2026-11-03T07:00:00"),
                                         end: clock.date("2026-11-03T08:20:00"), source: .agent)

        #expect(added == [TimedEntry(project: "Website Redesign", start: clock.date("2026-11-03T07:00:00"),
                                     end: clock.date("2026-11-03T08:20:00"), source: .agent)])
        #expect(tracker.timers.isEmpty)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 80 * 60)
        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T07:00:00-05:00", "end": "2026-11-03T08:20:00-05:00", "source": "agent" }
          ]
        }

        """)
    }

    @Test func addingAnEntryAcrossMidnightSplitsItAcrossBothDays() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)

        let added = try tracker.addEntry("Website Redesign", start: clock.date("2026-11-02T23:00:00"),
                                         end: clock.date("2026-11-03T00:45:00"))

        #expect(added.map(\.start) == [clock.date("2026-11-02T23:00:00"), clock.date("2026-11-03T00:00:00")])
        #expect(added.map(\.end) == [clock.date("2026-11-03T00:00:00"), clock.date("2026-11-03T00:45:00")])
        #expect(tracker.total("Website Redesign", on: Day(year: 2026, month: 11, day: 2)) == 60 * 60)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 45 * 60)
    }

    @Test(arguments: [("2026-11-03T08:00:00", "2026-11-03T09:01:00"), ("2026-11-03T09:30:00", "2026-11-03T10:00:00")])
    func addingAnEntryEndingInTheFutureIsRefused(start: String, end: String) throws {
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(throws: FutureTime.self) {
            try tracker.addEntry("Website Redesign", start: clock.date(start), end: clock.date(end))
        }
        #expect(contents(dayFile(root, "2026-11-03")) == nil)
    }

    @Test(arguments: ["2026-11-03T07:59:00", "2026-11-03T08:00:00"])
    func addingAnEntryEndingBeforeItStartsIsRefused(end: String) throws {
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(throws: EndBeforeStart.self) {
            try tracker.addEntry("Website Redesign", start: clock.date("2026-11-03T08:00:00"), end: clock.date(end))
        }
        #expect(contents(dayFile(root, "2026-11-03")) == nil)
    }

    @Test func addingAnEntryOverTheLabelsRunningTimerIsRefused() throws {
        clock.set("2026-11-03T08:30:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        try tracker.start("Internal")
        clock.set("2026-11-03T09:00:00")
        let before = contents(dayFile(root, "2026-11-03"))

        #expect(throws: Overlap.self) {
            try tracker.addEntry("Website Redesign", start: clock.date("2026-11-03T08:00:00"),
                                 end: clock.date("2026-11-03T08:45:00"))
        }

        #expect(contents(dayFile(root, "2026-11-03")) == before)
        _ = try tracker.addEntry("Website Redesign", start: clock.date("2026-11-03T08:00:00"),
                                 end: clock.date("2026-11-03T08:30:00"))
        #expect(tracker.total("Website Redesign", on: tracker.today) == 60 * 60)
    }

    @Test func addingAnEntryIsRefusedWhileADayItWritesIsMalformed() throws {
        try "not json".write(to: dayFile(root, "2026-11-02").creatingFolder(), atomically: true, encoding: .utf8)
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(throws: MalformedDayFile(day: Day(year: 2026, month: 11, day: 2))) {
            try tracker.addEntry("Website Redesign", start: clock.date("2026-11-02T23:00:00"),
                                 end: clock.date("2026-11-03T00:45:00"))
        }
        #expect(contents(dayFile(root, "2026-11-03")) == nil)
    }

    @Test func addingAnEntryBringsBackAnArchivedLabel() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.archiveProject("Website Redesign")

        _ = try tracker.addEntry("website redesign", start: clock.date("2026-11-03T07:00:00"),
                                 end: clock.date("2026-11-03T08:00:00"))

        #expect(tracker.archived.isEmpty)
        #expect(tracker.rows(tracker.today).map(\.project) == ["Website Redesign"])
    }

    @Test func addingADurationOnADayWritesAManualEntry() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let yesterday = Day(year: 2026, month: 11, day: 2)

        let project = try tracker.addEntry("Website Redesign", duration: "1:30", on: yesterday).project

        #expect(project == "Website Redesign")
        #expect(tracker.total("Website Redesign", on: yesterday) == 90 * 60)
        #expect(contents(dayFile(root, "2026-11-02"))?.contains(
            #"{ "project": "Website Redesign", "seconds": 5400, "note": "manual" }"#) == true)
    }

    @Test func addingADurationOnAPastDayReturnsThatDayAndTheSecondsStored() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let past = Day(year: 2026, month: 10, day: 28)

        let logged = try tracker.addEntry("Website Redesign", duration: "45", on: past)

        #expect(logged.day == past)
        #expect(logged.seconds == 45 * 60)
        #expect(tracker.total("Website Redesign", on: past) == 45 * 60)
    }

    @Test func addingADurationOnAFutureDayIsRefused() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(throws: FutureDay(day: Day(year: 2026, month: 11, day: 4))) {
            try tracker.addEntry("Website Redesign", duration: "1:30", on: Day(year: 2026, month: 11, day: 4))
        }
        #expect(contents(dayFile(root, "2026-11-04")) == nil)
    }

    @Test(arguments: ["0", "+15", "soon"])
    func addingADurationThatIsNotAPositiveTotalIsRefused(duration: String) throws {
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(throws: InvalidDuration(text: duration)) {
            try tracker.addEntry("Website Redesign", duration: duration, on: tracker.today)
        }
    }
}

private extension URL {
    /// This file's URL, once its folder exists.
    func creatingFolder() throws -> URL {
        try FileManager.default.createDirectory(at: deletingLastPathComponent(), withIntermediateDirectories: true)
        return self
    }
}

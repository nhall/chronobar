import Foundation
import Testing
import ChronobarCore
import ChronobarOperations

/// `stop` at a time, `set_start`, `add_entry` and `adjust`: each echoes what was stored and the Label's new
/// totals, and refuses bad times with an error that changes nothing.
@MainActor @Suite struct CorrectionsTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    // MARK: Stop at a time

    @Test func stoppingAtATimeEchoesTheStoredEntryAndTotals() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let operations = Operations(tracker: tracker)
        _ = try operations.start("Website Redesign")
        clock.set("2026-11-03T11:00:00")

        let stopped = try operations.stop("Website Redesign", at: clock.date("2026-11-03T10:15:00"))

        #expect(stopped.entry == EntryResult(label: "Website Redesign", start: clock.date("2026-11-03T09:00:00"),
                                             end: clock.date("2026-11-03T10:15:00"), source: .agent,
                                             totalSeconds: 75 * 60))
        #expect(stopped.running.isEmpty)
        #expect(stopped.today == DayResult(date: "2026-11-03", totalSeconds: 75 * 60, totalMinutes: 75, elapsedSeconds: 75 * 60, elapsedMinutes: 75))
    }

    @Test func stoppingWithoutALabelAtATimeTakesTheOnlyRunningTimer() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        clock.set("2026-11-03T10:00:00")

        let stopped = try Operations(tracker: tracker).stop(at: clock.date("2026-11-03T09:40:00"))

        #expect(stopped.entry.label == "Internal")
        #expect(stopped.entry.end == clock.date("2026-11-03T09:40:00"))
    }

    @Test func stoppingBackBeforeMidnightEchoesTheEntryAndTotalOfThatDay() throws {
        clock.set("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        let operations = Operations(tracker: tracker)
        _ = try operations.start("Website Redesign")
        clock.set("2026-11-04T08:00:00")

        let stopped = try operations.stop("Website Redesign", at: clock.date("2026-11-03T23:30:00"))

        #expect(stopped.entry.start == clock.date("2026-11-03T22:00:00"))
        #expect(stopped.entry.end == clock.date("2026-11-03T23:30:00"))
        #expect(stopped.entry.totalSeconds == 90 * 60)
        #expect(stopped.today == DayResult(date: "2026-11-04", totalSeconds: 0, totalMinutes: 0, elapsedSeconds: 0, elapsedMinutes: 0))
    }

    @Test func stoppingAtAFutureTimeIsRefused() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let operations = Operations(tracker: tracker)
        _ = try operations.start("Website Redesign")

        let error = operations.perform(.stop(label: "Website Redesign", at: clock.date("2026-11-03T09:10:00"))).error

        #expect(error?.kind == .futureTime)
        #expect(error?.message.contains("09:10") == true)
        #expect(tracker.isRunning("Website Redesign"))
    }

    @Test func stoppingBeforeTheTimerStartedIsRefused() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let operations = Operations(tracker: tracker)
        _ = try operations.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")

        let error = operations.perform(.stop(label: "Website Redesign", at: clock.date("2026-11-03T08:00:00"))).error

        #expect(error?.kind == .endBeforeStart)
        #expect(tracker.isRunning("Website Redesign"))
    }

    @Test func stoppingAtATimeALabelThatIsNotRunningListsTheRunningOnes() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")

        let error = Operations(tracker: tracker).perform(.stop(label: "Website Redesign", at: clock.now)).error

        #expect(error?.kind == .notRunning)
        #expect(error?.running?.map(\.label) == ["Internal"])
    }

    // MARK: Set start

    @Test func settingTheStartEchoesTheTimerAndTotals() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let operations = Operations(tracker: tracker)
        _ = try operations.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")

        let moved = try operations.setStart("website redesign", at: clock.date("2026-11-03T08:15:00"))

        #expect(moved.timer == TimerResult(label: "Website Redesign", start: clock.date("2026-11-03T08:15:00"),
                                           source: .agent, totalSeconds: 105 * 60))
        #expect(moved.earlier.isEmpty)
        #expect(moved.today == DayResult(date: "2026-11-03", totalSeconds: 105 * 60, totalMinutes: 105, elapsedSeconds: 105 * 60, elapsedMinutes: 105))
    }

    @Test func settingTheStartBeforeMidnightEchoesTheEntryOnTheDayBefore() throws {
        clock.set("2026-11-04T00:30:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        let operations = Operations(tracker: tracker)
        _ = try operations.start("Website Redesign")
        clock.set("2026-11-04T01:00:00")

        let moved = try operations.setStart(nil, at: clock.date("2026-11-03T23:15:00"))

        #expect(moved.earlier == [EntryResult(label: "Website Redesign", start: clock.date("2026-11-03T23:15:00"),
                                              end: clock.date("2026-11-04T00:00:00"), source: .agent,
                                              totalSeconds: 45 * 60)])
        #expect(moved.timer.start == clock.date("2026-11-04T00:00:00"))
        #expect(moved.timer.totalSeconds == 60 * 60)
    }

    @Test func settingTheStartInTheFutureIsRefused() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let operations = Operations(tracker: tracker)
        _ = try operations.start("Website Redesign")

        let error = operations.perform(.setStart(label: nil, at: clock.date("2026-11-03T09:30:00"))).error

        #expect(error?.kind == .futureTime)
        #expect(tracker.timers.map(\.start) == [clock.date("2026-11-03T09:00:00")])
    }

    @Test func settingTheStartWithSeveralRunningAndNoLabelIsAmbiguous() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Internal")
        try tracker.start("Website Redesign")

        let error = Operations(tracker: tracker).perform(.setStart(label: nil, at: clock.now)).error

        #expect(error?.kind == .ambiguous)
        #expect(error?.running?.count == 2)
    }

    @Test func settingTheStartOverTheLabelsEarlierTimeIsAnOverlap() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let operations = Operations(tracker: tracker)
        try tracker.addEntry("Website Redesign", start: clock.date("2026-11-03T07:00:00"),
                             end: clock.date("2026-11-03T08:00:00"))
        _ = try operations.start("Website Redesign")

        let error = operations.perform(.setStart(label: nil, at: clock.date("2026-11-03T07:30:00"))).error

        #expect(error?.kind == .overlap)
        #expect(error?.message.contains("07:00") == true)
    }

    // MARK: Add an Entry

    @Test func addingAnEntryByTimesEchoesTheStoredEntryAndTotals() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let operations = Operations(tracker: tracker)

        let added = try operations.addEntry("Website Redesign", .times(start: clock.date("2026-11-03T07:00:00"),
                                                                      end: clock.date("2026-11-03T08:20:00")))

        #expect(added.label == "Website Redesign")
        #expect(added.entries == [EntryResult(label: "Website Redesign", start: clock.date("2026-11-03T07:00:00"),
                                              end: clock.date("2026-11-03T08:20:00"), source: .agent,
                                              totalSeconds: 80 * 60)])
        #expect(added.manual == nil)
        #expect(added.days == [DayResult(date: "2026-11-03", totalSeconds: 80 * 60, totalMinutes: 80, elapsedSeconds: 80 * 60, elapsedMinutes: 80)])
        #expect(tracker.timers.isEmpty)
    }

    @Test func addingAnEntryAcrossMidnightEchoesBothDays() throws {
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let added = try operations.addEntry("Website Redesign", .times(start: clock.date("2026-11-02T23:00:00"),
                                                                      end: clock.date("2026-11-03T00:45:00")))

        #expect(added.entries.map(\.totalSeconds) == [60 * 60, 45 * 60])
        #expect(added.entries.map(\.end) == [clock.date("2026-11-03T00:00:00"), clock.date("2026-11-03T00:45:00")])
        #expect(added.days.map(\.date) == ["2026-11-02", "2026-11-03"])
    }

    @Test func addingADurationEchoesTheManualEntryAndTotals() throws {
        try write(root, "2026-11-02", #"    { "project": "Website Redesign", "seconds": 600, "note": "manual" }"#)
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let added = try operations.addEntry("website redesign", .duration("1:30", date: "2026-11-02"))

        #expect(added.label == "Website Redesign")
        #expect(added.entries.isEmpty)
        #expect(added.manual == ManualEntryResult(date: "2026-11-02", seconds: 90 * 60, totalSeconds: 100 * 60))
        #expect(added.days == [DayResult(date: "2026-11-02", totalSeconds: 100 * 60, totalMinutes: 100, elapsedSeconds: 0, elapsedMinutes: 0)])
    }

    @Test func addingADurationWithNoDayAddsItToday() throws {
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let added = try operations.addEntry("Website Redesign", .duration("45", date: nil))

        #expect(added.manual?.date == "2026-11-03")
    }

    @Test(arguments: [
        (EntrySpan.times(start: FakeClock("2026-11-03T08:00:00").now, end: FakeClock("2026-11-03T09:30:00").now),
         OperationError.Kind.futureTime),
        (.times(start: FakeClock("2026-11-03T08:00:00").now, end: FakeClock("2026-11-03T07:00:00").now),
         .endBeforeStart),
        (.duration("1:00", date: "2026-11-04"), .futureTime),
        (.duration("soon", date: nil), .invalidDuration),
    ])
    func badEntriesAreRefusedAndChangeNothing(span: EntrySpan, kind: OperationError.Kind) throws {
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let error = operations.perform(.addEntry(label: "Website Redesign", span: span)).error

        #expect(error?.kind == kind)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("days").path) == false)
    }

    @Test func addingAnEntryToAMalformedDayNamesThatDay() throws {
        try write(root, "2026-11-02", "not json")
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let error = operations.perform(.addEntry(label: "Website Redesign", span: .duration("1:00", date: "2026-11-02"))).error

        #expect(error?.kind == .malformedFile)
        #expect(error?.message.contains("days/2026-11-02.json") == true)
    }

    // MARK: Adjust

    @Test func adjustingEchoesTheLabelsNewTotalAndTheChange() throws {
        try write(root, "2026-11-02", #"    { "project": "Website Redesign", "seconds": 3600, "note": "manual" }"#)
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let adjusted = try operations.adjust("website redesign", "+15", date: "2026-11-02")

        #expect(adjusted == AdjustResult(label: "Website Redesign", date: "2026-11-02", changeSeconds: 15 * 60,
                                         totalSeconds: 75 * 60,
                                         day: DayResult(date: "2026-11-02", totalSeconds: 75 * 60, totalMinutes: 75, elapsedSeconds: 0, elapsedMinutes: 0)))
    }

    @Test func adjustingWithNoDayAdjustsToday() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let operations = Operations(tracker: tracker)
        _ = try operations.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")

        let adjusted = try operations.adjust("Website Redesign", "1:15", date: nil)

        #expect(adjusted.date == "2026-11-03")
        #expect(adjusted.changeSeconds == 15 * 60)
        #expect(adjusted.totalSeconds == 75 * 60)
        #expect(tracker.isRunning("Website Redesign"))
    }

    @Test func adjustingWithATypoIsRefused() throws {
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let error = operations.perform(.adjust(label: "Website Redesign", input: "1:75", date: nil)).error

        #expect(error?.kind == .invalidDuration)
        #expect(error?.message.contains("1:75") == true)
    }

    @Test func adjustingABlankLabelIsRefused() throws {
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        #expect(operations.perform(.adjust(label: " ", input: "1:00", date: nil)).error?.kind == .invalidLabel)
    }

    // MARK: Relabel

    @Test func relabelingEchoesTheStoredEntriesAndTheDaysTotals() throws {
        try write(root, "2026-11-02", """
            { "project": "Northwnd", "start": "2026-11-02T09:00:00-05:00", "end": "2026-11-02T10:00:00-05:00", "source": "agent" },
            { "project": "Northwnd", "seconds": 900, "note": "manual" }
        """)
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let relabeled = try operations.relabel("northwnd", to: "Northwind, Ticket 665", date: "2026-11-02")

        #expect(relabeled == RelabelResult(
            label: "Northwind, Ticket 665", date: "2026-11-02",
            entries: [EntryResult(label: "Northwind, Ticket 665", start: clock.date("2026-11-02T09:00:00"),
                                  end: clock.date("2026-11-02T10:00:00"), source: .agent, totalSeconds: 75 * 60)],
            totalSeconds: 75 * 60,
            day: DayResult(date: "2026-11-02", totalSeconds: 75 * 60, totalMinutes: 75, elapsedSeconds: 3600, elapsedMinutes: 60)))
    }

    @Test func relabelingWithNoDayRelabelsToday() throws {
        try write(root, "2026-11-03", #"    { "project": "Northwnd", "seconds": 900, "note": "manual" }"#)
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let relabeled = try operations.relabel("Northwnd", to: "Northwind", date: nil)

        #expect(relabeled.date == "2026-11-03")
        #expect(relabeled.entries.isEmpty)
        #expect(relabeled.totalSeconds == 900)
    }

    @Test func aCapitalisationFixEchoesTheNewSpelling() throws {
        let projectsFile = root.appendingPathComponent("projects.txt")
        try "northwnd\n".write(to: projectsFile, atomically: true, encoding: .utf8)
        try write(root, "2026-11-02", #"    { "project": "northwnd", "seconds": 900, "note": "manual" }"#)
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let relabeled = try operations.relabel("northwnd", to: "Northwnd", date: "2026-11-02")

        #expect(relabeled.label == "Northwnd")
        #expect(relabeled.totalSeconds == 900)
        #expect(contents(projectsFile) == "Northwnd\n")
    }

    @Test(arguments: [("Northwnd", " "), (" ", "Northwind")])
    func relabelingFromOrToABlankLabelIsRefused(label: String, newLabel: String) throws {
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let error = operations.perform(.relabel(label: label, newLabel: newLabel, date: nil)).error

        #expect(error?.kind == .invalidLabel)
    }

    @Test func relabelingALabelWithNoTimeThatDayIsRefusedNamingTheDay() throws {
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let error = operations.perform(.relabel(label: "Northwnd", newLabel: "Northwind", date: "2026-11-02")).error

        #expect(error?.kind == .unknownLabel)
        #expect(error?.message == "Northwnd has no time on 2026-11-02, so there's nothing to relabel.")
    }

    @Test func relabelingIntoALabelWithTimeThatDayEchoesTheMergedRow() throws {
        try write(root, "2026-11-02", """
            { "project": "Northwind", "start": "2026-11-02T09:00:00-05:00", "end": "2026-11-02T10:00:00-05:00", "source": "app" },
            { "project": "Northwnd", "seconds": 1800, "note": "manual" }
        """)
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let relabeled = try operations.relabel("Northwnd", to: "northwind", date: "2026-11-02")

        #expect(relabeled == RelabelResult(
            label: "Northwind", date: "2026-11-02",
            entries: [EntryResult(label: "Northwind", start: clock.date("2026-11-02T09:00:00"),
                                  end: clock.date("2026-11-02T10:00:00"), source: .app, totalSeconds: 90 * 60)],
            totalSeconds: 90 * 60,
            day: DayResult(date: "2026-11-02", totalSeconds: 90 * 60, totalMinutes: 90, elapsedSeconds: 3600, elapsedMinutes: 60)))
    }

    @Test func aMergeThatWouldCountTimeTwiceIsAnOverlapNamingTheNewLabelsEntry() throws {
        try write(root, "2026-11-02", """
            { "project": "Northwind", "start": "2026-11-02T09:00:00-05:00", "end": "2026-11-02T10:00:00-05:00", "source": "app" },
            { "project": "Northwnd", "start": "2026-11-02T09:30:00-05:00", "end": "2026-11-02T10:30:00-05:00", "source": "app" }
        """)
        let before = contents(dayFile(root, "2026-11-02"))
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let error = operations.perform(.relabel(label: "Northwnd", newLabel: "Northwind", date: "2026-11-02")).error

        #expect(error?.kind == .overlap)
        #expect(error?.message == "Northwind already has time from 2026-11-02T09:00:00-05:00 to "
                + "2026-11-02T10:00:00-05:00, which this would count twice.")
        #expect(contents(dayFile(root, "2026-11-02")) == before)
    }

    @Test func relabelsNotYetSupportedAreRefusedSayingWhy() throws {
        try write(root, "2026-11-03", #"    { "project": "Northwnd", "seconds": 900, "note": "manual" }"#)
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))
        _ = try operations.start("Internal")
        clock.set("2026-11-03T10:00:00")

        let running = operations.perform(.relabel(label: "Internal", newLabel: "Overhead", date: nil)).error
        let intoRunning = operations.perform(.relabel(label: "Northwnd", newLabel: "internal", date: nil)).error

        #expect(running?.kind == .failed)
        #expect(running?.message == "Internal's timer is running, and Chronobar can't relabel a running timer yet. "
                + "Stop it first, then relabel.")
        #expect(intoRunning?.kind == .failed)
        #expect(intoRunning?.message == "Internal's timer is running, and Chronobar can't merge time into a "
                + "running timer yet. Stop it first, then relabel.")
    }

    @Test func relabelingADayWhoseFileWontParseIsRefusedNamingIt() throws {
        try write(root, "2026-11-02", #"    { "project": "Northwnd", "seconds": 900, "note": "manual" }"#)
        try "{ oops".write(to: dayFile(root, "2026-11-02"), atomically: true, encoding: .utf8)
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let error = operations.perform(.relabel(label: "Northwnd", newLabel: "Northwind", date: "2026-11-02")).error

        #expect(error?.kind == .malformedFile)
        #expect(error?.message.contains("days/2026-11-02.json") == true)
    }

    // MARK: On the wire

    private func respond(_ line: String, _ operations: Operations) throws -> [String: Any] {
        let reply = operations.respond(to: Data(line.utf8))
        return try #require(try JSONSerialization.jsonObject(with: reply) as? [String: Any])
    }

    @Test func aStopLineWithATimeAnswersWithTheStoredTimes() throws {
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))
        _ = try operations.start("Website Redesign")
        clock.set("2026-11-03T11:00:00")

        let reply = try respond(#"{"op": "stop", "at": "2026-11-03T15:15:00Z"}"#, operations)

        let entry = try #require((reply["result"] as? [String: Any])?["entry"] as? [String: Any])
        #expect(entry["end"] as? String == "2026-11-03T10:15:00-05:00")
        #expect(entry["total_seconds"] as? Int == 75 * 60)
    }

    @Test func requestLinesForEachCorrectionAreRead() throws {
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))
        _ = try operations.start("Website Redesign")

        let moved = try respond(#"{"op": "set_start", "at": "2026-11-03T08:30:00-05:00"}"#, operations)
        let added = try respond(#"{"op": "add_entry", "label": "Internal", "start": "2026-11-03T07:00:00-05:00", "end": "2026-11-03T07:30:00-05:00"}"#, operations)
        let logged = try respond(#"{"op": "add_entry", "label": "Internal", "duration": "0:15", "date": "2026-11-02"}"#, operations)
        let adjusted = try respond(#"{"op": "adjust", "label": "Internal", "input": "-10"}"#, operations)
        let relabeled = try respond(#"{"op": "relabel", "label": "Internal", "new_label": "Overhead", "date": "2026-11-02"}"#, operations)

        #expect(moved["op"] as? String == "set_start")
        #expect(((moved["result"] as? [String: Any])?["timer"] as? [String: Any])?["start"] as? String
                == "2026-11-03T08:30:00-05:00")
        #expect(added["op"] as? String == "add_entry")
        #expect(((added["result"] as? [String: Any])?["entries"] as? [[String: Any]])?.count == 1)
        #expect(((logged["result"] as? [String: Any])?["manual"] as? [String: Any])?["date"] as? String == "2026-11-02")
        #expect((adjusted["result"] as? [String: Any])?["change_seconds"] as? Int == -10 * 60)
        #expect((adjusted["result"] as? [String: Any])?["total_seconds"] as? Int == 20 * 60)
        #expect(relabeled["op"] as? String == "relabel")
        #expect((relabeled["result"] as? [String: Any])?["label"] as? String == "Overhead")
        #expect((relabeled["result"] as? [String: Any])?["total_seconds"] as? Int == 15 * 60)
    }

    @Test(arguments: [#"{"op": "set_start", "at": "08:30"}"#, #"{"op": "set_start", "at": "2026-11-03T08:30:00"}"#])
    func aTimeWithoutADateAndOffsetIsAnInvalidRequestNamingIt(line: String) throws {
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let error = try #require(try respond(line, operations)["error"] as? [String: Any])

        #expect(error["kind"] as? String == "invalid_request")
        #expect((error["message"] as? String)?.contains(#""at""#) == true)
        #expect((error["message"] as? String)?.contains("ISO 8601") == true)
    }

    @Test func aDateThatIsNotADayIsAnInvalidDate() throws {
        let operations = Operations(tracker: Tracker(clock: clock, storageRoot: root))

        let error = try respond(#"{"op": "adjust", "label": "Internal", "input": "1:00", "date": "Tuesday"}"#, operations)["error"]

        #expect((error as? [String: Any])?["kind"] as? String == "invalid_date")
    }

    /// What the `chronobar` command sends and reads back, for each correction.
    @Test func everyCorrectionSurvivesTheRoundTrip() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        let operations = Operations(tracker: tracker)
        _ = try operations.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        let requests: [Request] = [
            .setStart(label: "Website Redesign", at: clock.date("2026-11-03T08:45:00")),
            .addEntry(label: "Internal", span: .times(start: clock.date("2026-11-03T07:00:00"), end: clock.date("2026-11-03T07:30:00"))),
            .addEntry(label: "Internal", span: .duration("15", date: "2026-11-02")),
            .adjust(label: "Internal", input: "+5", date: "2026-11-02"),
            .relabel(label: "Internal", newLabel: "Overhead", date: "2026-11-02"),
            .stop(label: nil, at: clock.date("2026-11-03T09:50:00")),
        ]

        for request in requests {
            let line = Wire.encode(request)
            #expect(Wire.request(from: line) == .success(request))
            let result = try Wire.response(from: operations.respond(to: line)).success()
            #expect(result.operation == request.operation)
        }
        #expect(tracker.total("Website Redesign", on: tracker.today) == 65 * 60)
    }
}

extension Operations {
    func stop(_ label: String? = nil, at end: Date) throws -> StopResult {
        guard case .stop(let result) = try perform(.stop(label: label, at: end)).success() else { throw Unexpected() }
        return result
    }

    func setStart(_ label: String?, at start: Date) throws -> SetStartResult {
        guard case .setStart(let result) = try perform(.setStart(label: label, at: start)).success() else {
            throw Unexpected()
        }
        return result
    }

    func addEntry(_ label: String, _ span: EntrySpan) throws -> AddEntryResult {
        guard case .addEntry(let result) = try perform(.addEntry(label: label, span: span)).success() else {
            throw Unexpected()
        }
        return result
    }

    func adjust(_ label: String, _ input: String, date: String?) throws -> AdjustResult {
        guard case .adjust(let result) = try perform(.adjust(label: label, input: input, date: date)).success() else {
            throw Unexpected()
        }
        return result
    }

    func relabel(_ label: String, to newLabel: String, date: String?) throws -> RelabelResult {
        guard case .relabel(let result) = try perform(.relabel(label: label, newLabel: newLabel, date: date)).success()
        else { throw Unexpected() }
        return result
    }
}

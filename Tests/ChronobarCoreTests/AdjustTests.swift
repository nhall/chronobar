import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct AdjustTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()
    let past = Day(year: 2026, month: 10, day: 28)
    let future = Day(year: 2026, month: 11, day: 16)

    /// A Tracker with an hour of Website Redesign today, from 7:00 to 8:00.
    func trackerWithAnHour() throws -> Tracker {
        try write(root, "2026-11-03", """
            { "project": "Website Redesign", "start": "2026-11-03T07:00:00-05:00", "end": "2026-11-03T08:00:00-05:00" }
        """)
        return Tracker(clock: clock, storageRoot: root)
    }

    @Test func anAbsoluteTotalWritesTheDifferenceAsOneAdjustment() throws {
        let tracker = try trackerWithAnHour()

        try tracker.adjust("Website Redesign", "1:15", on: tracker.today)

        #expect(tracker.total("Website Redesign", on: tracker.today) == 75 * 60)
        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T07:00:00-05:00", "end": "2026-11-03T08:00:00-05:00", "source": "app" },
            { "project": "Website Redesign", "seconds": 900, "note": "adjustment" }
          ]
        }

        """)
    }

    @Test func aRelativeChangeAddsToTheTotal() throws {
        let tracker = try trackerWithAnHour()

        try tracker.adjust("Website Redesign", "+15", on: tracker.today)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 75 * 60)

        try tracker.adjust("Website Redesign", "-10", on: tracker.today)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 65 * 60)

        try tracker.adjust("Website Redesign", "+1:00", on: tracker.today)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 125 * 60)
    }

    @Test func aTotalNeverGoesBelowZero() throws {
        let tracker = try trackerWithAnHour()

        try tracker.adjust("Website Redesign", "-2:00", on: tracker.today)

        #expect(tracker.total("Website Redesign", on: tracker.today) == 0)
        #expect(contents(dayFile(root, "2026-11-03"))?
            .contains(#"{ "project": "Website Redesign", "seconds": -3600, "note": "adjustment" }"#) == true)
    }

    /// A hand edit left the stored sum at -0:10, shown as 0:00. Adjusting starts from the 0:00 shown.
    @Test(arguments: [("1:00", 70 * 60), ("+15", 25 * 60)] as [(String, Int)])
    func adjustmentsActOnTheShownTotalWhenTheStoredSumIsBelowZero(input: String, written: Int) throws {
        try write(root, "2026-11-03", #"{ "project": "Garden Shed", "seconds": -600, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)
        #expect(tracker.total("Garden Shed", on: tracker.today) == 0)

        try tracker.adjust("Garden Shed", input, on: tracker.today)

        #expect(tracker.total("Garden Shed", on: tracker.today) == TimeInterval(written - 600))
        #expect(contents(dayFile(root, "2026-11-03"))?
            .contains(#"{ "project": "Garden Shed", "seconds": \#(written), "note": "adjustment" }"#) == true)
    }

    @Test func adjustingAPastDayWritesThatDayAndLeavesTodayAlone() throws {
        try write(root, "2026-10-28", #"{ "project": "Internal", "seconds": 1800, "note": "manual" }"#)
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        tracker.tick()

        try tracker.adjust("Internal", "2:00", on: past)

        #expect(tracker.rows(past) == [Row(project: "Internal", total: 2 * 60 * 60)])
        #expect(tracker.rows(tracker.today) == [Row(project: "Website Redesign", total: 60 * 60)])
        #expect(tracker.timers.newest?.project == "Website Redesign")
        #expect(contents(dayFile(root, "2026-10-28"))?
            .contains(#"{ "project": "Internal", "seconds": 5400, "note": "adjustment" }"#) == true)
    }

    @Test func adjustingTheRunningProjectKeepsItTickingFromTheNewTotal() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")

        try tracker.adjust("Website Redesign", "1:30", on: tracker.today)

        #expect(tracker.timers.newest?.project == "Website Redesign")
        #expect(tracker.timers.newest?.start == clock.now - 3600)
        #expect(tracker.total("Website Redesign", on: tracker.today) == 90 * 60)
        clock.set("2026-11-03T10:20:00")
        tracker.tick()
        #expect(tracker.total("Website Redesign", on: tracker.today) == 110 * 60)
        #expect(contents(dayFile(root, "2026-11-03")) == """
        {
          "date": "2026-11-03",
          "entries": [
            { "project": "Website Redesign", "start": "2026-11-03T09:00:00-05:00", "end": null, "source": "app" },
            { "project": "Website Redesign", "seconds": 1800, "note": "adjustment" }
          ]
        }

        """)
    }

    @Test func aTypedTotalHoldsEvenAfterAHandEditTheTrackerHasNotSeen() throws {
        let tracker = try trackerWithAnHour()
        try write(root, "2026-11-03", """
            { "project": "Website Redesign", "start": "2026-11-03T07:00:00-05:00", "end": "2026-11-03T08:00:00-05:00" },
            { "project": "Website Redesign", "seconds": 600, "note": "manual" }
        """)

        try tracker.adjust("Website Redesign", "1:15", on: tracker.today)

        #expect(tracker.total("Website Redesign", on: tracker.today) == 75 * 60)
    }

    @Test func loggingAndAdjustingAreRefusedWhileTheDayFileIsMalformed() throws {
        let tracker = try trackerWithAnHour()
        try write(root, "2026-11-03", "{ oops")
        let before = contents(dayFile(root, "2026-11-03"))

        #expect(throws: (any Error).self) { try tracker.adjust("Website Redesign", "2:00", on: tracker.today) }
        #expect(throws: (any Error).self) { try tracker.log("Website Redesign", "0:30", on: tracker.today) }

        #expect(contents(dayFile(root, "2026-11-03")) == before)
        #expect(tracker.isMalformed(tracker.today))
        try write(root, "2026-11-03", #"{ "project": "Website Redesign", "seconds": 3600, "note": "manual" }"#)
        tracker.reload()
        #expect(tracker.total("Website Redesign", on: tracker.today) == 60 * 60)
    }

    @Test func noChangeWritesNothing() throws {
        let tracker = try trackerWithAnHour()
        let before = contents(dayFile(root, "2026-11-03"))

        try tracker.adjust("Website Redesign", "1:00", on: tracker.today)
        try tracker.adjust("Website Redesign", "+0", on: tracker.today)

        #expect(contents(dayFile(root, "2026-11-03")) == before)
    }

    @Test(arguments: ["", "abc", "1:60", "+"])
    func invalidInputIsRejectedAndChangesNothing(text: String) throws {
        let tracker = try trackerWithAnHour()
        let before = contents(dayFile(root, "2026-11-03"))

        #expect(throws: InvalidDuration(text: text)) {
            try tracker.adjust("Website Redesign", text, on: tracker.today)
        }

        #expect(tracker.total("Website Redesign", on: tracker.today) == 60 * 60)
        #expect(contents(dayFile(root, "2026-11-03")) == before)
    }

    @Test func adjustingADayAheadWorksLikeAPastDay() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Vacation", "8:00", on: future)

        try tracker.adjust("Vacation", "-2:00", on: future)
        #expect(tracker.rows(future) == [Row(project: "Vacation", total: 6 * 60 * 60)])
        try tracker.adjust("Vacation", "7:30", on: future)

        #expect(tracker.rows(future) == [Row(project: "Vacation", total: 7.5 * 60 * 60)])
        #expect(tracker.rows(tracker.today).isEmpty)
        #expect(contents(dayFile(root, "2026-11-16"))?
            .contains(#"{ "project": "Vacation", "seconds": -7200, "note": "adjustment" }"#) == true)
        #expect(contents(dayFile(root, "2026-11-16"))?
            .contains(#"{ "project": "Vacation", "seconds": 5400, "note": "adjustment" }"#) == true)
    }
}

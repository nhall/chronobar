import Foundation
import Testing
import ChronobarCore

/// A change that writes several files (two Days, or a Day and `archived.txt`) writes all of them or none:
/// if a later file can't be replaced, the earlier ones are put back and the change is refused.
@MainActor @Suite struct AllOrNothingTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    /// Writes a Day file holding one finished Internal Entry from 08:00 to 08:30.
    private func writeDay(_ date: String) throws -> String {
        let text = """
            {
              "date": "\(date)",
              "entries": [
                { "project": "Internal", "start": "\(date)T08:00:00-05:00", "end": "\(date)T08:30:00-05:00", "source": "app" }
              ]
            }

            """
        try FileManager.default.createDirectory(
            at: dayFile(root, date).deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: dayFile(root, date), atomically: true, encoding: .utf8)
        return text
    }

    /// Makes `url` immutable, so it can still be read but never replaced, until `mutable(_:)`.
    private func immutable(_ url: URL) throws {
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: url.path)
    }

    private func mutable(_ url: URL) {
        try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: url.path)
    }

    /// The names in the `days` folder, temporary files included.
    private func dayFolder() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("days").path)) ?? []).sorted()
    }

    @Test func anEntryAcrossMidnightIsRefusedWhenTheSecondDayCantBeReplaced() throws {
        let before = try writeDay("2026-11-02")
        let today = try writeDay("2026-11-03")
        try immutable(dayFile(root, "2026-11-03"))
        defer { mutable(dayFile(root, "2026-11-03")) }
        let tracker = Tracker(clock: clock, storageRoot: root)

        #expect(throws: (any Error).self) {
            try tracker.addEntry("Website Redesign", start: clock.date("2026-11-02T23:00:00"),
                                 end: clock.date("2026-11-03T00:45:00"))
        }

        #expect(contents(dayFile(root, "2026-11-02")) == before)
        #expect(contents(dayFile(root, "2026-11-03")) == today)
        #expect(tracker.total("Website Redesign", on: Day(year: 2026, month: 11, day: 2)) == 0)
        #expect(dayFolder() == ["2026-11-02.json", "2026-11-03.json"])
    }

    @Test func aStopBackBeforeMidnightIsRefusedWhenTheSecondDayCantBeReplaced() throws {
        clock.set("2026-11-03T22:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign", source: .agent)
        clock.set("2026-11-04T08:00:00")
        tracker.tick()
        let before = contents(dayFile(root, "2026-11-03"))
        let today = contents(dayFile(root, "2026-11-04"))
        try immutable(dayFile(root, "2026-11-04"))
        defer { mutable(dayFile(root, "2026-11-04")) }

        #expect(throws: (any Error).self) {
            try tracker.stop("Website Redesign", at: clock.date("2026-11-03T23:30:00"))
        }

        #expect(contents(dayFile(root, "2026-11-03")) == before)
        #expect(contents(dayFile(root, "2026-11-04")) == today)
        #expect(tracker.isRunning("Website Redesign"))
        #expect(dayFolder() == ["2026-11-03.json", "2026-11-04.json"])
    }

    @Test func aStartMovedBackBeforeMidnightIsRefusedWhenTheSecondDayCantBeReplaced() throws {
        let before = try writeDay("2026-11-03")
        clock.set("2026-11-04T00:30:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        let today = contents(dayFile(root, "2026-11-04"))
        try immutable(dayFile(root, "2026-11-04"))
        defer { mutable(dayFile(root, "2026-11-04")) }
        clock.set("2026-11-04T01:00:00")

        #expect(throws: (any Error).self) {
            try tracker.setStart("Website Redesign", at: clock.date("2026-11-03T23:15:00"))
        }

        #expect(contents(dayFile(root, "2026-11-03")) == before)
        #expect(contents(dayFile(root, "2026-11-04")) == today)
        #expect(tracker.timers.map(\.start) == [clock.date("2026-11-04T00:30:00")])
        #expect(dayFolder() == ["2026-11-03.json", "2026-11-04.json"])
    }

    @Test(arguments: [IdleChoice.remove, .removeAndStop])
    func idleTimeAcrossMidnightIsKeptWhenTheSecondDayCantBeReplaced(choice: IdleChoice) throws {
        clock.set("2026-11-03T23:00:00")
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-04T00:30:00")
        tracker.tick()
        let before = contents(dayFile(root, "2026-11-03"))
        let today = contents(dayFile(root, "2026-11-04"))
        try immutable(dayFile(root, "2026-11-04"))
        defer { mutable(dayFile(root, "2026-11-04")) }

        #expect(throws: (any Error).self) {
            try tracker.resolveIdle(since: clock.date("2026-11-03T23:40:00"), choice: choice)
        }

        #expect(contents(dayFile(root, "2026-11-03")) == before)
        #expect(contents(dayFile(root, "2026-11-04")) == today)
        #expect(tracker.timers.map(\.start) == [clock.date("2026-11-04T00:00:00")])
        #expect(dayFolder() == ["2026-11-03.json", "2026-11-04.json"])
    }

    // MARK: An archived Label coming back

    /// A tracker with Internal archived and a Day file for today, `archived.txt` made immutable.
    private func archivedInternal() throws -> (Tracker, today: String) {
        let today = try writeDay("2026-11-03")
        try "Internal\n".write(to: archivedFile(root), atomically: true, encoding: .utf8)
        try immutable(archivedFile(root))
        return (Tracker(clock: clock, storageRoot: root), today)
    }

    @Test func anEntryForAnArchivedLabelIsRefusedWhenItCantComeBack() throws {
        let (tracker, today) = try archivedInternal()
        defer { mutable(archivedFile(root)) }

        #expect(throws: (any Error).self) {
            try tracker.addEntry("Internal", start: clock.date("2026-11-03T08:30:00"), end: clock.date("2026-11-03T08:45:00"))
        }

        #expect(contents(dayFile(root, "2026-11-03")) == today)
        #expect(tracker.archived == ["Internal"])
        #expect(dayFolder() == ["2026-11-03.json"])
    }

    @Test func aStartOfAnArchivedLabelIsRefusedWhenItCantComeBack() throws {
        let (tracker, today) = try archivedInternal()
        defer { mutable(archivedFile(root)) }

        #expect(throws: (any Error).self) { try tracker.start("Internal") }

        #expect(contents(dayFile(root, "2026-11-03")) == today)
        #expect(tracker.timers.isEmpty)
        #expect(tracker.archived == ["Internal"])
    }

    @Test func aDurationForAnArchivedLabelIsRefusedWhenItCantComeBack() throws {
        let (tracker, today) = try archivedInternal()
        defer { mutable(archivedFile(root)) }

        #expect(throws: (any Error).self) { try tracker.log("Internal", "0:15", on: tracker.today) }

        #expect(contents(dayFile(root, "2026-11-03")) == today)
        #expect(tracker.archived == ["Internal"])
    }
}

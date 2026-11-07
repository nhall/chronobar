import Foundation
import Testing
import ChronobarCore

@MainActor @Suite struct AtomicWriteTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    @Test func writesReplaceTheFileInsteadOfRewritingItInPlace() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        let before = contents(dayFile(root, "2026-11-03"))
        // A reader that opened the file before the write keeps seeing a whole, old file.
        let reader = try FileHandle(forReadingFrom: dayFile(root, "2026-11-03"))
        defer { try? reader.close() }

        clock.set("2026-11-03T10:00:00")
        try tracker.pause()

        let seenByReader = String(decoding: try reader.readToEnd() ?? Data(), as: UTF8.self)
        #expect(seenByReader == before)
        #expect(contents(dayFile(root, "2026-11-03")) != before)
    }

    @Test func writesLeaveNoTemporaryFilesBehind() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.start("Website Redesign")
        clock.set("2026-11-03T10:00:00")
        try tracker.pause()

        let names = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("days").path)
        #expect(names == ["2026-11-03.json"])
    }

    @Test func malformedDayFileIsNeverOverwritten() throws {
        let malformed = #"{ "date": "2026-11-03", "entries": [ { "project": "Internal", "start": "9am" } ] }"#
        try FileManager.default.createDirectory(
            at: dayFile(root, "2026-11-03").deletingLastPathComponent(), withIntermediateDirectories: true)
        try malformed.write(to: dayFile(root, "2026-11-03"), atomically: true, encoding: .utf8)

        let tracker = Tracker(clock: clock, storageRoot: root)
        #expect(throws: (any Error).self) { try tracker.start("Website Redesign") }

        #expect(tracker.timers.isEmpty)
        #expect(contents(dayFile(root, "2026-11-03")) == malformed)
    }
}

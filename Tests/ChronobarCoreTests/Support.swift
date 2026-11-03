import Foundation
import ChronobarCore

/// A clock the test moves by hand.
final class FakeClock: TimeSource {
    var now: Date
    var calendar: Calendar

    /// `"2026-11-03T09:00:00"` is read as local time in `timeZone`.
    init(_ local: String, timeZone: String = "America/New_York") {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        self.calendar = calendar
        self.now = FakeClock.date(local, calendar)
    }

    func set(_ local: String) { now = FakeClock.date(local, calendar) }
    func advance(_ seconds: TimeInterval) { now += seconds }

    private static func date(_ local: String, _ calendar: Calendar) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: local)!
    }
}

/// A fresh storage root under the system temp folder.
func temporaryRoot() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("ChronobarCoreTests-\(UUID().uuidString)", isDirectory: true)
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func dayFile(_ root: URL, _ date: String) -> URL {
    root.appendingPathComponent("days/\(date).json")
}

func projectsFile(_ root: URL) -> URL {
    root.appendingPathComponent("projects.txt")
}

func contents(_ url: URL) -> String? {
    try? String(contentsOf: url, encoding: .utf8)
}

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

    /// The moment `local` names on this clock's calendar.
    func date(_ local: String) -> Date { FakeClock.date(local, calendar) }

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

/// A settings store kept as a plist in its own temp folder, never in ~/Library/Preferences.
/// A suite named by an absolute path is stored at that path plus `.plist`. Call `remove()` when done.
struct TestSettings {
    let directory: URL
    private let suite: String

    init() {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChronobarCoreTests-\(UUID().uuidString)", isDirectory: true)
        suite = directory.appendingPathComponent("settings").path
    }

    /// A new store over the same file, as the app gets on its next launch.
    /// The folder is made on first use, so a suite whose test never asks for one leaves nothing.
    func fresh() -> UserDefaults {
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return UserDefaults(suiteName: suite)!
    }

    func remove() {
        fresh().removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }
}

func dayFile(_ root: URL, _ date: String) -> URL {
    root.appendingPathComponent("days/\(date).json")
}

func projectsFile(_ root: URL) -> URL {
    root.appendingPathComponent("projects.txt")
}

func archivedFile(_ root: URL) -> URL {
    root.appendingPathComponent("archived.txt")
}

func contents(_ url: URL) -> String? {
    try? String(contentsOf: url, encoding: .utf8)
}

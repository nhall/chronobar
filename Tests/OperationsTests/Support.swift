import Foundation
import ChronobarCore
import ChronobarOperations

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
        .appendingPathComponent("OperationsTests-\(UUID().uuidString)", isDirectory: true)
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func dayFile(_ root: URL, _ date: String) -> URL {
    root.appendingPathComponent("days/\(date).json")
}

/// Writes a Day file with the given Entry lines, as a hand edit would.
func write(_ root: URL, _ date: String, _ entries: String) throws {
    let url = dayFile(root, date)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "{\n  \"date\": \"\(date)\",\n  \"entries\": [\n\(entries)\n  ]\n}\n".write(to: url, atomically: true, encoding: .utf8)
}

func contents(_ url: URL) -> String {
    (try? String(contentsOf: url, encoding: .utf8)) ?? ""
}

/// A request a test expected to succeed failed.
struct UnexpectedFailure: Error {
    let error: OperationError
}

extension Response {
    func success() throws -> OperationResult {
        switch self {
        case .success(let result): result
        case .failure(let error): throw UnexpectedFailure(error: error)
        }
    }

    /// The error, or nil if the request succeeded.
    var error: OperationError? {
        if case .failure(let error) = self { error } else { nil }
    }
}

extension Operations {
    func status() throws -> StatusResult {
        guard case .status(let result) = try perform(.status).success() else { throw Unexpected() }
        return result
    }

    func start(_ label: String) throws -> StartResult {
        guard case .start(let result) = try perform(.start(label: label)).success() else { throw Unexpected() }
        return result
    }

    func stop(_ label: String? = nil) throws -> StopResult {
        guard case .stop(let result) = try perform(.stop(label: label)).success() else { throw Unexpected() }
        return result
    }
}

/// A request answered with another operation's result.
struct Unexpected: Error {}

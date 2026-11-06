import Foundation

/// The JSON text of one Day file. A public contract: users edit these by hand, so the output is
/// pretty-printed with one Entry per line and keys in a fixed order.
enum DayFile {
    struct Malformed: Error {}

    static func encode(_ day: Day, _ entries: [Entry], timeZone: TimeZone) -> Data {
        let dates = dateStyle(timeZone)
        let lines = entries.map { entry -> String in
            switch entry {
            case .timed(let project, let start, let end, let source):
                let endText = end.map { string($0.formatted(dates)) } ?? "null"
                // Always written, so the file shows who started each Entry; a missing `source` reads as `app`.
                return #"{ "project": \#(string(project)), "start": \#(string(start.formatted(dates))), "end": \#(endText), "source": \#(string(source.rawValue)) }"#
            case .manual(let project, let seconds, let note):
                return #"{ "project": \#(string(project)), "seconds": \#(seconds), "note": \#(string(note.rawValue)) }"#
            }
        }
        let list = lines.isEmpty ? "[]" : "[\n" + lines.map { "    " + $0 }.joined(separator: ",\n") + "\n  ]"
        return Data("{\n  \"date\": \"\(day)\",\n  \"entries\": \(list)\n}\n".utf8)
    }

    static func decode(_ data: Data) throws -> (day: Day, entries: [Entry]) {
        guard let file = try? JSONDecoder().decode(Raw.self, from: data),
              let day = Day(file.date) else { throw Malformed() }
        let entries = try file.entries.map { raw -> Entry in
            if let seconds = raw.seconds {
                guard raw.start == nil, raw.end == nil, raw.source == nil,
                      let note = ManualNote(rawValue: raw.note ?? "") else { throw Malformed() }
                return .manual(project: raw.project, seconds: seconds, note: note)
            }
            guard let start = raw.start.flatMap(parseDate) else { throw Malformed() }
            var end: Date?
            if let text = raw.end {
                guard let date = parseDate(text) else { throw Malformed() }
                end = date
            }
            var source = EntrySource.app
            if let text = raw.source {
                guard let parsed = EntrySource(rawValue: text) else { throw Malformed() }
                source = parsed
            }
            return .timed(project: raw.project, start: start, end: end, source: source)
        }
        return (day, entries)
    }

    private struct Raw: Decodable {
        let date: String
        let entries: [RawEntry]
    }

    private struct RawEntry: Decodable {
        let project: String
        let start: String?
        let end: String?
        let seconds: Int?
        let note: String?
        let source: String?
    }

    private static func dateStyle(_ timeZone: TimeZone) -> Date.ISO8601FormatStyle {
        Date.ISO8601FormatStyle(timeZoneSeparator: .colon, timeZone: timeZone)
    }

    private static func parseDate(_ text: String) -> Date? {
        let styles = [
            dateStyle(.gmt),
            Date.ISO8601FormatStyle(timeZone: .gmt),
            Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .gmt),
        ]
        for style in styles {
            if let date = try? style.parse(text) { return date }
        }
        return nil
    }

    /// A JSON string literal.
    private static func string(_ value: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        return String(decoding: try! encoder.encode(value), as: UTF8.self)
    }
}

/// A Day file that won't parse (or has writes still waiting for it), refusing a change.
public struct MalformedDayFile: Error, Equatable {
    public let day: Day

    public init(day: Day) {
        self.day = day
    }
}

/// Day files under `<root>/days/`, one per Day, named `YYYY-MM-DD.json`.
struct DayStore {
    let root: URL

    func url(for day: Day) -> URL {
        root.appendingPathComponent("days", isDirectory: true).appendingPathComponent("\(day).json")
    }

    /// Every Day with a file, newest first.
    func days() -> [Day] {
        let folder = root.appendingPathComponent("days", isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { $0.hasSuffix(".json") }
            .compactMap { Day(String($0.dropLast(".json".count))) }
            .sorted(by: >)
    }

    /// The Day's Entries; none if the file doesn't exist yet. Throws `DayFile.Malformed` if it won't parse.
    func load(_ day: Day) throws -> [Entry] {
        let url = url(for: day)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let file = try DayFile.decode(try Data(contentsOf: url))
        guard file.day == day else { throw DayFile.Malformed() }
        return file.entries
    }

    /// Writes to a temporary file and replaces the Day file with it, so a crash never leaves half a file.
    func save(_ day: Day, _ entries: [Entry], timeZone: TimeZone) throws {
        let url = url(for: day)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try DayFile.encode(day, entries, timeZone: timeZone).write(to: url, options: .atomic)
    }
}

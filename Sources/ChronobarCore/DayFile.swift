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

/// A file Core refuses to change because it won't parse, always named: `MalformedDayFile` for a Day file,
/// `MalformedLabelList` for `projects.txt` or `archived.txt`. These are the only malformed-file errors
/// that leave Core; `DayFile.Malformed` stays inside it.
public protocol MalformedFileError: Error {}

/// A Day file that won't parse (or has writes still waiting for it), refusing a change.
public struct MalformedDayFile: MalformedFileError, Equatable {
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
        try save([(day, entries)], timeZone: timeZone)
    }

    /// Replaces each Day's file, and writes `others`, all or none (see `FileWrite.replace`).
    func save(_ days: [(Day, [Entry])], alongWith others: [FileWrite] = [], timeZone: TimeZone) throws {
        let writes = days.map { day, entries in
            FileWrite(url: url(for: day), data: DayFile.encode(day, entries, timeZone: timeZone))
        }
        try FileWrite.replace(writes + others)
    }
}

/// New contents for one file.
struct FileWrite {
    let url: URL
    let data: Data

    /// Replaces every file in `writes` or none. Each one's contents first go to a temporary file beside it,
    /// where a full disk or a folder that can't be written fails before any file changes; then each
    /// temporary file is moved over its file. If a move fails, the files already moved are put back as
    /// they were, and the error is thrown. A crash never leaves half a file, though one in the middle of
    /// the moves can leave only some of the files replaced.
    static func replace(_ writes: [FileWrite]) throws {
        let manager = FileManager.default
        var temporary: [URL] = []
        // Whatever wasn't moved into place, on success or failure.
        defer { for url in temporary { try? manager.removeItem(at: url) } }
        for write in writes {
            try manager.createDirectory(at: write.url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let url = sibling(of: write.url, suffix: "tmp")
            temporary.append(url)
            try write.data.write(to: url)
        }
        // Each file moved into place, with where its earlier contents now are (nil: it didn't exist).
        var moved: [(url: URL, earlier: URL?)] = []
        do {
            for (write, url) in zip(writes, temporary) {
                moved.append((write.url, try place(url, over: write.url)))
            }
        } catch {
            for file in moved.reversed() {
                if let earlier = file.earlier { try? move(earlier, over: file.url) } else { try? manager.removeItem(at: file.url) }
            }
            throw error
        }
        for file in moved { if let earlier = file.earlier { try? manager.removeItem(at: earlier) } }
    }

    /// Moves `source` over `destination` in one step. Returns where `destination`'s earlier contents are
    /// kept, until the caller removes them or moves them back; nil if it didn't exist. Where the disk can,
    /// the two are swapped, so the earlier contents end up at `source` and a failure leaves no file behind.
    private static func place(_ source: URL, over destination: URL) throws -> URL? {
        guard FileManager.default.fileExists(atPath: destination.path) else {
            try move(source, over: destination)
            return nil
        }
        // macOS only; elsewhere (the Linux build for Glama, ADR 0009) straight to the fallback below.
        #if canImport(Darwin)
        if renamex_np(source.path, destination.path, UInt32(RENAME_SWAP)) == 0 { return source }
        guard errno == ENOTSUP || errno == EINVAL else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        #endif
        let backup = sibling(of: destination, suffix: "bak")
        if (try? FileManager.default.linkItem(at: destination, to: backup)) == nil {
            try FileManager.default.copyItem(at: destination, to: backup)
        }
        do {
            try move(source, over: destination)
        } catch {
            try? FileManager.default.removeItem(at: backup)
            throw error
        }
        return backup
    }

    /// A new hidden name in `url`'s folder, which `DayStore.days()` never lists.
    private static func sibling(of url: URL, suffix: String) -> URL {
        url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).\(suffix)")
    }

    /// Renames `source` to `destination`, replacing it in one step.
    private static func move(_ source: URL, over destination: URL) throws {
        guard rename(source.path, destination.path) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }
}

import Foundation

/// A list of Projects in a text file under `root`: UTF-8, one Project per line. Users edit it by hand.
/// `projects.txt` holds the Pinned Projects, `archived.txt` the archived ones.
struct ProjectStore {
    struct Malformed: MalformedFileError {}

    let root: URL
    var fileName = "projects.txt"

    var url: URL { root.appendingPathComponent(fileName) }

    /// The listed Projects, trimmed, without blank lines; none if the file doesn't exist yet.
    /// Throws `Malformed` if the file isn't UTF-8, so a write never replaces it.
    func load() throws -> [String] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        guard let text = String(data: try Data(contentsOf: url), encoding: .utf8) else { throw Malformed() }
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func save(_ projects: [String]) throws {
        try FileWrite.replace([write(projects)])
    }

    /// The file listing `projects`, for writing along with other files.
    func write(_ projects: [String]) -> FileWrite {
        FileWrite(url: url, data: Data(projects.map { $0 + "\n" }.joined().utf8))
    }
}

/// Project names match case-insensitively after trimming whitespace.
public enum ProjectName {
    public static func trimmed(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func matches(_ a: String, _ b: String) -> Bool {
        trimmed(a).caseInsensitiveCompare(trimmed(b)) == .orderedSame
    }
}

/// What a typed Project name refers to.
public enum ProjectMatch: Equatable, Sendable {
    /// Nothing yet: starting or logging it creates a Project.
    case new
    /// A Project the suggestions list (pinned, or used in the last 30 days and not archived), as they spell it.
    case active(String)
    /// A Project the suggestions leave out, archived or not used for 30 days, as `archived.txt` or its most
    /// recent Entry spells it. Starting or logging it brings it back.
    case archived(String)

    /// The existing Project's name; nil for a new one.
    public var project: String? {
        switch self {
        case .new: nil
        case .active(let project), .archived(let project): project
        }
    }
}

/// A Project name that is empty after trimming whitespace.
public struct EmptyProjectName: Error {}

import Foundation

/// The Project list in `<root>/projects.txt`: UTF-8, one active Project per line. Users edit it by hand.
struct ProjectStore {
    struct Malformed: Error {}

    let root: URL

    var url: URL { root.appendingPathComponent("projects.txt") }

    /// The active Projects, trimmed, without blank lines; none if the file doesn't exist yet.
    /// Throws `Malformed` if the file isn't UTF-8, so a write never replaces it.
    func load() throws -> [String] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        guard let text = String(data: try Data(contentsOf: url), encoding: .utf8) else { throw Malformed() }
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func save(_ projects: [String]) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(projects.map { $0 + "\n" }.joined().utf8).write(to: url, options: .atomic)
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
    /// A Project on the Project list, as the list spells it.
    case active(String)
    /// An archived Project with time in the Day files, as its most recent Entry spells it.
    case archived(String)
}

/// A Project name that is empty after trimming whitespace.
public struct EmptyProjectName: Error {}

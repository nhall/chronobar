import Foundation

/// A list of Projects in a text file under `root`: UTF-8, one Project per line. Users edit it by hand.
/// `projects.txt` holds the Pinned Projects, `archived.txt` the archived ones.
struct ProjectStore {
    let root: URL
    var list = LabelList.pinned

    var url: URL { root.appendingPathComponent(list.fileName) }

    /// The listed Projects, trimmed, without blank lines; none if the file doesn't exist yet.
    /// Throws `MalformedLabelList` naming this list if the file isn't UTF-8, so a write never replaces it.
    func load() throws -> [String] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        guard let text = String(data: try Data(contentsOf: url), encoding: .utf8) else {
            throw MalformedLabelList(list: list)
        }
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

/// One of the two Label lists, each a file in the data folder that users edit by hand.
public enum LabelList: Sendable {
    /// The Pinned Labels, in `projects.txt`.
    case pinned
    /// The Archived Labels, in `archived.txt`.
    case archived

    /// The list's file in the data folder.
    public var fileName: String {
        switch self {
        case .pinned: "projects.txt"
        case .archived: "archived.txt"
        }
    }
}

/// A Label list that won't parse (it isn't UTF-8), refusing a change so a write never replaces it.
public struct MalformedLabelList: MalformedFileError, Equatable {
    public let list: LabelList

    public init(list: LabelList) {
        self.list = list
    }

    /// The malformed list's file in the data folder.
    public var fileName: String { list.fileName }
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
    /// A Label on the Archived Labels, as they spell it. Starting or logging it brings it back.
    case archived(String)
    /// A Label with time in the Day files but none in the last 30 days, and not archived, spelled as
    /// start would write it.
    case unused(String)

    /// The existing Project's name; nil for a new one.
    public var project: String? {
        switch self {
        case .new: nil
        case .active(let project), .archived(let project), .unused(let project): project
        }
    }
}

/// A Project name that is empty after trimming whitespace.
public struct EmptyProjectName: Error {}

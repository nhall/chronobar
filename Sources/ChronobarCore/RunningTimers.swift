import Foundation

/// A running timer: the open timed Entry for one Project.
public struct Running: Equatable, Sendable {
    public let project: String
    public let start: Date
    public let source: EntrySource

    init(project: String, start: Date, source: EntrySource = .app) {
        self.project = project
        self.start = start
        self.source = source
    }
}

/// The running timers, at most one per Project, so a Project's name (matched as `ProjectName` does)
/// identifies its timer. Kept in the order they started.
public struct RunningTimers: RandomAccessCollection, Equatable, Sendable {
    private var timers: [Running] = []

    /// `timers` in order, dropping any whose Project already has one.
    init(_ timers: some Sequence<Running> = []) {
        for timer in timers where self[timer.project] == nil { self.timers.append(timer) }
    }

    public var startIndex: Int { timers.startIndex }
    public var endIndex: Int { timers.endIndex }
    public subscript(position: Int) -> Running { timers[position] }

    /// The Project's timer, if it runs.
    public subscript(project: String) -> Running? {
        timers.first { ProjectName.matches($0.project, project) }
    }

    /// Whether the Project's timer runs.
    public func contains(_ project: String) -> Bool { self[project] != nil }

    /// The timer started last.
    public var newest: Running? { timers.last }

    /// Adds `timer`, replacing the one its Project had.
    mutating func insert(_ timer: Running) {
        remove(timer.project)
        timers.append(timer)
    }

    /// Removes the Project's timer.
    mutating func remove(_ project: String) {
        timers.removeAll { ProjectName.matches($0.project, project) }
    }
}

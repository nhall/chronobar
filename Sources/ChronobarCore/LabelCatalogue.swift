import Foundation
import Observation

/// Everything Core knows about Labels apart from their time: the Pinned and Archived Labels and their
/// files, the spelling a name is stored under, what a typed name matches, the ＋ form's suggestions, and
/// pinning, archiving and bringing a Label back. It reads the Day history through `DayFiles` and never
/// writes a Day file; a Label-list write that must land with a Day change is handed to the caller to save
/// with it (`resolvingForWrite`).
@MainActor @Observable
final class LabelCatalogue {
    /// The Pinned Labels, always suggested, in `projects.txt` order.
    private(set) var pinned: [String] = []
    /// The Archived Labels, never suggested until typed again, in `archived.txt` order.
    private(set) var archived: [String] = []

    @ObservationIgnored private let pinnedStore: ProjectStore
    @ObservationIgnored private let archivedStore: ProjectStore
    @ObservationIgnored private let files: DayFiles

    /// How many Days, today included, a Label stays suggested after its last Entry.
    private static let suggestedDays = 30

    init(root: URL, files: DayFiles) {
        self.pinnedStore = ProjectStore(root: root)
        self.archivedStore = ProjectStore(root: root, fileName: "archived.txt")
        self.files = files
    }

    /// Re-reads both lists, picking up hand edits. A list that won't parse reads as empty; writes to it
    /// stay refused until it parses again.
    func reload() {
        pinned = (try? pinnedStore.load()) ?? []
        archived = (try? archivedStore.load()) ?? []
    }

    /// Re-reads both lists, throwing if either won't parse so a write never replaces it.
    private func load() throws {
        let pinned = try pinnedStore.load()
        let archived = try archivedStore.load()
        self.pinned = pinned
        self.archived = archived
    }

    // MARK: Spelling

    /// The Label `name` refers to, for writing under: the Pinned spelling, else the Archived one, else
    /// that of its latest Entry, else `name` trimmed. Re-reads both lists first and throws if either
    /// won't parse.
    private func resolve(_ name: String) throws -> String {
        let name = ProjectName.trimmed(name)
        guard !name.isEmpty else { throw EmptyProjectName() }
        try load()
        return pinned.first(matching: name) ?? archived.first(matching: name)
            ?? historicalName(matching: name) ?? name
    }

    /// Whether `name` is on the Pinned Labels, ignoring case and surrounding spaces.
    func isPinned(_ name: String) -> Bool {
        pinned.contains(matching: name)
    }

    /// The Pinned spelling of `name`, else `name` trimmed: what a Row is shown under.
    func shownName(_ name: String) -> String {
        pinned.first(matching: name) ?? ProjectName.trimmed(name)
    }

    /// The name a past Entry used for this Label, newest Day first. Malformed Days are skipped.
    private func historicalName(matching name: String) -> String? {
        for day in files.days() {
            let entries = files.reread(day) ?? []
            if let entry = entries.last(where: { ProjectName.matches($0.project, name) }) { return entry.project }
        }
        return nil
    }

    // MARK: Writing

    /// Resolves `name` for a change that puts time under it, and hands `save` the stored spelling with the
    /// Label-list writes that must land with that change, all or none: taking it off `archived.txt` if it
    /// is archived. `save` writes them with its change, or not at all. Afterwards the lists are re-read, so
    /// they show the Label back only if that save landed, whether `save` returned, threw or skipped it.
    func resolvingForWrite<T>(_ name: String, _ save: (_ label: String, _ alongWith: [FileWrite]) throws -> T) throws -> T {
        let label = try resolve(name)
        defer { reload() }
        return try save(label, bringingBack(label))
    }

    /// The `archived.txt` write taking `label` off it, as last read; none if it isn't archived.
    private func bringingBack(_ label: String) -> [FileWrite] {
        guard archived.contains(matching: label) else { return [] }
        return [archivedStore.write(archived.filter { !ProjectName.matches($0, label) })]
    }

    /// Pins `name`, bringing it back if archived, both lists in one write. Returns its stored spelling.
    /// Pinning a Pinned Label changes nothing.
    func pin(_ name: String) throws -> String {
        try resolvingForWrite(name) { label, writes in
            try FileWrite.replace(writes + (isPinned(label) ? [] : [pinnedStore.write(pinned + [label])]))
            return label
        }
    }

    /// Archives the Label matching `name`: takes it off `projects.txt` and adds it to `archived.txt`, both
    /// in one write after reading both, so if one won't parse or can't be saved nothing changes. Returns
    /// the stored spelling archived: the Archived one if it already was, else as start spells it.
    @discardableResult
    func archive(_ name: String) throws -> String {
        var label = try resolve(name)
        var pinned = pinned
        var archived = archived
        var writes: [FileWrite] = []
        if let already = archived.first(matching: label) {
            label = already
        } else {
            archived.append(label)
            writes.append(archivedStore.write(archived))
        }
        if pinned.contains(matching: label) {
            pinned.removeAll { ProjectName.matches($0, label) }
            writes.append(pinnedStore.write(pinned))
        }
        try FileWrite.replace(writes)
        self.pinned = pinned
        self.archived = archived
        return label
    }

    // MARK: Suggestions and match

    /// Suggested Labels containing `text` anywhere, ignoring case and surrounding spaces. A name matching
    /// `text` exactly comes first, then names starting with it, then the rest; within each, the most
    /// recently used first.
    func suggestions(for text: String, today: Day, calendar: Calendar) -> [String] {
        let text = ProjectName.trimmed(text)
        let recent = suggested(today: today, calendar: calendar)
        guard !text.isEmpty else { return recent }
        // Rank 0 is an exact match, 1 starts with `text`, 2 contains it; `recency` keeps recent use within each.
        let ranked = recent.enumerated().compactMap { recency, name -> (rank: Int, recency: Int, name: String)? in
            guard let found = name.range(of: text, options: .caseInsensitive) else { return nil }
            let rank = ProjectName.matches(name, text) ? 0 : found.lowerBound == name.startIndex ? 1 : 2
            return (rank, recency, name)
        }
        return ranked.sorted { ($0.rank, $0.recency) < ($1.rank, $1.recency) }.map(\.name)
    }

    /// What a typed name would start or log: a suggested Label, an archived one, an unused one (time in
    /// the Day files but not lately), each spelled as start would write it, or a new one. Nil for a blank
    /// name.
    func match(_ name: String, today: Day, calendar: Calendar) -> ProjectMatch? {
        let name = ProjectName.trimmed(name)
        guard !name.isEmpty else { return nil }
        if let active = suggested(today: today, calendar: calendar).first(matching: name) { return .active(active) }
        if let archived = archived.first(matching: name) { return .archived(archived) }
        for day in files.days() {
            if let entry = files.entries(on: day).last(where: { ProjectName.matches($0.project, name) }) {
                return .unused(shownName(entry.project))
            }
        }
        return .new
    }

    /// The Labels the ＋ form suggests: those with an Entry on today or the Days just before it
    /// (`suggestedDays` in all), the latest used first, then Pinned Labels not used in that time, in
    /// `projects.txt` order. Archived Labels are left out. Time logged ahead isn't a use.
    private func suggested(today: Day, calendar: Calendar) -> [String] {
        let first = today.adding(days: 1 - Self.suggestedDays, in: calendar)
        var used: [String] = []
        for day in [today] + files.days().filter({ $0 < today && $0 >= first }) {
            for entry in files.entries(on: day).reversed()
            where !used.contains(matching: entry.project) {
                used.append(shownName(entry.project))
            }
        }
        let unused = pinned.filter { !used.contains(matching: $0) }
        return (used + unused).filter { !archived.contains(matching: $0) }
    }
}

private extension [String] {
    /// The first name matching `name`, ignoring case and surrounding spaces.
    func first(matching name: String) -> String? {
        first { ProjectName.matches($0, name) }
    }

    /// Whether a name matches `name`, ignoring case and surrounding spaces.
    func contains(matching name: String) -> Bool {
        contains { ProjectName.matches($0, name) }
    }
}

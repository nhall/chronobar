import Foundation
import Testing
import ChronobarCore
import ChronobarOperations

/// `labels`: the ＋ form's suggestions, and what a query names when they leave it out.
@MainActor @Suite struct LabelsTests {
    let clock = FakeClock("2026-11-03T09:00:00")
    let root = temporaryRoot()

    /// Used in the last 30 Days (today and the 29 before), latest first, then Pinned Labels; archived ones
    /// left out.
    @Test func withNoQueryLabelsListsTheSuggestions() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Old Client", "1:00", on: Day(year: 2026, month: 10, day: 4))
        try tracker.log("Client A, Ticket 665", "1:00", on: Day(year: 2026, month: 10, day: 5))
        try tracker.log("Website Redesign", "1:00", on: Day(year: 2026, month: 11, day: 2))
        try tracker.log("Retired", "1:00", on: Day(year: 2026, month: 11, day: 2))
        try tracker.archiveProject("Retired")
        try tracker.pinProject("Internal meeting")
        try tracker.pinProject("Website Redesign")

        let labels = try Operations(tracker: tracker).labels()

        #expect(labels.labels == [
            LabelResult(label: "Website Redesign", pinned: true),
            LabelResult(label: "Client A, Ticket 665", pinned: false),
            LabelResult(label: "Internal meeting", pinned: true),
        ])
        #expect(labels.match == nil)
    }

    @Test func aQueryNarrowsTheSuggestionsExactThenStartingWithThenContaining() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Client A", "1:00", on: Day(year: 2026, month: 11, day: 1))
        try tracker.log("Big Client A job", "1:00", on: Day(year: 2026, month: 11, day: 2))
        try tracker.log("Client A, Ticket 665", "1:00", on: Day(year: 2026, month: 11, day: 3))
        try tracker.log("Internal", "1:00", on: Day(year: 2026, month: 11, day: 3))

        let labels = try Operations(tracker: tracker).labels(" client a ")

        #expect(labels.labels.map(\.label) == ["Client A", "Client A, Ticket 665", "Big Client A job"])
        #expect(labels.match == LabelMatchResult(kind: .suggested, label: "Client A"))
    }

    @Test func anUnknownLabelMatchesNothingAndWouldBeNew() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "1:00", on: tracker.today)

        let labels = try Operations(tracker: tracker).labels("Client B")

        #expect(labels.labels.isEmpty)
        #expect(labels.match == LabelMatchResult(kind: .new, label: nil))
    }

    @Test func anArchivedLabelIsLeftOutButTheMatchNamesIt() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "1:00", on: tracker.today)
        try tracker.archiveProject("website redesign")

        let labels = try Operations(tracker: tracker).labels("WEBSITE REDESIGN")

        #expect(labels.labels.isEmpty)
        #expect(labels.match == LabelMatchResult(kind: .archived, label: "Website Redesign"))
    }

    @Test func aLabelNotUsedFor30DaysIsLeftOutButTheMatchNamesIt() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Old Client", "1:00", on: Day(year: 2026, month: 10, day: 4))

        let labels = try Operations(tracker: tracker).labels("old client")

        #expect(labels.labels.isEmpty)
        #expect(labels.match == LabelMatchResult(kind: .unused, label: "Old Client"))
    }

    /// A blank query is no query.
    @Test func aBlankQueryListsEverySuggestion() throws {
        let tracker = Tracker(clock: clock, storageRoot: root)
        try tracker.log("Website Redesign", "1:00", on: tracker.today)

        let labels = try Operations(tracker: tracker).labels("  ")

        #expect(labels.labels.map(\.label) == ["Website Redesign"])
        #expect(labels.match == nil)
    }
}

import Testing
import ChronobarCore

/// What a row's Label field says while the typed name is another row's on the viewed Day: that Return
/// would merge the two, and the other row's Total.
@Suite struct MergeHintTests {
    let rows = [
        DaySheet.Row(project: "Northwnd", time: Figure(seconds: 1800, minutes: 30), runningSource: nil),
        DaySheet.Row(project: "Northwind", time: Figure(seconds: 3599, minutes: 60), runningSource: nil),
    ]

    @Test func aNameMatchingAnotherRowGivesThatRowAndTheTotalItShows() {
        let hint = MergeHint(typed: "Northwind", editing: "Northwnd", rows: rows)

        #expect(hint == MergeHint(project: "Northwind", total: "1:00"))
        #expect(hint?.text == "merges with Northwind (1:00)")
    }

    @Test func theMatchIgnoresCapitalsAndSurroundingSpaces() {
        #expect(MergeHint(typed: "  northWIND ", editing: "Northwnd", rows: rows)?.project == "Northwind")
    }

    @Test(arguments: ["Northwnd", "northwnd ", " NORTHWND"])
    func theRowBeingEditedIsNeverAMerge(typed: String) {
        #expect(MergeHint(typed: typed, editing: "Northwnd", rows: rows) == nil)
    }

    /// Return would be refused, the Timer running, so there's no merge to warn of.
    @Test func aRunningRowGivesNoHint() {
        let rows = [
            DaySheet.Row(project: "Northwnd", time: Figure(seconds: 1800, minutes: 30), runningSource: nil),
            DaySheet.Row(project: "Northwind", time: Figure(seconds: 3599, minutes: 60), runningSource: .agent),
        ]

        #expect(MergeHint(typed: "Northwind", editing: "Northwnd", rows: rows) == nil)
    }

    @Test(arguments: ["", "  ", "North", "Northwind, Ticket 665"])
    func aNameMatchingNoOtherRowGivesNoHint(typed: String) {
        #expect(MergeHint(typed: typed, editing: "Northwnd", rows: rows) == nil)
    }
}

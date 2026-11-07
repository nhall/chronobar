import Testing
import ChronobarCore

@Suite struct SuggestionListTests {
    @Test func typingOpensTheListOfWhatMatches() {
        var list = SuggestionList()
        list.typed("cli", suggestions: ["Client A", "Client B"])
        #expect(list.isOpen)
        #expect(list.items == ["Client A", "Client B"])
        #expect(list.highlighted == nil)
    }

    /// Emptying the field, or typing what nothing matches, closes the list.
    @Test(arguments: [("  ", ["Client A"]), ("zz", [])])
    func typingWhatNothingMatchesClosesTheList(text: String, suggestions: [String]) {
        var list = SuggestionList()
        list.typed("cli", suggestions: ["Client A"])
        list.typed(text, suggestions: suggestions)
        #expect(!list.isOpen)
    }

    /// ↓ with the list closed opens it with every suggestion for what was typed, the empty field
    /// included, and highlights nothing yet.
    @Test func downOpensTheList() {
        var list = SuggestionList()
        list.typed("", suggestions: ["Client A", "Internal"])
        #expect(list.press(.down) == .handled)
        #expect(list.isOpen)
        #expect(list.highlighted == nil)
    }

    /// The field shows the name moved to; the list stays narrowed to what was typed.
    @Test func downMovesThroughTheListAndStopsAtTheLast() {
        var list = SuggestionList()
        list.typed("cli", suggestions: ["Client A", "Client B"])
        #expect(list.press(.down) == .show("Client A"))
        #expect(list.press(.down) == .show("Client B"))
        #expect(list.press(.down) == .handled)
        #expect(list.highlighted == 1)
        #expect(list.items == ["Client A", "Client B"])
    }

    /// ↑ from the first name goes back to what was typed, with nothing highlighted.
    @Test func upMovesBackToWhatWasTyped() {
        var list = SuggestionList()
        list.typed("cli", suggestions: ["Client A", "Client B"])
        _ = list.press(.down)
        _ = list.press(.down)
        #expect(list.press(.up) == .show("Client A"))
        #expect(list.press(.up) == .show("cli"))
        #expect(list.highlighted == nil)
        #expect(list.press(.up) == .handled)
        #expect(list.isOpen)
    }

    /// Return on a highlighted name picks it: the field holds it, the list closes and nothing starts.
    @Test func returnPicksTheHighlightedName() {
        var list = SuggestionList()
        list.typed("cli", suggestions: ["Client A", "Client B"])
        _ = list.press(.down)
        #expect(list.press(.return) == .pick("Client A"))
        #expect(!list.isOpen)
        #expect(list.highlighted == nil)
    }

    /// With nothing highlighted, open or not, Return is the form's Start or Log, and the list closes.
    @Test func returnWithNothingHighlightedSubmits() {
        var list = SuggestionList()
        list.typed("cli", suggestions: ["Client A"])
        #expect(list.press(.return) == .submit)
        #expect(!list.isOpen)
        #expect(list.press(.return) == .submit)
    }

    /// Escape closes the open list and leaves the field as it is; with the list closed it is the Panel's.
    @Test func escapeClosesTheList() {
        var list = SuggestionList()
        list.typed("cli", suggestions: ["Client A"])
        _ = list.press(.down)
        #expect(list.press(.escape) == .handled)
        #expect(!list.isOpen)
        #expect(list.highlighted == nil)
        #expect(list.press(.escape) == .ignored)
    }

    /// A click on a row picks its name, as Return on it does.
    @Test func clickingARowPicksItsName() {
        var list = SuggestionList()
        list.typed("cli", suggestions: ["Client A", "Client B"])
        #expect(list.click(row: 1) == "Client B")
        #expect(!list.isOpen)
    }

    /// A click below the last row, or anywhere with no row (the table's -1), picks nothing.
    @Test(arguments: [-1, 2])
    func clickingOffTheRowsPicksNothing(row: Int) {
        var list = SuggestionList()
        list.typed("cli", suggestions: ["Client A", "Client B"])
        #expect(list.click(row: row) == nil)
        #expect(list.isOpen)
        #expect(list.label(atRow: row) == nil)
    }

    @Test func eachRowIsItsSuggestion() {
        var list = SuggestionList()
        list.typed("cli", suggestions: ["Client A", "Client B"])
        #expect(list.label(atRow: 0) == "Client A")
        #expect(list.label(atRow: 1) == "Client B")
    }

    /// Every suggestion can be archived; pinning is offered unless it is pinned.
    @Test func rightClickingAnUnpinnedNameOffersPinAndArchive() {
        let menu = SuggestionList.menu(for: "Client A", isPinned: false)
        #expect(menu.map(\.action) == [.pin, .archive])
        #expect(menu.map(\.title) == ["Pin “Client A”", "Archive “Client A”"])
        #expect(menu.allSatisfy { $0.label == "Client A" })
    }

    @Test func rightClickingAPinnedNameOffersArchiveOnly() {
        let menu = SuggestionList.menu(for: "Internal", isPinned: true)
        #expect(menu.map(\.action) == [.archive])
        #expect(menu.map(\.title) == ["Archive “Internal”"])
    }

    /// Archiving from the open list drops the name; the list stays open and the highlight stays on the
    /// name it was on.
    @Test func newSuggestionsKeepTheListOpenAndTheHighlightOnItsName() {
        var list = SuggestionList()
        list.typed("cli", suggestions: ["Client A", "Client B", "Client C"])
        _ = list.press(.down)
        _ = list.press(.down)
        _ = list.press(.down)
        list.reload(["Client B", "Client C"])
        #expect(list.isOpen)
        #expect(list.items == ["Client B", "Client C"])
        #expect(list.highlighted == 1)
    }

    @Test func newSuggestionsWithoutTheHighlightedNameHighlightNothing() {
        var list = SuggestionList()
        list.typed("cli", suggestions: ["Client A", "Client B"])
        _ = list.press(.down)
        list.reload(["Client B"])
        #expect(list.highlighted == nil)
    }

    @Test func archivingTheLastSuggestionClosesTheList() {
        var list = SuggestionList()
        list.typed("cli", suggestions: ["Client A"])
        list.reload([])
        #expect(!list.isOpen)
    }

    /// The form empties the field after archiving the name it held: the empty field is the new filter,
    /// and the open list stays open.
    @Test func textSetFromOutsideIsTheNewFilter() {
        var list = SuggestionList()
        list.typed("cli", suggestions: ["Client A"])
        _ = list.press(.down)
        list.set("", suggestions: ["Internal"])
        #expect(list.isOpen)
        #expect(list.items == ["Internal"])
        #expect(list.highlighted == nil)
        _ = list.press(.down)
        _ = list.press(.up)
        #expect(list.press(.up) == .handled)
        _ = list.press(.down)
        #expect(list.press(.up) == .show(""))
    }

    /// ▾ opens the list with every suggestion for what was typed, and closes it again.
    @Test func theDisclosureButtonOpensAndClosesTheList() {
        var list = SuggestionList()
        list.typed("", suggestions: ["Client A"])
        list.toggle()
        #expect(list.isOpen)
        list.toggle()
        #expect(!list.isOpen)
    }

    @Test func theDisclosureButtonDoesNotOpenAnEmptyList() {
        var list = SuggestionList()
        list.typed("", suggestions: [])
        list.toggle()
        #expect(!list.isOpen)
    }

    /// VoiceOver stays in the field while ↓ and ↑ move, so it is told the name and where it is.
    @Test func theHighlightIsSpokenWithItsPlace() {
        var list = SuggestionList()
        list.typed("cli", suggestions: ["Client A", "Client B", "Client C"])
        #expect(list.spokenHighlight == nil)
        _ = list.press(.down)
        _ = list.press(.down)
        #expect(list.spokenHighlight == "Client B, 2 of 3")
    }

    @Test func upWithTheListClosedIsTheFieldsOwn() {
        var list = SuggestionList()
        list.typed("", suggestions: ["Client A"])
        #expect(list.press(.up) == .ignored)
    }
}

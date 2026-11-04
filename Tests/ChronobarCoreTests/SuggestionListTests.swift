import Testing
import ChronobarCore

@Suite struct SuggestionListTests {
    @Test func pickingASuggestionClosesTheList() {
        var list = SuggestionList()
        #expect(list.isOpen)

        list.pick("Internal")

        #expect(!list.isOpen)
    }

    @Test func typingAfterAPickReopensTheList() {
        var list = SuggestionList()
        list.pick("Internal")
        // The pick itself fills the field, which reports the change like any other.
        list.typed("Internal")
        #expect(!list.isOpen)

        list.typed("Internal ")

        #expect(list.isOpen)
    }
}

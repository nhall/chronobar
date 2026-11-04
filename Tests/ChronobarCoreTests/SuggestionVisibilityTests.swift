import Testing
import ChronobarCore

@Suite struct SuggestionVisibilityTests {
    @Test func pickingASuggestionHidesTheSuggestions() {
        var suggestions = SuggestionVisibility()
        #expect(suggestions.isShown)

        suggestions.pick("Internal")

        #expect(!suggestions.isShown)
    }

    @Test func editingTheNameAfterAPickShowsThemAgain() {
        var suggestions = SuggestionVisibility()
        suggestions.pick("Internal")
        // The pick itself fills the field, which reports the change like any other.
        suggestions.nameChanged(to: "Internal")
        #expect(!suggestions.isShown)

        suggestions.nameChanged(to: "Internal ")

        #expect(suggestions.isShown)
    }
}

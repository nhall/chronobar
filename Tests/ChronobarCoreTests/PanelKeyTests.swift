import Foundation
import Testing
import ChronobarCore

@Suite struct PanelKeyTests {
    let calendar = FakeClock("2026-11-03T09:00:00").calendar
    /// Tuesday.
    let today = Day(year: 2026, month: 11, day: 3)

    private func day(_ string: String) -> Day { Day(string)! }

    private func change(_ command: PanelCommand, viewing viewed: String?) -> PanelChange {
        command.change(viewing: viewed.map(day), today: today, calendar: calendar)
    }

    @Test func dayKeysMoveTheViewedDayOneDay() {
        #expect(change(.previousDay, viewing: nil) == .view(day("2026-11-02")))
        #expect(change(.nextDay, viewing: nil) == .view(day("2026-11-04")))
    }

    /// Past the strip's first or last Day, the strip moves to the week the new Day is in.
    @Test func dayKeysCrossWeeksAndMonths() {
        #expect(change(.previousDay, viewing: "2026-11-01") == .view(day("2026-10-31")))
        #expect(change(.nextDay, viewing: "2026-12-31") == .view(day("2027-01-01")))
    }

    @Test func weekKeysMoveTheViewedDaySevenDays() {
        #expect(change(.previousWeek, viewing: nil) == .view(day("2026-10-27")))
        #expect(change(.nextWeek, viewing: "2026-10-30") == .view(day("2026-11-06")))
    }

    /// Landing on today, by any key, goes back to following the clock across midnight.
    @Test func reachingTodayFollowsTheClock() {
        #expect(change(.today, viewing: "2026-09-14") == .view(nil))
        #expect(change(.nextDay, viewing: "2026-11-02") == .view(nil))
        #expect(change(.previousWeek, viewing: "2026-11-10") == .view(nil))
    }

    @Test func formKeysOpenTheirFormsAndLeaveTheViewedDay() {
        #expect(change(.newProject, viewing: "2026-09-14") == .openNewProject)
        #expect(change(.timeSummary, viewing: "2026-09-14") == .toggleTimeSummary)
    }

    /// A click on a Day in the strip.
    @Test func viewingADayFollowsTheClockOnlyForToday() {
        #expect(PanelChange.viewing(today, today: today) == .view(nil))
        #expect(PanelChange.viewing(day("2026-11-04"), today: today) == .view(day("2026-11-04")))
    }

    @Test func eachCommandNamesItsKey() {
        #expect(PanelCommand.previousWeek.keyName == "⌘[")
        #expect(PanelCommand.nextWeek.keyName == "⌘]")
        #expect(PanelCommand.previousDay.keyName == "←")
        #expect(PanelCommand.nextDay.keyName == "→")
        #expect(PanelCommand.today.keyName == "⌘T")
        #expect(PanelCommand.newProject.keyName == "⌘N")
        #expect(PanelCommand.timeSummary.keyName == "⌘I")
    }

    @Test func aHelpTagEndsWithItsKey() {
        #expect(PanelCommand.previousWeek.help("Previous week") == "Previous week (⌘[)")
        #expect(PanelCommand.timeSummary.help("Time Summary") == "Time Summary (⌘I)")
    }

    @Test func aHelpTagCanNameSeveralKeys() {
        #expect(PanelCommand.help("Move a Day", keys: .previousDay, .nextDay) == "Move a Day (← →)")
    }

    @Test func commandBracketsMoveAWeek() {
        #expect(PanelKey.command(for: .character("["), modifiers: .command, editingText: false) == .previousWeek)
        #expect(PanelKey.command(for: .character("]"), modifiers: .command, editingText: false) == .nextWeek)
    }

    /// `[` types a bracket, and ⌘⇧[ or ⌘⌥[ belong to someone else.
    @Test func bracketsNeedCommandAlone() {
        #expect(PanelKey.command(for: .character("["), modifiers: [], editingText: false) == nil)
        #expect(PanelKey.command(for: .character("]"), modifiers: [], editingText: true) == nil)
        #expect(PanelKey.command(for: .character("["), modifiers: [.command, .shift], editingText: false) == nil)
        #expect(PanelKey.command(for: .character("]"), modifiers: [.command, .option], editingText: false) == nil)
    }

    @Test func commandLettersGoToTodayNewProjectAndSummary() {
        #expect(PanelKey.command(for: .character("t"), modifiers: .command, editingText: false) == .today)
        #expect(PanelKey.command(for: .character("n"), modifiers: .command, editingText: false) == .newProject)
        #expect(PanelKey.command(for: .character("i"), modifiers: .command, editingText: false) == .timeSummary)
    }

    /// With Caps Lock on, the key arrives as a capital.
    @Test func commandLettersIgnoreCapsLock() {
        #expect(PanelKey.command(for: .character("T"), modifiers: .command, editingText: false) == .today)
    }

    /// None of the ⌘ keys edits text in a plain text field, so they work from the ＋ form's fields and a
    /// row's adjust field too.
    @Test func commandKeysWorkWhileATextFieldHasFocus() {
        #expect(PanelKey.command(for: .character("["), modifiers: .command, editingText: true) == .previousWeek)
        #expect(PanelKey.command(for: .character("]"), modifiers: .command, editingText: true) == .nextWeek)
        #expect(PanelKey.command(for: .character("t"), modifiers: .command, editingText: true) == .today)
        #expect(PanelKey.command(for: .character("n"), modifiers: .command, editingText: true) == .newProject)
        #expect(PanelKey.command(for: .character("i"), modifiers: .command, editingText: true) == .timeSummary)
    }

    /// Typing t, n or i in a field types it; ⌘⇧T and the like are left alone.
    @Test func lettersNeedCommandAlone() {
        for letter in ["t", "n", "i"] {
            #expect(PanelKey.command(for: .character(letter), modifiers: [], editingText: true) == nil)
            #expect(PanelKey.command(for: .character(letter), modifiers: [.command, .shift], editingText: false) == nil)
            #expect(PanelKey.command(for: .character(letter), modifiers: [.command, .control], editingText: false) == nil)
        }
    }

    /// ⌘A, ⌘C, ⌘V and the rest of text editing pass through.
    @Test func otherCommandKeysPassThrough() {
        for letter in ["a", "c", "v", "x", "z", "q", ","] {
            #expect(PanelKey.command(for: .character(letter), modifiers: .command, editingText: true) == nil)
        }
    }

    @Test func arrowsMoveADayWithNoTextFieldFocused() {
        #expect(PanelKey.command(for: .leftArrow, modifiers: [], editingText: false) == .previousDay)
        #expect(PanelKey.command(for: .rightArrow, modifiers: [], editingText: false) == .nextDay)
    }

    /// In the ＋ form's fields or a row's adjust field, ← and → move the insertion point.
    @Test func arrowsMoveTheInsertionPointInATextField() {
        #expect(PanelKey.command(for: .leftArrow, modifiers: [], editingText: true) == nil)
        #expect(PanelKey.command(for: .rightArrow, modifiers: [], editingText: true) == nil)
    }

    /// ⌘←, ⇧→ and ⌥← are text-editing and selection keys; they never move the viewed Day.
    @Test func arrowsWithModifiersDoNothing() {
        for modifiers: PanelKey.Modifiers in [.command, .shift, .option, .control] {
            #expect(PanelKey.command(for: .leftArrow, modifiers: modifiers, editingText: false) == nil)
            #expect(PanelKey.command(for: .rightArrow, modifiers: modifiers, editingText: false) == nil)
        }
    }
}

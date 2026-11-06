import Foundation
import Testing
import ChronobarCore

@Suite struct PanelKeyTests {
    let calendar = FakeClock("2026-11-03T09:00:00").calendar
    /// Tuesday.
    let today = Day(year: 2026, month: 11, day: 3)

    private func day(_ string: String) -> Day { Day(string)! }

    @Test func dayKeysMoveTheViewedDayOneDay() {
        #expect(PanelCommand.previousDay.day(from: day("2026-11-03"), today: today, calendar: calendar)
            == day("2026-11-02"))
        #expect(PanelCommand.nextDay.day(from: day("2026-11-03"), today: today, calendar: calendar)
            == day("2026-11-04"))
    }

    /// Past the strip's first or last Day, the strip moves to the week the new Day is in.
    @Test func dayKeysCrossWeeksAndMonths() {
        #expect(PanelCommand.previousDay.day(from: day("2026-11-01"), today: today, calendar: calendar)
            == day("2026-10-31"))
        #expect(PanelCommand.nextDay.day(from: day("2026-12-31"), today: today, calendar: calendar)
            == day("2027-01-01"))
    }

    @Test func weekKeysMoveTheViewedDaySevenDays() {
        #expect(PanelCommand.previousWeek.day(from: day("2026-11-03"), today: today, calendar: calendar)
            == day("2026-10-27"))
        #expect(PanelCommand.nextWeek.day(from: day("2026-10-30"), today: today, calendar: calendar)
            == day("2026-11-06"))
    }

    @Test func todayKeyGoesBackToToday() {
        #expect(PanelCommand.today.day(from: day("2026-09-14"), today: today, calendar: calendar) == today)
    }

    /// ＋ and (i) leave the viewed Day where it is.
    @Test func formKeysDontMoveTheViewedDay() {
        #expect(PanelCommand.newProject.day(from: day("2026-09-14"), today: today, calendar: calendar) == nil)
        #expect(PanelCommand.timeSummary.day(from: day("2026-09-14"), today: today, calendar: calendar) == nil)
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

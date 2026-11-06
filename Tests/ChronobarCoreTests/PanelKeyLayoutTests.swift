import Testing
import ChronobarCore

/// A keyboard layout as the Panel's keys see it: what each key types with modifiers held. The rows are
/// copied from what macOS's own layouts type (`UCKeyTranslate`, dead keys off), so they are a record of
/// the layouts, not of this code. ⌃ is left out of the rows: the layout types the same with it held.
struct Layout {
    /// What a key types, by US key position, with nothing, ⇧, ⌥, ⌥⇧, ⌘, ⌘⇧, ⌘⌥ and ⌘⌥⇧ held.
    let rows: [UInt16: [String]]

    /// Caps Lock capitalizes a letter, ⌘ held or not, as macOS's layouts do.
    func types(_ keyCode: UInt16, _ modifiers: PanelKey.Modifiers) -> String? {
        guard let row = rows[keyCode] else { return nil }
        let index = (modifiers.contains(.shift) ? 1 : 0) + (modifiers.contains(.option) ? 2 : 0)
            + (modifiers.contains(.command) ? 4 : 0)
        return modifiers.contains(.capsLock) ? row[index].uppercased() : row[index]
    }

    func command(_ keyCode: UInt16, _ modifiers: PanelKey.Modifiers, editingText: Bool = false) -> PanelCommand? {
        PanelKey.command(keyCode: keyCode, modifiers: modifiers, layout: types, editingText: editingText)
    }
}

/// US key positions (`kVK_ANSI_…`), named for what they type on the US layout.
enum USKey {
    static let t: UInt16 = 0x11
    static let n: UInt16 = 0x2D
    static let i: UInt16 = 0x22
    static let leftBracket: UInt16 = 0x21
    static let rightBracket: UInt16 = 0x1E
    static let five: UInt16 = 0x17
    static let six: UInt16 = 0x16
    static let minus: UInt16 = 0x1B
    static let equal: UInt16 = 0x18
    static let k: UInt16 = 0x28
    static let g: UInt16 = 0x05
    static let l: UInt16 = 0x25
}

extension Layout {
    static let us = Layout(rows: [
        USKey.t: ["t", "T", "†", "ˇ", "t", "t", "†", "ˇ"],
        USKey.n: ["n", "N", "", "˜", "n", "n", "~", "˜"],
        USKey.i: ["i", "I", "", "ˆ", "i", "i", "^", "ˆ"],
        USKey.leftBracket: ["[", "{", "“", "”", "[", "[", "“", "”"],
        USKey.rightBracket: ["]", "}", "‘", "’", "]", "]", "‘", "’"],
    ])

    /// German types `[` and `]` with ⌥5 and ⌥6, and ü where US has `[`.
    static let german = Layout(rows: [
        USKey.t: ["t", "T", "†", "˝", "t", "t", "†", "˝"],
        USKey.n: ["n", "N", "", "›", "n", "n", "~", "›"],
        USKey.i: ["i", "I", "⁄", "Û", "i", "i", "⁄", "Û"],
        USKey.leftBracket: ["ü", "Ü", "•", "°", "ü", "ü", "•", "°"],
        USKey.rightBracket: ["+", "*", "±", "\u{F8FF}", "+", "*", "±", "\u{F8FF}"],
        USKey.five: ["5", "%", "[", "ﬁ", "5", "5", "[", "ﬁ"],
        USKey.six: ["6", "&", "]", "", "6", "6", "]", "^"],
    ])

    /// French (AZERTY) types `[` and `]` with ⌥⇧5 and ⌥⇧-, and `(` and `)` on the keys alone.
    static let french = Layout(rows: [
        USKey.t: ["t", "T", "†", "™", "t", "T", "†", "™"],
        USKey.n: ["n", "N", "", "ı", "n", "N", "~", "ı"],
        USKey.i: ["i", "I", "î", "ï", "i", "I", "î", "ï"],
        USKey.leftBracket: ["", "", "ô", "Ô", "", "", "ô", "Ô"],
        USKey.rightBracket: ["$", "*", "€", "¥", "$", "*", "€", "¥"],
        USKey.five: ["(", "5", "{", "[", "(", "5", "{", "["],
        USKey.minus: [")", "°", "}", "]", ")", "°", "}", "]"],
    ])

    static let dvorak = Layout(rows: [
        USKey.t: ["y", "Y", "¥", "Á", "y", "y", "¥", "Á"],
        USKey.n: ["b", "B", "∫", "ı", "b", "b", "∫", "ı"],
        USKey.i: ["c", "C", "ç", "Ç", "c", "c", "ç", "Ç"],
        USKey.leftBracket: ["/", "?", "÷", "¿", "/", "/", "÷", "¿"],
        USKey.rightBracket: ["=", "+", "≠", "±", "=", "=", "≠", "±"],
        USKey.minus: ["[", "{", "“", "”", "[", "[", "“", "”"],
        USKey.equal: ["]", "}", "‘", "’", "]", "]", "‘", "’"],
        USKey.k: ["t", "T", "†", "ˇ", "t", "t", "†", "ˇ"],
        USKey.l: ["n", "N", "", "˜", "n", "n", "˜", "˜"],
        USKey.g: ["i", "I", "", "ˆ", "i", "i", "ˆ", "ˆ"],
    ])

    /// Dvorak, but with ⌘ held it types US letters, ignoring ⌥.
    static let dvorakQWERTYCommand = Layout(rows: [
        USKey.t: ["y", "Y", "¥", "Á", "t", "t", "t", "t"],
        USKey.n: ["b", "B", "∫", "ı", "n", "n", "n", "n"],
        USKey.i: ["c", "C", "ç", "Ç", "i", "i", "i", "i"],
        USKey.leftBracket: ["/", "?", "÷", "¿", "[", "{", "[", "{"],
        USKey.rightBracket: ["=", "+", "≠", "±", "]", "}", "]", "}"],
        USKey.k: ["t", "T", "†", "ˇ", "k", "k", "k", "k"],
    ])

    /// Russian types Cyrillic, but with ⌘ held it types US letters and brackets, ignoring ⌥.
    static let russian = Layout(rows: [
        USKey.t: ["е", "Е", "†", "†", "t", "T", "t", "T"],
        USKey.n: ["т", "Т", "™", "™", "n", "N", "n", "N"],
        USKey.i: ["ш", "Ш", "ѕ", "Ѕ", "i", "I", "i", "I"],
        USKey.leftBracket: ["х", "Х", "“", "”", "[", "{", "[", "{"],
        USKey.rightBracket: ["ъ", "Ъ", "ъ", "Ъ", "]", "}", "]", "}"],
    ])
}

@Suite struct PanelKeyLayoutTests {
    // MARK: US

    @Test func usCommandBracketsMoveAWeek() {
        #expect(Layout.us.command(USKey.leftBracket, .command) == .previousWeek)
        #expect(Layout.us.command(USKey.rightBracket, .command) == .nextWeek)
    }

    @Test func usCommandLettersGoToTodayNewProjectAndSummary() {
        #expect(Layout.us.command(USKey.t, .command) == .today)
        #expect(Layout.us.command(USKey.n, .command) == .newProject)
        #expect(Layout.us.command(USKey.i, .command) == .timeSummary)
    }

    /// `[` and `t` type, and ⌘⇧[, ⌘⌥], ⌘⇧T and the like belong to someone else, though US still types
    /// `t` and `[` with ⌘⇧ held.
    @Test func usKeysWithExtraModifiersPassThrough() {
        for key in [USKey.leftBracket, USKey.rightBracket, USKey.t, USKey.n, USKey.i] {
            #expect(Layout.us.command(key, []) == nil)
            #expect(Layout.us.command(key, .shift) == nil)
            #expect(Layout.us.command(key, [.command, .shift]) == nil)
            #expect(Layout.us.command(key, [.command, .option]) == nil)
            #expect(Layout.us.command(key, [.command, .option, .shift]) == nil)
            #expect(Layout.us.command(key, [.command, .control]) == nil)
        }
    }

    /// None of the ⌘ keys edits text in a plain text field, so they work from the ＋ form's fields and a
    /// row's adjust field too.
    @Test func commandKeysWorkWhileATextFieldHasFocus() {
        #expect(Layout.us.command(USKey.leftBracket, .command, editingText: true) == .previousWeek)
        #expect(Layout.us.command(USKey.rightBracket, .command, editingText: true) == .nextWeek)
        #expect(Layout.us.command(USKey.t, .command, editingText: true) == .today)
        #expect(Layout.us.command(USKey.n, .command, editingText: true) == .newProject)
        #expect(Layout.us.command(USKey.i, .command, editingText: true) == .timeSummary)
        #expect(Layout.german.command(USKey.five, [.command, .option], editingText: true) == .previousWeek)
        #expect(Layout.french.command(USKey.minus, [.command, .option, .shift], editingText: true) == .nextWeek)
    }

    /// Typing in a field types, on any layout: German ⌥5 types `[` and French `(` is the 5 key alone.
    @Test func keysWithoutCommandTypeInATextField() {
        #expect(Layout.us.command(USKey.t, [], editingText: true) == nil)
        #expect(Layout.us.command(USKey.leftBracket, [], editingText: true) == nil)
        #expect(Layout.german.command(USKey.five, .option, editingText: true) == nil)
        #expect(Layout.french.command(USKey.five, [.option, .shift], editingText: true) == nil)
        #expect(Layout.russian.command(USKey.t, [], editingText: true) == nil)
    }

    /// ⌘A, ⌘C, ⌘V, ⌘X, ⌘Z and the rest of text editing pass through, and so do ⌘Q and ⌘, for the menu.
    @Test func otherCommandKeysPassThrough() {
        let others = Layout(rows: [
            0x00: ["a", "A", "å", "Å", "a", "a", "å", "Å"],
            0x08: ["c", "C", "ç", "Ç", "c", "c", "ç", "Ç"],
            0x09: ["v", "V", "√", "◊", "v", "v", "√", "◊"],
            0x07: ["x", "X", "≈", "˛", "x", "x", "≈", "˛"],
            0x06: ["z", "Z", "Ω", "¸", "z", "z", "Ω", "¸"],
            0x0C: ["q", "Q", "œ", "Œ", "q", "q", "œ", "Œ"],
            0x2B: [",", "<", "≤", "¯", ",", ",", "≤", "¯"],
        ])
        for key: UInt16 in [0x00, 0x08, 0x09, 0x07, 0x06, 0x0C, 0x2B] {
            #expect(others.command(key, .command, editingText: true) == nil)
            #expect(others.command(key, .command, editingText: false) == nil)
        }
    }

    /// Caps Lock capitalizes a letter even with ⌘ held; the ⌘ keys go by the letter it capitalizes.
    @Test func commandLettersIgnoreCapsLock() {
        #expect(Layout.us.command(USKey.t, [.command, .capsLock]) == .today)
        #expect(Layout.us.command(USKey.n, [.command, .capsLock], editingText: true) == .newProject)
        #expect(Layout.us.command(USKey.i, [.command, .capsLock]) == .timeSummary)
        #expect(Layout.us.command(USKey.leftBracket, [.command, .capsLock]) == .previousWeek)
        #expect(Layout.german.command(USKey.five, [.command, .option, .capsLock]) == .previousWeek)
    }

    /// Caps Lock is no modifier of its own: ⌘⇧T with it on still passes through, and ← still moves a Day.
    @Test func capsLockChangesNothingElse() {
        #expect(Layout.us.command(USKey.t, [.command, .shift, .capsLock]) == nil)
        #expect(Layout.us.command(USKey.t, .capsLock) == nil)
        #expect(Layout.us.command(PanelKey.leftArrow, .capsLock) == .previousDay)
        #expect(Layout.us.command(PanelKey.rightArrow, .capsLock, editingText: true) == nil)
    }

    /// An input source without layout data, such as some input methods, still has the arrows; the ⌘ keys
    /// pass through.
    @Test func arrowsWorkWithoutLayoutData() {
        func command(_ keyCode: UInt16, _ modifiers: PanelKey.Modifiers) -> PanelCommand? {
            PanelKey.command(keyCode: keyCode, modifiers: modifiers, layout: nil, editingText: false)
        }
        #expect(command(PanelKey.leftArrow, []) == .previousDay)
        #expect(command(PanelKey.rightArrow, []) == .nextDay)
        #expect(command(USKey.t, .command) == nil)
    }

    // MARK: Arrows

    @Test func arrowsMoveTheInsertionPointInATextField() {
        #expect(Layout.us.command(PanelKey.leftArrow, [], editingText: true) == nil)
        #expect(Layout.us.command(PanelKey.rightArrow, [], editingText: true) == nil)
    }

    /// ⌘←, ⇧→ and ⌥← are text-editing and selection keys; they never move the viewed Day.
    @Test func arrowsWithModifiersDoNothing() {
        for modifiers: PanelKey.Modifiers in [.command, .shift, .option, .control] {
            #expect(Layout.us.command(PanelKey.leftArrow, modifiers) == nil)
            #expect(Layout.us.command(PanelKey.rightArrow, modifiers) == nil)
        }
    }

    // MARK: Other layouts

    /// German types `[` and `]` with ⌥5 and ⌥6, so ⌘⌥5 and ⌘⌥6 are its ⌘[ and ⌘].
    @Test func germanWeekKeysAreCommandOptionFiveAndSix() {
        #expect(Layout.german.command(USKey.five, [.command, .option]) == .previousWeek)
        #expect(Layout.german.command(USKey.six, [.command, .option]) == .nextWeek)
    }

    @Test func germanLetterKeysAreWhereGermanTypesThem() {
        #expect(Layout.german.command(USKey.t, .command) == .today)
        #expect(Layout.german.command(USKey.n, .command) == .newProject)
        #expect(Layout.german.command(USKey.i, .command) == .timeSummary)
    }

    /// German types ü where US has `[`; ⌘ü is not the week key.
    @Test func germanKeysAtTheUSBracketPositionsPassThrough() {
        #expect(Layout.german.command(USKey.leftBracket, .command) == nil)
        #expect(Layout.german.command(USKey.rightBracket, .command) == nil)
        #expect(Layout.german.command(USKey.five, .command) == nil)
    }

    /// French types `[` and `]` with ⌥⇧5 and ⌥⇧-, so both modifiers are needed.
    @Test func frenchWeekKeysAreCommandOptionShiftFiveAndMinus() {
        #expect(Layout.french.command(USKey.five, [.command, .option, .shift]) == .previousWeek)
        #expect(Layout.french.command(USKey.minus, [.command, .option, .shift]) == .nextWeek)
        #expect(Layout.french.command(USKey.five, [.command, .option]) == nil)
        #expect(Layout.french.command(USKey.five, [.command, .shift]) == nil)
    }

    @Test func frenchLetterKeys() {
        #expect(Layout.french.command(USKey.t, .command) == .today)
        #expect(Layout.french.command(USKey.n, .command) == .newProject)
        #expect(Layout.french.command(USKey.i, .command) == .timeSummary)
        #expect(Layout.french.command(USKey.t, [.command, .shift]) == nil)
    }

    /// Dvorak's keys are where Dvorak types their characters, not where US has them.
    @Test func dvorakKeysAreWhereDvorakTypesThem() {
        #expect(Layout.dvorak.command(USKey.minus, .command) == .previousWeek)
        #expect(Layout.dvorak.command(USKey.equal, .command) == .nextWeek)
        #expect(Layout.dvorak.command(USKey.k, .command) == .today)
        #expect(Layout.dvorak.command(USKey.l, .command) == .newProject)
        #expect(Layout.dvorak.command(USKey.g, .command) == .timeSummary)
        #expect(Layout.dvorak.command(USKey.t, .command) == nil)
        #expect(Layout.dvorak.command(USKey.leftBracket, .command) == nil)
    }

    /// "Dvorak – QWERTY ⌘" types US characters with ⌘ held, so its ⌘ keys are at the US positions.
    @Test func dvorakQWERTYCommandKeysAreAtTheirUSPositions() {
        #expect(Layout.dvorakQWERTYCommand.command(USKey.leftBracket, .command) == .previousWeek)
        #expect(Layout.dvorakQWERTYCommand.command(USKey.rightBracket, .command) == .nextWeek)
        #expect(Layout.dvorakQWERTYCommand.command(USKey.t, .command) == .today)
        #expect(Layout.dvorakQWERTYCommand.command(USKey.k, .command) == nil)
        #expect(Layout.dvorakQWERTYCommand.command(USKey.t, [.command, .option]) == nil)
        #expect(Layout.dvorakQWERTYCommand.command(USKey.t, [.command, .option, .shift]) == nil)
    }

    @Test func russianKeysAreAtTheirUSPositions() {
        #expect(Layout.russian.command(USKey.leftBracket, .command) == .previousWeek)
        #expect(Layout.russian.command(USKey.rightBracket, .command) == .nextWeek)
        #expect(Layout.russian.command(USKey.t, .command) == .today)
        #expect(Layout.russian.command(USKey.n, .command) == .newProject)
        #expect(Layout.russian.command(USKey.i, .command) == .timeSummary)
    }

    /// A modifier the key doesn't need to type its character makes it someone else's key, even where the
    /// layout types the same character with it held.
    @Test func aModifierTheCharacterDoesNotNeedPassesThrough() {
        #expect(Layout.russian.command(USKey.t, [.command, .option]) == nil)
        #expect(Layout.russian.command(USKey.leftBracket, [.command, .option]) == nil)
    }

    /// Without ⌘ the keys type, and with ⌃ they belong to someone else.
    @Test func characterKeysNeedCommandAndNotControl() {
        #expect(Layout.german.command(USKey.five, .option) == nil)
        #expect(Layout.us.command(USKey.t, []) == nil)
        #expect(Layout.us.command(USKey.leftBracket, []) == nil)
        #expect(Layout.us.command(USKey.t, [.command, .control]) == nil)
        #expect(Layout.german.command(USKey.five, [.command, .option, .control]) == nil)
    }

    /// The arrows are the same keys on every layout.
    @Test func arrowsMoveADayOnAnyLayout() {
        for layout in [Layout.us, .german, .french, .dvorak, .russian] {
            #expect(layout.command(PanelKey.leftArrow, []) == .previousDay)
            #expect(layout.command(PanelKey.rightArrow, []) == .nextDay)
        }
    }
}

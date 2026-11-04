import Testing
import ChronobarCore

@Suite struct ForegroundTests {
    @Test func contrastMatchesKnownWCAGRatios() {
        let white = SRGB(red: 1, green: 1, blue: 1)
        let black = SRGB(red: 0, green: 0, blue: 0)
        #expect(abs(Contrast.ratio(white, black) - 21) < 0.01)
        #expect(abs(Contrast.ratio(black, white) - 21) < 0.01)
        #expect(abs(Contrast.ratio(white, white) - 1) < 0.01)
        // #777777 on white is the textbook 4.48:1.
        let gray = SRGB(red: 0x77 / 255.0, green: 0x77 / 255.0, blue: 0x77 / 255.0)
        #expect(abs(Contrast.ratio(gray, white) - 4.48) < 0.01)
    }

    /// Light mode's system blue, #007AFF: white is about 4:1 on it.
    let blue = SRGB(red: 0, green: 122 / 255.0, blue: 1)
    /// Light mode's system yellow, #FFCC00: white is about 1.6:1 on it.
    let yellow = SRGB(red: 1, green: 204 / 255.0, blue: 0)
    /// Light mode's system indigo, #5856D6: white is about 6:1 on it.
    let indigo = SRGB(red: 88 / 255.0, green: 86 / 255.0, blue: 214 / 255.0)

    @Test func whiteStaysWhereverItIsReadable() {
        #expect(Foreground.on(indigo, for: .text) == .white)
        #expect(Foreground.on(indigo, for: .glyph) == .white)
        // About 4:1 is enough for a glyph.
        #expect(Foreground.on(blue, for: .glyph) == .white)
    }

    @Test func blackReplacesWhiteWhereWhiteIsTooFaint() {
        #expect(Foreground.on(yellow, for: .text) == .black)
        #expect(Foreground.on(yellow, for: .glyph) == .black)
        // About 4:1 is too low for text.
        #expect(Foreground.on(blue, for: .text) == .black)
    }

    @Test func everyBackgroundGetsAForegroundThatMeetsItsRole() {
        let steps = stride(from: 0.0, through: 1.0, by: 1 / 32.0)
        for r in steps { for g in steps { for b in steps {
            let background = SRGB(red: r, green: g, blue: b)
            for role in [Foreground.Role.text, .glyph] {
                let ratio = Contrast.ratio(Foreground.on(background, for: role).srgb, background)
                #expect(ratio >= role.minimumContrast, "\(background) \(role)")
            }
        } } }
    }

    @Test func theMinimumsAreWCAGs() {
        #expect(Foreground.Role.text.minimumContrast == 4.5)
        #expect(Foreground.Role.glyph.minimumContrast == 3)
    }
}

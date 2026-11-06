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
        #expect(Foreground.on(indigo) == .white)
    }

    @Test func blackReplacesWhiteWhereWhiteIsTooFaint() {
        #expect(Foreground.on(yellow) == .black)
        // About 4:1 was enough for ▶ or ⏸, but not for the running count, which is text.
        #expect(Foreground.on(blue) == .black)
    }

    @Test func everyBackgroundGetsAReadableForeground() {
        let steps = stride(from: 0.0, through: 1.0, by: 1 / 32.0)
        for r in steps { for g in steps { for b in steps {
            let background = SRGB(red: r, green: g, blue: b)
            let ratio = Contrast.ratio(Foreground.on(background).srgb, background)
            #expect(ratio >= Foreground.minimumContrast, "\(background)")
        } } }
    }

    /// The square shows the running count, a digit at 11 points, which is small text.
    @Test func theMinimumIsWCAGsForSmallText() {
        #expect(Foreground.minimumContrast == 4.5)
    }
}

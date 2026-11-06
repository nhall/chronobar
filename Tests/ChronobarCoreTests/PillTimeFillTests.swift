import Testing
import ChronobarCore

/// The dark fill behind the Pill's white time, under the Display accessibility settings.
@Suite struct PillTimeFillTests {
    private let white = SRGB(red: 1, green: 1, blue: 1)

    @Test func byDefaultTheMenuBarShowsThroughALittle() {
        let fill = PillTimeFill(increaseContrast: false, reduceTransparency: false)

        #expect(fill.opacity < 1)
    }

    @Test func reduceTransparencyMakesItOpaque() {
        let fill = PillTimeFill(increaseContrast: false, reduceTransparency: true)

        #expect(fill.opacity == 1)
    }

    /// Opaque, so nothing behind it can lower the contrast, and dark enough for 7:1 (WCAG AAA) with an
    /// edge that sets it off a dark menu bar.
    @Test func increaseContrastMakesItOpaqueDarkerAndOutlined() {
        let standard = PillTimeFill(increaseContrast: false, reduceTransparency: false)
        let fill = PillTimeFill(increaseContrast: true, reduceTransparency: false)

        #expect(fill.opacity == 1)
        #expect(Contrast.ratio(white, fill.color) >= 7)
        #expect(Contrast.ratio(white, fill.color) > Contrast.ratio(white, standard.color))
        #expect(fill.outlined)
        #expect(!standard.outlined)
    }
}

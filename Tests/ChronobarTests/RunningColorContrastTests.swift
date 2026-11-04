import SwiftUI
import Testing
import ChronobarCore
@testable import Chronobar

/// Light, dark, and each with Increase Contrast on.
struct Appearance: CustomTestStringConvertible, Sendable {
    let scheme: ColorScheme
    let contrast: ColorSchemeContrast

    static let all = [ColorScheme.light, .dark].flatMap { scheme in
        [ColorSchemeContrast.standard, .increased].map { Appearance(scheme: scheme, contrast: $0) }
    }

    var environment: EnvironmentValues {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        // `colorSchemeContrast` has no public setter, and the app resolves its colors from the view's
        // environment (`RunningColor.background(in:)`), not from an `NSAppearance`. Resolving an `NSColor`
        // in a high-contrast appearance would measure a different path from the one the Pill draws, so
        // this sets the underlying value SwiftUI reads.
        environment._colorSchemeContrast = contrast
        return environment
    }

    var testDescription: String { "\(scheme) \(contrast)" }
}

/// The foreground drawn on each running color, measured on the color SwiftUI draws in each appearance.
/// The accent color is the one currently set in System Settings; `ForegroundTests` covers every other.
@MainActor @Suite struct RunningColorContrastTests {
    @Test(arguments: RunningColor.allCases, Appearance.all)
    func textAndGlyphsAreReadableOnEveryRunningColor(color: RunningColor, appearance: Appearance) {
        let background = color.background(in: appearance.environment)
        for role in [Foreground.Role.text, .glyph] {
            let foreground = color.foreground(for: role, in: appearance.environment)
            #expect(Contrast.ratio(foreground.srgb, background) >= role.minimumContrast, "\(role)")
        }
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func whiteWasUnreadableOnYellowAndIsReplaced(scheme: ColorScheme) {
        let environment = Appearance(scheme: scheme, contrast: .standard).environment
        #expect(Contrast.ratio(Foreground.white.srgb, RunningColor.yellow.background(in: environment)) < 2)
        #expect(RunningColor.yellow.foreground(for: .glyph, in: environment) == .black)
        #expect(RunningColor.yellow.foreground(for: .text, in: environment) == .black)
    }

    @Test func increaseContrastDarkensLightModeYellowEnoughForWhite() {
        // The accessible light yellow is a dark amber; black would fall below 4.5:1 on it.
        let environment = Appearance(scheme: .light, contrast: .increased).environment
        #expect(RunningColor.yellow.foreground(for: .text, in: environment) == .white)
    }

    @Test(arguments: Appearance.all)
    func theNamedColorsStayDistinctInEveryAppearance(appearance: Appearance) {
        let backgrounds = RunningColor.allCases.filter { $0 != .accent }
            .map { $0.background(in: appearance.environment) }
        for (i, a) in backgrounds.enumerated() {
            for b in backgrounds[(i + 1)...] { #expect(a != b) }
        }
    }
}

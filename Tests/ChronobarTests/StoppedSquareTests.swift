import SwiftUI
import Testing
import ChronobarCore
@testable import Chronobar

/// With nothing running, the square shows 0 on gray, in the running count's digit style, so it is text
/// and needs WCAG's 4.5:1 too.
@MainActor @Suite struct StoppedSquareTests {
    @Test(arguments: Appearance.all)
    func theZeroIsReadableOnStoppedGray(appearance: Appearance) {
        let background = StoppedSquare.background(in: appearance.environment)
        let foreground = StoppedSquare.foreground(in: appearance.environment)
        #expect(Contrast.ratio(foreground.srgb, background) >= Foreground.minimumContrast)
    }

    /// White on the stopped gray is about 3.3:1 in light mode and 2.9:1 in dark.
    @Test(arguments: [ColorScheme.light, .dark])
    func whiteIsTooFaintForTheZero(scheme: ColorScheme) {
        let environment = Appearance(scheme: scheme, contrast: .standard).environment
        #expect(Contrast.ratio(Foreground.white.srgb, StoppedSquare.background(in: environment)) < 3.5)
        #expect(StoppedSquare.foreground(in: environment) == .black)
    }
}

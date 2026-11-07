import SwiftUI
import Testing
import ChronobarCore
@testable import Chronobar

/// With nothing running, the square shows 0 on gray, in the running count's digit style, so it is text
/// and needs WCAG's 4.5:1 too.
@MainActor @Suite struct StoppedSquareTests {
    /// The gray in each appearance, the digit's color and its contrast, measured with WCAG 2:
    /// light #AEAEB2, black 9.50:1; dark #B8B8BC, black 10.62:1;
    /// light Increase Contrast #6C6C70, white 5.23:1; dark Increase Contrast #C7C7CC, black 12.47:1.
    static let expected: [(Appearance, red: Int, green: Int, blue: Int, Foreground, ratio: Double)] = [
        (Appearance(scheme: .light, contrast: .standard), 0xAE, 0xAE, 0xB2, .black, 9.50),
        (Appearance(scheme: .dark, contrast: .standard), 0xB8, 0xB8, 0xBC, .black, 10.62),
        (Appearance(scheme: .light, contrast: .increased), 0x6C, 0x6C, 0x70, .white, 5.23),
        (Appearance(scheme: .dark, contrast: .increased), 0xC7, 0xC7, 0xCC, .black, 12.47),
    ]

    @Test(arguments: Appearance.all)
    func theZeroIsReadableOnStoppedGray(appearance: Appearance) {
        let background = StoppedSquare.background(in: appearance.environment)
        let foreground = StoppedSquare.foreground(in: appearance.environment)
        #expect(Contrast.ratio(foreground.srgb, background) >= Foreground.minimumContrast)
    }

    @Test(arguments: 0..<4)
    func eachAppearanceHasItsOwnGray(index: Int) {
        let (appearance, red, green, blue, foreground, ratio) = Self.expected[index]
        let background = StoppedSquare.background(in: appearance.environment)
        #expect(Int((background.red * 255).rounded()) == red)
        #expect(Int((background.green * 255).rounded()) == green)
        #expect(Int((background.blue * 255).rounded()) == blue)
        #expect(StoppedSquare.foreground(in: appearance.environment) == foreground)
        #expect(abs(Contrast.ratio(foreground.srgb, background) - ratio) < 0.005)
    }

    /// The SwiftUI-drawn color is the same gray `background(in:)` measures.
    @Test(arguments: Appearance.all)
    func theDrawnColorIsTheMeasuredOne(appearance: Appearance) {
        let resolved = StoppedSquare.color(in: appearance.environment).resolve(in: appearance.environment)
        let background = StoppedSquare.background(in: appearance.environment)
        #expect(abs(Double(resolved.red) - background.red) < 0.002)
        #expect(abs(Double(resolved.green) - background.green) < 0.002)
        #expect(abs(Double(resolved.blue) - background.blue) < 0.002)
    }

    /// White on the stopped gray is about 2.2:1 in light mode and 2.0:1 in dark.
    @Test(arguments: [ColorScheme.light, .dark])
    func whiteIsTooFaintForTheZero(scheme: ColorScheme) {
        let environment = Appearance(scheme: scheme, contrast: .standard).environment
        #expect(Contrast.ratio(Foreground.white.srgb, StoppedSquare.background(in: environment)) < 3.5)
        #expect(StoppedSquare.foreground(in: environment) == .black)
    }

    /// Running Gray stays SwiftUI's gray, so it no longer matches the stopped square.
    @Test func runningGrayIsUnchanged() {
        #expect(RunningColor.gray.color == .gray)
    }
}

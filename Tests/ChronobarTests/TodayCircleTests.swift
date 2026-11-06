import SwiftUI
import Testing
import ChronobarCore
@testable import Chronobar

/// Today's date in the Week strip: a circle in the text color, with the date in the opposite color.
@MainActor @Suite struct TodayCircleTests {
    @Test(arguments: [ColorScheme.light, .dark])
    func theCircleIsTheTextColorAndTheDateTheOpposite(scheme: ColorScheme) {
        let environment = Appearance(scheme: scheme, contrast: .standard).environment
        let circle = TodayCircle.fill.resolve(in: environment)
        let date = TodayCircle.date(in: environment.colorScheme).resolve(in: environment)
        let circleLuminance = SRGB(
            red: Double(circle.red), green: Double(circle.green), blue: Double(circle.blue)).luminance
        // Dark mode: a white circle with a black date. Light mode: a black circle with a white date. The
        // text color is near white or black rather than exactly, and may be partly transparent.
        if scheme == .dark {
            #expect(circleLuminance > 0.8)
            #expect(date == Color.Resolved(red: 0, green: 0, blue: 0))
        } else {
            #expect(circleLuminance < 0.05)
            #expect(date == Color.Resolved(red: 1, green: 1, blue: 1))
        }
    }

    /// The circle's text color is partly transparent outside Increase Contrast, so it is measured over the
    /// backdrop that makes it faintest: white in light mode, black in dark mode.
    @Test(arguments: Appearance.all)
    func theDateIsReadableOnTheCircle(appearance: Appearance) {
        let environment = appearance.environment
        let backdrop: Double = appearance.scheme == .dark ? 0 : 1
        let circle = TodayCircle.fill.resolve(in: environment)
        func over(_ c: Float) -> Double { Double(c) * Double(circle.opacity) + backdrop * (1 - Double(circle.opacity)) }
        let fill = SRGB(red: over(circle.red), green: over(circle.green), blue: over(circle.blue))
        let date = TodayCircle.date(in: environment.colorScheme).resolve(in: environment)
        let text = SRGB(red: Double(date.red), green: Double(date.green), blue: Double(date.blue))
        #expect(Contrast.ratio(text, fill) >= 4.5)
    }
}

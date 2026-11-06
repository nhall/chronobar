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
        let backdrop = appearance.scheme == .dark ? SRGB(red: 0, green: 0, blue: 0) : SRGB(red: 1, green: 1, blue: 1)
        let fill = TodayCircle.fill.srgb(in: environment, over: backdrop)
        let text = TodayCircle.date(in: environment.colorScheme).srgb(in: environment, over: fill)
        #expect(Contrast.ratio(text, fill) >= 4.5)
    }
}

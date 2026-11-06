import SwiftUI
import Testing
import ChronobarCore
@testable import Chronobar

/// The viewed Day in the Week strip, when it isn't today: a gray circle that stands out from the Panel
/// and from today's circle, with its date readable on it.
@MainActor @Suite struct ViewedDayCircleTests {
    /// The Panel behind the Week strip, as measured in screenshots of the running app with Increase
    /// Contrast on, which makes the popover close to opaque. With it off the popover is see-through, so its
    /// color follows the desktop behind it and can't be pinned down; these stand in for it too.
    static func panel(_ scheme: ColorScheme) -> SRGB {
        scheme == .dark ? SRGB(red: 0.212, green: 0.216, blue: 0.212) : SRGB(red: 0.933, green: 0.933, blue: 0.933)
    }

    static func srgb(_ color: Color, in environment: EnvironmentValues, over backdrop: SRGB) -> SRGB {
        let c = color.resolve(in: environment)
        let a = Double(c.opacity)
        return SRGB(red: Double(c.red) * a + backdrop.red * (1 - a),
                    green: Double(c.green) * a + backdrop.green * (1 - a),
                    blue: Double(c.blue) * a + backdrop.blue * (1 - a))
    }

    /// WCAG's 3:1 for a non-text UI element.
    @Test(arguments: Appearance.all)
    func theCircleStandsOutFromThePanel(appearance: Appearance) {
        let environment = appearance.environment
        let panel = Self.panel(appearance.scheme)
        let circle = Self.srgb(ViewedDayCircle.fill(in: environment.colorScheme), in: environment, over: panel)
        #expect(Contrast.ratio(circle, panel) >= 3)
    }

    @Test(arguments: Appearance.all)
    func theDateIsReadableOnTheCircle(appearance: Appearance) {
        let environment = appearance.environment
        let panel = Self.panel(appearance.scheme)
        let circle = Self.srgb(ViewedDayCircle.fill(in: environment.colorScheme), in: environment, over: panel)
        let date = Self.srgb(ViewedDayCircle.date, in: environment, over: circle)
        #expect(Contrast.ratio(date, circle) >= 4.5)
    }

    /// Next to each other, today's circle and the viewed Day's differ by more than a shade.
    @Test(arguments: Appearance.all)
    func theCircleIsApartFromToday(appearance: Appearance) {
        let environment = appearance.environment
        let panel = Self.panel(appearance.scheme)
        let viewed = Self.srgb(ViewedDayCircle.fill(in: environment.colorScheme), in: environment, over: panel)
        let today = Self.srgb(TodayCircle.fill, in: environment, over: panel)
        #expect(Contrast.ratio(viewed, today) >= 2)
    }
}

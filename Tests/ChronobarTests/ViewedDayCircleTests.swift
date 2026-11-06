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

    /// WCAG's 3:1 for a non-text UI element.
    @Test(arguments: Appearance.all)
    func theCircleStandsOutFromThePanel(appearance: Appearance) {
        let environment = appearance.environment
        let panel = Self.panel(appearance.scheme)
        let circle = ViewedDayCircle.fill(in: environment.colorScheme).srgb(in: environment, over: panel)
        #expect(Contrast.ratio(circle, panel) >= 3)
    }

    @Test(arguments: Appearance.all)
    func theDateIsReadableOnTheCircle(appearance: Appearance) {
        let environment = appearance.environment
        let panel = Self.panel(appearance.scheme)
        let circle = ViewedDayCircle.fill(in: environment.colorScheme).srgb(in: environment, over: panel)
        let date = ViewedDayCircle.date.srgb(in: environment, over: circle)
        #expect(Contrast.ratio(date, circle) >= 4.5)
    }

    /// Next to each other, today's circle and the viewed Day's differ by more than a shade.
    @Test(arguments: Appearance.all)
    func theCircleIsApartFromToday(appearance: Appearance) {
        let environment = appearance.environment
        let panel = Self.panel(appearance.scheme)
        let viewed = ViewedDayCircle.fill(in: environment.colorScheme).srgb(in: environment, over: panel)
        let today = TodayCircle.fill.srgb(in: environment, over: panel)
        #expect(Contrast.ratio(viewed, today) >= 2)
    }
}

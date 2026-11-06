import SwiftUI

/// The viewed Day in the Week strip, when it isn't today: an opaque mid gray, so it stands out from the
/// Panel at 3:1 or more in light and dark mode, with Increase Contrast on or off, and stays apart from
/// `TodayCircle`, which is white in dark mode and black in light mode.
enum ViewedDayCircle {
    /// Lighter than the Panel in dark mode, darker than it in light mode.
    static func fill(in colorScheme: ColorScheme) -> Color {
        Color(white: colorScheme == .dark ? 0.62 : 0.5)
    }

    /// Black on both grays: white on dark mode's lighter gray would fall short of 4.5:1.
    static let date = Color.black

}

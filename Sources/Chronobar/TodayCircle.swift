import SwiftUI

/// Today's date in the Week strip: a circle in the text color, with the date in the opposite color, so
/// "today" reads apart from "a timer is running" and from the viewed Day's gray circle.
enum TodayCircle {
    static let fill = Color.primary

    /// Black on dark mode's white circle, white on light mode's black one.
    static func date(in colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black : .white
    }
}

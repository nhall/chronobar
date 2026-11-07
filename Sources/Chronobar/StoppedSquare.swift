import SwiftUI
import ChronobarCore

/// The Pill's square with nothing running: 0 on gray. The 0 is text like the running count, so it gets
/// the same white-or-black rule; white is under 3.3:1 on this gray outside Increase Contrast.
enum StoppedSquare {
    /// SwiftUI's gray, not `NSColor.systemGray`, so it follows Increase Contrast as the running colors do.
    static let color = Color.gray

    /// `color` as SwiftUI draws it in `environment`.
    static func background(in environment: EnvironmentValues) -> SRGB {
        let resolved = color.resolve(in: environment)
        return SRGB(red: Double(resolved.red), green: Double(resolved.green), blue: Double(resolved.blue))
    }

    /// White or black, whichever the 0 is readable in.
    static func foreground(in environment: EnvironmentValues) -> Foreground {
        Foreground.on(background(in: environment))
    }

    /// `foreground(in:)` as a SwiftUI color.
    static func foregroundColor(in environment: EnvironmentValues) -> Color {
        foreground(in: environment) == .white ? .white : .black
    }
}

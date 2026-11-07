import SwiftUI
import ChronobarCore

/// The Pill's square with nothing running: 0 on gray. The 0 is text like the running count, so it gets
/// the same white-or-black rule: black on the gray in light and dark, white on the darker Increase
/// Contrast gray in light mode.
enum StoppedSquare {
    /// Chronobar's own grays, lighter than SwiftUI's `.gray` (which running Gray keeps). Picked from the
    /// view's environment rather than an `NSColor` provider: SwiftUI resolves an `NSColor` for the light
    /// or dark scheme only, never for Increase Contrast.
    static func background(in environment: EnvironmentValues) -> SRGB {
        switch (environment.colorScheme, environment.colorSchemeContrast) {
        case (.dark, .increased): gray(0xC7, 0xC7, 0xCC)
        case (.dark, _): gray(0xB8, 0xB8, 0xBC)
        case (_, .increased): gray(0x6C, 0x6C, 0x70)
        default: gray(0xAE, 0xAE, 0xB2)
        }
    }

    /// `background(in:)` as a SwiftUI color, to draw the square with.
    static func color(in environment: EnvironmentValues) -> Color {
        let background = background(in: environment)
        return Color(.sRGB, red: background.red, green: background.green, blue: background.blue)
    }

    /// White or black, whichever the 0 is readable in.
    static func foreground(in environment: EnvironmentValues) -> Foreground {
        Foreground.on(background(in: environment))
    }

    /// `foreground(in:)` as a SwiftUI color.
    static func foregroundColor(in environment: EnvironmentValues) -> Color {
        foreground(in: environment) == .white ? .white : .black
    }

    private static func gray(_ red: Int, _ green: Int, _ blue: Int) -> SRGB {
        SRGB(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }
}

import Foundation

/// An opaque color as gamma-encoded sRGB components. Extended-range values (below 0 or above 1, from
/// wide-gamut colors) are allowed.
public struct SRGB: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// WCAG 2 relative luminance.
    public var luminance: Double {
        0.2126 * Self.linear(red) + 0.7152 * Self.linear(green) + 0.0722 * Self.linear(blue)
    }

    /// Sign-preserving, so extended-range components stay meaningful.
    private static func linear(_ c: Double) -> Double {
        let magnitude = abs(c)
        let value = magnitude <= 0.04045 ? magnitude / 12.92 : pow((magnitude + 0.055) / 1.055, 2.4)
        return c < 0 ? -value : value
    }
}

/// WCAG 2 contrast ratios.
public enum Contrast {
    /// From 1 (none) to 21 (black on white), in either order.
    public static func ratio(_ a: SRGB, _ b: SRGB) -> Double {
        let (la, lb) = (min(max(a.luminance, 0), 1), min(max(b.luminance, 0), 1))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}

/// What is drawn on the running color: white wherever white is readable, black otherwise. Black always
/// meets the minimum where white doesn't, so every running color, including any system accent, passes.
public enum Foreground: Equatable, Sendable {
    case white, black

    /// What is drawn, and so how much contrast it needs (WCAG 2).
    public enum Role: Sendable {
        /// The Project name and totals: 4.5:1.
        case text
        /// ▶ and ⏸ alone, as in the Pill's square: 3:1.
        case glyph

        public var minimumContrast: Double {
            switch self {
            case .text: 4.5
            case .glyph: 3
            }
        }
    }

    public static func on(_ background: SRGB, for role: Role) -> Foreground {
        Contrast.ratio(white.srgb, background) >= role.minimumContrast ? .white : .black
    }

    public var srgb: SRGB {
        switch self {
        case .white: SRGB(red: 1, green: 1, blue: 1)
        case .black: SRGB(red: 0, green: 0, blue: 0)
        }
    }
}

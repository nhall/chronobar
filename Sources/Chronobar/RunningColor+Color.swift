import SwiftUI
import ChronobarCore

extension RunningColor {
    var color: Color {
        switch self {
        case .accent: .accentColor
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .gray: .gray
        }
    }

    /// This color as SwiftUI draws it in `environment`: its light or dark variant, the Increase Contrast
    /// one when that is on, and for the accent color whatever System Settings has.
    func background(in environment: EnvironmentValues) -> SRGB {
        let resolved = color.resolve(in: environment)
        return SRGB(red: Double(resolved.red), green: Double(resolved.green), blue: Double(resolved.blue))
    }

    /// White or black, whichever is readable on this color in `environment`.
    func foreground(for role: Foreground.Role, in environment: EnvironmentValues) -> Foreground {
        Foreground.on(background(in: environment), for: role)
    }

    /// `foreground(for:in:)` as a SwiftUI color.
    func foregroundColor(for role: Foreground.Role, in environment: EnvironmentValues) -> Color {
        foreground(for: role, in: environment) == .white ? .white : .black
    }

    var title: String { self == .accent ? "Accent color" : rawValue.capitalized }

    /// The Settings picker's dot. The pop-up menu turns an SF Symbol into a template drawn in the text
    /// color, so this draws its own circle, and on every display so the accent color stays current.
    var swatch: NSImage {
        let fill = self == .accent ? NSColor.controlAccentColor : NSColor(color)
        let image = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
            fill.setFill()
            circle.fill()
            // Keeps yellow and gray visible on a light menu.
            NSColor.separatorColor.setStroke()
            circle.stroke()
            return true
        }
        image.cacheMode = .never
        return image
    }
}

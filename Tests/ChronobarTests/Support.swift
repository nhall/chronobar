import SwiftUI
import ChronobarCore

extension Color {
    /// The color as drawn over `backdrop`: resolved in `environment`, its opacity composited onto the
    /// backdrop, so a partly transparent color is measured as it shows.
    func srgb(in environment: EnvironmentValues, over backdrop: SRGB) -> SRGB {
        let c = resolve(in: environment)
        let a = Double(c.opacity)
        return SRGB(red: Double(c.red) * a + backdrop.red * (1 - a),
                    green: Double(c.green) * a + backdrop.green * (1 - a),
                    blue: Double(c.blue) * a + backdrop.blue * (1 - a))
    }
}

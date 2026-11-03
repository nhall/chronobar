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

    var title: String { self == .accent ? "Accent color" : rawValue.capitalized }
}

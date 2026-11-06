import SwiftUI
import ChronobarCore

/// The sizes only the Pill's drawing needs; its horizontal layout is in Core, shared with the click zones.
extension PillMetrics {
    static let height: CGFloat = 18
    static let cornerRadius: CGFloat = 4
}

/// The two-segment menu bar item: the ▶/⏸ square and today's Day total.
struct PillView: View {
    let tracker: Tracker
    let preferences: Preferences
    /// A development copy's mark (`BuildVariant.badge`), drawn after the time so two Pills side by side
    /// can be told apart. Nil for the everyday copy, whose Pill is unchanged.
    let badge: String?
    /// For the running color's light, dark or Increase Contrast variant, as the menu bar draws it.
    @Environment(\.self) private var environment

    var body: some View {
        let isRunning = !tracker.timers.isEmpty
        HStack(spacing: PillMetrics.gap) {
            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                .font(.system(size: 9, weight: .bold))
                // White on stopped gray; on the running color, whichever of white and black reads.
                .foregroundStyle(isRunning
                    ? preferences.runningColor.foregroundColor(in: environment) : .white)
                .frame(width: PillMetrics.squareWidth, height: PillMetrics.height)
                .background(
                    RoundedRectangle(cornerRadius: PillMetrics.cornerRadius)
                        .fill(isRunning ? preferences.runningColor.color : Color(nsColor: .systemGray)))
            Text(time)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .frame(height: PillMetrics.height)
                .background(timeBackground)
            if let badge {
                // Black on orange reads on a light or dark menu bar. It falls in the time segment's click
                // zone, which runs to the Pill's trailing edge, so a click on it opens the Panel.
                Text(badge)
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 3)
                    .frame(height: PillMetrics.height)
                    .background(RoundedRectangle(cornerRadius: PillMetrics.cornerRadius)
                        .fill(Color(nsColor: .systemOrange)))
            }
        }
        .padding(.horizontal, PillMetrics.inset)
        .fixedSize()
        // The status item's button carries the Pill's label and actions (`PillAccessibility`).
        .accessibilityHidden(true)
    }

    /// Follows Increase Contrast and Reduce Transparency (`PillTimeFill`).
    private var timeBackground: some View {
        let fill = PillTimeFill(increaseContrast: environment.colorSchemeContrast == .increased,
                                reduceTransparency: environment.accessibilityReduceTransparency)
        let shape = RoundedRectangle(cornerRadius: PillMetrics.cornerRadius)
        return shape
            .fill(Color(.sRGB, red: fill.color.red, green: fill.color.green, blue: fill.color.blue,
                        opacity: fill.opacity))
            .overlay(shape.strokeBorder(Color.white.opacity(fill.outlined ? 0.6 : 0), lineWidth: 1))
    }

    private var time: String { DurationFormat.hoursMinutes(tracker.dayTotal(tracker.today)) }
}

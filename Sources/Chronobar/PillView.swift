import SwiftUI
import ChronobarCore

/// The Pill's sizes in points.
enum PillMetrics {
    /// Space between the Pill and the edges of the status item.
    static let inset: CGFloat = 3
    static let squareWidth: CGFloat = 22
    static let gap: CGFloat = 2
    static let height: CGFloat = 18
    static let cornerRadius: CGFloat = 4
}

/// The two-segment menu bar item: the square, with the running count (0 on gray when nothing runs), and
/// today's Day total. It only shows; any click on it opens the Panel.
struct PillView: View {
    let tracker: Tracker
    let preferences: Preferences
    /// A development copy's mark (`BuildVariant.badge`), drawn after the time so two Pills side by side
    /// can be told apart. Nil for the everyday copy, whose Pill is unchanged.
    let badge: String?
    /// For the running color's or gray's light, dark or Increase Contrast variant, as the menu bar draws it.
    @Environment(\.self) private var environment

    var body: some View {
        let count = tracker.timers.count
        let isRunning = count > 0
        HStack(spacing: PillMetrics.gap) {
            // Shrinks rather than truncating should the count ever reach three digits.
            Text("\(count)")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.horizontal, 2)
                // Whichever of white and black reads on the running color, or on stopped gray.
                .foregroundStyle(isRunning ? preferences.runningColor.foregroundColor(in: environment)
                                           : StoppedSquare.foregroundColor(in: environment))
                .frame(width: PillMetrics.squareWidth, height: PillMetrics.height)
                .background(
                    RoundedRectangle(cornerRadius: PillMetrics.cornerRadius)
                        .fill(isRunning ? preferences.runningColor.color : StoppedSquare.color))
            Text(time)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .frame(height: PillMetrics.height)
                .background(timeBackground)
            if let badge {
                // Black on orange reads on a light or dark menu bar. Like the rest of the Pill, a click on it
                // opens the Panel.
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

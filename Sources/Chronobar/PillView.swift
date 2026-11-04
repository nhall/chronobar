import SwiftUI
import ChronobarCore

/// The two-segment menu bar item: the ▶/⏸ square and the Selected Project's time today.
struct PillView: View {
    let tracker: Tracker
    let preferences: Preferences

    var body: some View {
        let isRunning = tracker.running != nil
        HStack(spacing: PillMetrics.gap) {
            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: PillMetrics.squareWidth, height: PillMetrics.height)
                .background(
                    RoundedRectangle(cornerRadius: PillMetrics.cornerRadius)
                        .fill(isRunning ? preferences.runningColor.color : Color(nsColor: .systemGray)))
            Text(time)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .frame(height: PillMetrics.height)
                .background(
                    RoundedRectangle(cornerRadius: PillMetrics.cornerRadius)
                        .fill(Color(white: 0.18, opacity: 0.85)))
        }
        .padding(.horizontal, PillMetrics.inset)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isRunning ? "Running, \(time)" : "Stopped, \(time)")
    }

    private var time: String {
        guard let project = tracker.selectedProject else { return DurationFormat.hoursMinutes(0) }
        return DurationFormat.hoursMinutes(tracker.total(project, on: tracker.today))
    }
}

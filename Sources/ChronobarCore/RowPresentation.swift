import Foundation

/// How a Panel row shows whether its Project runs. The running color belongs to the Pill's square, so a
/// row never uses it: the running row has a quiet neutral highlight and ⏸ in the text color, and the
/// others are plain, with ▶ in the secondary text color.
public struct RowPresentation: Equatable, Sendable {
    /// The row's ▶/⏸.
    public enum Toggle: Equatable, Sendable {
        case start, pause
    }

    /// Which of the system's text colors something is drawn in.
    public enum Tone: Equatable, Sendable {
        case primary, secondary
    }

    /// Whether the row has the neutral highlight.
    public let isHighlighted: Bool
    public let toggle: Toggle
    public let toggleTone: Tone
    /// What VoiceOver reads for the name: the highlight says which row runs, this says it in words.
    public let nameLabel: String
    /// The ▶/⏸ button's label and help tag: "Start Website Redesign" or "Pause Website Redesign".
    public let toggleLabel: String
    /// The help tag of the terminal icon on a row whose timer an agent started; nil for no icon.
    public let agentMark: String?

    /// `source` is who started the row's running timer.
    public init(row: Row, isRunning: Bool, source: EntrySource = .app) {
        let byAgent = isRunning && source == .agent
        isHighlighted = isRunning
        toggle = isRunning ? .pause : .start
        toggleTone = isRunning ? .primary : .secondary
        nameLabel = isRunning ? "\(row.project), running\(byAgent ? ", started by an agent" : "")" : row.project
        toggleLabel = "\(TimerToggle.name(isRunning: isRunning)) \(row.project)"
        agentMark = byAgent ? "Started by an agent; not paused for idle time" : nil
    }
}

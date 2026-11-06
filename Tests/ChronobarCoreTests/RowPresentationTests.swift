import Foundation
import Testing
import ChronobarCore

/// How a Panel row shows whether it runs: a neutral highlight and ⏸ in the text color, never the
/// running color, and "running" in words for VoiceOver.
@Suite struct RowPresentationTests {
    let row = Row(project: "Orchard Rebuild", total: 83 * 60)

    @Test func theRunningRowIsHighlightedWithPauseInTheTextColor() {
        let presentation = RowPresentation(row: row, isRunning: true)
        #expect(presentation.isHighlighted)
        #expect(presentation.toggle == .pause)
        #expect(presentation.toggleTone == .primary)
    }

    @Test func aRowThatIsNotRunningIsPlainWithStartInTheSecondaryColor() {
        let presentation = RowPresentation(row: row, isRunning: false)
        #expect(!presentation.isHighlighted)
        #expect(presentation.toggle == .start)
        #expect(presentation.toggleTone == .secondary)
    }

    @Test func voiceOverReadsTheRunningRowAsRunning() {
        let presentation = RowPresentation(row: row, isRunning: true)
        #expect(presentation.nameLabel == "Orchard Rebuild, running")
        #expect(presentation.toggleLabel == "Pause Orchard Rebuild")
    }

    @Test func voiceOverReadsAnyOtherRowByName() {
        let presentation = RowPresentation(row: row, isRunning: false)
        #expect(presentation.nameLabel == "Orchard Rebuild")
        #expect(presentation.toggleLabel == "Start Orchard Rebuild")
    }

    @Test func aTimerAnAgentStartedIsMarkedWithWhyItIsNotPausedForIdleTime() {
        let presentation = RowPresentation(row: row, isRunning: true, source: .agent)
        #expect(presentation.agentMark == "Started by an agent; not paused for idle time")
        #expect(presentation.nameLabel == "Orchard Rebuild, running, started by an agent")
    }

    @Test func aTimerStartedInTheAppAndAStoppedRowHaveNoAgentMark() {
        #expect(RowPresentation(row: row, isRunning: true, source: .app).agentMark == nil)
        #expect(RowPresentation(row: row, isRunning: false).agentMark == nil)
    }
}

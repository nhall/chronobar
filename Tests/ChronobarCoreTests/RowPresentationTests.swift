import Foundation
import Testing
import ChronobarCore

/// How a Panel row shows whether it runs: a neutral highlight and ⏸ in the text color, never the
/// running color, and "running" in words for VoiceOver.
@Suite struct RowPresentationTests {
    let row = Row(project: "Orchard Rebuild", total: 83 * 60)

    @Test func theRunningRowIsHighlightedWithPauseInTheTextColor() {
        let presentation = RowPresentation(row: row, minutes: 83, isRunning: true)
        #expect(presentation.isHighlighted)
        #expect(presentation.toggle == .pause)
        #expect(presentation.toggleTone == .primary)
    }

    @Test func aRowThatIsNotRunningIsPlainWithStartInTheSecondaryColor() {
        let presentation = RowPresentation(row: row, minutes: 83, isRunning: false)
        #expect(!presentation.isHighlighted)
        #expect(presentation.toggle == .start)
        #expect(presentation.toggleTone == .secondary)
    }

    @Test func voiceOverReadsTheRunningRowAsRunning() {
        let presentation = RowPresentation(row: row, minutes: 83, isRunning: true)
        #expect(presentation.nameLabel == "Orchard Rebuild, running")
        #expect(presentation.toggleLabel == "Pause Orchard Rebuild")
    }

    @Test func voiceOverReadsAnyOtherRowByName() {
        let presentation = RowPresentation(row: row, minutes: 83, isRunning: false)
        #expect(presentation.nameLabel == "Orchard Rebuild")
        #expect(presentation.toggleLabel == "Start Orchard Rebuild")
    }

    @Test func aTimerAnAgentStartedIsMarkedWithWhyItIsNotPausedForIdleTime() {
        let presentation = RowPresentation(row: row, minutes: 83, isRunning: true, source: .agent)
        #expect(presentation.agentMark == "Started by an agent; not paused for idle time")
        #expect(presentation.nameLabel == "Orchard Rebuild, running, started by an agent")
    }

    @Test func aTimerStartedInTheAppAndAStoppedRowHaveNoAgentMark() {
        #expect(RowPresentation(row: row, minutes: 83, isRunning: true, source: .app).agentMark == nil)
        #expect(RowPresentation(row: row, minutes: 83, isRunning: false).agentMark == nil)
    }

    /// The row shows and reads the minutes it was given under the Total line (`RowMinutes`), which can be
    /// one more than its own time rounded down: 1:08:49 under Total 3:17 shows 1:09.
    @Test func theRowShowsAndReadsTheMinutesThatAddUpToTheTotal() {
        let presentation = RowPresentation(row: Row(project: "Two", total: 3600 + 8 * 60 + 49), minutes: 69,
                                           isRunning: false)
        #expect(presentation.total == "1:09")
        #expect(presentation.totalLabel == "Two total, 1 hour 9 minutes")
    }
}

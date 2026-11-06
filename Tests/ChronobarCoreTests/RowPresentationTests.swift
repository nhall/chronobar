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
}

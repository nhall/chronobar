import CoreGraphics
import Testing
import ChronobarCore

/// Where the Pill's cover goes: over the status item, up to the top of the screen, while the pointer is there.
@Suite struct PillCoverAreaTests {
    // A 1728 × 1117 screen with a 33-point menu bar; the status item is 94 × 22, 5 points below the top.
    let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    let visible = CGRect(x: 0, y: 0, width: 1728, height: 1084)
    let item = CGRect(x: 1186, y: 1089, width: 94, height: 22)

    @Test func coversTheStatusItemUpToTheTopOfTheScreenWithThePointerOnIt() {
        #expect(PillCoverArea.frame(item: item, screen: screen, visible: visible,
                                    pointer: CGPoint(x: 1231, y: 1100), commandKey: false)
            == CGRect(x: 1186, y: 1089, width: 94, height: 28))
    }

    /// A press at the very top of the screen is still on the Pill.
    @Test func coversThePointerAtTheTopEdge() {
        #expect(PillCoverArea.frame(item: item, screen: screen, visible: visible,
                                    pointer: CGPoint(x: 1190, y: 1117), commandKey: false) != nil)
    }

    @Test func isAwayWithThePointerOffTheStatusItem() {
        for pointer in [CGPoint(x: 1185, y: 1100), CGPoint(x: 1280, y: 1100), CGPoint(x: 1231, y: 1088),
                        CGPoint(x: 600, y: 500)] {
            #expect(PillCoverArea.frame(item: item, screen: screen, visible: visible, pointer: pointer,
                                        commandKey: false) == nil)
        }
    }

    /// ⌘-drag moves the status item, which the menu bar does; the cover would stop it.
    @Test func isAwayWhileCommandIsHeld() {
        #expect(PillCoverArea.frame(item: item, screen: screen, visible: visible,
                                    pointer: CGPoint(x: 1231, y: 1100), commandKey: true) == nil)
    }

    /// With the menu bar hidden, the screen's visible area reaches its top, and what is under the status
    /// item's place belongs to other windows.
    @Test func isAwayWhenTheMenuBarIsHidden() {
        #expect(PillCoverArea.frame(item: item, screen: screen, visible: screen,
                                    pointer: CGPoint(x: 1231, y: 1100), commandKey: false) == nil)
    }
}

import CoreGraphics
import Testing
import ChronobarCore

/// Where the Pill's cover goes: over the status item, up to the top of the screen, while the pointer is there
/// and the menu bar is shown.
@Suite struct PillCoverAreaTests {
    // A 1728 × 1117 screen with a 33-point menu bar; the status item is 94 × 22, 5 points below the top.
    let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    let menuBar = CGRect(x: 0, y: 1084, width: 1728, height: 33)
    let item = CGRect(x: 1186, y: 1089, width: 94, height: 22)
    let onItem = CGPoint(x: 1231, y: 1100)

    private func placement(item: CGRect? = nil, screen: CGRect? = nil, pointer: CGPoint, commandKey: Bool = false,
                           pressHeld: Bool = false, menuBars: [CGRect]? = nil) -> PillCoverArea.Placement {
        PillCoverArea.placement(item: item ?? self.item, screen: screen ?? self.screen, pointer: pointer,
                                commandKey: commandKey, pressHeld: pressHeld, menuBars: menuBars ?? [menuBar])
    }

    @Test func coversTheStatusItemUpToTheTopOfTheScreenWithThePointerOnIt() {
        #expect(placement(pointer: onItem) == .cover(CGRect(x: 1186, y: 1089, width: 94, height: 28)))
    }

    /// A press at the very top of the screen is still on the Pill.
    @Test func coversThePointerAtTheTopEdge() {
        #expect(placement(pointer: CGPoint(x: 1190, y: 1117)) != .away)
    }

    /// A press released at the very top of the screen, where the pointer stops when flung up, is a release
    /// on the Pill; so is one on its left edge, but not one just past its right edge.
    @Test func aReleaseAtTheTopEdgeIsOnTheCover() {
        let cover = CGRect(x: 0, y: 0, width: 94, height: 27.5)
        #expect(PillCoverArea.isOn(cover, CGPoint(x: 50, y: 27.5)))
        #expect(PillCoverArea.isOn(cover, CGPoint(x: 0, y: 10)))
        #expect(!PillCoverArea.isOn(cover, CGPoint(x: 94, y: 10)))
        #expect(!PillCoverArea.isOn(cover, CGPoint(x: 50, y: -1)))
    }

    @Test func isAwayWithThePointerOffTheStatusItem() {
        for pointer in [CGPoint(x: 1185, y: 1100), CGPoint(x: 1280, y: 1100), CGPoint(x: 1231, y: 1088),
                        CGPoint(x: 600, y: 500)] {
            #expect(placement(pointer: pointer) == .away)
        }
    }

    /// ⌘-drag moves the status item, which the menu bar does; the cover would stop it.
    @Test func isAwayWhileCommandIsHeld() {
        #expect(placement(pointer: onItem, commandKey: true) == .away)
    }

    /// With the menu bar auto-hidden, the status item keeps its place while the menu bar is away, and what
    /// is there belongs to other windows. The menu bar slides in when the pointer reaches the top of the
    /// screen, so the cover waits for it.
    @Test func waitsForAHiddenMenuBarToSlideIn() {
        let hidden = CGRect(x: 0, y: 1117, width: 1728, height: 33)
        #expect(placement(pointer: onItem, menuBars: []) == .awaitingMenuBar)
        #expect(placement(pointer: CGPoint(x: 1190, y: 1117), menuBars: [hidden]) == .awaitingMenuBar)
    }

    /// Halfway through sliding in, the menu bar isn't under the status item yet.
    @Test func waitsForAMenuBarStillSlidingIn() {
        let sliding = CGRect(x: 0, y: 1103, width: 1728, height: 33)
        #expect(placement(pointer: onItem, menuBars: [sliding]) == .awaitingMenuBar)
    }

    /// Without the pointer on the status item there is nothing to wait for.
    @Test func isAwayWithAHiddenMenuBarAndThePointerElsewhere() {
        #expect(placement(pointer: CGPoint(x: 600, y: 500), menuBars: []) == .away)
    }

    /// Only the status item's own screen's menu bar counts: another display's shown menu bar says nothing
    /// about this one.
    @Test func ignoresAnotherDisplaysMenuBar() {
        let otherDisplays = CGRect(x: 1728, y: 1084, width: 1920, height: 33)
        #expect(placement(pointer: onItem, menuBars: [otherDisplays]) == .awaitingMenuBar)
    }

    /// On a display other than the main one, the cover goes over the status item there and reaches that
    /// display's top, not the main display's.
    @Test func coversTheStatusItemOnASecondDisplay() {
        let second = CGRect(x: -1920, y: 1117, width: 1920, height: 1080)
        let secondItem = CGRect(x: -500, y: 2170, width: 94, height: 22)
        let secondMenuBar = CGRect(x: -1920, y: 2164, width: 1920, height: 33)
        #expect(placement(item: secondItem, screen: second, pointer: CGPoint(x: -450, y: 2180),
                          menuBars: [menuBar, secondMenuBar])
            == .cover(CGRect(x: -500, y: 2170, width: 94, height: 27)))
    }

    /// A press already under way that the cover didn't take stays with whatever took it, so the cover
    /// doesn't go up under a held button. A cover already up stays.
    @Test func doesNotGoUpDuringAPressItDidNotTake() {
        #expect(placement(pointer: onItem, pressHeld: true) == .away)
    }

    /// The window list gives the menu bar as the window server's window at the main menu level, in
    /// coordinates with y down from the main display's top. An auto-hidden menu bar stays in the list, off
    /// screen and above the top.
    @Test func readsTheMenuBarsOnScreenFromTheWindowList() {
        func window(owner: String, layer: Int, onScreen: Bool, bounds: CGRect) -> [String: Any] {
            [kCGWindowOwnerName as String: owner, kCGWindowLayer as String: layer,
             kCGWindowIsOnscreen as String: onScreen, kCGWindowBounds as String: bounds.dictionaryRepresentation]
        }
        let windows = [
            window(owner: "Window Server", layer: 24, onScreen: true, bounds: CGRect(x: 0, y: 0, width: 1728, height: 33)),
            window(owner: "Window Server", layer: 24, onScreen: false, bounds: CGRect(x: 0, y: -33, width: 1728, height: 33)),
            window(owner: "Window Server", layer: 24, onScreen: true,
                   bounds: CGRect(x: -1920, y: -1080, width: 1920, height: 33)),
            window(owner: "Some App", layer: 24, onScreen: true, bounds: CGRect(x: 0, y: 0, width: 400, height: 33)),
            window(owner: "Window Server", layer: 25, onScreen: true, bounds: CGRect(x: 0, y: 0, width: 1728, height: 33)),
            [kCGWindowOwnerName as String: "Window Server", kCGWindowLayer as String: 24],
        ]
        #expect(PillCoverArea.menuBars(in: windows, mainDisplayHeight: 1117)
            == [CGRect(x: 0, y: 1084, width: 1728, height: 33), CGRect(x: -1920, y: 2164, width: 1920, height: 33)])
    }

    /// Whether the menu bar is shown is only worked out with the pointer on the status item, so following
    /// the pointer elsewhere costs nothing.
    @Test func looksForTheMenuBarOnlyWithThePointerOnTheStatusItem() {
        var looked = false
        func menuBars() -> [CGRect] { looked = true; return [] }
        _ = PillCoverArea.placement(item: item, screen: screen, pointer: CGPoint(x: 600, y: 500),
                                    commandKey: false, pressHeld: false, menuBars: menuBars())
        #expect(!looked)
    }
}

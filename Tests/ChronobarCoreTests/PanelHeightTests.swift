import CoreGraphics
import Testing
import ChronobarCore

/// How tall the Panel can be under the Pill, and how much of that its rows get before they scroll.
@Suite struct PanelHeightTests {
    // A 1728 × 1117 screen with a 33-point menu bar and no Dock at the bottom; the Pill is 94 × 22,
    // 5 points below the top.
    let visible = CGRect(x: 0, y: 0, width: 1728, height: 1084)
    let pill = CGRect(x: 1186, y: 1089, width: 94, height: 22)

    /// From the Pill's bottom down to the bottom of the screen's visible area, less the popover's own frame
    /// and arrow around the content and a margin above the screen's edge.
    @Test func roomIsFromThePillDownToTheVisibleBottomLessTheChromeAndMargin() {
        #expect(PanelHeight.available(under: pill, visible: visible, chrome: 13) == 1089 - 13 - 8)
    }

    /// A Dock at the bottom raises the visible area's bottom edge.
    @Test func theDockTakesItsShareOfTheRoom() {
        let aboveDock = CGRect(x: 0, y: 70, width: 1728, height: 1014)

        #expect(PanelHeight.available(under: pill, visible: aboveDock, chrome: 13) == 1089 - 70 - 13 - 8)
    }

    /// A smaller external display to the right of the built-in one, its top lower: the room is that
    /// screen's, measured from the Pill on it.
    @Test func roomIsWorkedOutOnTheScreenThePillIsOn() {
        let external = CGRect(x: 1728, y: 0, width: 1280, height: 777)
        let pillThere = CGRect(x: 2700, y: 778, width: 94, height: 22)

        #expect(PanelHeight.available(under: pillThere, visible: external, chrome: 13) == 778 - 13 - 8)
    }

    /// With the menu bar hidden the Pill shows over the visible area; the room still starts at its bottom.
    @Test func roomStartsAtThePillWithTheMenuBarHidden() {
        let whole = CGRect(x: 0, y: 0, width: 1728, height: 1117)

        #expect(PanelHeight.available(under: pill, visible: whole, chrome: 13) == 1089 - 13 - 8)
    }

    /// Rows that fit keep their own height, and nothing scrolls: the Panel is as tall as it was before the cap.
    @Test func rowsThatFitKeepTheirHeight() {
        let rows = PanelHeight.rows(natural: 300, rest: 400, available: 1068)

        #expect(rows == 300)
    }

    @Test func rowsThatExactlyFillTheRoomDontScroll() {
        #expect(PanelHeight.rows(natural: 668, rest: 400, available: 1068) == 668)
    }

    /// Past the room, the rows get what the header, the Week strip and ＋ leave, and scroll.
    @Test func rowsPastTheRoomGetWhatTheRestLeavesAndScroll() {
        let rows = PanelHeight.rows(natural: 2000, rest: 400, available: 1068)

        #expect(rows == 668)
    }

    /// The open ＋ form takes from the rows, not from the bottom of the Panel.
    @Test func theOpenFormTakesFromTheRows() {
        #expect(PanelHeight.rows(natural: 2000, rest: 480, available: 1068) == 588)
    }

    /// On a screen too short for the rest, the rows still show a couple of rows rather than vanishing.
    @Test func rowsKeepAFewRowsOnAVeryShortScreen() {
        let rows = PanelHeight.rows(natural: 2000, rest: 400, available: 380)

        #expect(rows == PanelHeight.minimumRows)
    }

    /// The popover's window is 26 points taller than the Panel in it (its arrow, frame and shadow), and its
    /// top sits at the Pill's bottom snapped down to a whole point: half a point more under a Pill at 1089.5.
    @Test func chromeIsTheWindowAroundThePanelPlusTheSnapUnderThePill() {
        #expect(PanelHeight.chrome(window: 1081, panel: 1055, pillBottom: 1089.5) == 27)
        #expect(PanelHeight.chrome(window: 1081, panel: 1055, pillBottom: 1089) == 26)
    }

    /// A popover too tall for the screen is squeezed onto it and moved off the Pill, Panel and all, but its
    /// frame around the Panel stays the same, so the measure doesn't depend on where the system put it.
    @Test func chromeIsTheSameWhenTheSystemSqueezedThePopover() {
        #expect(PanelHeight.chrome(window: 1084, panel: 1058, pillBottom: 1089.5) == 27)
    }

    /// A window not yet laid out round its Panel, or one far bigger than any popover's frame, is refused.
    @Test(arguments: [(1055.0, 1055.0), (1000, 1055), (0, 0), (1300, 1055)])
    func implausibleChromeIsRefused(window: Double, panel: Double) {
        #expect(PanelHeight.chrome(window: window, panel: panel, pillBottom: 1089.5) == nil)
    }

    @Test func fewRowsOnAVeryShortScreenKeepTheirHeight() {
        #expect(PanelHeight.rows(natural: 30, rest: 400, available: 380) == 30)
    }
}

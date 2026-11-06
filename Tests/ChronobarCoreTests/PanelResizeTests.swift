import Testing
import ChronobarCore

/// The Panel's height as it grows or shrinks to fit its content, such as the ＋ form opening.
@Suite struct PanelResizeTests {
    @Test func startsAtTheOldHeightAndEndsExactlyAtTheNewOne() {
        let resize = PanelResize(from: 582, to: 616, reduceMotion: false)

        #expect(resize.height(after: 0) == 582)
        #expect(resize.height(after: PanelResize.duration) == 616)
        #expect(resize.height(after: PanelResize.duration + 1) == 616)
        #expect(!resize.isFinished(after: 0))
        #expect(resize.isFinished(after: PanelResize.duration))
    }

    /// Quick at first, then settling, and always between the two heights: the Panel's edge never passes
    /// where it is going, so nothing under it is uncovered and covered again.
    @Test(arguments: [(582.0, 616.0), (616.0, 582.0)])
    func easesOutWithoutOvershooting(from: Double, to: Double) {
        let resize = PanelResize(from: from, to: to, reduceMotion: false)
        let halfway = resize.height(after: PanelResize.duration / 2)

        #expect(abs(halfway - from) > abs(to - from) / 2)
        for step in 0...20 {
            let height = resize.height(after: PanelResize.duration * Double(step) / 20)
            #expect(height >= min(from, to) && height <= max(from, to))
        }
    }

    @Test func reduceMotionTakesTheNewHeightAtOnce() {
        let resize = PanelResize(from: 616, to: 582, reduceMotion: true)

        #expect(resize.height(after: 0) == 582)
        #expect(resize.isFinished(after: 0))
    }
}

import AppKit
import SwiftUI
import ChronobarCore

/// Hosts the Panel's content in its popover and keeps the popover's height fitted to it. The Panel opens
/// at its final height (`fitBeforeShowing`); while it is open a change of height, as when the ＋ form
/// opens or closes, is stepped a frame at a time (`PanelResize`), as NSPopover takes a new `contentSize`
/// in one step. The content stays pinned to the top while the popover catches up with it.
@MainActor
final class PanelSizer {
    private let popover: NSPopover
    private var host: NSView?
    private var timer: Timer?

    init<Content: View>(popover: NSPopover, content: Content) {
        self.popover = popover
        // Not `.preferredContentSize`, or Auto Layout constraints from the content, which resize the popover
        // in one step.
        let host = NSHostingView(rootView: content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGSize.self, of: \.size) { [weak self] size in self?.fit(size) }
            .frame(minHeight: 0, maxHeight: .infinity, alignment: .top))
        host.sizingOptions = []
        host.frame = NSRect(x: 0, y: 0, width: PanelView.width, height: 0)
        self.host = host
        let controller = NSViewController()
        controller.view = host
        popover.contentViewController = controller
    }

    /// Sizes the closed popover to its content as it is now, so the Panel opens at its final height. Changes
    /// made just before it shows (the ＋ form opened from the Pill, rows re-read from disk) and the first
    /// opening would otherwise only be laid out once it is open, and then animate. Laying the content out
    /// here reports its size (`fit`) at once, while the popover is still closed.
    func fitBeforeShowing() {
        guard let host, !popover.isShown else { return }
        host.layoutSubtreeIfNeeded()
    }

    /// Fits the popover to `size`: at once while it is closed, else a frame at a time.
    private func fit(_ size: CGSize) {
        let target = CGSize(width: ceil(size.width), height: ceil(size.height))
        timer?.invalidate()
        timer = nil
        guard target != popover.contentSize else { return }
        guard popover.isShown, popover.contentSize.width == target.width else {
            popover.contentSize = target
            return
        }
        let resize = PanelResize(from: popover.contentSize.height, to: target.height,
                                 reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        let began = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] timer in
            let elapsed = CACurrentMediaTime() - began
            if resize.isFinished(after: elapsed) { timer.invalidate() }
            MainActor.assumeIsolated {
                // Whole points, so the popover's edge doesn't wobble a point between steps.
                self?.popover.contentSize = CGSize(width: target.width,
                                                   height: resize.height(after: elapsed).rounded())
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        timer.fire()
    }
}

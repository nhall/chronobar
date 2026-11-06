import AppKit
import ChronobarCore

extension NSApplication {
    /// Brings the app to the front, taking over from the app in front where there is one (`Activation`),
    /// for whenever the app must really be active: the Panel, the idle alert, Settings after leaving the
    /// Dock. If macOS turns that down too, the app asks plainly.
    @MainActor
    func comeToFront() {
        let current = NSRunningApplication.current
        let frontmost = NSWorkspace.shared.frontmostApplication
        switch Activation.request(frontmost: frontmost?.processIdentifier, current: current.processIdentifier) {
        case .takeOver:
            if let frontmost, current.activate(from: frontmost, options: []) { return }
        case .plain:
            break
        }
        activate()
    }
}

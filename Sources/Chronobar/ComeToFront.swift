import AppKit
import ChronobarCore

extension NSApplication {
    /// Brings the app to the front, taking over from the app in front where there is one (`Activation`),
    /// for whenever the app must really be active: the Panel, the idle alert, Settings after leaving the
    /// Dock. If macOS turns that down too, the app asks plainly.
    @MainActor
    func comeToFront() {
        let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        switch Activation.request(frontmost: frontmost, current: NSRunningApplication.current.processIdentifier) {
        case .takeOver(let pid):
            // The app in front never calls `yieldActivation(to:)`; this relies on macOS letting the take-over
            // through without it, as it does on macOS 27. If a later macOS stops that, the plain request
            // below is all that is left.
            if let app = NSRunningApplication(processIdentifier: pid),
               NSRunningApplication.current.activate(from: app, options: []) { return }
        case .plain:
            break
        }
        activate()
    }
}

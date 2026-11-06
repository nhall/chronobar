import AppKit
import ServiceManagement

/// Start at login, via `SMAppService.mainApp`. The system owns the state, so it is read back rather than
/// stored: the user can also remove the login item in System Settings.
@MainActor @Observable
final class LoginItem {
    private(set) var status = SMAppService.mainApp.status

    /// On, or waiting for the user's approval in System Settings.
    var isOn: Bool { status == .enabled || status == .requiresApproval }

    func refresh() { status = SMAppService.mainApp.status }

    /// Called at launch. Registering again points the login item at this copy of the app, as
    /// `brew upgrade` deletes the versioned folder (and signature) it was registered from.
    func renew() {
        guard isOn else { return }
        do {
            try SMAppService.mainApp.register()
        } catch {
            reportFailure(error, category: "login", beep: false)
        }
        refresh()
    }

    func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            reportFailure(error, category: "login")
        }
        refresh()
    }
}

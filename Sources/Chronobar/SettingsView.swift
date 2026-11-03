import SwiftUI
import ServiceManagement
import ChronobarCore
import os

extension RunningColor {
    var color: Color {
        switch self {
        case .accent: .accentColor
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .gray: .gray
        }
    }

    var title: String { self == .accent ? "Accent color" : rawValue.capitalized }
}

/// Start at login, via `SMAppService.mainApp`. The system owns the state, so it is read back rather than
/// stored: the user can also remove the login item in System Settings.
@MainActor @Observable
final class LoginItem {
    private(set) var status = SMAppService.mainApp.status

    /// On, or waiting for the user's approval in System Settings.
    var isOn: Bool { status == .enabled || status == .requiresApproval }

    func refresh() { status = SMAppService.mainApp.status }

    func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            Logger(subsystem: "Chronobar", category: "login").error("\(error, privacy: .public)")
            NSSound.beep()
        }
        refresh()
    }
}

/// The standard Settings window (⌘,).
struct SettingsView: View {
    @Bindable var preferences: Preferences
    let loginItem: LoginItem

    var body: some View {
        Form {
            Picker("Running color", selection: $preferences.runningColor) {
                ForEach(RunningColor.allCases, id: \.self) { color in
                    Label {
                        Text(color.title)
                    } icon: {
                        Image(systemName: "circle.fill").foregroundStyle(color.color)
                    }
                    .tag(color)
                }
            }
            Toggle("Show in Dock", isOn: $preferences.showInDock)
            Toggle("Start at login", isOn: Binding(get: { loginItem.isOn }, set: { loginItem.set($0) }))
            if loginItem.status == .requiresApproval {
                HStack {
                    Text("Allow Chronobar in Login Items to finish turning this on.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                        .controlSize(.small)
                }
            }
            Toggle("Detect idle keyboard and mouse", isOn: $preferences.detectsInputIdle)
            Stepper("Idle after \(preferences.idleThresholdMinutes) min without input",
                    value: $preferences.idleThresholdMinutes, in: 1...480)
                .disabled(!preferences.detectsInputIdle)
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .fixedSize()
        .onAppear { loginItem.refresh() }
    }
}

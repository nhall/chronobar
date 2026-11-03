import SwiftUI
import ServiceManagement
import ChronobarCore
import KeyboardShortcuts

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
            KeyboardShortcuts.Recorder("Play/pause shortcut", name: .toggleTimer)
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

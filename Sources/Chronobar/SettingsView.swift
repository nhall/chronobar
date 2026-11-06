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
                        Image(nsImage: color.swatch)
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
            Picker("Idle after no input for", selection: $preferences.idleThreshold) {
                ForEach(IdleThreshold.presets, id: \.self) { threshold in
                    Text(threshold.minutes.map { "\($0) minutes" } ?? "Off").tag(threshold)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .fixedSize()
        .onAppear { loginItem.refresh() }
    }
}

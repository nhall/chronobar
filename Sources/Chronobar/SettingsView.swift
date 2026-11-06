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
            Toggle("Starting a timer pauses the others", isOn: $preferences.startPausesOthers)
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
            Picker(selection: $preferences.idleThreshold) {
                ForEach(IdleThreshold.presets, id: \.self) { threshold in
                    Text(threshold.minutes.map { "\($0) minutes" } ?? "Off").tag(threshold)
                }
            } label: {
                Text("Idle after no input for")
                // A grouped Form shows a label's second Text as its subtitle.
                Text("Applies to timers started in the app. Agents' timers keep running.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .fixedSize()
        .onAppear { loginItem.refresh() }
    }
}

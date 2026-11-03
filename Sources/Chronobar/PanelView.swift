import SwiftUI
import ChronobarCore

/// The Panel's view state, including what the Pill drives (opening straight into the ＋ form).
/// View state lives here rather than in `@State`, which needs a macro plugin that ships only with Xcode.
@MainActor @Observable
final class PanelModel {
    var showingNewProject = false {
        didSet { if !showingNewProject { newProjectName = "" } }
    }
    var newProjectName = ""
}

/// The popover under the Pill.
struct PanelView: View {
    let tracker: Tracker
    @Bindable var panel: PanelModel
    let start: (String) -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today").font(.headline)
                Spacer()
                Button {
                    panel.showingNewProject.toggle()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Start a Project")
            }
            if panel.showingNewProject {
                NewProjectForm(name: $panel.newProjectName) { project in
                    start(project)
                    panel.showingNewProject = false
                    close()
                }
            } else if let project = tracker.selectedProject {
                HStack {
                    Text(project)
                    Spacer()
                    Text(DurationFormat.hoursMinutes(tracker.total(project, on: tracker.today)))
                        .monospacedDigit()
                }
            } else {
                Text("No time tracked").foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 280)
    }
}

/// The ＋ form: a Project name and Start.
private struct NewProjectForm: View {
    @Binding var name: String
    let start: (String) -> Void
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            TextField("Project", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(submit)
            Button("Start", action: submit)
                .keyboardShortcut(.defaultAction)
                .disabled(trimmed.isEmpty)
        }
        .onAppear { focused = true }
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func submit() {
        guard !trimmed.isEmpty else { return }
        start(trimmed)
    }
}

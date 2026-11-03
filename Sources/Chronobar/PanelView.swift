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
    let archive: (String) -> Void
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
                NewProjectForm(
                    name: $panel.newProjectName,
                    suggestions: tracker.suggestions(for: panel.newProjectName),
                    start: { project in
                        start(project)
                        panel.showingNewProject = false
                        close()
                    },
                    archive: archive)
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

/// The ＋ form: a Project name and Start, with the matching Projects listed below the field.
/// Clicking a suggestion starts it; right-clicking offers Archive. A new name creates a Project.
private struct NewProjectForm: View {
    @Binding var name: String
    let suggestions: [String]
    let start: (String) -> Void
    let archive: (String) -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Project", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit(submit)
                Button("Start", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty)
            }
            if !suggestions.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestions, id: \.self) { project in
                            Button {
                                start(project)
                            } label: {
                                Text(project)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 3)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Archive") { archive(project) }
                            }
                        }
                    }
                }
                .frame(maxHeight: 160)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { focused = true }
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func submit() {
        guard !trimmed.isEmpty else { return }
        start(trimmed)
    }
}

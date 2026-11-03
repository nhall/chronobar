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
    let pause: () -> Void
    let close: () -> Void
    let openDataFolder: () -> Void

    var body: some View {
        let day = tracker.today
        let rows = tracker.rows(day)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today").font(.headline)
                Spacer()
                Text(DurationFormat.hoursMinutes(tracker.dayTotal(day)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .help("Total today")
                Button {
                    panel.showingNewProject.toggle()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Start a Project")
                Menu {
                    Button("Open data folder", action: openDataFolder)
                } label: {
                    Image(systemName: "gearshape")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            if tracker.isMalformed(day) {
                Label("This Day's file can't be read, so changes to it are refused. Fix it by hand in the data folder.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if panel.showingNewProject {
                NewProjectForm(name: $panel.newProjectName) { project in
                    start(project)
                    panel.showingNewProject = false
                    close()
                }
            }
            if rows.isEmpty {
                Text("No time tracked").foregroundStyle(.secondary)
            } else {
                VStack(spacing: 2) {
                    ForEach(rows, id: \.project) { row in
                        RowView(row: row, isRunning: tracker.running?.project == row.project,
                                start: { start(row.project) }, pause: pause)
                    }
                }
            }
        }
        .padding()
        .frame(width: 280)
    }
}

/// One Project's total today, with ▶ to switch to it, or a clock that pauses it while it runs.
private struct RowView: View {
    let row: Row
    let isRunning: Bool
    let start: () -> Void
    let pause: () -> Void

    var body: some View {
        HStack {
            Button(action: isRunning ? pause : start) {
                Image(systemName: isRunning ? "clock.fill" : "play.fill")
                    .frame(width: 16)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(isRunning ? Color.white : Color.secondary)
            .help(isRunning ? "Pause" : "Start \(row.project)")
            Text(row.project).lineLimit(1)
            Spacer()
            Text(DurationFormat.hoursMinutes(row.total)).monospacedDigit()
        }
        .foregroundStyle(isRunning ? Color.white : Color.primary)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isRunning ? Color.accentColor : Color.clear))
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

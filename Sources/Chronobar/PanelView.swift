import SwiftUI
import ChronobarCore

/// The Panel's view state, including what the Pill drives (opening straight into the ＋ form).
/// View state lives here rather than in `@State`, which needs a macro plugin that ships only with Xcode.
@MainActor @Observable
final class PanelModel {
    var showingNewProject = false {
        didSet {
            if !showingNewProject {
                newProjectName = ""
                newProjectDuration = ""
                newProjectListOpen = false
            }
        }
    }
    var newProjectName = ""
    /// Bumped to put focus in the ＋ form's Project field once the Panel's window can take it: the form's
    /// own focus on appearing is lost when the Panel opens straight into it.
    var newProjectFocusRequests = 0
    /// Whether the ＋ form's Project list is showing, which takes Return from the Start/Log button.
    var newProjectListOpen = false
    /// The ＋ form's duration; empty starts a timer, anything else logs that much time.
    var newProjectDuration = ""
    /// The Day the Panel shows; nil follows today, including across midnight.
    var viewedDay: Day? {
        didSet { adjusting = nil }
    }
    var showingSummary = false
    /// The Project whose row's time is being typed over, and what has been typed.
    var adjusting: String? {
        didSet { adjustment = "" }
    }
    var adjustment = ""
}

/// What the Panel asks the app to do.
struct PanelActions {
    let start: (String) -> Void
    /// A row's ▶/⏸: starts the Project, or pauses it while it runs.
    let toggle: (String) -> Void
    /// Log and adjust return false when the input was refused, so the field keeps what was typed.
    let log: (_ project: String, _ duration: String, _ day: Day) -> Bool
    let adjust: (_ project: String, _ input: String, _ day: Day) -> Bool
    let archive: (String) -> Void
    let openDataFolder: () -> Void
    let quit: () -> Void
}

/// The popover under the Pill.
struct PanelView: View {
    let tracker: Tracker
    @Bindable var panel: PanelModel
    let preferences: Preferences
    let loginItem: LoginItem
    let actions: PanelActions

    var body: some View {
        let today = tracker.today
        let day = panel.viewedDay ?? today
        let isToday = day == today
        let rows = tracker.rows(day)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: showToday) {
                    // Room around the text for the focus ring Tab gives it, which otherwise sits on the
                    // glyphs; the negative padding keeps the text aligned with the content below.
                    Text(title(day, isToday: isToday)).font(.headline)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .fixedSize()
                .padding(.horizontal, -4)
                .help(isToday ? "" : "Back to today")
                Spacer()
                Text(DurationFormat.hoursMinutes(tracker.dayTotal(day)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .help("Total for the day")
                Button {
                    panel.showingSummary.toggle()
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                .help("Time Summary")
                .popover(isPresented: $panel.showingSummary, arrowEdge: .bottom) {
                    SummaryView(summary: tracker.summary())
                }
                Button {
                    panel.showingNewProject.toggle()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help(isToday ? "Start or log time" : "Log time")
                Menu {
                    SettingsLink { Text("Settings…") }
                        .keyboardShortcut(",", modifiers: .command)
                    Button("Open data folder", action: actions.openDataFolder)
                    Divider()
                    Button("Quit Chronobar", action: actions.quit)
                        .keyboardShortcut("q", modifiers: .command)
                } label: {
                    Image(systemName: "gearshape")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Settings, data folder and Quit")
            }
            if tracker.isMalformed(day) {
                Label("This Day's file can't be read, so changes to it are refused. Fix it by hand in the data folder.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !preferences.loginHintDismissed && !loginItem.isOn {
                LoginHint(
                    turnOn: {
                        loginItem.set(true)
                        preferences.loginHintDismissed = true
                    },
                    dismiss: { preferences.loginHintDismissed = true })
            }
            WeekStrip(week: tracker.weekTotals(containing: day), today: today, viewed: day,
                      calendar: tracker.calendar, runningColor: preferences.runningColor.color,
                      view: { show($0, today: today) },
                      move: { show(day.adding(days: 7 * $0, in: tracker.calendar), today: today) })
            // Under the strip, as the title row has no room for it at the Panel's width and above the
            // strip it would push ‹ › away from the pointer.
            if !isToday {
                HStack {
                    Spacer()
                    Button("Today", action: showToday)
                        .controlSize(.small)
                        .help("Back to today")
                }
            }
            if panel.showingNewProject {
                NewProjectForm(
                    name: $panel.newProjectName,
                    duration: $panel.newProjectDuration,
                    isListOpen: $panel.newProjectListOpen,
                    focusRequests: panel.newProjectFocusRequests,
                    canStart: isToday,
                    suggestions: tracker.suggestions(for:),
                    match: tracker.match(panel.newProjectName),
                    // Start and Log go back to the rows and leave the Panel open.
                    start: { project in
                        actions.start(project)
                        panel.showingNewProject = false
                    },
                    log: { project in
                        if actions.log(project, panel.newProjectDuration, day) { panel.showingNewProject = false }
                    },
                    // The field empties, so Return can't bring the Project straight back.
                    archive: { project in
                        actions.archive(project)
                        panel.newProjectName = ""
                        panel.newProjectFocusRequests += 1
                    })
            }
            if rows.isEmpty {
                Text("No time tracked").foregroundStyle(.secondary)
            } else {
                VStack(spacing: 2) {
                    ForEach(rows, id: \.project) { row in
                        // Only today's rows run or have ▶/⏸; any other Day's rows are just totals.
                        RowView(row: row, isRunning: isToday && tracker.isRunning(row.project),
                                canStart: isToday, runningColor: preferences.runningColor.color,
                                panel: panel,
                                toggle: { actions.toggle(row.project) },
                                adjust: {
                                    if actions.adjust(row.project, panel.adjustment, day) { panel.adjusting = nil }
                                })
                    }
                }
            }
        }
        .padding()
        .frame(width: 300)
    }

    /// "Today, 03 Nov" or "Wednesday, 28 Oct", in the system locale.
    private func title(_ day: Day, isToday: Bool) -> String {
        let date = day.noon(in: tracker.calendar)
        let style = Date.FormatStyle(locale: .autoupdatingCurrent, calendar: tracker.calendar,
                                     timeZone: tracker.calendar.timeZone)
        if isToday {
            return "Today, " + date.formatted(style.day(.twoDigits).month(.abbreviated))
        }
        return date.formatted(style.weekday(.wide).day(.twoDigits).month(.abbreviated))
    }

    /// Today's rows and the week containing it, for the date header and the Today button alike.
    private func showToday() {
        panel.viewedDay = nil
    }

    /// Views `day`, past or future; today itself goes back to following the clock.
    private func show(_ day: Day, today: Day) {
        panel.viewedDay = day == today ? nil : day
    }
}

/// Seven Days with their totals, ‹ › to move a week back or forward without limit. Today has a filled
/// running-color circle, the viewed Day a gray one.
private struct WeekStrip: View {
    let week: [DayTotal]
    let today: Day
    let viewed: Day
    let calendar: Calendar
    let runningColor: Color
    let view: (Day) -> Void
    let move: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button { move(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.borderless)
                .help("Previous week")
            ForEach(week, id: \.day) { item in
                Button { view(item.day) } label: { column(item) }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
            }
            Button { move(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.borderless)
                .help("Next week")
        }
    }

    private func column(_ item: DayTotal) -> some View {
        let date = item.day.noon(in: calendar)
        let style = Date.FormatStyle(locale: .autoupdatingCurrent, calendar: calendar, timeZone: calendar.timeZone)
        let isToday = item.day == today
        let isViewed = item.day == viewed
        return VStack(spacing: 2) {
            Text(date.formatted(style.weekday(.narrow)))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(date.formatted(style.day()))
                .font(.callout.monospacedDigit())
                .foregroundStyle(isToday ? Color.white : Color.primary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(
                    isToday ? runningColor : isViewed ? Color.gray.opacity(0.35) : Color.clear))
            Text(DurationFormat.hoursMinutes(item.total))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

/// The (i) Time Summary.
private struct SummaryView: View {
    let summary: Summary

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            line("Today", summary.today)
            line("Yesterday", summary.yesterday)
            line("This week", summary.week)
            line("This month", summary.month)
        }
        .padding()
    }

    private func line(_ label: String, _ total: TimeInterval) -> some View {
        GridRow {
            Text(label)
            Text(DurationFormat.hoursMinutes(total))
                .monospacedDigit()
                .gridColumnAlignment(.trailing)
        }
    }
}

/// One Project's total on the viewed Day. Today's rows end with ▶ to switch to the Project, or ⏸ to pause
/// it while it runs; rows on any other Day have neither. Clicking the time types over it: a new total
/// (`1:15`) or a change (`+15`, `-10`). Return applies it, Escape cancels.
private struct RowView: View {
    let row: Row
    let isRunning: Bool
    let canStart: Bool
    let runningColor: Color
    @Bindable var panel: PanelModel
    let toggle: () -> Void
    let adjust: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Text(row.project).lineLimit(1)
            Spacer()
            if panel.adjusting == row.project {
                TextField(DurationFormat.hoursMinutes(row.total), text: $panel.adjustment)
                    .textFieldStyle(.roundedBorder)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                    .focused($focused)
                    .onSubmit(adjust)
                    .onExitCommand { panel.adjusting = nil }
                    .onAppear { focused = true }
                    .help("A new total (1:15) or a change (+15, -10)")
            } else {
                Button {
                    panel.adjusting = row.project
                } label: {
                    Text(DurationFormat.hoursMinutes(row.total)).monospacedDigit()
                }
                .buttonStyle(.plain)
                .help("Change this total")
            }
            if canStart {
                Button(action: toggle) {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .frame(width: 16)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(isRunning ? Color.white : Color.secondary)
                .help(label)
                .accessibilityLabel(label)
            }
        }
        .foregroundStyle(isRunning ? Color.white : Color.primary)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isRunning ? runningColor : Color.clear))
    }

    private var label: String { (isRunning ? "Pause " : "Start ") + row.project }
}

/// The one-time suggestion to turn on Start at login. Either button hides it for good.
private struct LoginHint: View {
    let turnOn: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Start Chronobar when you log in?")
                .font(.callout)
            Spacer()
            Button("Turn On", action: turnOn)
                .controlSize(.small)
            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Dismiss")
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
    }
}

/// The ＋ form: a Project combo box, a duration and Start. The combo box lists the Project list, most
/// recently used first, narrowed to what is typed; picking from it fills the name for Start or Log to act on.
/// With a duration typed (`1:30`, `45`) the button reads Log and adds that time to the viewed Day without
/// starting a timer; on any Day other than today it always reads Log and needs a duration. The line under
/// the field says whether the name is a New Project or an Existing Project, with Archive for one on the
/// Project list.
private struct NewProjectForm: View {
    @Binding var name: String
    @Binding var duration: String
    @Binding var isListOpen: Bool
    let focusRequests: Int
    let canStart: Bool
    let suggestions: (String) -> [String]
    let match: ProjectMatch?
    let start: (String) -> Void
    let log: (String) -> Void
    let archive: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ProjectComboBox(name: $name, isListOpen: $isListOpen, suggestions: suggestions,
                                focusRequests: focusRequests,
                                submit: submit)
                TextField("h:mm", text: $duration)
                    .textFieldStyle(.roundedBorder)
                    .monospacedDigit()
                    .frame(width: 52)
                    .onSubmit(submit)
                    .help("Time to log, such as 1:30 or 45 minutes. Leave empty to start a timer.")
                Button(logs ? "Log" : "Start", action: submit)
                    .keyboardShortcut(isListOpen ? nil : .defaultAction)
                    .disabled(trimmed.isEmpty || (!canStart && !hasDuration))
            }
            if let match {
                HStack(alignment: .firstTextBaseline) {
                    Text(match == .new ? "New Project" : "Existing Project")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if case .active(let project) = match {
                        Button("Archive") { archive(project) }
                            .controlSize(.small)
                            .help("Remove \(project) from the Project list. Its time stays.")
                            .accessibilityLabel("Archive \(project)")
                    }
                }
                .onChange(of: match == .new, initial: false) { _, isNew in
                    NSAccessibility.post(
                        element: NSApp.keyWindow ?? NSApp as Any, notification: .announcementRequested,
                        userInfo: [.announcement: isNew ? "New Project" : "Existing Project",
                                   .priority: NSAccessibilityPriorityLevel.low.rawValue])
                }
            }
        }
    }

    private var trimmed: String { ProjectName.trimmed(name) }
    private var hasDuration: Bool { !duration.trimmingCharacters(in: .whitespaces).isEmpty }
    private var logs: Bool { hasDuration || !canStart }

    private func submit() {
        guard !trimmed.isEmpty, canStart || hasDuration else { return }
        if hasDuration {
            log(trimmed)
        } else {
            start(trimmed)
        }
    }
}

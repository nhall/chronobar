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
    /// Bumped to put focus on the date header, today's date, once the Panel's window can take it.
    var headerFocusRequests = 0
    /// Whether the date header draws its focus ring: hidden after a click on the Pill opens the Panel, until
    /// a key press. Until then nothing else has focus but a text field the click put it in, which always
    /// shows its ring.
    private(set) var focusRing = FocusRing()
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
    /// The most the Panel's content can be on the Pill's screen (`PanelHeight.available`), set before the
    /// Panel opens and whenever the Pill or its screen changes.
    var availableHeight = Double.infinity
    /// A Project whose row to scroll into view: one Start or Log just added or changed, or one keyboard
    /// focus just moved onto.
    var reveal: String?

    /// The Panel opened, by `opening`.
    func opened(by opening: PanelOpening) {
        focusRing.panelOpened(by: opening)
    }

    /// The Panel was asked to open, by `opening`, while it was already open.
    func askedToOpenWhileOpen(by opening: PanelOpening) {
        focusRing.askedToOpenWhileOpen(by: opening)
    }

    /// A key was pressed in the Panel or the (i) Time Summary it shows.
    func keyPressed() {
        focusRing.keyPressed()
    }

    /// Carries out one of the Panel's key equivalents, or a control that does the same.
    func perform(_ command: PanelCommand, today: Day, calendar: Calendar) {
        apply(command.change(viewing: viewedDay, today: today, calendar: calendar))
    }

    func apply(_ change: PanelChange) {
        switch change {
        case .view(let day):
            viewedDay = day
        case .openNewProject:
            showingNewProject = true
            newProjectFocusRequests += 1
        case .toggleTimeSummary:
            showingSummary.toggle()
        }
    }
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
    /// `BuildVariant.appName`, so a development copy's menu reads "Quit Chronobar Dev".
    let appName: String
    let actions: PanelActions
    @FocusState private var headerFocused: Bool

    var body: some View {
        let today = tracker.today
        let day = panel.viewedDay ?? today
        let isToday = day == today
        let rows = tracker.rows(day)
        PanelStack(available: panel.availableHeight - 2 * Self.padding) {
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
                // Opening the Panel focuses the header. Its ring is drawn here rather than by the system,
                // which doesn't redraw the ring of a control that already has focus when
                // `focusEffectDisabled` changes, so the first key press after a click would show nothing.
                // With Keyboard navigation off the header can't take focus, and has no ring.
                .focusEffectDisabled()
                .focused($headerFocused)
                .overlay {
                    if headerFocused && panel.focusRing.isVisible {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color(nsColor: .keyboardFocusIndicatorColor), lineWidth: 3)
                            .padding(-1.5)
                    }
                }
                .padding(.horizontal, -4)
                .onChange(of: panel.headerFocusRequests) { headerFocused = true }
                .help(isToday ? "" : PanelCommand.today.help(Self.backToToday))
                .accessibilityHint(isToday ? "" : Self.backToToday)
                Spacer()
                Text(DurationFormat.hoursMinutes(tracker.dayTotal(day)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .help("Total for the day")
                    .accessibilityLabel("Total for the day, \(DurationFormat.spoken(tracker.dayTotal(day)))")
                Button {
                    panel.showingSummary.toggle()
                } label: {
                    Image(systemName: "info.circle")
                }
                .iconButton(.primary)
                .help(PanelCommand.timeSummary.help("Time Summary"))
                .accessibilityLabel("Time Summary")
                .popover(isPresented: $panel.showingSummary, arrowEdge: .bottom) {
                    SummaryView(summary: tracker.summary())
                }
                Menu {
                    SettingsLink { Text("Settings…") }
                        .keyboardShortcut(",", modifiers: .command)
                    Button("Open data folder", action: actions.openDataFolder)
                    Divider()
                    Button("Quit \(appName)", action: actions.quit)
                        .keyboardShortcut("q", modifiers: .command)
                } label: {
                    // On the image: a menu takes its VoiceOver description from its label's image.
                    Image(systemName: "gearshape")
                        .accessibilityLabel("Menu")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .foregroundStyle(.primary)
                .fixedSize()
                .help("Settings, data folder and Quit")
                .accessibilityHint("Settings, data folder and Quit")
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
                      calendar: tracker.calendar,
                      view: { panel.apply(.viewing($0, today: today)) },
                      move: { panel.perform($0, today: today, calendar: tracker.calendar) })
            // Under the strip, as the title row has no room for it at the Panel's width and above the
            // strip it would push ‹ › away from the pointer.
            if !isToday {
                HStack {
                    Spacer()
                    Button("Today", action: showToday)
                        .controlSize(.small)
                        .help(PanelCommand.today.help(Self.backToToday))
                }
            }
            if rows.isEmpty {
                Text("No time tracked").foregroundStyle(.secondary)
            } else {
                RowList(panel: panel) {
                    ForEach(rows, id: \.project) { row in
                        // Only today's rows run or have ▶/⏸; any other Day's rows are just totals.
                        RowView(row: row, isRunning: isToday && tracker.isRunning(row.project),
                                canStart: isToday, panel: panel,
                                toggle: { actions.toggle(row.project) },
                                adjust: {
                                    if actions.adjust(row.project, panel.adjustment, day) { panel.adjusting = nil }
                                })
                        .id(row.project)
                    }
                }
                .layoutValue(key: PanelStack.Rows.self, value: true)
            }
            // ＋ and its form sit under the rows, where Start or Log adds a new Project's row (rows keep the
            // order their Projects were first tracked in), so the eye stays at the bottom of the Panel.
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
                        panel.reveal = project
                    },
                    log: { project in
                        if actions.log(project, panel.newProjectDuration, day) {
                            panel.showingNewProject = false
                            panel.reveal = project
                        }
                    },
                    // The field empties, so Return can't bring the Project straight back.
                    archive: { project in
                        actions.archive(project)
                        panel.newProjectName = ""
                        panel.newProjectFocusRequests += 1
                    })
            }
            Button {
                panel.showingNewProject.toggle()
            } label: {
                Image(systemName: "plus")
            }
            .iconButton(.primary)
            .help(PanelCommand.newProject.help(isToday ? "Start or log time" : "Log time"))
            .accessibilityLabel(isToday ? "Start or log time" : "Log time")
        }
        .padding(Self.padding)
        .frame(width: Self.width)
    }

    static let width: CGFloat = 300
    /// Around the Panel's content: the system's standard padding, spelled out as the height cap takes it off.
    private static let padding: CGFloat = 16

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

    private static let backToToday = "Back to today"

    /// Today's rows and the week containing it, for the date header and the Today button alike.
    private func showToday() {
        panel.perform(.today, today: tracker.today, calendar: tracker.calendar)
    }
}

/// Seven Days with their totals, ‹ › to move a week back or forward without limit. Today has a
/// `TodayCircle`, the viewed Day a `ViewedDayCircle`.
private struct WeekStrip: View {
    let week: [DayTotal]
    let today: Day
    let viewed: Day
    let calendar: Calendar
    @Environment(\.self) private var environment
    let view: (Day) -> Void
    /// ‹ and ›: `.previousWeek` or `.nextWeek`.
    let move: (PanelCommand) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button { move(.previousWeek) } label: { Image(systemName: "chevron.left") }
                .iconButton(.secondary)
                .help(PanelCommand.previousWeek.help("Previous week"))
                .accessibilityLabel("Previous week")
            ForEach(week, id: \.day) { item in
                Button { view(item.day) } label: { column(item) }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .help(PanelCommand.help("View this Day. Move a Day", keys: .previousDay, .nextDay))
                    .accessibilityLabel(WeekStripAccessibility.label(
                        item, today: today, viewed: viewed, calendar: calendar, locale: .autoupdatingCurrent))
                    .accessibilityAddTraits(item.day == viewed ? .isSelected : [])
            }
            Button { move(.nextWeek) } label: { Image(systemName: "chevron.right") }
                .iconButton(.secondary)
                .help(PanelCommand.nextWeek.help("Next week"))
                .accessibilityLabel("Next week")
        }
    }

    private func column(_ item: DayTotal) -> some View {
        let date = item.day.noon(in: calendar)
        let style = Date.FormatStyle(locale: .autoupdatingCurrent, calendar: calendar, timeZone: calendar.timeZone)
        let isToday = item.day == today
        let isViewed = item.day == viewed
        // With Differentiate Without Color, or Increase Contrast, the viewed Day also has a ring, so it
        // differs from today's filled circle in shape as well as color, and today's date is bold.
        let marksShape = environment.accessibilityDifferentiateWithoutColor
            || environment.colorSchemeContrast == .increased
        return VStack(spacing: 2) {
            Text(date.formatted(style.weekday(.narrow)))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(date.formatted(style.day()))
                .font(.callout.monospacedDigit().weight(isToday && marksShape ? .bold : .regular))
                .foregroundStyle(isToday ? TodayCircle.date(in: environment.colorScheme)
                    : isViewed ? ViewedDayCircle.date : Color.primary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(isToday ? TodayCircle.fill
                    : isViewed ? ViewedDayCircle.fill(in: environment.colorScheme) : Color.clear))
                .overlay(Circle().strokeBorder(
                    Color.primary.opacity(isViewed && !isToday && marksShape ? 1 : 0), lineWidth: 1.5))
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
        // VoiceOver reads each line as one element: "This week, 12 hours 5 minutes".
        GridRow {
            Text(label)
                .accessibilityLabel("\(label), \(DurationFormat.spoken(total))")
            Text(DurationFormat.hoursMinutes(total))
                .monospacedDigit()
                .gridColumnAlignment(.trailing)
                .accessibilityHidden(true)
        }
    }
}

/// The viewed Day's rows, as tall as they are until the Panel would pass the bottom of the Pill's screen;
/// past that only they scroll (`PanelHeight`). A row Start or Log added or changed, and a row keyboard
/// focus moves onto, is scrolled into view. Each row's id is its Project.
private struct RowList<Rows: View>: View {
    @Bindable var panel: PanelModel
    @ViewBuilder let content: Rows
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 2) { content }
            }
            .scrollBounceBehavior(.basedOnSize)
            // A Day's first row needs no scrolling.
            .onAppear { panel.reveal = nil }
            .onChange(of: panel.reveal) { _, project in
                guard let project else { return }
                panel.reveal = nil
                withAnimation(reduceMotion ? nil : .easeOut(duration: PanelResize.duration)) {
                    proxy.scrollTo(project)
                }
            }
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
    @Bindable var panel: PanelModel
    let toggle: () -> Void
    let adjust: () -> Void
    @FocusState private var focused: Bool
    /// Which of the row's buttons has keyboard focus, so a row focus moves onto is scrolled into view.
    @FocusState private var focusedButton: FocusedButton?

    private enum FocusedButton {
        case total, toggle
    }

    var body: some View {
        let presentation = RowPresentation(row: row, isRunning: isRunning)
        HStack {
            Text(row.project).lineLimit(1)
                .accessibilityLabel(presentation.nameLabel)
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
                    .accessibilityLabel("New total for \(row.project)")
                    .accessibilityHint("A new total such as 1:15, or a change such as +15 or -10. "
                        + "Return applies it, Escape cancels.")
            } else {
                Button {
                    panel.adjusting = row.project
                } label: {
                    Text(DurationFormat.hoursMinutes(row.total)).monospacedDigit()
                }
                .buttonStyle(.plain)
                .focused($focusedButton, equals: .total)
                .help("Change this total")
                .accessibilityLabel("\(row.project) total, \(DurationFormat.spoken(row.total))")
                .accessibilityHint("Change this total")
            }
            if canStart {
                Button(action: toggle) {
                    Image(systemName: presentation.toggle == .pause ? "pause.fill" : "play.fill")
                        .frame(width: 16)
                }
                .iconButton(presentation.toggleTone.style)
                .focused($focusedButton, equals: .toggle)
                .help(presentation.toggleLabel)
                .accessibilityLabel(presentation.toggleLabel)
            }
        }
        .onChange(of: focusedButton) { _, button in
            if button != nil { panel.reveal = row.project }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        // The same quiet fill as the Start at login message, so the Panel never shows the running color.
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(presentation.isHighlighted ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear)))
    }
}

private extension RowPresentation.Tone {
    var style: HierarchicalShapeStyle {
        switch self {
        case .primary: .primary
        case .secondary: .secondary
        }
    }
}

private extension View {
    /// A button drawn as its bare label, in `style`, so its color is chosen here. Not `.borderless`, which
    /// leaves its label's color to the system and can draw it in the accent color. The whole of its frame
    /// takes clicks, not only the glyph's strokes, as a plain button's label otherwise would.
    func iconButton(_ style: HierarchicalShapeStyle) -> some View {
        buttonStyle(.plain).foregroundStyle(style).contentShape(Rectangle())
    }
}

/// The one-time suggestion to turn on Start at login. Either button hides it for good.
/// The question and ✕ share the first row, so the text has the full width to wrap in; Turn On sits under
/// the text, on its leading edge. VoiceOver reads the question, then Turn On, then Dismiss.
private struct LoginHint: View {
    let turnOn: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Start Chronobar when you log in?")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilitySortPriority(3)
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                }
                .iconButton(.secondary)
                .help("Dismiss")
                .accessibilityLabel("Dismiss")
                .accessibilitySortPriority(1)
            }
            Button("Turn On", action: turnOn)
                .controlSize(.small)
                .accessibilitySortPriority(2)
        }
        .accessibilityElement(children: .contain)
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
                    .accessibilityLabel("Duration")
                    .accessibilityHint(canStart
                        ? "Time to log, such as 1:30 or 45 minutes. Leave empty to start a timer."
                        : "Time to log, such as 1:30 or 45 minutes.")
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

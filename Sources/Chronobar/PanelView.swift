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
    /// Bumped to put focus in the ＋ form's Label field once the Panel's window can take it: the form's
    /// own focus on appearing is lost when the Panel opens straight into it.
    var newProjectFocusRequests = 0
    /// Bumped to put focus on the date header, today's date, once the Panel's window can take it.
    var headerFocusRequests = 0
    /// Whether the date header draws its focus ring: hidden after a click on the Pill opens the Panel, until
    /// a key press. Until then nothing else has focus but a text field the click put it in, which always
    /// shows its ring.
    private(set) var focusRing = FocusRing()
    /// Whether the ＋ form's Label list is showing, which takes Return from the Start/Log button.
    var newProjectListOpen = false
    /// The ＋ form's duration; empty starts a timer, anything else logs that much time.
    var newProjectDuration = ""
    /// The Day the Panel shows; nil follows today, including across midnight.
    var viewedDay: Day? {
        didSet { editing = nil }
    }
    var showingSummary = false
    /// The row being edited, if any: one at a time, so starting an edit ends any other. Each start clears
    /// what was typed, and a Label edit starts from the row's Label.
    var editing: RowEdit? {
        didSet {
            adjustment = ""
            relabelProjectName = if case .label(let project) = editing { project } else { "" }
            relabelProjectListOpen = false
        }
    }
    /// What has been typed over the edited row's time.
    var adjustment = ""
    /// The Label typed for the edited row.
    var relabelProjectName = ""
    /// Whether the row's Label field shows its list, which takes Return and Escape.
    var relabelProjectListOpen = false
    /// The most the Panel's content can be on the Pill's screen (`PanelHeight.available`), set before the
    /// Panel opens and whenever the Pill or its screen changes.
    var availableHeight = Double.infinity
    /// A Project whose row to scroll into view: one Start or Log just added or changed, or one keyboard
    /// focus just moved onto.
    var projectToReveal: String?

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

/// What part of a Panel row is being edited, and the row's Project.
enum RowEdit: Equatable {
    /// Its time, typed over with a new total or a change.
    case total(String)
    /// Its Label, to move the row's time to another.
    case label(String)
}

/// What the Panel asks the app to do.
struct PanelActions {
    /// Start and log return the Project's name as its row is shown, which can differ from what was typed
    /// (`Tracker.addProject`), or nil when refused, so the field keeps what was typed.
    let start: (String) -> String?
    /// A row's ▶/⏸: starts the Project, or pauses it while it runs.
    let toggle: (String) -> Void
    let log: (_ project: String, _ duration: String, _ day: Day) -> String?
    /// Returns false when the input was refused, so the field keeps what was typed.
    let adjust: (_ project: String, _ input: String, _ day: Day) -> Bool
    /// Moves the row's time on `day` to `newLabel`. Returns the new Label's name as stored, or nil when
    /// refused, so the field keeps what was typed.
    let relabel: (_ project: String, _ newLabel: String, _ day: Day) -> String?
    let archive: (String) -> Void
    let pin: (String) -> Void
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
        let sheet = tracker.daySheet(day)
        // Double(padding): Swift 6.0 and 6.1 find `2 * padding` ambiguous beside a Double.
        PanelStack(available: panel.availableHeight - 2 * Double(Self.padding)) {
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
            if sheet.isMalformed {
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
            if sheet.rows.isEmpty {
                Text("No time tracked").foregroundStyle(.secondary)
            } else {
                // Above the rows, out of the title row, which a long past Day's title and two-digit hours
                // would crowd. An empty Day has none: "No time tracked" says it. The rows' minutes add up
                // to the Total line's (`DaySheet`).
                DayTotalLineView(line: DayTotalLine(total: TimeInterval(sheet.total.seconds),
                                                    elapsed: TimeInterval(sheet.clockTime.seconds)))
                RowList(panel: panel) {
                    ForEach(sheet.rows, id: \.project) { row in
                        // Only today's rows run or have ▶/⏸; any other Day's rows are just totals.
                        RowView(row: row, canStart: isToday, panel: panel,
                                toggle: { actions.toggle(row.project) },
                                adjust: {
                                    if actions.adjust(row.project, panel.adjustment, day) { panel.editing = nil }
                                },
                                labels: RowView.Labels(
                                    rows: sheet.rows, suggestions: tracker.suggestions(for:),
                                    isPinned: tracker.isPinned, pin: actions.pin, archive: actions.archive,
                                    relabel: {
                                        let typed = panel.relabelProjectName
                                        guard let project = actions.relabel(row.project, typed, day) else { return }
                                        panel.editing = nil
                                        panel.projectToReveal = project
                                    }))
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
                    start: { name in
                        let project = actions.start(name)
                        panel.showingNewProject = false
                        panel.projectToReveal = project
                    },
                    log: { name in
                        if let project = actions.log(name, panel.newProjectDuration, day) {
                            panel.showingNewProject = false
                            panel.projectToReveal = project
                        }
                    },
                    // The field empties if it holds the Project, so Return can't bring it straight back.
                    archive: { project in
                        actions.archive(project)
                        if ProjectName.matches(panel.newProjectName, project) { panel.newProjectName = "" }
                        panel.newProjectFocusRequests += 1
                    },
                    isPinned: tracker.isPinned,
                    pin: actions.pin)
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
        let mark = DayMark(item.day, today: today, viewed: viewed)
        let scheme = environment.colorScheme
        // With Differentiate Without Color, or Increase Contrast, the viewed Day also has a ring, so it
        // differs from today's filled circle in shape as well as color, and today's date is bold.
        let marksShape = environment.accessibilityDifferentiateWithoutColor
            || environment.colorSchemeContrast == .increased
        return VStack(spacing: 2) {
            Text(date.formatted(style.weekday(.narrow)))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(date.formatted(style.day()))
                .font(.callout.monospacedDigit().weight(mark == .today && marksShape ? .bold : .regular))
                .foregroundStyle(mark.date(in: scheme))
                .frame(width: 24, height: 24)
                .background(Circle().fill(mark.fill(in: scheme)))
                .overlay(Circle().strokeBorder(
                    Color.primary.opacity(mark == .viewed && marksShape ? 1 : 0), lineWidth: 1.5))
            Text(DurationFormat.hoursMinutes(item.total))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

/// How a Day's date is marked in the Week strip: today's circle, the viewed Day's when it isn't today, or
/// none. Each gives the circle's fill and the date's color on it.
private enum DayMark {
    case today, viewed, plain

    init(_ day: Day, today: Day, viewed: Day) {
        self = day == today ? .today : day == viewed ? .viewed : .plain
    }

    func fill(in scheme: ColorScheme) -> Color {
        switch self {
        case .today: TodayCircle.fill
        case .viewed: ViewedDayCircle.fill(in: scheme)
        case .plain: .clear
        }
    }

    func date(in scheme: ColorScheme) -> Color {
        switch self {
        case .today: TodayCircle.date(in: scheme)
        case .viewed: ViewedDayCircle.date
        case .plain: .primary
        }
    }
}

/// "Total 2:57 · Clock time 2:50" (`DayTotalLine`), one run of text from the leading edge, in the
/// secondary color so it doesn't read as a row. It has the rows' inset, so "Total" starts where their
/// names do. The widest, "Total 23:59 · Clock time 23:59", measures about 184 points of the 256 the
/// Panel's width leaves inside that inset, so it needs no shorter form.
private struct DayTotalLineView: View {
    let line: DayTotalLine

    var body: some View {
        Text(line.text)
            .monospacedDigit()
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.secondary)
            .padding(.horizontal, RowView.horizontalPadding)
            .help(line.help)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(line.accessibilityLabel)
    }
}

/// The (i) Time Summary.
private struct SummaryView: View {
    let summary: Summary

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            line("Today", summary.today, summary.elapsed.today)
            line("Yesterday", summary.yesterday, summary.elapsed.yesterday)
            line("This week", summary.week, summary.elapsed.week)
            line("This month", summary.month, summary.elapsed.month)
        }
        .padding()
    }

    /// "This week 12:05 · Clock time 9:00", the figures in columns so the periods line up.
    private func line(_ name: String, _ total: TimeInterval, _ elapsed: TimeInterval) -> some View {
        let line = DayTotalLine(name, total: total, elapsed: elapsed)
        // VoiceOver reads each line as one element: "This week 12 hours 5 minutes, clock time 9 hours".
        return GridRow(alignment: .firstTextBaseline) {
            Text(line.name)
                .accessibilityLabel(line.accessibilityLabel)
            Text(line.total)
                .monospacedDigit()
                .gridColumnAlignment(.trailing)
                .accessibilityHidden(true)
            Text("· \(line.clockTime)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .help(line.help)
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
            .onAppear { panel.projectToReveal = nil }
            .onChange(of: panel.projectToReveal) { _, project in
                guard let project else { return }
                panel.projectToReveal = nil
                withAnimation(reduceMotion ? nil : .easeOut(duration: PanelResize.duration)) {
                    proxy.scrollTo(project)
                }
            }
        }
    }
}

/// One Project's total on the viewed Day. Today's rows end with ▶ to switch to the Project, or ⏸ to pause
/// it while it runs; rows on any other Day have neither. Clicking the time types over it: a new total
/// (`1:15`) or a change (`+15`, `-10`). Clicking the Label edits it in a Label field with the ＋ form's
/// suggestions, to move the row's time to another Label; while the typed Label is another row's, the field
/// says the two would merge. Return applies either edit, Escape cancels.
private struct RowView: View {
    /// What the row's Label field needs: the ＋ form's suggestions and their Pin and Archive, the Day's rows
    /// for the hint that the typed Label would merge into one, and the relabel Return makes.
    struct Labels {
        let rows: [DaySheet.Row]
        let suggestions: (String) -> [String]
        let isPinned: (String) -> Bool
        let pin: (String) -> Void
        let archive: (String) -> Void
        let relabel: () -> Void
    }

    /// With its share of the Total line's minutes, and who started its running timer: an agent's gets a
    /// terminal icon after the name.
    let row: DaySheet.Row
    let canStart: Bool
    @Bindable var panel: PanelModel
    let toggle: () -> Void
    let adjust: () -> Void
    let labels: Labels
    @FocusState private var focused: Bool
    /// Which of the row's buttons has keyboard focus, so a row focus moves onto is scrolled into view.
    @FocusState private var focusedButton: FocusedButton?

    private enum FocusedButton {
        case label, total, toggle
    }

    /// The ▶/⏸ column's width and the row's side insets, which the Total line above the rows matches.
    static let toggleWidth: CGFloat = 16
    static let horizontalPadding: CGFloat = 6

    var body: some View {
        let presentation = RowPresentation(row)
        HStack {
            if panel.editing == .label(row.project) {
                LabelField(name: $panel.relabelProjectName, isListOpen: $panel.relabelProjectListOpen,
                           suggestions: labels.suggestions, focusRequests: 0, submit: labels.relabel,
                           cancel: { panel.editing = nil },
                           isPinned: labels.isPinned, pin: labels.pin, archive: labels.archive)
                    .help("Another Label for this row's time. Return moves it, Escape cancels.")
                // Beside the field, not under it: the suggestions open in a window under the field.
                if let hint = MergeHint(typed: panel.relabelProjectName, editing: row.project, rows: labels.rows) {
                    Text(hint.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }
            } else {
                Button {
                    panel.editing = .label(row.project)
                } label: {
                    Text(row.project).lineLimit(1)
                }
                .buttonStyle(.plain)
                .focused($focusedButton, equals: .label)
                .help("Change this row's Label")
                .accessibilityLabel(presentation.nameLabel)
                .accessibilityHint("Change this row's Label")
            }
            if let agentMark = presentation.agentMark {
                // The name's VoiceOver label already says an agent started it.
                Image(systemName: "terminal")
                    .foregroundStyle(.secondary)
                    .help(agentMark)
                    .accessibilityHidden(true)
            }
            Spacer()
            if panel.editing == .total(row.project) {
                TextField(presentation.total, text: $panel.adjustment)
                    .textFieldStyle(.roundedBorder)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                    .focused($focused)
                    .onSubmit(adjust)
                    .onExitCommand { panel.editing = nil }
                    .onAppear { focused = true }
                    .help("A new total (1:15) or a change (+15, -10)")
                    .accessibilityLabel("New total for \(row.project)")
                    .accessibilityHint("A new total such as 1:15, or a change such as +15 or -10. "
                        + "Return applies it, Escape cancels.")
            } else {
                Button {
                    panel.editing = .total(row.project)
                } label: {
                    Text(presentation.total).monospacedDigit()
                }
                .buttonStyle(.plain)
                .focused($focusedButton, equals: .total)
                .help("Change this total")
                .accessibilityLabel(presentation.totalLabel)
                .accessibilityHint("Change this total")
            }
            if canStart {
                Button(action: toggle) {
                    Image(systemName: presentation.toggle == .pause ? "pause.fill" : "play.fill")
                        .frame(width: Self.toggleWidth)
                }
                .iconButton(presentation.toggleTone.style)
                .focused($focusedButton, equals: .toggle)
                .help(presentation.toggleLabel)
                .accessibilityLabel(presentation.toggleLabel)
            }
        }
        .onChange(of: focusedButton) { _, button in
            if button != nil { panel.projectToReveal = row.project }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, Self.horizontalPadding)
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

/// The ＋ form: a Label field, a duration and Start. The field's list shows the suggested Labels (used
/// in the last 30 days, or pinned), most recently used first, narrowed to what is typed; picking from it
/// fills the name for Start or Log to act on, and right-clicking one offers Pin and Archive. With a duration
/// typed (`1:30`, `45`) the button reads Log and adds that time to the viewed Day without starting a timer;
/// on any Day other than today it always reads Log and needs a duration. The line under the field says
/// whether the name is a New Label or an Existing Label, with Pin for one not pinned and Archive for one
/// suggested, so both work from the keyboard too.
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
    let isPinned: (String) -> Bool
    let pin: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                LabelField(name: $name, isListOpen: $isListOpen, suggestions: suggestions,
                           focusRequests: focusRequests,
                           submit: submit, isPinned: isPinned, pin: pin, archive: archive)
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
                    Text(match == .new ? "New Label" : "Existing Label")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let project = match.project, !isPinned(project) {
                        Button("Pin") { pin(project) }
                            .controlSize(.small)
                            .help("Always suggest \(project), however long since it was used.")
                            .accessibilityLabel("Pin \(project)")
                    }
                    if case .active(let project) = match {
                        Button("Archive") { archive(project) }
                            .controlSize(.small)
                            .help("Stop suggesting \(project) until it is typed again. Its time stays.")
                            .accessibilityLabel("Archive \(project)")
                    }
                }
                .onChange(of: match == .new, initial: false) { _, isNew in
                    NSAccessibility.post(
                        element: NSApp.keyWindow ?? NSApp as Any, notification: .announcementRequested,
                        userInfo: [.announcement: isNew ? "New Label" : "Existing Label",
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

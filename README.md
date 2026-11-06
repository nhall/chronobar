# Chronobar

A project timer that lives in the macOS menu bar. Pick a project, click ▶ to start, click ⏸ to pause,
and open the panel to see what each day went to. Everything stays on your Mac in plain JSON files you
can read and edit. There are no accounts, no sync and no integrations.

<!-- TODO: screenshots
  - docs/screenshots/pill.png         the Pill, stopped and running, in light and dark menu bars
  - docs/screenshots/panel.png        the Panel: date header, Week strip, project rows, ＋ and ⚙
  - docs/screenshots/new-project.png  the ＋ form with project suggestions and a duration
  - docs/screenshots/idle-alert.png   the idle alert after waking the Mac
  - docs/screenshots/settings.png     the Settings window
-->

## How it works

- **The Pill** sits in the menu bar. Its left square shows ▶ on gray when stopped and ⏸ on a colored
  background while a timer runs. Click it to start or pause. The right side shows today's time for the
  selected project (`1:23`); click it to open the Panel.
- **The Panel** shows the day you are viewing, a strip with the week's daily totals, and one row per
  project with its total for that day. Each of today's rows ends with a ▶ button that switches the
  timer to that project; the running row is highlighted and shows ⏸ to pause it. Use ＋ to start a new
  project or to log time you forgot to track. ‹ › move a week back or forward without limit; on any
  day other than today, ＋ only logs time and rows have no ▶, so you can fix last week or log a
  vacation ahead. While you view another day, a Today button under the strip brings you back, as
  does clicking the date.
- **Keys in the Panel** work wherever focus is, with or without Keyboard navigation turned on:
  ⌘[ and ⌘] move a week back or forward, ← and → move a Day (unless you're typing in a field, where
  they move the insertion point), ⌘T goes back to today, ⌘N opens ＋ and ⌘I opens or closes the (i)
  Time Summary. Each control's help tag names its key.
- Only one timer runs at a time. Starting a project pauses whichever one was running.
- If you come back to a running timer after the Mac slept, locked, or sat with no input, Chronobar asks
  whether to remove the time you were away.

## Install

Chronobar is built from source on your Mac by Homebrew. You need macOS 14 Sonoma or later and the
Command Line Tools (`xcode-select --install`). Xcode is not required.

```sh
brew install nhall/tap/chronobar
ln -sfn "$(brew --prefix)/opt/chronobar/Chronobar.app" ~/Applications/Chronobar.app
open ~/Applications/Chronobar.app
```

Homebrew installs the app into its own prefix, not `/Applications`. The link in `~/Applications` lets
you open Chronobar from Spotlight, Launchpad and Finder. It points at Homebrew's `opt` path, which
always leads to the installed version, so you only need to make it once.

Because the app is compiled on your own Mac and signed there (ad hoc), it isn't quarantined and opens
without a Gatekeeper warning. You don't need an Apple Developer account.

Update with `brew upgrade chronobar`. To remove it, quit Chronobar, then:

```sh
brew uninstall chronobar
rm ~/Applications/Chronobar.app
```

Your data in `~/Library/Application Support/Chronobar` is left alone; delete that folder too if you
want it gone.

### Building without Homebrew

```sh
git clone https://github.com/nhall/chronobar.git
cd chronobar
scripts/bundle-app.sh            # builds build/Chronobar.app
open build/Chronobar.app
```

`swift test` runs the tests. The test suite needs Xcode, because Swift Testing isn't usable with the
Command Line Tools alone; building the app doesn't.

### A development copy

To try a change without touching the Chronobar you use every day, build a development copy:

```sh
scripts/bundle-app.sh --dev      # builds "build/Chronobar Dev.app"
open "build/Chronobar Dev.app"
```

It runs next to the everyday copy and shares nothing with it:

| | Everyday copy | Development copy |
|---|---|---|
| App | `Chronobar.app` | `Chronobar Dev.app` |
| Bundle ID (settings, Selected Project, start at login) | `io.github.nhall.chronobar` | `io.github.nhall.chronobar.dev` |
| Data folder | `~/Library/Application Support/Chronobar` | `~/Library/Application Support/Chronobar Dev` |
| Process (for `killall`) | `Chronobar` | `ChronobarDev` |

Its Pill ends in an orange **DEV** mark, its Dock icon carries a **DEV** badge, and its ⚙ menu reads
**Quit Chronobar Dev**, so with both running you can tell which Pill to click. The everyday copy's Pill
has no mark. To start the development copy fresh, quit it, then delete its data folder and run
`defaults delete io.github.nhall.chronobar.dev`.

Without `--dev`, the script builds exactly what the Homebrew formula installs.

## Your data

Everything lives in `~/Library/Application Support/Chronobar`. The ⚙ menu has **Open data folder**.

```
Chronobar/
  projects.txt          the project list, one project per line
  days/
    2026-11-02.json
    2026-11-03.json     one file per day, named by local date
```

### Day files

Each day is one JSON file with one entry per line:

```json
{
  "date": "2026-11-03",
  "entries": [
    { "project": "Website Redesign", "start": "2026-11-03T09:02:11-05:00", "end": "2026-11-03T10:47:30-05:00" },
    { "project": "Website Redesign", "start": "2026-11-03T13:15:00-05:00", "end": null },
    { "project": "Internal", "seconds": 900, "note": "manual" },
    { "project": "Internal", "seconds": -300, "note": "adjustment" }
  ]
}
```

- `date` must match the file name.
- A **timed** entry has `start` and `end` as ISO 8601 times with a UTC offset, to the second. `end` is
  `null` only for the one running timer.
- A **manual** entry has a whole number of `seconds`, negative for subtractions. `note` is `manual`
  for time logged with ＋ and `adjustment` for a corrected total; it is a marker, not free text.
- A project's total for the day is the sum of its timed durations and manual seconds, never shown
  below `0:00`, and displayed as hours and minutes rounded down.
- Any Day can have a file, past or future: time logged ahead, such as a vacation, goes in that Day's
  file in the same format. Timers run only today, so a day ahead holds only manual entries until it
  arrives.
- A timer running past midnight is split: the old day's entry ends at the start of the new day and a
  new entry starts in the new day's file.

You can edit these files by hand, for example to fix a start time. Chronobar re-reads a day's file
before every change, so it won't overwrite your edit. If a file stops being valid JSON, Chronobar
leaves it untouched and refuses to change that day until you fix it.

### Project list

`projects.txt` is UTF-8 text with one active project per line. Archiving a project removes its line;
its history in the day files stays. Names match regardless of case and surrounding spaces, so
`internal ` and `Internal` are the same project.

### Settings

Settings, the selected project and the app's last-alive time are kept in the app's preferences
(`io.github.nhall.chronobar`), not in the data folder.

## Manual test checklist

The timing logic is covered by `swift test`. The menu bar, panel and system behavior are checked by
hand. Run through this list before a release, on the Homebrew build. Don't use a Mac whose real data
you care about, or back up the data folder first.

Mark anything that isn't built yet *(not built yet)*, and update this list as features land.

**Start, pause, switch**

- [ ] With no project selected, ▶ opens the ＋ form.
- [ ] ＋, type a new project name, Start: the square turns colored with ⏸ and the time starts at `0:00`.
      The form closes back to the rows, the new project's row is highlighted, and the Panel stays open.
- [ ] Click outside the Panel: it closes.
- [ ] After a minute the time reads `0:01`; the day file has one entry with `"end": null`.
- [ ] Click ⏸: the square goes gray with ▶, the time stays, the entry now has an `end`.
- [ ] Click ▶: the same project resumes and its total keeps counting from where it was.
- [ ] With the Panel closed, click the square several times, on its edges as well as its middle: each
      click toggles ⏸ and ▶, and the Panel stays closed.
- [ ] With the Panel open, do the same: each click toggles, and the Panel stays open.
- [ ] Repeat both with a trackpad (tap to click and a full press) as well as a mouse.
- [ ] Click the time segment: the Panel opens.
- [ ] Start a second project from ＋: the first entry closes, only one entry is open, and the Panel
      highlights the new project's row.
- [ ] Each of today's rows shows its time, then ▶ at the far right; the running row shows ⏸ instead
      and is highlighted. Rows on any other Day have no button.
- [ ] Click the first project's ▶ in the Panel: it resumes on its existing row, and the second pauses.
- [ ] Click the running row's ⏸: the timer pauses, the row loses its highlight and shows ▶, and the
      Pill's square goes gray with ▶.
- [ ] With the Panel open, click the Pill's square or press the global shortcut: the row's ⏸ and ▶
      follow it.
- [ ] Clicking a row's time still opens the field to change its total; ▶/⏸ does not.
- [ ] ＋, click ▾ in the Project field (or press ↓): every project is listed, most recently used first,
      and the list scrolls when long. Type part of a name: the list narrows to names containing it, those
      starting with it first. Clicking one, or ↓ to it and Return, fills the field, closes the list and
      starts nothing; Start (or Return) then starts it.
- [ ] With `test`, `test 2` and `test 3` (started in that order), type `test`: `test` is listed first and
      the field keeps `test`; Return starts `test`.
- [ ] The line under the field reads New Project for a new name and Existing Project for a listed or
      archived one. Archive, shown for a listed project, removes it from the list and empties the field.
- [ ] With VoiceOver on, the Project field is announced as a combo box, with whether its list is open and
      each item as you move through it; New Project / Existing Project is read when it changes; Tab
      reaches Archive with keyboard navigation on.
- [ ] Type a project name in different case with extra spaces: it starts on the existing row.
- [ ] The Pill reads clearly in light and dark menu bars and on a notched display.
- [ ] In Settings, open Running color in light and in dark mode: each option's dot is the color it
      names, and Accent color's dot matches the accent in System Settings › Appearance, changing
      when you pick another accent there.
- [ ] With a timer running, pick yellow, mint, blue and Accent color in turn, in light and dark mode
      and with Increase Contrast on and off: the Pill's ⏸ and today's date in the Week strip read
      clearly on each (white on dark colors, black on light ones).
- [ ] With several rows, one running, in light and dark mode, with Increase Contrast on and off and
      whatever running color is picked: no row has the running color or the accent color behind it. The
      running row has a quiet gray highlight, with its name, total and ⏸ in the normal text color; the
      other rows' ▶ are gray. ‹ ›, (i), ＋ and ⚙ are gray or the text color, never the accent color.

**Accessibility**

- [ ] With VoiceOver on, move to the Pill (⌃F8 or the VoiceOver menu bar commands): it reads the Selected
      Project, its time today in words and whether it is running, or No Project selected. VO-Space opens
      the Panel. VO-⌘-Space lists Start or Pause (New Project with nothing selected) and Open Panel;
      Start and Pause work without opening the Panel, and the label follows.
- [ ] With VoiceOver on and another app in front, press the global shortcut: VoiceOver says "Started"
      then the Selected Project, and on the next press "Paused" and the Project. With no Selected Project
      it says "New Project" as the ＋ form opens. With VoiceOver off, the shortcut says nothing.
- [ ] In the Panel, VoiceOver reads a label for every control: the date, Total for the day, Time
      Summary, Start or log time, Menu, Previous week and Next week, each Day in the Week strip with its
      date, total, and "today" or "viewed" (the viewed Day also reads as selected), each row's name
      (with "running" on the running row), its total and Start or Pause, and Duration in the ＋ form.
      Each Time Summary line reads as one: "This week, 12 hours 5 minutes".
- [ ] With Differentiate Without Color on, view a Day other than today: the viewed Day has a ring and
      today's date is bold, so they differ without color.
- [ ] With Increase Contrast on, the Pill's time segment is opaque, darker, and outlined; with Reduce
      Transparency on it is opaque. Check both in light and dark menu bars.
- [ ] With Keyboard navigation on (System Settings › Keyboard), open the Panel from the Pill with ⌃F8 and
      Space, then use Tab, Space and Return alone to: view another Day, move a week each way, go back to
      today, start and pause a row, change a row's total (Escape cancels), open (i) and ＋, Log time,
      open the ⚙ menu and each of its items. Escape closes the Panel.
- [ ] With Keyboard navigation off (the macOS default), open the Panel and, without the mouse: ← and →
      move the viewed Day, past the strip's ends into the next or previous week; ⌘[ and ⌘] move a week;
      ⌘T goes back to today; ⌘N opens ＋ with the Project field focused; ⌘I opens the (i) Time Summary
      and ⌘I again closes it. Repeat with Keyboard navigation on and focus on a strip Day or a row.
- [ ] In the ＋ form's Project and duration fields and in a row's adjust field, type some text: ← and →
      move the insertion point and ⌘← ⌘→ ⇧← ⌥← edit and select as usual, without changing the Day;
      ⌘A, ⌘C and ⌘V work. ⌘[ ⌘] ⌘T ⌘N ⌘I still work from those fields.
- [ ] Hover over ‹, ›, a strip Day, the Today button, the date (on another Day), ＋ and (i): each help
      tag names its key.
- [ ] With the Settings window in front, the Panel's keys do nothing there.

**Logging and adjusting time**

- [ ] ＋, pick a project, type `1:30`: the button reads Log; Log adds 1:30 without starting a timer.
      The form closes back to the rows, the row shows the new total, and the Panel stays open.
- [ ] On a past or future Day, ＋ reads Log and stays disabled until a duration is typed; it never
      starts a timer.
- [ ] Click › past the current week, then a Day there: its rows and totals show, with no ▶/⏸. Log
      `8:00` there: the Day's total and its column in the strip read `8:00`, a new file appears for it
      in the data folder's `days` folder, and the (i) week and month totals include it when that Day
      falls in them. Click its row's time and adjust it, as on a past Day.
- [ ] Keep clicking ›: it goes on into later weeks without stopping; ‹ comes back to any past week.
- [ ] On today there is no Today button. Click a past Day, then a Day weeks ahead: a Today button
      shows at the right under the strip each time, and ‹ › stay where they were. Click it: today's
      rows and the week containing today show, and the button is gone.
- [ ] From a past or future Day, click the date header instead: it also returns to today.
- [ ] Repeat with the longest weekday (Wednesday) and a two-digit total: the header, strip and Today
      button fit without truncating or overlapping.
- [ ] Click a row's time, type `1:15`, Return: the row reads `1:15`. Try `+15` and `-10` too.
- [ ] `-9:00` on a short row stops at `0:00`; a typo like `1:7x` beeps and changes nothing.
- [ ] Adjusting the running row keeps the timer running from the new total.

**Idle after sleep and lock**

- [ ] Start a timer, sleep the Mac for a few minutes, wake it: one alert says when you went idle and
      which project is running.
- [ ] Remove idle time: the entry ends at the idle time and the timer continues from now.
- [ ] Repeat with ⌃⌘Q (lock screen) and unlock; repeat with no input past the idle threshold.
- [ ] In Settings, Idle after no input for is a pop-up of Off, 5, 10, 15, 20, 30, 45 and 60 minutes,
      15 on a first launch. Pick 5 minutes with a timer running and leave the keyboard and mouse
      alone: the alert comes after about 5 minutes, without relaunching.
- [ ] Pick Off: no alert after an hour without input, but sleep and lock still bring it up.
- [ ] Remove & stop leaves the timer stopped; Keep changes nothing.
- [ ] No alert appears when no timer was running.
- [ ] Start a timer, break today's day file by hand (delete a brace), sleep and wake, Remove idle time:
      a second alert names the broken file and the timer keeps counting. Fix the file: within a second
      the idle alert comes back, from the idle time to when you first answered; Remove idle time keeps
      the time since that first answer.

**Quit and crash recovery**

- [ ] Quit from the ⚙ menu with a timer running: the entry ends at the quit time; relaunching shows
      no alert and no timer.
- [ ] Start a timer, wait two minutes, `killall -9 Chronobar`, wait a few minutes, relaunch: one alert
      says you've been idle since about the kill time; Remove idle time ends the entry there.
- [ ] Repeat, but kill it before midnight and relaunch the next day: the old day's entry is found and
      the alert covers the time since.
- [ ] Repeat, but break today's day file by hand before relaunching: no alert and no timer. Fix the
      file and open the Panel: the idle alert appears for the time since the kill.

**Dock**

- [ ] Show in Dock on (default): the Dock icon appears; clicking it opens the Panel under the Pill.
- [ ] Show in Dock off: the icon disappears at once and stays hidden after relaunching.

**Start at login**

- [ ] Off by default, and the Panel shows a hint about it until dismissed (it stays dismissed after
      relaunching).
- [ ] Turn it on in Settings, log out and back in: Chronobar starts into the menu bar.
- [ ] With Show in Dock off as well, it starts with no Dock icon.
- [ ] After `brew upgrade chronobar`, log out and in again: it still starts at login.
- [ ] Turn it off: it no longer starts at login, and it no longer appears in System Settings › General
      › Login Items.

**Install**

- [ ] On a Mac with only the Command Line Tools, `brew install nhall/tap/chronobar` succeeds.
- [ ] The app opens from `~/Applications` without a Gatekeeper warning.

## Releasing

The Homebrew formula's source of truth is [`packaging/homebrew/chronobar.rb`](packaging/homebrew/chronobar.rb).
The tap is the `nhall/homebrew-tap` repository, which holds a copy at `Formula/chronobar.rb`.

1. Tag the release: `git tag v0.2.0 && git push origin v0.2.0`.
2. Hash the tarball:
   `curl -L https://github.com/nhall/chronobar/archive/refs/tags/v0.2.0.tar.gz | shasum -a 256`.
3. Update `url` and `sha256` in `packaging/homebrew/chronobar.rb`, commit, and copy the file to the tap.
4. `brew update && brew upgrade chronobar`, then run the checklist.

The formula needs the repository to be public: Homebrew downloads the tarball without credentials.

## License

MIT. See [LICENSE](LICENSE).

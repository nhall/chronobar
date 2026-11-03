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
  project with its total for that day. Each of today's rows has a ▶ button that switches the timer to
  that project. Use ＋ to start a new project or to log time you forgot to track.
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

## Your data

Everything lives in `~/Library/Application Support/Chronobar`. The ⚙ menu will have **Open data
folder** *(not built yet)*.

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

Items marked *(not built yet)* are waiting on later work; update this list as they land.

**Start, pause, switch**

- [ ] With no project selected, ▶ opens the ＋ form.
- [ ] ＋, type a new project name, Start: the square turns colored with ⏸ and the time starts at `0:00`.
- [ ] After a minute the time reads `0:01`; the day file has one entry with `"end": null`.
- [ ] Click ⏸: the square goes gray with ▶, the time stays, the entry now has an `end`.
- [ ] Click ▶: the same project resumes and its total keeps counting from where it was.
- [ ] Start a second project from ＋: the first entry closes, only one entry is open, and the Panel
      highlights the new project's row.
- [ ] Click the first project's ▶ in the Panel: it resumes on its existing row, and the second pauses.
- [ ] Click the running row's clock icon: the timer pauses.
- [ ] The Pill reads clearly in light and dark menu bars and on a notched display.

**Idle after sleep and lock** *(not built yet)*

- [ ] Start a timer, sleep the Mac for a few minutes, wake it: one alert says when you went idle and
      which project is running.
- [ ] Remove idle time: the entry ends at the idle time and the timer continues from now.
- [ ] Repeat with ⌃⌘Q (lock screen) and unlock; repeat with no input past the idle threshold.
- [ ] Remove & stop leaves the timer stopped; Keep changes nothing.
- [ ] No alert appears when no timer was running.

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

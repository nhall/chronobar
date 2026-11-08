# Using the app

The parts of the app, the Panel's keys, idle handling and Settings.
[Back to the README](../README.md)

## The parts

- **Label**: the name you file time under, such as "Northwind, Ticket 665" or "Internal meeting".
  You type it; there are no clients, projects or tasks to set up. Each Label has its own timer.
- **Pill**: Chronobar's item in the menu bar. It shows how many timers are running and today's total.
- **Panel**: the window that opens under the Pill. It lists each Label's time for a Day, with buttons
  to start and pause its timer.
- **Total** and **Clock time**: the Total adds up every Label's time, so two timers running side by
  side for an hour make 2:00. Clock time is how long any timer was running, counting overlaps once:
  1:00 for that same hour. Time you log by hand counts toward the Total only.

## The Pill

The Pill sits in the menu bar. Its left square shows how many timers are running (`1`, `2`, …) on a
colored background, or `0` on gray when none are. The right side shows today's total across all
Labels (`1:23`), ticking while any timer runs. Any click on the Pill opens the Panel, where you start
and pause timers; the global shortcut you can record in Settings opens it too.

## The Panel

The Panel shows the Day you are viewing, a strip with the week's daily totals, and one row per Label
with its total for that Day.

- Each of today's rows ends with a ▶ button that starts that Label's timer. Every running row is
  highlighted and shows ⏸ to pause just that timer.
- A row whose timer an agent started shows a small terminal icon; hover over it for "Started by an
  agent; not paused for idle time".
- Above the rows, the Total line shows the Day's total and its clock time
  (`Total 3:17 · Clock time 3:00`). See [Data format](data-format.md#clock-time).
- Use ＋, under the rows, to start a new Label or to log time you forgot to track. Its form opens just
  above it, and a new Label's row appears at the bottom of the rows, right above the form. The Label
  field suggests Labels used in the last 30 days and pinned ones; right-click a suggestion to pin or
  archive it.
- Click a row's time to change its total: type `1:15` to set it, or `+15` and `-10` to change it.
- The header shows the date, (i) and ⚙. (i) opens the Time Summary: today, yesterday, this week and
  this month, each with its clock time.
- ‹ › move a week back or forward without limit. On any Day other than today, ＋ only logs time and
  rows have no ▶, so you can fix last week or log a vacation ahead. While you view another Day, a
  Today button under the strip brings you back, as does clicking the date.
- On a Day with more rows than fit, the Panel stops just above the bottom of the screen and only the
  rows scroll; the header, the strip, the Total line and ＋ stay in view.

## Keys in the Panel

The keys work wherever focus is, with or without Keyboard navigation turned on:

| Key | Does |
|---|---|
| ⌘[ and ⌘] | Move a week back or forward. |
| ← and → | Move a Day back or forward (unless you're typing in a field, where they move the insertion point). |
| ⌘T | Go back to today. |
| ⌘N | Open ＋. |
| ⌘I | Open or close the (i) Time Summary. |

Each control's help tag names its key. Like menu shortcuts, the keys follow your keyboard layout: ⌘[ is
⌘ with whatever types `[` (⌘⌥5 on German, ⌘⌥⇧5 on French), and ⌘T is ⌘ with the key that types `t`. On
layouts such as Russian, which type Latin letters with ⌘ held, the keys are where they are on a US
keyboard.

With Keyboard navigation on, Tab, Space and Return reach every control. VoiceOver reads the Pill
("2 timers running, 1 hour 23 minutes today"), every control in the Panel, and each row's name, total
and state.

## Timers side by side

Several timers can run at once, one per Label. Starting a Label leaves the others running, and starting
one that is already running keeps it going. Turn on "Starting a timer pauses the others" in Settings to
have each start pause every other timer instead.

## Idle, quitting and long-running timers

- If you come back to a running timer after the Mac slept, locked, or sat with no input, Chronobar asks
  whether to remove the time you were away. One alert covers every timer you started in the app, and
  your answer applies to all of them. Timers an agent started are left out: the agent's work goes on
  while you're away.
- Quitting Chronobar stops the timers you started in the app and leaves agents' timers running; they
  continue when it opens again. After a crash, the app's timers bring up the idle alert on the next
  launch, and agents' timers keep running.
- A timer still running after 4 hours raises a notification naming its Label, once per run, with a
  Stop button that stops it then. Chronobar never stops or trims it by itself. Pick 2 to 8 hours, or Off, in Settings.
- Every timer running past midnight is split, so each Day holds its own time.

## Settings

Settings has the running color, Show in Dock, Start at login, the Open Panel shortcut, "Starting a timer
pauses the others", how long without input counts as idle (Off, or 5 to 60 minutes; it applies to
timers started in the app), and when to warn about a long-running timer (Off, or 2 to 8 hours).

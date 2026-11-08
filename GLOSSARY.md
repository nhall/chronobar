# Chronobar

A macOS menu bar time tracker whose timers run side by side, one per Label, and which AI agents start,
stop and correct as readily as the user does by hand.

## Time

**Label**:
The free-text name a Timer and its Entries are filed under, such as "Northwind, Ticket 665". Flat: no
clients, projects or tasks; names match regardless of case and surrounding spaces.
_Avoid_: Project (v1's name, still used by the code and the Day files' `project` key), task, client

**Timer**:
A running timed Entry for one Label. Several run at once, at most one per Label, so a Label identifies
its Timer.
_Avoid_: Timer ID, session timer, stopwatch

**Source**:
Who started a timed Entry: `app` (the Pill, the Panel or the shortcut) or `agent` (MCP or the command
line).
_Avoid_: Origin, owner

**Entry**:
One stretch of time on one Day for one Label: _timed_ (a start, an end that is empty while running, and
a Source) or _manual_ (a signed number of seconds, logged by hand or as an adjustment).
_Avoid_: Record, line item (fine in user-facing prose for a manual or finished Entry, not as a term)

**Day**:
One local calendar date and the Entries on it. Every Timer running past midnight is split so each Day
holds only its own time.
_Avoid_: Date (for the concept), log

**Total**:
The sum of Labels' time over a Day, a week or a longer period. With Timers side by side it can exceed
the Clock time.
_Avoid_: Day total (fine for a Day's Total specifically), hours, billed time

**Clock time**:
The time on a Day covered by at least one timed Entry, overlaps counted once. Manual Entries add to the
Total but never to Clock time.
_Avoid_: Elapsed time (the spec's name, still used by the code and the `elapsed_seconds` key), wall time

## Labels

**Pinned Labels**:
Labels the user keeps in the suggestions whatever their use.
_Avoid_: Favorites, projects list

**Archived Labels**:
Labels the user has hidden from the suggestions; their time stays. Starting, logging or pinning one
brings it back.
_Avoid_: Deleted Labels, hidden Labels

## Agents

**Session**:
One agent conversation, served by its own MCP server process, which remembers the Labels it started so
"stop the timer" means that Session's Timer.
_Avoid_: Connection, client

## Interface

**Pill**:
Chronobar's menu bar item: the count of running Timers and today's Total.
_Avoid_: Status item, menu bar icon

**Panel**:
The window that opens under the Pill, listing each Label's Total for the viewed Day; today's rows each
have a start and pause button.
_Avoid_: Popover, popup, menu

**Week strip**:
The row of the viewed week's Days, each with its Total, under the Panel's header.
_Avoid_: Calendar, week bar

**Time Summary**:
The (i) view of Totals and Clock times for today, yesterday, this week and this month.
_Avoid_: Report, stats

## Safety

**Idle time**:
The stretch while the Mac slept, locked or had no input with a Timer running. Chronobar offers to
remove it, and only from Timers whose Source is `app`.
_Avoid_: Away time, inactivity

**Heartbeat**:
The app's last-alive time, recorded every minute while it runs, which bounds the Idle time offered after a crash.
_Avoid_: Last seen, ping

**Long-running warning**:
The one notification per Timer start when a Timer passes a threshold (4 hours by default), with a Stop action.
It never cuts time on its own.
_Avoid_: Timeout, auto-stop

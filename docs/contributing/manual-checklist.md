# Manual test checklist

The hand checks to run before a release: menu bar, Panel, accessibility, logging time, idle, quitting,
command line, agents, the long-running warning, Dock, Start at login and install.
[Back to AGENTS.md](../../AGENTS.md)

The timing logic is covered by `swift test`. The menu bar, Panel and system behavior are checked by
hand. Run through this list before a release (see [Releasing](releasing.md)), on the Homebrew build, except
the Command line and Agents (MCP) sections, which use the development copy. Don't use a Mac whose real data
you care about, or back up the data folder first.

Mark anything that isn't built yet *(not built yet)*, and update this list as features land.

**Start, pause, switch**

- [ ] With no Timer running, the square shows `0` on gray, in the same digit style as a running count,
      dark on the gray in light and dark mode, white with Increase Contrast on in light mode. The gray is
      lighter than the Gray running color, and lighter again with Increase Contrast on in dark mode. Click it, then the time segment: each opens the
      Panel, and no Timer starts.
- [ ] ＋, type a new Label, Start: the square turns colored with `1` and the time starts at `0:00`.
      The form closes back to the rows, the new Label's row is highlighted, and the Panel stays open.
- [ ] ＋ sits at the bottom of the Panel, on its left edge: under "No time tracked" on an empty Day, and
      under the last row with one row and with many. The header shows the date, (i) and ⚙, and no ＋
      and no total.
- [ ] Click ＋: its form opens under the rows, just above ＋, with the Label field focused; the Panel
      grows smoothly and stays attached to the Pill. Click ＋ again: the form closes and the Panel
      shrinks back smoothly. Start or Log a new Label: its row appears last, right above where the
      form was.
- [ ] With enough rows to pass the bottom of the screen (add Labels, or hand-edit a Day file): the
      Panel stops a little above the bottom of the screen's visible area, above the Dock, still
      attached to the Pill, with the Total line whole above the rows. The rows scroll with the
      trackpad or mouse wheel; the header, the Week strip, the Total line and ＋ stay put, and so does
      the ＋ form when open. Start or Log a new Label: the rows
      scroll to its row. Tab or ⇧Tab onto a row out of view: the rows scroll to it, and the Panel's
      keys still work. With a few rows there is no scroll bar and the Panel is as tall as its content.
      Repeat with the Pill on a smaller external display, if you have one.
- [ ] Click outside the Panel: it closes.
- [ ] After a minute the time reads `0:01`; the Day file has one Entry with `"end": null`.
- [ ] Click the row's ⏸: the square goes gray with `0`, the time stays, the Entry now has an `end`.
- [ ] Click the row's ▶: the same Label resumes on its row and its total keeps counting from where it
      was.
- [ ] With a Timer running and the Panel closed, click the square on its edge, its middle, the time
      segment and the gap between them: each click opens the Panel and the Timer keeps running. With
      the Panel open, a click anywhere on the Pill closes it, it stays closed, and the Timer keeps
      running. Repeat that close with the press held for a second or two before release.
- [ ] Repeat both with a trackpad (tap to click and a full press) as well as a mouse.
- [ ] ⌘-drag the Pill along the menu bar: it moves, and the Panel doesn't open.
- [ ] With Reduce Motion on (System Settings › Accessibility › Display), open the Panel and click the
      Pill: the Panel closes and stays closed.
- [ ] Press and hold the Pill: the menu bar's brief highlight shows behind it and goes on release, in
      light and dark menu bars.
- [ ] With the Panel open, there is no highlight behind the Pill.
- [ ] With a second display, the same on its copy of the Pill: the highlight on press, a click opens
      the Panel, and no highlight while it's open.
- [ ] With the Pill in the « overflow (⌘-drag it there, or fill the menu bar until it moves there), the
      chevron and the neighboring items click normally.
- [ ] In another app's full screen, clicks near the menu bar, including the band beside the camera
      housing, reach that app.
- [ ] With "Automatically hide and show the menu bar" on, the first click on the Pill once the menu bar
      has slid in opens the Panel.
- [ ] Rest the pointer on the Pill without moving it (for example after the Pill appears under it), then
      click: the Panel opens.
- [ ] Start a second Label from ＋: the first keeps running, the Day file has two Entries with
      `"end": null`, both rows are highlighted with ⏸, the square shows `2`, and the Pill's time is the
      sum of both, going up by two minutes each minute. Start a third: the square shows `3`.
- [ ] Each of today's rows shows its time, then ▶ at the far right; every running row shows ⏸ instead
      and is highlighted. Rows on any other Day have no button.
- [ ] Type a running Label in ＋ and Start: nothing changes; its row keeps counting, with no
      new Entry and no alert.
- [ ] Click one running row's ⏸: only that Timer pauses, its row loses its highlight and shows ▶, and
      the other keeps running and the square shows `1`. Pause the last one: the Pill's square goes gray
      with `0` and the time stops.
- [ ] In Settings, the shortcut is labelled "Open Panel shortcut". Record one, and with zero, one and two
      Timers running and another app in front, press it: the Panel opens under the Pill with every Timer
      as it was. A shortcut recorded in an earlier version still works.
- [ ] In Settings, "Starting a timer pauses the others" is off. Turn it on, start two Labels one after
      the other: the first pauses. Turn it off: starting another leaves the running one running.
- [ ] With two Timers running before midnight, wait past it (or set the clock): both Entries end at
      midnight in the old Day's file and both continue in the new Day's file.
- [ ] Clicking a row's time still opens the field to change its total; ▶/⏸ does not.
- [ ] ＋, click ▾ in the Label field (or press ↓): Labels used in the last 30 days and pinned ones
      are listed, most recently used first, and the list scrolls when long. Type part of a name: the list narrows to names containing it, those
      starting with it first. Clicking one, or ↓ to it and Return, fills the field, closes the list and
      starts nothing; Start (or Return) then starts it.
- [ ] With `test`, `test 2` and `test 3` (started in that order), type `test`: `test` is listed first and
      the field keeps `test`; Return starts `test`.
- [ ] The line under the field reads New Label for a new name and Existing Label for a suggested,
      archived or long-unused one. Pin, shown for one not pinned, adds its line to `projects.txt`.
      Archive, shown for a suggested Label, moves it to `archived.txt`, drops it from the list and
      empties the field; its rows and totals stay.
- [ ] With the list open, right-click a name (and Control-click, and a two-finger trackpad click): the
      menu reads Pin “name” (unless it is pinned) and Archive “name”, for the name under the pointer,
      not the highlighted one. Archive drops it from the open list, which stays open; Pin keeps it there,
      and it is still listed after 30 days without use. The field keeps what was typed unless it held
      the archived name. Right-click below the last name: no menu.
- [ ] Clicking a name in the list, or right-clicking it, leaves the Panel open and the insertion point
      in the field; typing goes on narrowing the list.
- [ ] With the list open: ↓ and ↑ move the highlight one name at a time and the field shows it, and the
      list scrolls to keep it in view; ↓ stops on the last name; ↑ from the first goes back to what was
      typed. Escape closes the list and leaves the field as it is; a second Escape closes the Panel. Tab
      closes the list and moves on to the duration field. The list closes when the Panel closes.
- [ ] Open the list near the bottom of the screen (many rows, or the Pill on a short display): the list
      shows above the field instead of off screen. It is as wide as the field and ▾, and its rows and
      shadow read clearly in light and dark mode.
- [ ] Type an archived Label in different case and Start: its row uses the spelling it was archived
      with, it is listed again, and its line is gone from `archived.txt`.
- [ ] Add a name to `archived.txt` by hand and reopen the Panel: it is no longer listed.
- [ ] With VoiceOver on, the Label field is announced as a combo box, with whether its list is open;
      ↓ and ↑ read each name with its place ("Client B, 2 of 3"); with the list open, VoiceOver can move
      into it (VO-→ or the window chooser) and read it as Suggestions; New Label / Existing Label is read
      when it changes; ▾ reads as Suggestions; Tab reaches Pin and Archive with keyboard navigation on.
- [ ] Type a Label in different case with extra spaces: it starts on the existing row.
- [ ] The Pill reads clearly in light and dark menu bars and on a notched display.
- [ ] In Settings, open Running color in light and in dark mode: each option's dot is the color it
      names, and Accent color's dot matches the accent in System Settings › Appearance, changing
      when you pick another accent there.
- [ ] With a Timer running, pick yellow, mint, blue and Accent color in turn, in light and dark mode
      and with Increase Contrast on and off: the running count in the Pill's square reads clearly on each
      (white on dark colors, black on light ones, including blue).
- [ ] In light and dark mode, with Increase Contrast on and off and whatever running color is picked:
      today's date in the Week strip is on a circle in the text color, drawn in the opposite color
      (black on white in dark mode, white on black in light mode), never on the running color.
- [ ] With several rows, one running, in light and dark mode, with Increase Contrast on and off and
      whatever running color is picked: no row has the running color or the accent color behind it. The
      running row has a quiet gray highlight, with its name, total and ⏸ in the normal text color; the
      other rows' ▶ are gray. ‹ ›, (i), ＋ and ⚙ are gray or the text color, never the accent color.

**Accessibility**

- [ ] With VoiceOver on, move to the Pill (⌃F8 or the VoiceOver menu bar commands) with zero, one and
      two Timers running: it reads the count and today's Total in words: "Nothing running, 45 minutes
      today", "1 timer running, 1 hour 23 minutes today", "2 timers running, …". VO-Space opens the
      Panel; VO-⌘-Space offers no actions.
- [ ] With VoiceOver on and another app in front, press the global shortcut: VoiceOver says "Panel
      opened" and what the Pill reads ("Panel opened. 2 timers running, 1 hour today"), and no Timer
      changes. With VoiceOver off, the shortcut says nothing.
- [ ] In the Panel, VoiceOver reads a label for every control: the date, Time Summary, Menu, Previous
      week and Next week, each Day in the Week strip with its date, total, and "today" or "viewed" (the
      viewed Day also reads as selected), the Total line as one element ("Total 3 hours
      17 minutes, clock time 3 hours"), each row's name (with "running" on
      the running row), its total and Start or Pause, then, with the ＋ form open, Duration in the form,
      and last Start or log time (＋) under it. Each Time Summary line reads as one: "This week 12 hours 5 minutes, clock time 9 hours".
- [ ] With Differentiate Without Color on, view a Day other than today: the viewed Day has a ring and
      today's date is bold, so they differ without color.
- [ ] With Increase Contrast on, the Pill's time segment is opaque, darker, and outlined; with Reduce
      Transparency on it is opaque. Check both in light and dark menu bars.
- [ ] With Keyboard navigation on (System Settings › Keyboard), open the Panel from the Pill with ⌃F8 and
      Space, then use Tab, Space and Return alone to: view another Day, move a week each way, go back to
      today, start and pause a row, change a row's total and its Label (Escape cancels each), open (i)
      and ＋, Log time,
      open the ⚙ menu and each of its items. Escape closes the Panel.
- [ ] With Keyboard navigation off (the macOS default), open the Panel and, without the mouse: ← and →
      move the viewed Day, past the strip's ends into the next or previous week; ⌘[ and ⌘] move a week;
      ⌘T goes back to today; ⌘N opens ＋ with the Label field focused; ⌘I opens the (i) Time Summary
      and ⌘I again closes it. Repeat with Keyboard navigation on and focus on a strip Day or a row.
- [ ] In the ＋ form's Label and duration fields and in a row's adjust field, type some text: ← and →
      move the insertion point and ⌘← ⌘→ ⇧← ⌥← edit and select as usual, without changing the Day;
      ⌘A, ⌘C and ⌘V work. ⌘[ ⌘] ⌘T ⌘N ⌘I still work from those fields.
- [ ] Add German, French, Dvorak and Russian in System Settings › Keyboard › Text Input and, with each
      selected, check the keys above: ⌘ with whatever types `[` and `]` moves a week (⌘⌥5 and ⌘⌥6 on
      German, ⌘⌥⇧5 and ⌘⌥⇧- on French), ⌘T ⌘N ⌘I work where the layout types t, n and i (on Russian, at
      the US positions), and typing `[` (⌥5 on German) in a field types it. On US, ⌘⇧[, ⌘⌥[ and ⌘⇧T don't
      move a week or go to today.
- [ ] Hover over ‹, ›, a strip Day, the Today button, the date (on another Day), ＋ and (i): each help
      tag names its key.
- [ ] With the Settings window in front, the Panel's keys do nothing there.

**Logging and adjusting time**

- [ ] ＋, pick a Label, type `1:30`: the button reads Log; Log adds 1:30 without starting a Timer.
      The form closes back to the rows, the row shows the new total, and the Panel stays open.
- [ ] On a past or future Day, ＋ reads Log and stays disabled until a duration is typed; it never
      starts a Timer.
- [ ] Click › past the current week, then a Day there: its rows and totals show, with no ▶/⏸. Log
      `8:00` there: the Day's Total and its column in the strip read `8:00`, a new file appears for it
      in the data folder's `days` folder, and the (i) week and month Totals include it when that Day
      falls in them. Click its row's time and adjust it, as on a past Day.
- [ ] Keep clicking ›: it goes on into later weeks without stopping; ‹ comes back to any past week.
- [ ] On today there is no Today button. Click a past Day, then a Day weeks ahead: a Today button
      shows at the right under the strip each time, and ‹ › stay where they were. Click it: today's
      rows and the week containing today show, and the button is gone.
- [ ] From a past or future Day, click the date header instead: it also returns to today.
- [ ] Repeat with the longest weekday (Wednesday) and a two-digit total (hand-edit a Day file to over
      10 hours): the header, strip, Today button and Total line fit without truncating or overlapping,
      and the Total line reads in full (`Total 12:30 · Clock time 11:00`). Hovering it shows a help tag
      saying Clock time counts the time when any Timer was running, overlapping Timers once, and
      doesn't include time logged by hand.
- [ ] The Total line sits between the Week strip (or the Today button) and the rows, "Total" lined up
      with the rows' names and each figure right after its words (`Total 3:17 · Clock time 3:00`), not
      pushed to the right. Both figures are the same size. An empty Day shows only "No time tracked",
      with no Total line. The whole line is gray, so it never reads as a row.
- [ ] With two Timers running side by side for 10 minutes, the Total line reads
      `Total 0:20 · Clock time 0:10`; with no overlap the two times match, and logging `1:00` with ＋
      raises the total only. Open (i): each line reads like `Today 0:20 · Clock time 0:10`, the Clock
      time in gray, hovering it shows the same help tag, and VoiceOver reads it as one:
      "Today 20 minutes, clock time 10 minutes".
- [ ] With rows whose seconds don't fall on the minute (for example two Timers started 30 seconds
      apart), the rows' minutes always add up to the Total line's, and VoiceOver reads each row's
      time as shown. `chronobar day` shows the same row times and total as the Panel.
- [ ] On a Day whose rows need apportioning (as above), the Panel, `chronobar day` and that Day's line
      in `chronobar week` show the same Total and Clock time, and `chronobar day --json` gives each
      row's `total_minutes` as the Panel shows it. `chronobar week --json`'s `total_minutes` matches the
      `chronobar week` text's last line, and the Labels' week lines add up to it.
- [ ] Click a row's time, type `1:15`, Return: the row reads `1:15`. Try `+15` and `-10` too.
- [ ] `-9:00` on a short row stops at `0:00`; a typo like `1:7x` beeps and changes nothing.
- [ ] Adjusting the running row keeps the Timer running from the new total.
- [ ] Click a stopped row's Label: it turns into a Label field holding the Label, focused, with ▾ and
      the ＋ form's suggestions. Type a new Label, Return: the row reads the new Label with the same
      time, and the Total line, Week strip, (i) Time Summary and Pill don't change. The same Label on
      another Day keeps its name.
- [ ] Pick a suggestion with ↓ and Return, then Return again: the row moves to it. Escape with the list
      open closes the list; Escape again cancels and the row is as it was. Return on the unchanged
      Label closes the field and changes nothing.
- [ ] While one row's Label field is open, click another row's time: the Label field closes. Clicking a
      Label closes an open time edit the same way, and moving to another Day closes either.
- [ ] Relabel a row on a past Day: only that Day's row changes.
- [ ] With a `Northwnd` row (0:30) and a `Northwind` row (1:00) that don't overlap, click `Northwnd` and
      type `northwind`: beside the field it reads "merges with Northwind (1:00)", readable while the
      suggestions are open. Typing `Northwnd` again, or `NORTHWND`, or a Label with no row that Day, hides
      it. Return: one `Northwind` row of 1:30, with the Total line and Clock time unchanged.
- [ ] Pin a Label spelled `northwind` and relabel its row to `Northwind`: the row, the row on other Days
      and the pinned suggestion all read `Northwind`. An archived Label respelled this way stays
      archived. Relabel a row onto an archived Label: it shows in the suggestions again.
- [ ] Beeps and keeps the field open, changing nothing: an empty Label, the running row (in other
      capitals too), a merge into a row whose timed time overlaps it, and a merge into the running row.

**Idle after sleep and lock**

- [ ] Start a Timer, sleep the Mac for a few minutes, wake it: one alert says when you went idle and
      which Label is running.
- [ ] Remove idle time: the Entry ends at the idle time and the Timer continues from now.
- [ ] Repeat with ⌃⌘Q (lock screen) and unlock; repeat with no input past the idle threshold.
- [ ] In Settings, Idle after no input for is a pop-up of Off, 5, 10, 15, 20, 30, 45 and 60 minutes,
      15 on a first launch. Pick 5 minutes with a Timer running and leave the keyboard and mouse
      alone: the alert comes after about 5 minutes, without relaunching.
- [ ] Pick Off: no alert after an hour without input, but sleep and lock still bring it up.
- [ ] Remove & stop leaves the Timer stopped; Keep changes nothing.
- [ ] No alert appears when no Timer was running.
- [ ] Start a Timer, break today's Day file by hand (delete a brace), sleep and wake, Remove idle time:
      a second alert names the broken file and the Timer keeps counting. Fix the file: within a second
      the idle alert comes back, from the idle time to when you first answered; Remove idle time keeps
      the time since that first answer.
- [ ] Repeat, but after the second alert lock the screen and unlock it before fixing the file: no
      alert. Fix the file: one alert, from the first idle time up to now.
- [ ] The alert's times read as the Panel's do, with no date for a time today. Sleep with a Timer
      running before midnight and wake after it: the start shows its date (`Nov 3, 2026 at 11:50 PM`).

**Quit and crash recovery**

- [ ] Quit from the ⚙ menu with a Timer running: the Entry ends at the quit time; relaunching shows
      no alert and no Timer.
- [ ] Start a Timer, wait two minutes, `killall -9 Chronobar`, wait a few minutes, relaunch: one alert
      says you've been idle since about the kill time; Remove idle time ends the Entry there.
- [ ] Repeat, but kill it before midnight and relaunch the next day: the old Day's Entry is found and
      the alert covers the time since.
- [ ] Repeat, but break today's Day file by hand before relaunching: no alert and no Timer. Fix the
      file and open the Panel: the idle alert appears for the time since the kill.

**Command line**

Try these against the [development copy](development.md#a-development-copy) (`chronobar --dev …`) unless you are checking the Homebrew build.

- [ ] With the app running, `chronobar start "Client A"` prints `Started Client A at HH:MM.` and the
      Panel shows a highlighted Client A row with a terminal icon after the name; hovering over the
      icon shows "Started by an agent; not paused for idle time". The Day file's Entry has
      `"source": "agent"`.
- [ ] `chronobar status` lists Client A with its time and "started by an agent", then today's Total and
      Clock time (`Today: Total 0:10 · Clock time 0:10`). A Timer started with ▶ in the Panel is
      listed too, without "started by an agent", and its row has no terminal icon.
- [ ] `chronobar start "client a"` again: "Client A was already running, since …"; there is still one row.
- [ ] With two Timers running, `chronobar stop` stops nothing, exits 1 and lists both;
      `chronobar stop client a` stops just that one, and the Pill and Panel update within a second.
- [ ] With one Timer running, `chronobar stop` stops it; with none, it exits 1 with "No timer is running."
- [ ] `chronobar --json status` prints one line of JSON with `"ok":true` and times with a UTC offset;
      `chronobar --json stop` with nothing running prints `"ok":false` and `"kind":"nothing_running"`.
- [ ] `chronobar day` shows the same rows, totals and Clock time as the Panel, with "running" on running
      rows; `chronobar day <a past date>` matches the Panel on that Day; `chronobar day 2026-11-31` exits 1.
- [ ] `chronobar week` shows the same daily Totals as the Week strip, and each Label's total for the
      week; `chronobar week <a date last week>` matches the strip after ⌘[.
- [ ] `chronobar summary` matches the (i) Time Summary.
- [ ] `chronobar labels` matches the ＋ form's list; `chronobar pin X` adds X to it at once (open the ＋
      form again) and to `projects.txt`; `chronobar archive X` takes it off both and adds it to
      `archived.txt`, its row and time stay. `chronobar archive Nonsense` exits 1 and changes nothing.
- [ ] `ls -l` on the data folder shows `chronobar.sock` as `srw-------`.
- [ ] With the previous release's app running, the new `chronobar status` exits 1 with "The running
      Chronobar is older than this command. Quit Chronobar and run the command again."; `chronobar
      --json status` prints the app's answer and exits 0; over MCP, `status` is a tool error with the
      same message. After quitting the app, `chronobar status` launches the new one and works.
- [ ] Quit the app, then run `chronobar status`: the app launches in the background without coming to
      the front, and the status prints. The same with the app never opened since a restart.
- [ ] While the idle alert is open, `chronobar status` still answers.
- [ ] Copy `chronobar` out of `build/bin` on its own, to a folder with no app beside it: on a Mac where
      the app was never opened, `chronobar status` exits 3 saying it couldn't find Chronobar and to
      open it once.
- [ ] `chronobar --dev status` reaches only the development copy, with the everyday copy running too.
- [ ] Start Client A, wait a few minutes, then `chronobar stop client a --at HH:MM` with a minute in
      between: it prints the stored start and end and Client A's total; the Panel row shows that total.
      `--at` a minute ahead exits 1 with "is in the future" and the Timer keeps running.
- [ ] `chronobar start "Client A"`, then `chronobar set-start --at HH:MM` an hour earlier: the Panel
      row jumps by an hour and the Pill's time with it.
- [ ] `chronobar add Client B --start 9:00 --end 9:30` adds a 0:30 row without a Timer;
      `--end 8:00` exits 1 with "isn't after the start", and running it again for the same times exits
      1 with "already has time".
- [ ] `chronobar add Client B --duration 15 --day YYYY-MM-DD` for yesterday: that Day in the Panel
      shows the extra 0:15. `chronobar adjust Client B -10` takes 0:10 off today's total.
- [ ] `chronobar relabel Client B --to Client C, Ticket 665 --day YYYY-MM-DD` for yesterday prints
      "Relabeled as Client C, Ticket 665 on …" with its total, and yesterday's Panel row reads the new
      Label while today's Client B row stays. `chronobar relabel Client B --to Client C` with Client C
      already having time today merges the rows and prints the combined total; with Client C's timed
      time overlapping Client B's, it exits 1 with "already has time" and changes nothing.

**Agents (MCP)**

Register the development copy in your client under a name of its own (in Claude Code,
`claude mcp add chronobar-dev -- <path>/build/bin/chronobar --dev mcp`), and remove it afterwards.

- [ ] The client lists the thirteen tools, with descriptions, and connects without errors.
- [ ] Ask "start a timer for Client A": the Panel shows Client A running with the terminal icon, and the
      agent repeats the stored start time.
- [ ] A few minutes later, ask it to stop the Timer back at a minute ago: it calls `stop` without a
      Label (or with Client A), the Panel row stops at that time, and the agent gives the stored end and
      Client A's total.
- [ ] Ask "add a line item for Client B from 9:00 to 9:30 today": a 0:30 Client B row appears without a
      Timer.
- [ ] Ask it to "move today's Client B time to Client D": it calls `relabel`, the Panel's row reads
      Client D with the same 0:30, and the agent gives Client D's total.
- [ ] Start Client A from the agent and Client B with ▶ in the Panel, then ask it to "stop the timer": it
      stops Client A only. Start a second Label from the agent and ask again: it stops nothing and asks
      which, listing all three.
- [ ] Start a Timer from the agent, then close the session (quit the client): the Timer keeps running.
      In a new session, "stop the timer" stops nothing and lists it; "stop Client A" stops it.
- [ ] Try the same session in a second MCP client.
- [ ] Register `chronobar mcp` with each setup in [Connecting agents](../connecting-agents.md#setup): Claude Code, Codex, Gemini CLI,
      Claude Desktop and Cursor. Each lists the thirteen tools and can run `status`. Claude Desktop and
      Cursor, opened from the Dock, connect with the full path.

**Long-running warning**

- [ ] In Settings, Warn when a timer runs for is a pop-up of Off, 2, 3, 4, 6 and 8 hours, 4 on a first
      launch.
- [ ] Pick 2 hours and leave a Timer running for 2 hours: the first time, macOS asks whether
      Chronobar may send notifications. Allow: a notification reads "‹Label› is still running" and
      "Running for over 2 hours, since ‹start›. Stop it if it's done.", the start a time with no date. It
      shows even with Chronobar frontmost. It doesn't come back
      while that Timer keeps running, nor after quitting and relaunching with it still running (an
      agent's Timer, which quitting leaves running).
- [ ] Wait a few minutes, then click Stop on the notification: the Timer stops at the click, not at
      the 2-hour mark, and other Timers keep running.
- [ ] Pause and start the Timer again: a new notification comes 2 hours after the new start.
- [ ] Start a Timer at 23:00 with 2 hours picked: the notification comes at 01:00, after the midnight
      split, and gives the start with its date, as in "since Nov 3, 2026 at 11:00 PM".
- [ ] With notifications denied in System Settings › Notifications, nothing appears and the Timer
      keeps running. With Off picked, no notification comes.

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

- [ ] On a Mac with only the Command Line Tools, `brew install nhall/tap/chronobar` succeeds and
      `brew test chronobar` passes.
- [ ] `which chronobar` is in `$(brew --prefix)/bin`. Before opening the app at all, `chronobar status`
      launches it in the background and prints the status.
- [ ] The app opens from `~/Applications` without a Gatekeeper warning.
- [ ] After `brew upgrade chronobar` (or `brew reinstall chronobar`), quit the app and run
      `chronobar status`: it launches the new version (`ps -o command= -p $(pgrep -x Chronobar)` shows
      the new keg's path).

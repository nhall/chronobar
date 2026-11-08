# Data format

Where Chronobar keeps your time, the format of each file, and how totals are counted.
[Back to the README](../README.md)

Chronobar has no accounts, no sync and no network access. The app is the only writer of your data.

Everything lives in `~/Library/Application Support/Chronobar`. The ⚙ menu in the Panel (the window
under the Pill, Chronobar's menu bar item) has **Open data folder**. Time is filed under Labels, the
names you type, such as "Northwind, Ticket 665"; see [Using the app](app.md#the-parts).

```
Chronobar/
  projects.txt          pinned Labels, one per line
  archived.txt          archived Labels, one per line
  chronobar.sock        the socket the chronobar command reaches the app on
  days/
    2026-11-02.json
    2026-11-03.json     one file per Day, named by local date
```

## Day files

Each Day is one JSON file with one Entry per line:

```json
{
  "date": "2026-11-03",
  "entries": [
    { "project": "Website redesign", "start": "2026-11-03T09:02:11-05:00", "end": "2026-11-03T10:47:30-05:00", "source": "app" },
    { "project": "Website redesign", "start": "2026-11-03T13:15:00-05:00", "end": null, "source": "app" },
    { "project": "Northwind, Ticket 665", "start": "2026-11-03T13:40:00-05:00", "end": null, "source": "agent" },
    { "project": "Internal meeting", "seconds": 900, "note": "manual" },
    { "project": "Internal meeting", "seconds": -300, "note": "adjustment" }
  ]
}
```

- `date` must match the file name. `project` holds the Entry's Label (the key keeps its older name so
  older files load unchanged).
- A **timed** Entry has `start` and `end` as ISO 8601 times with a UTC offset, to the second. `end` is
  `null` only for a running timer, at most one per Label. `source` says who started it: `"app"` or
  `"agent"`. Chronobar always writes it; an Entry without it, as in older files, is the app's.
- A **manual** Entry has a whole number of `seconds`, negative for subtractions. `note` is `manual`
  for time logged with ＋ and `adjustment` for a corrected total; it is a marker, not free text.
- Any Day can have a file, past or future: time logged ahead, such as a vacation, goes in that Day's
  file in the same format. Timers run only today, so a Day ahead holds only manual Entries until it
  arrives.
- Every timer running past midnight is split: the old Day's Entry ends at the start of the new Day and
  a new Entry starts in the new Day's file.

### Totals

- A Label's total for the Day is the sum of its timed durations and manual seconds, rounded down to
  the whole second and never below zero (`0:00`). The Day's Total is the sum of its Labels' totals,
  and a week's the sum of its Days', so in JSON the rows always add up to the total exactly.
- Hours and minutes always add up too. A total is rounded down to the minute; the rows under it are
  rounded down as well, and the minutes that loses go one each to the rows with the most seconds left
  over (the first row on a tie). So 2:08:45 and 1:08:49 show as 2:08 and 1:09 under Total 3:17. This
  applies to the Panel's rows and to `chronobar day`.
- A Day's figure is the same everywhere: `chronobar week` shows each Day's own Total, as the Panel and
  `chronobar day` do, and the week's Total is the sum of those Day lines, as is the week's Clock time
  (in JSON too, `elapsed_seconds` is the sum of the Days'). The week's Total can be a few minutes less
  than each Label's week time rounded down and added up, so the Labels' week lines are fitted to it: minutes too many
  come off the Labels with the fewest seconds left over (the first Label on a tie), never below
  `0:00`.

### Clock time

A Day's Clock time (`elapsed_seconds` in JSON) is the time when any timer was running, a running one
counted up to now. Time two timers share counts once, so with timers running side by side it is less
than the Day's Total. Time logged by hand (manual Entries) counts toward the Total only. A Day's Clock
time is rounded down to the minute on its own. The (i) Time Summary's Clock times are the sums of
their Days'.

### Editing by hand

You can edit these files by hand, for example to fix a start time. Chronobar re-reads a Day's file
before every change, so it won't overwrite your edit. If a file stops being valid JSON, Chronobar
leaves it untouched and refuses to change that Day until you fix it.

## Label lists

The ＋ form suggests every Label with time on today or the 29 days before it, plus your pinned Labels,
minus archived ones. Starting or logging a Label doesn't add it to a list; it is suggested for 30 days
after it was last used, then drops out until you type it again.

`projects.txt` is UTF-8 text with one pinned Label per line: pinned Labels are always suggested.
`archived.txt`, in the same format, lists archived Labels, which are never suggested. Right-click a
suggestion, or use the buttons under the field, to pin it (adding its line to `projects.txt`) or
archive it (moving its line to `archived.txt`). Starting, logging or pinning an archived Label takes it
off `archived.txt`, with the spelling stored there.

Neither list touches the Day files, so archiving never loses time. Names match regardless of case and
surrounding spaces, so `internal meeting ` and `Internal meeting` are the same Label. Chronobar re-reads
both files when the Panel opens, and leaves a file that isn't UTF-8 untouched, refusing to pin or
archive until you fix it.

Upgrading from version 1: every line of your old `projects.txt` becomes a pinned Label. Labels you
archived before have no line in `archived.txt`, so any of them used in the last 30 days is suggested
again until you archive it once more.

## Settings

Settings, the app's last-alive time and the long-running timers it has warned about are kept in the
app's preferences (`io.github.nhall.chronobar`), not in the data folder.

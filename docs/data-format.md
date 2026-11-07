# Data format

Where Chronobar keeps your time, the format of each file, and how totals are counted.
[Back to the README](../README.md)

Chronobar has no accounts, no sync and no network access. The app is the only writer of your data, and
it re-reads a file before every change, so a hand edit is never overwritten.

Everything lives in `~/Library/Application Support/Chronobar`. The ⚙ menu has **Open data folder**.

```
Chronobar/
  projects.txt          pinned Labels, one per line
  archived.txt          archived Labels, one per line
  chronobar.sock        the socket the chronobar command reaches the app on
  days/
    2026-11-02.json
    2026-11-03.json     one file per Day, named by local date
```

The [development copy](development.md#a-development-copy) uses `Chronobar Dev` instead.

## Day files

Each Day is one JSON file with one entry per line:

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

- `date` must match the file name. `project` holds the entry's Label (the key keeps its older name so
  older files load unchanged).
- A **timed** entry has `start` and `end` as ISO 8601 times with a UTC offset, to the second. `end` is
  `null` only for a running timer, at most one per Label. `source` says who started it: `"app"` or
  `"agent"`. Chronobar always writes it; an entry without it, as in older files, is the app's.
- A **manual** entry has a whole number of `seconds`, negative for subtractions. `note` is `manual`
  for time logged with ＋ and `adjustment` for a corrected total; it is a marker, not free text.
- Any Day can have a file, past or future: time logged ahead, such as a vacation, goes in that Day's
  file in the same format. Timers run only today, so a Day ahead holds only manual entries until it
  arrives.
- Every timer running past midnight is split: the old Day's entry ends at the start of the new Day and
  a new entry starts in the new Day's file.

### Totals

- A Label's total for the Day is the sum of its timed durations and manual seconds, rounded down to
  the whole second and never below zero (`0:00`). The Day's total is the sum of its Labels' totals,
  and a week's the sum of its Days', so in JSON the rows always add up to the total exactly.
- Hours and minutes always add up too. A total is rounded down to the minute; the rows under it are
  rounded down as well, and the minutes that loses go one each to the rows with the most seconds left
  over (the first row on a tie). So 2:08:45 and 1:08:49 show as 2:08 and 1:09 under Total 3:17. This
  applies to the Panel's rows and to `chronobar day`.
- A Day's figure is the same everywhere: `chronobar week` shows each Day's own total, as the Panel and
  `chronobar day` do, and the week total is the sum of those Day lines, as is the week's clock time
  (in JSON too, `elapsed_seconds` is the sum of the Days'). The week total can be a few minutes less
  than the Labels' time rounded down, so the Labels' week lines are fitted to it: minutes too many
  come off the Labels with the fewest seconds left over (the first Label on a tie), never below
  `0:00`.

### Clock time

A Day's clock time (`elapsed_seconds` in JSON) is the time when any timer was running, a running one
counted up to now. Time two timers share counts once, so with timers running side by side it is less
than the Day's total. Time logged by hand (manual entries) counts toward the total only. A Day's clock
time is rounded down to the minute on its own. The (i) Time Summary's clock times are the sums of
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

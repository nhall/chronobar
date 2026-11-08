# Clock time is the union of timed intervals, and rows always add up

With Timers side by side, a Day's Total can exceed the time that passed, which is correct for billing.
To show how long the user actually worked, Clock time is the union of the Day's timed Entries'
intervals (running ones up to now), so overlapping Timers count once and manual Entries are left out.

In the Panel's rows and in `chronobar day` and `week`, every figure shown under a total adds up to it. Each row is floored to whole seconds and the Day's
Total is their sum. For hours and minutes, the total is rounded down to the minute, the rows are
rounded down too, and the minutes lost go one each to the rows with the largest remainders (the first
row on a tie). A week is built from its Days: its Total and Clock time are the sums of the Day figures,
and the Labels' week lines are fitted to that Total the same way. Rounding each figure on its own
would let rows disagree with the total under them by a minute or two, which reads as a bug on an
invoice, and a Day must show the same figure in the Panel, `chronobar day` and `chronobar week`.

## Consequences

- A row can show a minute more than its own seconds rounded down.
- The Week strip, the Time Summary and the status lines show plain floored figures; only the Panel's
  rows and `chronobar day` / `week` apportion.

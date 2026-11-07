# Labels are flat, and a Label identifies its Timer

Chronobar files time under free-text Labels with no clients, projects or tasks above them, because
the user often types a Label per piece of work ("Northwind, Ticket 665") and a hierarchy would make
every start a picking exercise. At most one Timer runs per Label, so a Label is the Timer's identity:
tools, commands and the Panel address Timers by Label, and there are no Timer IDs. Starting a Label
that is already running keeps its Timer and returns it, so the same work is never counted twice.

## Consequences

- Two concurrent pieces of work need two different Labels; there is no "second timer on the same
  Label".
- An agent can say "stop Northwind, Ticket 665" without first listing Timers to find an ID, and a
  stop with no Label works only when exactly one candidate Timer is running (or the Session started
  exactly one).
- Adding structure later (clients, rates) would be a model change, not a field: it was explicitly left
  out of scope for v2.

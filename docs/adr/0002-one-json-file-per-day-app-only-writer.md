# One plain JSON file per Day, written only by the app

Each Day is one hand-editable JSON file (`days/YYYY-MM-DD.json`), one Entry per line. v2 kept v1's
shape and its `project` key for the Label, so v1 files load unchanged, and added an optional `source`
on timed Entries (missing reads as `app`; v2 always writes it). The app is the only writer; it re-reads
a file before every change so a hand edit is never overwritten, and leaves a malformed file untouched
while refusing to change that Day.

A change that touches several files (a stop reaching back past midnight, an idle removal plus restart,
a start that also takes a Label off `archived.txt`) is saved all or nothing: temp files are written
beside each target, then swapped into place, and rolled back if any swap fails.

## Considered Options

- Renaming the `project` key to `label` when v2 renamed Project to Label: rejected, since it would
  break every existing file for a cosmetic gain. Many code identifiers still say `project` too.

## Consequences

- The command line and MCP server never write files; see ADR 0003.
- Any change to the file format must keep older files loading unchanged.

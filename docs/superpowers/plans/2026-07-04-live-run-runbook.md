# Live-run runbook — GsheetGenie launch proof

**Status:** waiting on Jesse's todo-list item (filed 2026-07-04, "Create GCP
service account + JSON key for GsheetGenie live run"). The script this runbook
describes is ready now; it needs two inputs to leave dry-run mode.

## Why service-account auth (not interactive OAuth)

`googlesheets4::gs4_auth(use_oob = TRUE)` requires `base::interactive()` to be
`TRUE`. Every path an agent has to run R (Rscript, backgrounded or not) reports
`interactive() == FALSE`, so gargle refuses before printing the consent URL —
confirmed by direct test on 2026-07-04. A service account sidesteps this
entirely: the JSON key is a non-interactive credential.

## What's needed (2 things, both Jesse's action)

1. A GCP service-account JSON key with Sheets API + Drive API enabled on its
   project.
2. An empty Google Sheet, shared with that service account's email
   (`...@<project>.iam.gserviceaccount.com`) at Editor access — service
   accounts have no Drive storage of their own, so `gs4_create()` won't work
   for one; a pre-shared sheet is required.

## Running it

```bash
export GSHEETGENIE_SA_KEY=/path/to/key.json
export GSHEETGENIE_SHEET="https://docs.google.com/spreadsheets/d/..."
Rscript docs/superpowers/plans/2026-07-04-live-run.R
```

Without both env vars set, the script runs in **dry-run mode**: it exercises
the full lazy pipeline (`magic.table() |> mutate() |> as_sheet_cells()`) with
zero network calls and prints the formula cells that would be sent. This is
already verified working (see the script's own dry-run output).

## What "success" looks like

- Script prints `provenance()` (source vs. computed columns + expressions).
- Script prints/writes the formula cell tibble.
- In live mode: opens the sheet URL and confirms `=(B2)-(C2)` etc. show as
  live formulas in row 2 (not static values), and the no-clobber path
  (`write_sheet()` called twice) refuses on external edits without
  `overwrite = TRUE`.

# magic.table

An R package. `magic.table()` wraps a data frame in a recorded-computation
table: `dplyr::mutate()` on it records each expression instead of evaluating
it, and an export backend turns the recorded columns into live spreadsheet
formulas. Two backends exist, Excel (`write_excel()`) and Google Sheets
(`write_sheet()`), and both share one no-clobber contract. The package is at
the `experimental` lifecycle stage.

`north_star.md` is the maintainer's own statement of direction. Agents read it
and never edit it. Everything below describes what the code does today; verify
against the code before relying on it, and change this file in the same PR that
changes the behavior.

## How the code is laid out

- `R/magic_table.R` — the object. A `magic.table` is a list `{data, ops,
  backend}` of class `c("magic.table", "tbl")`: `data` is a tibble, `ops` the
  recorded computations in order, `backend` `NULL` until a writer binds one.
  It wraps a tibble rather than inheriting from it; inheriting is an open
  option, not a plan. Both `magic.table(df)` (mirrors `data.frame()`) and
  `as.magic.table(x)` (the coercer, idempotent on a magic.table) are exported.
- `R/mutate.R` — `mutate.magic.table()` captures its named arguments as
  quosures into one `mutate` op. Nothing is evaluated. `mutate` is the only
  recorded verb.
- `R/provenance.R` — `provenance()` derives a per-column `source` / `computed`
  view with the defining expression from `data` + `ops`. No separate state.
- `R/translate.R` + `R/dialect.R` — the pure expression → A1 translator. A
  bare column symbol becomes the current row's cell; calls dispatch through
  the registry `register_sheet_translator()` / `sheet_translators()` edit.
  Whole-column aggregates are not built in; the demo registers a `mean`
  translator to show how.
- `R/write_sheet.R` — `as_sheet_cells()` materializes the formula grid as a
  tibble (pure, no auth: the testability lever for everything), and
  `write_sheet()` is the Google Sheets backend. Its I/O is injectable
  (`.writer`, `.reader`) so the reconciliation tests run offline.
- `R/write_excel.R` — the Excel backend, consuming the same cells. An existing
  workbook keeps its other sheets; a re-written sheet keeps its position.
- `R/write_analytical_table.R`, `R/summary_row.R`, `R/col_letter.R` — the
  original eager helpers (data block flanked by `=SUM(...)`-style summary
  rows). They ship as-is beside the lazy API.

## The backend contract

A writer returns the magic.table bound to its target, invisibly, so the
caller keeps the binding by capturing the result:

- Google Sheets: `backend = list(type = "gsheet", ss, sheet, start_row,
  snapshot)`, snapshot = the written cells as strings.
- Excel: `backend = list(type = "excel", path, sheet, start_row, snapshot)`,
  snapshot = the file's md5 as written.

A re-write to the *same* target compares the live state against the snapshot
and, if it differs, refuses with a warning and returns the input unchanged.
`overwrite = TRUE` writes unconditionally. A different target is a fresh
binding, no comparison. A bound Excel file that no longer exists is written
again without complaint. "Never silently destroy an edit someone made in the
sheet" is the rule behind the default.

Add a backend as a sibling file that consumes `as_sheet_cells()` output and
binds `backend` with its own `type`; the core files stay backend-agnostic.

## Dependencies

Runtime (`Imports`): dplyr, googlesheets4, lifecycle, openxlsx, rlang, tibble.
Dev/test (`Suggests`): testthat, knitr, rmarkdown, withr. openxlsx is the
maintainer's call for the auth-free `.xlsx` path. A new runtime dependency is
the maintainer's decision: ask, with what it buys and what hand-rolling costs.

## Tests and the merge gate

`tests/testthat/` runs with no network and no Google account: every
Sheets-side behavior is exercised through `as_sheet_cells()` or injected
I/O, and the Excel tests read formulas back out of the saved workbook.
`Rscript -e 'devtools::test()'` on the host. `./check` is the exo-watch gate:
it runs the full suite when the package's dependencies are installed, and
otherwise runs only `test-identity.R` (base R + testthat) and names what it
skipped; with no R in the box at all it skips everything, says so, and exits 0
(a skip by substrate, never a red for a wrong box). Which fbox profile the gate runs in is exo's data, not this repo's: exo's
`repo-profiles.tsv` maps this repo to `claude-r`, and no `.exo-profile` ships here.

`tests/testthat/test-identity.R` fails on the maintainer's name anywhere in
the tree outside the system identifiers that carry it by function
(`DESCRIPTION` author field, the LICENSE files, the generated package Rd).
Docs say "the maintainer" or "the user", never a name.

## Verification artifacts

`verification/` holds the offline proof that the formulas evaluate:
`magic-table-demo.qmd` is the narrated walkthrough, `make-demo.R` runs its
chunks to regenerate `demo-formulas.xlsx` (via `write_excel()`) and
`demo-paste.tsv`, and `PASTE-ME.md` says what to open or paste and what
values to expect. Regenerate the artifacts in any PR that changes the
translator or a backend.

## Branches and PRs

Feature branches land on `dev` by PR; `dev` → `main` is the promotion PR
exo-watch opens and the maintainer approves. The package deploys nowhere on
the box; a merge to `main` is the release.

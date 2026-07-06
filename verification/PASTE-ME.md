# Verify: do the formulas actually work?

Same `head(mtcars)` demo — literal data plus two derived columns recorded as lazy
`mutate()`s (`power_to_weight = hp/wt`, `mpg_vs_avg = mpg/mean(mpg)`) and an
`Average` summary row — materialized to real spreadsheet formulas **offline** by
this package (no API, no auth, no token). Two artifacts, three ways to check.

## Artifact 1 — `demo-formulas.xlsx` (real embedded formulas)

Written via **openxlsx** (`writeFormula`), the working token-free Excel backend.

- **Excel / LibreOffice:** just **open the file**. Formulas recalculate on open.
- **Google Sheets:** New sheet → **File ▸ Import ▸ Upload** `demo-formulas.xlsx` ▸
  *Replace spreadsheet* (or *Insert new sheet*). The `=...` cells arrive as live
  formulas and Sheets computes them.

## Artifact 2 — `demo-paste.tsv` (copy-paste route)

- **Google Sheets / Excel:** open a blank sheet → click cell **A1** → paste
  (Ctrl/Cmd-V). Tab-separated cells split into columns; `=...` cells become live
  formulas. Paste target **must be A1** — refs (`B2`, `C2`, …) assume the block
  starts there. (Excel: if it lands in one column, Data ▸ Text to Columns ▸ Tab.)

## What you should see (compare the computed cells to these)

| car | power_to_weight | mpg_vs_avg |
|---|---|---|
| Mazda RX4 | 41.9847 | 1.0244 |
| Mazda RX4 Wag | 38.2609 | 1.0244 |
| Datsun 710 | 40.0862 | 1.1122 |
| Hornet 4 Drive | 34.2146 | 1.0439 |
| Hornet Sportabout | 50.8721 | 0.9122 |
| Valiant | 30.3468 | 0.8829 |

`Average` row → mpg **20.5**, hp **117.1667**, wt **2.9883**, cyl **6**  (mean(mpg) = 20.5).

## Dialect caveats (from `R/dialect.R`)

- **Whole-column aggregates aren't in the built-in dialect.** A bare column symbol
  translates to the *current row's* cell, so `mean(mpg)` alone can't span the
  column. The demo teaches it via the public `register_sheet_translator("mean", …)`
  → an absolute-range `AVERAGE(B$2:B$7)`. The `Average` summary row uses the
  separate `make_summary_row()` path. Built-ins cover arithmetic (`+ - * / ^`),
  comparisons (`==`→`=`, `!=`→`<>`), logicals (`&`→`AND`, `|`→`OR`, `!`→`NOT`),
  `ifelse`→`IF`, and curated math (`abs sqrt round pmin`→`MIN` `pmax`→`MAX`
  `is.na`→`ISBLANK`).
- Operands are defensively parenthesized (`=(C2)/(D2)`) — noisy but correct.
- Regenerate both artifacts anytime: `Rscript verification/make-demo.R`.

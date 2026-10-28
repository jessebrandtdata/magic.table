# magic.table

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

> Turn an R data frame into a live-formula table.

magic.table builds external tables whose derived columns are **live formulas**
rather than pre-computed values, via
[googlesheets4](https://googlesheets4.tidyverse.org/). It focuses on the
formula-and-layout logic — no formatting or styling features.

## Installation

```r
# install.packages("pak")
pak::pak("jessebrandtdata/magic.table")
```

## The magic.table

`magic.table()` wraps a data frame in a **recorded-computation table**: a lazy
`dplyr::mutate()` records each tidy expression as column provenance instead of
evaluating it, and the result is exported as live formulas to an external table:
an Excel workbook or a Google Sheet today.

```r
library(magic.table)
library(dplyr)

ss <- googlesheets4::gs4_create("Q1 sales")

tibble::tibble(region = c("E", "W"), sales = c(120, 80), cost = c(40, 30)) |>
  magic.table() |>
  mutate(margin     = sales - cost,     # -> =(B2)-(C2), …
         margin_pct = margin / sales) |># -> =(D2)/(B2), …
  write_sheet(ss, sheet = "Sales", start_row = 1)
```

The same table goes to an `.xlsx` file with no account and no token; Excel
recalculates the formulas on open, and Google Sheets imports the file with
them intact:

```r
mt <- tibble::tibble(region = c("E", "W"), sales = c(120, 80), cost = c(40, 30)) |>
  magic.table() |>
  mutate(margin = sales - cost) |>
  write_excel("q1-sales.xlsx", sheet = "Sales")
```

Both writers hand back the magic.table **bound** to its target. A later write to
the same target is refused with a warning if the sheet or file changed in the
meantime; pass `overwrite = TRUE` to write anyway.

Preview the cells that *would* be written — no auth, no network — with
`as_sheet_cells()`. Extend the R→spreadsheet dialect with
`register_sheet_translator()`.

## Eager summary tables

The original helper writes a data table flanked by live-formula summary rows:

```r
library(magic.table)
library(googlesheets4)

ss <- gs4_create("Q1 sales analysis")

write_analytical_table(
  ss,
  sales_q1,
  sheet     = "Sales",
  title     = "Q1 Sales by Region",
  summaries = c(Total = "SUM", Average = "AVERAGE")
)
```

The sheet ends up laid out as:

| Row | Content                              |
| --- | ------------------------------------ |
| 1   | Title ("Q1 Sales by Region")         |
| 2   | (blank)                              |
| 3   | Column headers                       |
| 4–N | Data                                 |
| N+1 | `=SUM(...)` summary row ("Total")    |
| N+2 | `=AVERAGE(...)` summary row          |

For non-standard layouts, drop down a level: build summary rows with
`make_summary_row()` and append them yourself with `googlesheets4::sheet_append()`.

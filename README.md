# GsheetGenie

> Build analytical Google Sheets from R.

GsheetGenie writes data tables surrounded by live-formula summary rows
(sums, means, etc.) to Google Sheets via
[googlesheets4](https://googlesheets4.tidyverse.org/). It focuses on the
formula-and-layout logic — no formatting or styling features.

## Installation

```r
# install.packages("pak")
pak::pak("jesseabrandt/GsheetGenie")
```

## Usage

```r
library(GsheetGenie)
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

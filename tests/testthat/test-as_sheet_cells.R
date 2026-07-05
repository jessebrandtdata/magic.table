df <- data.frame(region = c("E", "W"), sales = c(10, 20), cost = c(4, 8),
                 stringsAsFactors = FALSE)

# A reusable assertion helper for formula columns.
expect_formula_col <- function(cells, name, expected) {
  col <- cells[[name]]
  # gs4_formula() returns class c("googlesheets4_formula", "vctrs_vctr")
  expect_true(inherits(col, "googlesheets4_formula"))
  expect_equal(as.character(col), expected)
}

test_that("as_sheet_cells passes through original columns unchanged", {
  mt <- magic.table(df)
  cells <- as_sheet_cells(mt, start_row = 1L)
  expect_equal(cells$region, df$region)
  expect_equal(cells$sales,  df$sales)
  expect_equal(cells$cost,   df$cost)
})

test_that("as_sheet_cells materializes a single mutate column per row", {
  mt <- magic.table(df) |> dplyr::mutate(margin = sales - cost)
  cells <- as_sheet_cells(mt, start_row = 3L)
  # start_row = 3 means header at row 3, data at rows 4..5.
  expect_formula_col(cells, "margin", c("=(B4)-(C4)", "=(B5)-(C5)"))
})

test_that("as_sheet_cells respects start_row", {
  mt <- magic.table(df) |> dplyr::mutate(margin = sales - cost)
  cells <- as_sheet_cells(mt, start_row = 1L)
  # start_row = 1 -> header row 1, data rows 2..3.
  expect_formula_col(cells, "margin", c("=(B2)-(C2)", "=(B3)-(C3)"))
})

test_that("as_sheet_cells resolves intra-call self-reference", {
  mt <- magic.table(df) |>
    dplyr::mutate(margin = sales - cost,
                  margin_pct = margin / sales)
  cells <- as_sheet_cells(mt, start_row = 3L)
  expect_formula_col(cells, "margin",     c("=(B4)-(C4)", "=(B5)-(C5)"))
  # margin lands at column D (after region=A, sales=B, cost=C).
  expect_formula_col(cells, "margin_pct", c("=(D4)/(B4)", "=(D5)/(B5)"))
})

test_that("as_sheet_cells handles multiple successive mutate ops", {
  mt <- magic.table(df) |>
    dplyr::mutate(margin = sales - cost) |>
    dplyr::mutate(margin_pct = margin / sales)
  cells <- as_sheet_cells(mt, start_row = 3L)
  expect_formula_col(cells, "margin_pct", c("=(D4)/(B4)", "=(D5)/(B5)"))
})

test_that("as_sheet_cells validates start_row", {
  mt <- magic.table(df)
  expect_error(as_sheet_cells(mt, start_row = 0),    "must be a single positive integer")
  expect_error(as_sheet_cells(mt, start_row = 1.5),  "must be a single positive integer")
  expect_error(as_sheet_cells(mt, start_row = NA),   "must be a single positive integer")
  expect_error(as_sheet_cells(mt, start_row = c(1, 2)), "must be a single positive integer")
})

test_that("as_sheet_cells errors when expression references missing column", {
  mt <- magic.table(df) |> dplyr::mutate(x = profit + 1)
  expect_error(as_sheet_cells(mt, start_row = 1L),
               "column `profit` not found")
})

test_that("as_sheet_cells translates a plain overwrite in place", {
  # Overwriting a column with a formula that references itself is inherently a
  # self-reference in the sheet; we only pin that it lands in the same column.
  mt <- magic.table(df) |> dplyr::mutate(sales = sales * 2)
  cells <- as_sheet_cells(mt, start_row = 1L)
  expect_equal(names(cells), c("region", "sales", "cost"))
  expect_formula_col(cells, "sales", c("=(B2)*(2)", "=(B3)*(2)"))
})

# ---------------------------------------------------------------------------
# CHARACTERIZATION TEST — PINS A KNOWN BUG (do not treat as desired behavior).
#
# BUG: as_sheet_cells() (R/write_sheet.R) appends a new schema entry for every
# materialized column using `col_letter(length(schema) + 1L)` as the letter.
# When an earlier mutate OVERWRITES an existing column, `schema` gains a
# DUPLICATE entry, so its length no longer equals the column count. Every
# computed column added afterwards is then assigned a letter that is one-too-far
# to the right for each prior overwrite, so later formulas that reference those
# columns point at the WRONG cell (here, `x` references column E, but `margin`
# actually lives in column D — E is `x` itself, a broken/circular reference).
#
# When this is fixed, this test SHOULD fail; update it to assert `=(D2)+(1)`.
# ---------------------------------------------------------------------------
test_that("[known bug] overwrite offsets later columns' schema letters", {
  mt <- magic.table(df) |>
    dplyr::mutate(sales = sales * 2) |>   # overwrite -> spurious extra schema entry
    dplyr::mutate(margin = sales - cost) |>
    dplyr::mutate(x = margin + 1)         # references margin (physically column D)

  cells <- as_sheet_cells(mt, start_row = 1L)
  expect_equal(names(cells), c("region", "sales", "cost", "margin", "x"))
  # margin is physically column D:
  expect_equal(match("margin", names(cells)), 4L)
  expect_equal(col_letter(4L), "D")
  # ...but `x` mis-references it as column E (the CORRECT value would be D):
  expect_formula_col(cells, "x", c("=(E2)+(1)", "=(E3)+(1)"))
})

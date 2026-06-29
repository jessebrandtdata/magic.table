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
  sf <- as_sheet_frame(df)
  cells <- as_sheet_cells(sf, start_row = 1L)
  expect_equal(cells$region, df$region)
  expect_equal(cells$sales,  df$sales)
  expect_equal(cells$cost,   df$cost)
})

test_that("as_sheet_cells materializes a single mutate column per row", {
  sf <- as_sheet_frame(df) |> dplyr::mutate(margin = sales - cost)
  cells <- as_sheet_cells(sf, start_row = 3L)
  # start_row = 3 means header at row 3, data at rows 4..5.
  expect_formula_col(cells, "margin", c("=(B4)-(C4)", "=(B5)-(C5)"))
})

test_that("as_sheet_cells respects start_row", {
  sf <- as_sheet_frame(df) |> dplyr::mutate(margin = sales - cost)
  cells <- as_sheet_cells(sf, start_row = 1L)
  # start_row = 1 -> header row 1, data rows 2..3.
  expect_formula_col(cells, "margin", c("=(B2)-(C2)", "=(B3)-(C3)"))
})

test_that("as_sheet_cells resolves intra-call self-reference", {
  sf <- as_sheet_frame(df) |>
    dplyr::mutate(margin = sales - cost,
                  margin_pct = margin / sales)
  cells <- as_sheet_cells(sf, start_row = 3L)
  expect_formula_col(cells, "margin",     c("=(B4)-(C4)", "=(B5)-(C5)"))
  # margin lands at column D (after region=A, sales=B, cost=C).
  expect_formula_col(cells, "margin_pct", c("=(D4)/(B4)", "=(D5)/(B5)"))
})

test_that("as_sheet_cells handles multiple successive mutate ops", {
  sf <- as_sheet_frame(df) |>
    dplyr::mutate(margin = sales - cost) |>
    dplyr::mutate(margin_pct = margin / sales)
  cells <- as_sheet_cells(sf, start_row = 3L)
  expect_formula_col(cells, "margin_pct", c("=(D4)/(B4)", "=(D5)/(B5)"))
})

test_that("as_sheet_cells validates start_row", {
  sf <- as_sheet_frame(df)
  expect_error(as_sheet_cells(sf, start_row = 0),    "must be a single positive integer")
  expect_error(as_sheet_cells(sf, start_row = 1.5),  "must be a single positive integer")
  expect_error(as_sheet_cells(sf, start_row = NA),   "must be a single positive integer")
  expect_error(as_sheet_cells(sf, start_row = c(1, 2)), "must be a single positive integer")
})

test_that("as_sheet_cells errors when expression references missing column", {
  sf <- as_sheet_frame(df) |> dplyr::mutate(x = profit + 1)
  expect_error(as_sheet_cells(sf, start_row = 1L),
               "column `profit` not found")
})

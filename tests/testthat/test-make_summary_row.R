test_that("returns a one-row tibble matching df's column names", {
  df <- data.frame(region = c("E", "W"), sales = c(10, 20), units = c(1L, 2L))
  row <- make_summary_row(df, data_start_row = 4, label = "Total", fn = "SUM")

  expect_s3_class(row, "tbl_df")
  expect_equal(nrow(row), 1L)
  expect_named(row, c("region", "sales", "units"))
})

test_that("numeric columns are gs4_formula-wrapped with correct A1 ranges", {
  df <- data.frame(region = c("E", "W"), sales = c(10, 20), units = c(1L, 2L))
  row <- make_summary_row(df, data_start_row = 4, label = "Total", fn = "SUM")

  expect_s3_class(row$sales, "googlesheets4_formula")
  expect_s3_class(row$units, "googlesheets4_formula")
  expect_equal(as.character(row$sales), "=SUM(B4:B5)")
  expect_equal(as.character(row$units), "=SUM(C4:C5)")
})

test_that("label goes in the first non-numeric column", {
  df <- data.frame(region = c("E", "W"), code = c("a", "b"), sales = c(10, 20))
  row <- make_summary_row(df, data_start_row = 4, label = "Total", fn = "SUM")

  expect_equal(as.character(row$region), "Total")
  expect_true(is.na(row$code))
})

test_that("when all columns are numeric, label overwrites column 1", {
  df <- data.frame(a = c(1, 2), b = c(3, 4))
  row <- make_summary_row(df, data_start_row = 4, label = "Total", fn = "SUM")

  expect_equal(as.character(row$a), "Total")
  expect_s3_class(row$b, "googlesheets4_formula")
  expect_equal(as.character(row$b), "=SUM(B4:B5)")
})

test_that("end row reflects nrow(df) and data_start_row", {
  df <- data.frame(
    region = c("E", "W", "N", "S", "Mid"),
    sales  = c(1, 2, 3, 4, 5)
  )
  row <- make_summary_row(df, data_start_row = 4, label = "Avg", fn = "AVERAGE")
  expect_equal(as.character(row$sales), "=AVERAGE(B4:B8)")

  row2 <- make_summary_row(df, data_start_row = 10, label = "Avg", fn = "AVERAGE")
  expect_equal(as.character(row2$sales), "=AVERAGE(B10:B14)")
})

test_that("cols restricts which numeric columns get formulas", {
  df <- data.frame(region = c("E", "W"), sales = c(10, 20), units = c(1L, 2L))
  row <- make_summary_row(df, data_start_row = 4, label = "Total", fn = "SUM",
                          cols = "sales")
  expect_s3_class(row$sales, "googlesheets4_formula")
  expect_true(is.na(row$units))
})

test_that("inputs are validated", {
  df <- data.frame(x = 1:3)
  expect_error(make_summary_row("not a df", 4, "T", "SUM"))
  expect_error(make_summary_row(df, "not numeric", "T", "SUM"))
  expect_error(make_summary_row(df, 1.5, "T", "SUM"))
  expect_error(make_summary_row(df, 4, c("a", "b"), "SUM"))
  expect_error(make_summary_row(df, 4, NA_character_, "SUM"))
  expect_error(make_summary_row(df, 4, "T", ""))
  expect_error(make_summary_row(df, 4, "T", "SUM", cols = "nonexistent"))
  # Non-numeric column passed via cols should error.
  df2 <- data.frame(region = "E", sales = 10)
  expect_error(make_summary_row(df2, 4, "T", "SUM", cols = "region"))
})

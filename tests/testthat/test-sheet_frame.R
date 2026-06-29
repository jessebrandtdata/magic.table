test_that("as_sheet_frame wraps a data frame", {
  df <- data.frame(region = c("E", "W"), sales = c(10, 20))
  sf <- as_sheet_frame(df)
  expect_s3_class(sf, "sheet_frame")
  expect_equal(sheet_frame_data(sf), tibble::as_tibble(df))
  expect_equal(sheet_frame_ops(sf), list())
})

test_that("as_sheet_frame accepts a tibble unchanged", {
  tb <- tibble::tibble(a = 1:3, b = letters[1:3])
  sf <- as_sheet_frame(tb)
  expect_equal(sheet_frame_data(sf), tb)
})

test_that("as_sheet_frame rejects non-data-frames", {
  expect_error(as_sheet_frame(1:3), "must be a data frame")
  expect_error(as_sheet_frame(list(a = 1)), "must be a data frame")
  expect_error(as_sheet_frame(NULL), "must be a data frame")
})

test_that("print.sheet_frame shows schema and pending op count", {
  sf <- as_sheet_frame(data.frame(a = 1, b = 2))
  out <- capture.output(print(sf))
  expect_true(any(grepl("sheet_frame", out)))
  expect_true(any(grepl("a", out)) && any(grepl("b", out)))
  expect_true(any(grepl("0 pending op", out)))
})

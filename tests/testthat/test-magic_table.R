test_that("magic.table wraps a data frame", {
  df <- data.frame(region = c("E", "W"), sales = c(10, 20))
  mt <- magic.table(df)
  expect_s3_class(mt, "magic.table")
  expect_equal(magic_table_data(mt), tibble::as_tibble(df))
  expect_equal(magic_table_ops(mt), list())
})

test_that("a fresh magic.table has no synced backend", {
  mt <- magic.table(data.frame(a = 1))
  expect_null(magic_table_backend(mt))
})

test_that("magic.table accepts a tibble unchanged", {
  tb <- tibble::tibble(a = 1:3, b = letters[1:3])
  mt <- magic.table(tb)
  expect_equal(magic_table_data(mt), tb)
})

test_that("magic.table rejects non-data-frames", {
  expect_error(magic.table(1:3), "must be a data frame")
  expect_error(magic.table(list(a = 1)), "must be a data frame")
  expect_error(magic.table(NULL), "must be a data frame")
})

test_that("print.magic.table shows schema, recorded ops, and backend", {
  mt <- magic.table(data.frame(a = 1, b = 2))
  out <- capture.output(print(mt))
  expect_true(any(grepl("magic.table", out)))
  expect_true(any(grepl("a", out)) && any(grepl("b", out)))
  expect_true(any(grepl("0 recorded op", out)))
  expect_true(any(grepl("backend", out)))
})

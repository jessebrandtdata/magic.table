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

test_that("print.magic.table reports row/col counts and an unsynced backend", {
  mt <- magic.table(data.frame(a = c(1, 2, 3), b = c(4, 5, 6)))
  out <- paste(capture.output(print(mt)), collapse = "\n")
  expect_match(out, "3 rows")
  expect_match(out, "2 cols")
  expect_match(out, "none \\(not synced\\)")
})

test_that("print.magic.table pluralizes the recorded-op count", {
  one <- magic.table(data.frame(a = 1:2)) |> dplyr::mutate(b = a + 1)
  out1 <- paste(capture.output(print(one)), collapse = "\n")
  expect_match(out1, "1 recorded op\\b")   # singular, no trailing "s"

  two <- one |> dplyr::mutate(c = b * 2)
  out2 <- paste(capture.output(print(two)), collapse = "\n")
  expect_match(out2, "2 recorded ops")
})

test_that("print.magic.table returns its input invisibly", {
  mt <- magic.table(data.frame(a = 1))
  capture.output(ret <- withVisible(print(mt)))
  expect_false(ret$visible)
  expect_identical(ret$value, mt)
})

test_that("as.magic.table coerces a data frame like magic.table()", {
  df <- data.frame(a = 1:2, b = 3:4)
  expect_equal(as.magic.table(df), magic.table(df))
  expect_s3_class(as.magic.table(df), "magic.table")
})

test_that("as.magic.table is idempotent on a magic.table (keeps recorded ops)", {
  mt <- magic.table(data.frame(a = 1:2)) |> dplyr::mutate(b = a + 1)
  expect_identical(as.magic.table(mt), mt)
})

test_that("as.magic.table rejects non-data-frames", {
  expect_error(as.magic.table(1:3), "must be a data frame")
})

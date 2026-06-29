test_that("mutate.sheet_frame returns a sheet_frame", {
  sf <- as_sheet_frame(data.frame(a = 1:2, b = 3:4))
  out <- dplyr::mutate(sf, c = a + b)
  expect_s3_class(out, "sheet_frame")
})

test_that("mutate appends one op holding the captured quosures", {
  sf <- as_sheet_frame(data.frame(a = 1:2, b = 3:4))
  out <- dplyr::mutate(sf, c = a + b, d = c * 2)
  ops <- sheet_frame_ops(out)
  expect_equal(length(ops), 1L)
  expect_equal(ops[[1]]$verb, "mutate")
  expect_equal(names(ops[[1]]$cols), c("c", "d"))
  expect_true(rlang::is_quosure(ops[[1]]$cols[[1]]))
  expect_equal(rlang::quo_get_expr(ops[[1]]$cols$c), quote(a + b))
  expect_equal(rlang::quo_get_expr(ops[[1]]$cols$d), quote(c * 2))
})

test_that("successive mutate calls accumulate ops in order", {
  sf <- as_sheet_frame(data.frame(a = 1:2, b = 3:4))
  out <- dplyr::mutate(dplyr::mutate(sf, c = a + b), d = c * 2)
  ops <- sheet_frame_ops(out)
  expect_equal(length(ops), 2L)
  expect_equal(names(ops[[1]]$cols), "c")
  expect_equal(names(ops[[2]]$cols), "d")
})

test_that("mutate does not touch the underlying data tibble", {
  df <- data.frame(a = 1:2, b = 3:4)
  sf <- as_sheet_frame(df)
  out <- dplyr::mutate(sf, c = a + b)
  expect_equal(sheet_frame_data(out), tibble::as_tibble(df))
})

test_that("mutate requires named arguments", {
  sf <- as_sheet_frame(data.frame(a = 1:2))
  expect_error(dplyr::mutate(sf, a + 1), "all mutate arguments must be named")
})

test_that("mutate.magic.table returns a magic.table", {
  mt <- magic.table(data.frame(a = 1:2, b = 3:4))
  out <- dplyr::mutate(mt, c = a + b)
  expect_s3_class(out, "magic.table")
})

test_that("mutate appends one op holding the captured quosures", {
  mt <- magic.table(data.frame(a = 1:2, b = 3:4))
  out <- dplyr::mutate(mt, c = a + b, d = c * 2)
  ops <- magic_table_ops(out)
  expect_equal(length(ops), 1L)
  expect_equal(ops[[1]]$verb, "mutate")
  expect_equal(names(ops[[1]]$cols), c("c", "d"))
  expect_true(rlang::is_quosure(ops[[1]]$cols[[1]]))
  expect_equal(rlang::quo_get_expr(ops[[1]]$cols$c), quote(a + b))
  expect_equal(rlang::quo_get_expr(ops[[1]]$cols$d), quote(c * 2))
})

test_that("successive mutate calls accumulate ops in order", {
  mt <- magic.table(data.frame(a = 1:2, b = 3:4))
  out <- dplyr::mutate(dplyr::mutate(mt, c = a + b), d = c * 2)
  ops <- magic_table_ops(out)
  expect_equal(length(ops), 2L)
  expect_equal(names(ops[[1]]$cols), "c")
  expect_equal(names(ops[[2]]$cols), "d")
})

test_that("mutate does not touch the underlying data tibble", {
  df <- data.frame(a = 1:2, b = 3:4)
  mt <- magic.table(df)
  out <- dplyr::mutate(mt, c = a + b)
  expect_equal(magic_table_data(out), tibble::as_tibble(df))
})

test_that("mutate requires named arguments", {
  mt <- magic.table(data.frame(a = 1:2))
  expect_error(dplyr::mutate(mt, a + 1), "all mutate arguments must be named")
})

test_that("mutate rejects a mix of named and unnamed arguments", {
  mt <- magic.table(data.frame(a = 1:2, b = 3:4))
  expect_error(dplyr::mutate(mt, c = a + b, a - b),
               "all mutate arguments must be named")
})

test_that("mutate with no expressions is a no-op (records nothing)", {
  mt <- magic.table(data.frame(a = 1:2))
  out <- dplyr::mutate(mt)
  expect_s3_class(out, "magic.table")
  expect_equal(length(magic_table_ops(out)), 0L)
  expect_identical(out, mt)
})

test_that("col_letter handles single-letter columns", {
  expect_equal(col_letter(1), "A")
  expect_equal(col_letter(2), "B")
  expect_equal(col_letter(26), "Z")
})

test_that("col_letter handles two-letter columns", {
  expect_equal(col_letter(27), "AA")
  expect_equal(col_letter(28), "AB")
  expect_equal(col_letter(52), "AZ")
  expect_equal(col_letter(53), "BA")
  expect_equal(col_letter(702), "ZZ")
})

test_that("col_letter handles three-letter columns", {
  expect_equal(col_letter(703), "AAA")
  expect_equal(col_letter(704), "AAB")
})

test_that("col_letter is vectorised", {
  expect_equal(col_letter(c(1, 27, 702, 703)), c("A", "AA", "ZZ", "AAA"))
})

test_that("col_letter rejects bad input", {
  expect_error(col_letter(0))
  expect_error(col_letter(-1))
  expect_error(col_letter(1.5))
  expect_error(col_letter(NA_real_))
  expect_error(col_letter("A"))
  expect_error(col_letter(integer(0)))
})

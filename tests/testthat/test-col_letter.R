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

test_that("col_letter handles the ZZ/AAA boundary and beyond", {
  # 702 = ZZ is the last two-letter column; 703 = AAA is the first three-letter.
  expect_equal(col_letter(702), "ZZ")
  expect_equal(col_letter(703), "AAA")
  # 18278 = ZZ..Z last three-letter column; 18279 = AAAA first four-letter.
  expect_equal(col_letter(18278), "ZZZ")
  expect_equal(col_letter(18279), "AAAA")
})

test_that("col_letter accepts integer-valued doubles", {
  expect_equal(col_letter(27), "AA")
  expect_equal(col_letter(27L), "AA")
})

test_that("col_letter rejects bad input", {
  expect_error(col_letter(0))
  expect_error(col_letter(-1))
  expect_error(col_letter(1.5))
  expect_error(col_letter(NA_real_))
  expect_error(col_letter("A"))
  expect_error(col_letter(integer(0)))
})

test_that("col_letter rejects a vector with any invalid element", {
  # The guard is all-or-nothing: one bad value rejects the whole vector.
  expect_error(col_letter(c(1, 0)),  "positive integers")
  expect_error(col_letter(c(1, -3)), "positive integers")
  expect_error(col_letter(c(1, 2.5)), "positive integers")
  expect_error(col_letter(c(1, NA_real_)), "positive integers")
})

test_that("col_letter rejects non-finite input (errors, if not cleanly)", {
  # Inf slips past the `< 1` / `is.na` guards and trips an internal coercion
  # error rather than the clean "positive integers" message; -Inf is caught by
  # the `< 1` guard. We pin that both error. See the col_letter robustness note.
  expect_error(suppressWarnings(col_letter(Inf)))
  expect_error(col_letter(-Inf))
})

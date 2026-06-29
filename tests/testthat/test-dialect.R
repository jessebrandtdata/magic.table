test_that("sheet_translators returns a named list including arithmetic ops", {
  tr <- sheet_translators()
  expect_type(tr, "list")
  for (op in c("+", "-", "*", "/", "^")) {
    expect_true(op %in% names(tr), info = paste0("missing translator: ", op))
    expect_type(tr[[op]], "closure")
  }
})

test_that("binary `+` translator joins two args with +", {
  tr <- sheet_translators()
  expect_equal(tr[["+"]](list("A4", "B4"), list()), "(A4)+(B4)")
})

test_that("`/` translator wraps args with parens for safety", {
  tr <- sheet_translators()
  out <- tr[["/"]](list("A4", "B4"), list())
  expect_true(out == "A4/B4" || out == "(A4)/(B4)")
})

test_that("register_sheet_translator adds and overrides entries", {
  on.exit(register_sheet_translator("__test_fn__", NULL), add = TRUE)
  f <- function(args, ctx) paste0("TEST(", paste(args, collapse = ","), ")")
  prev <- register_sheet_translator("__test_fn__", f)
  expect_null(prev)
  expect_identical(sheet_translators()[["__test_fn__"]], f)

  g <- function(args, ctx) "OTHER"
  prev2 <- register_sheet_translator("__test_fn__", g)
  expect_identical(prev2, f)
  expect_identical(sheet_translators()[["__test_fn__"]], g)
})

test_that("register_sheet_translator(name, NULL) removes an entry", {
  f <- function(args, ctx) "X"
  register_sheet_translator("__test_remove__", f)
  expect_true("__test_remove__" %in% names(sheet_translators()))
  register_sheet_translator("__test_remove__", NULL)
  expect_false("__test_remove__" %in% names(sheet_translators()))
})

test_that("register_sheet_translator validates inputs", {
  expect_error(register_sheet_translator(123, function(a, c) ""), "single non-empty character")
  expect_error(register_sheet_translator("", function(a, c) ""), "single non-empty character")
  expect_error(register_sheet_translator("ok", "not a function"), "must be a function or NULL")
})

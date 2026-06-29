schema <- c(region = "A", sales = "B", cost = "C")

test_that("walk_expr translates a bare column symbol to <letter><row>", {
  expect_equal(walk_expr(quote(sales), schema, row_n = 4L), "B4")
  expect_equal(walk_expr(quote(cost),  schema, row_n = 7L), "C7")
})

test_that("walk_expr errors on an unknown symbol", {
  expect_error(
    walk_expr(quote(profit), schema, row_n = 4L),
    "column `profit` not found .* have: region, sales, cost"
  )
})

test_that("walk_expr translates numeric and logical literals", {
  expect_equal(walk_expr(10,    schema, row_n = 4L), "10")
  expect_equal(walk_expr(1.5,   schema, row_n = 4L), "1.5")
  expect_equal(walk_expr(TRUE,  schema, row_n = 4L), "TRUE")
  expect_equal(walk_expr(FALSE, schema, row_n = 4L), "FALSE")
})

test_that("walk_expr translates a binary arithmetic expression", {
  expect_equal(
    walk_expr(quote(sales - cost), schema, row_n = 4L),
    "(B4)-(C4)"
  )
  expect_equal(
    walk_expr(quote((sales - cost) / sales), schema, row_n = 5L),
    "((B5)-(C5))/(B5)"
  )
})

test_that("walk_expr errors on unknown call head with a helpful message", {
  expect_error(
    walk_expr(quote(lm(sales ~ cost)), schema, row_n = 4L),
    "no Sheets translator for `lm`"
  )
})

test_that("walk_expr errors on bare NA literal", {
  expect_error(walk_expr(NA,            schema, row_n = 4L), "NA literals are not supported")
  expect_error(walk_expr(NA_real_,      schema, row_n = 4L), "NA literals are not supported")
  expect_error(walk_expr(NA_character_, schema, row_n = 4L), "NA literals are not supported")
})

test_that("walk_expr translates string literals with double-quote escaping", {
  expect_equal(walk_expr("foo",        schema, row_n = 4L), "\"foo\"")
  expect_equal(walk_expr("say \"hi\"", schema, row_n = 4L), "\"say \"\"hi\"\"\"")
})

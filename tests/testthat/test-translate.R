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

test_that("walk_expr handles comparisons (== becomes =, != becomes <>)", {
  expect_equal(walk_expr(quote(sales > 100), schema, row_n = 4L), "(B4)>(100)")
  expect_equal(walk_expr(quote(sales == 0),  schema, row_n = 4L), "(B4)=(0)")
  expect_equal(walk_expr(quote(sales != 0),  schema, row_n = 4L), "(B4)<>(0)")
})

test_that("walk_expr handles logical AND/OR/NOT as Sheets functions", {
  expect_equal(
    walk_expr(quote(sales > 0 & cost < 100), schema, row_n = 4L),
    "AND((B4)>(0),(C4)<(100))"
  )
  expect_equal(
    walk_expr(quote(sales > 0 | cost < 100), schema, row_n = 4L),
    "OR((B4)>(0),(C4)<(100))"
  )
  expect_equal(
    walk_expr(quote(!(sales > 0)), schema, row_n = 4L),
    "NOT((B4)>(0))"
  )
})

test_that("walk_expr translates ifelse to IF", {
  expect_equal(
    walk_expr(quote(ifelse(sales > 0, sales, 0)), schema, row_n = 4L),
    "IF((B4)>(0),B4,0)"
  )
})

test_that("walk_expr translates unary minus", {
  expect_equal(walk_expr(quote(-sales), schema, row_n = 4L), "-(B4)")
})

test_that("walk_expr translates curated math/stat fns", {
  expect_equal(walk_expr(quote(abs(sales)),        schema, row_n = 4L), "ABS(B4)")
  expect_equal(walk_expr(quote(round(sales, 2)),   schema, row_n = 4L), "ROUND(B4,2)")
  expect_equal(walk_expr(quote(sqrt(sales)),       schema, row_n = 4L), "SQRT(B4)")
  expect_equal(walk_expr(quote(pmin(sales, cost)), schema, row_n = 4L), "MIN(B4,C4)")
  expect_equal(walk_expr(quote(pmax(sales, cost)), schema, row_n = 4L), "MAX(B4,C4)")
  expect_equal(walk_expr(quote(is.na(sales)),      schema, row_n = 4L), "ISBLANK(B4)")
})

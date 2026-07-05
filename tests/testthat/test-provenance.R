df <- data.frame(region = c("E", "W"), sales = c(10, 20), cost = c(4, 8),
                 stringsAsFactors = FALSE)

test_that("provenance of a fresh magic.table marks every column as source", {
  prov <- provenance(magic.table(df))
  expect_s3_class(prov, "tbl_df")
  expect_equal(prov$column, c("region", "sales", "cost"))
  expect_equal(prov$origin, rep("source", 3))
  expect_true(all(is.na(prov$expr)))
})

test_that("provenance records computed columns with their expression", {
  mt <- magic.table(df) |> dplyr::mutate(margin = sales - cost)
  prov <- provenance(mt)
  expect_equal(prov$column, c("region", "sales", "cost", "margin"))
  expect_equal(prov$origin, c("source", "source", "source", "computed"))
  expect_equal(prov$expr[prov$column == "margin"], "sales - cost")
})

test_that("provenance preserves order across multiple computed columns", {
  mt <- magic.table(df) |>
    dplyr::mutate(margin = sales - cost) |>
    dplyr::mutate(margin_pct = margin / sales)
  prov <- provenance(mt)
  expect_equal(prov$column,
               c("region", "sales", "cost", "margin", "margin_pct"))
  expect_equal(prov$origin[prov$column == "margin_pct"], "computed")
  expect_equal(prov$expr[prov$column == "margin_pct"], "margin/sales")
})

test_that("overwriting a source column keeps its position but marks it computed", {
  mt <- magic.table(df) |> dplyr::mutate(sales = sales * 2)
  prov <- provenance(mt)
  expect_equal(prov$column, c("region", "sales", "cost"))
  expect_equal(prov$origin, c("source", "computed", "source"))
  expect_equal(prov$expr[prov$column == "sales"], "sales * 2")
})

test_that("provenance records several new columns from a single mutate op", {
  # Two computed columns added in ONE mutate() call (one recorded op).
  mt <- magic.table(df) |>
    dplyr::mutate(margin = sales - cost, markup = margin / cost)
  prov <- provenance(mt)
  expect_equal(prov$column,
               c("region", "sales", "cost", "margin", "markup"))
  expect_equal(prov$origin,
               c("source", "source", "source", "computed", "computed"))
  expect_equal(prov$expr[prov$column == "margin"], "sales - cost")
  expect_equal(prov$expr[prov$column == "markup"], "margin/cost")
})

test_that("a later mutate can overwrite a previously computed column", {
  mt <- magic.table(df) |>
    dplyr::mutate(margin = sales - cost) |>
    dplyr::mutate(margin = margin * 2)
  prov <- provenance(mt)
  # margin stays in its position, keeps the latest expression.
  expect_equal(prov$column, c("region", "sales", "cost", "margin"))
  expect_equal(prov$origin[prov$column == "margin"], "computed")
  expect_equal(prov$expr[prov$column == "margin"], "margin * 2")
})

test_that("provenance rejects non-magic.tables", {
  expect_error(provenance(df), "must be a magic.table")
})

test_that("write_sheet validates its arguments", {
  mt <- magic.table(data.frame(a = 1:2))
  expect_error(write_sheet("not a frame", "ss", "Sheet1"), "must be a magic.table")
  expect_error(write_sheet(mt, NULL, "Sheet1"),    "`ss` must not be NULL")
  expect_error(write_sheet(mt, "ss", 123),         "`sheet` must be a single non-empty character string")
  expect_error(write_sheet(mt, "ss", "Sheet1", start_row = 0), "must be a single positive integer")
})

test_that("write_sheet calls range_write with the materialized cells", {
  mt <- magic.table(data.frame(a = c(1, 2), b = c(3, 4))) |>
    dplyr::mutate(c = a + b)

  called <- list()
  fake_range_write <- function(ss, data, range, ...) {
    called$ss    <<- ss
    called$data  <<- data
    called$range <<- range
    invisible(data)
  }

  write_sheet(mt, ss = "SSID", sheet = "Sales", start_row = 3L,
              .writer = fake_range_write)

  expect_equal(called$ss, "SSID")
  expect_equal(called$range, "Sales!A3")
  expect_equal(names(called$data), c("a", "b", "c"))
  expect_equal(as.character(called$data$c), c("=(A4)+(B4)", "=(A5)+(B5)"))
})

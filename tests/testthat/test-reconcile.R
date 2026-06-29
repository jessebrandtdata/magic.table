# Reconciliation / backend-binding behavior of write_sheet().
# All Google Sheets I/O is injected (.writer / .reader) so these run without auth.

mt0 <- function() {
  magic.table(data.frame(a = c(1, 2), b = c(3, 4))) |> dplyr::mutate(c = a + b)
}

# A writer that records calls and never touches the network.
recording_writer <- function(store) {
  function(ss, data, range, ...) {
    store$calls <- (store$calls %||% 0L) + 1L
    store$last_data <- data
    store$last_range <- range
    invisible(data)
  }
}
`%||%` <- function(a, b) if (is.null(a)) b else a

test_that("first write binds a gsheet backend with a snapshot", {
  store <- new.env()
  out <- write_sheet(mt0(), ss = "SSID", sheet = "Sales", start_row = 3L,
                     .writer = recording_writer(store))
  expect_s3_class(out, "magic.table")
  be <- magic_table_backend(out)
  expect_equal(be$type, "gsheet")
  expect_equal(be$ss, "SSID")
  expect_equal(be$sheet, "Sales")
  expect_equal(be$start_row, 3L)
  expect_true(is.character(be$snapshot) && length(be$snapshot) > 0)
  expect_equal(store$calls, 1L)
})

test_that("first write does not read (no prior backend to reconcile against)", {
  store <- new.env()
  reader_called <- local({ n <- 0L; function(...) { n <<- n + 1L; character() } })
  write_sheet(mt0(), ss = "SSID", sheet = "Sales", start_row = 3L,
              .writer = recording_writer(store),
              .reader = reader_called)
  expect_equal(store$calls, 1L)
})

test_that("re-write to same target with unchanged sheet overwrites", {
  store <- new.env()
  bound <- write_sheet(mt0(), ss = "SSID", sheet = "Sales", start_row = 3L,
                       .writer = recording_writer(store))
  snap <- magic_table_backend(bound)$snapshot
  # reader reports the sheet still holds exactly what we last wrote -> no divergence
  out <- write_sheet(bound, ss = "SSID", sheet = "Sales", start_row = 3L,
                     .writer = recording_writer(store),
                     .reader = function(ss, sheet, range) snap)
  expect_equal(store$calls, 2L)            # wrote again
  expect_s3_class(out, "magic.table")
})

test_that("re-write refuses to clobber an externally changed sheet (warns, no write)", {
  store <- new.env()
  bound <- write_sheet(mt0(), ss = "SSID", sheet = "Sales", start_row = 3L,
                       .writer = recording_writer(store))
  diverged_reader <- function(ss, sheet, range) "someone-edited-this"
  expect_warning(
    out <- write_sheet(bound, ss = "SSID", sheet = "Sales", start_row = 3L,
                       .writer = recording_writer(store),
                       .reader = diverged_reader),
    "changed since"
  )
  expect_equal(store$calls, 1L)            # writer NOT called the second time
  expect_identical(out, bound)             # returned unchanged
})

test_that("overwrite = TRUE writes despite divergence and skips the read", {
  store <- new.env()
  bound <- write_sheet(mt0(), ss = "SSID", sheet = "Sales", start_row = 3L,
                       .writer = recording_writer(store))
  read_called <- local({ n <- 0L; function(...) { n <<- n + 1L; "x" } })
  out <- write_sheet(bound, ss = "SSID", sheet = "Sales", start_row = 3L,
                     overwrite = TRUE,
                     .writer = recording_writer(store),
                     .reader = read_called)
  expect_equal(store$calls, 2L)            # wrote
  expect_s3_class(out, "magic.table")
})

test_that("writing to a different target does not reconcile against the old one", {
  store <- new.env()
  bound <- write_sheet(mt0(), ss = "SSID", sheet = "Sales", start_row = 3L,
                       .writer = recording_writer(store))
  # different sheet -> treated as a fresh bind, no divergence check, no warning
  expect_no_warning(
    out <- write_sheet(bound, ss = "SSID", sheet = "Other", start_row = 3L,
                       .writer = recording_writer(store),
                       .reader = function(...) stop("should not read"))
  )
  expect_equal(store$calls, 2L)
  expect_equal(magic_table_backend(out)$sheet, "Other")
})

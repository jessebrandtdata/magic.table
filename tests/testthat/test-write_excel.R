# The Excel (.xlsx) export backend: write_excel() writes the cells that
# as_sheet_cells() materializes into a real workbook, formula columns as
# live `=` formulas. All on disk, no auth.

mt0 <- function() {
  magic.table(data.frame(a = c(1, 2), b = c(3, 4))) |> dplyr::mutate(c = a + b)
}

# Formula strings of `sheet` as the saved workbook holds them, row-major.
sheet_formulas <- function(path, sheet = "Sheet1") {
  wb <- openxlsx::loadWorkbook(path)
  sd <- wb$worksheets[[match(sheet, names(wb))]]$sheet_data
  f <- sd$f[order(sd$rows, sd$cols)]
  gsub("</?f>", "", f[!is.na(f)])
}

test_that("write_excel writes computed columns as live formulas", {
  path <- withr::local_tempfile(fileext = ".xlsx")
  write_excel(mt0(), path)
  expect_true(file.exists(path))
  expect_equal(sheet_formulas(path), c("(A2)+(B2)", "(A3)+(B3)"))
})

test_that("write_excel writes the header and source values", {
  path <- withr::local_tempfile(fileext = ".xlsx")
  write_excel(mt0(), path, sheet = "Data")
  back <- openxlsx::read.xlsx(path, sheet = "Data")
  expect_equal(names(back), c("a", "b", "c"))
  expect_equal(back$a, c(1, 2))
  expect_equal(back$b, c(3, 4))
})

test_that("write_excel anchors the block at start_row", {
  path <- withr::local_tempfile(fileext = ".xlsx")
  write_excel(mt0(), path, start_row = 3L)
  expect_equal(sheet_formulas(path), c("(A4)+(B4)", "(A5)+(B5)"))
  back <- openxlsx::read.xlsx(path, startRow = 3L)
  expect_equal(names(back), c("a", "b", "c"))
})

test_that("first write binds an excel backend with a file snapshot", {
  path <- withr::local_tempfile(fileext = ".xlsx")
  out <- write_excel(mt0(), path, sheet = "Sales", start_row = 2L)
  expect_s3_class(out, "magic.table")
  be <- magic_table_backend(out)
  expect_equal(be$type, "excel")
  expect_equal(be$path, path)
  expect_equal(be$sheet, "Sales")
  expect_equal(be$start_row, 2L)
  expect_equal(be$snapshot, unname(tools::md5sum(path)))
})

test_that("re-write to the same untouched file writes without warning", {
  path <- withr::local_tempfile(fileext = ".xlsx")
  mt <- write_excel(mt0(), path)
  mt2 <- dplyr::mutate(mt, d = c * 2)
  expect_no_warning(write_excel(mt2, path))
  expect_equal(sheet_formulas(path),
               c("(A2)+(B2)", "(C2)*(2)", "(A3)+(B3)", "(C3)*(2)"))
})

test_that("re-write refuses to clobber an externally changed file (warns, no write)", {
  path <- withr::local_tempfile(fileext = ".xlsx")
  mt <- write_excel(mt0(), path)
  # An external edit: someone re-saves the workbook with a new sheet.
  wb <- openxlsx::loadWorkbook(path)
  openxlsx::addWorksheet(wb, "Notes")
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  external_hash <- unname(tools::md5sum(path))

  mt2 <- dplyr::mutate(mt, d = c * 2)
  expect_warning(out <- write_excel(mt2, path), "changed since")
  expect_equal(unname(tools::md5sum(path)), external_hash)
  expect_identical(out, mt2)
})

test_that("overwrite = TRUE writes despite an external change", {
  path <- withr::local_tempfile(fileext = ".xlsx")
  mt <- write_excel(mt0(), path)
  wb <- openxlsx::loadWorkbook(path)
  openxlsx::addWorksheet(wb, "Notes")
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)

  mt2 <- dplyr::mutate(mt, d = c * 2)
  expect_no_warning(out <- write_excel(mt2, path, overwrite = TRUE))
  expect_equal(length(sheet_formulas(path)), 4L)
  expect_equal(magic_table_backend(out)$snapshot, unname(tools::md5sum(path)))
})

test_that("re-writing a sheet keeps its position among the workbook's sheets", {
  path <- withr::local_tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  for (nm in c("Intro", "Sales", "Notes")) openxlsx::addWorksheet(wb, nm)
  openxlsx::saveWorkbook(wb, path)
  write_excel(mt0(), path, sheet = "Sales")
  expect_equal(names(openxlsx::loadWorkbook(path)), c("Intro", "Sales", "Notes"))
  expect_equal(sheet_formulas(path, "Sales"), c("(A2)+(B2)", "(A3)+(B3)"))
})

test_that("a bound file that was deleted is simply written again", {
  path <- withr::local_tempfile(fileext = ".xlsx")
  mt <- write_excel(mt0(), path)
  unlink(path)
  expect_no_warning(write_excel(mt, path))
  expect_true(file.exists(path))
})

test_that("writing to a different path does not reconcile against the old one", {
  path1 <- withr::local_tempfile(fileext = ".xlsx")
  path2 <- withr::local_tempfile(fileext = ".xlsx")
  mt <- write_excel(mt0(), path1)
  writeLines("not a workbook", path2)
  expect_no_warning(out <- write_excel(mt, path2))
  expect_equal(magic_table_backend(out)$path, path2)
})

test_that("write_excel validates its arguments", {
  path <- withr::local_tempfile(fileext = ".xlsx")
  expect_error(write_excel(data.frame(a = 1), path), "must be a magic.table")
  expect_error(write_excel(mt0(), c(path, path)), "`path`")
  expect_error(write_excel(mt0(), path, sheet = ""), "`sheet`")
  expect_error(write_excel(mt0(), path, overwrite = NA), "`overwrite`")
  expect_error(write_excel(mt0(), path, start_row = 0), "`start_row`")
  expect_false(file.exists(path))
})

test_that("print.magic.table names a bound excel backend by file and sheet", {
  path <- withr::local_tempfile(fileext = ".xlsx")
  mt <- write_excel(mt0(), path, sheet = "Sales")
  out <- paste(capture.output(print(mt)), collapse = "\n")
  expect_match(out, "backend: excel ")
  expect_match(out, basename(path), fixed = TRUE)
  expect_match(out, "Sales", fixed = TRUE)
  expect_no_match(out, magic_table_backend(mt)$snapshot, fixed = TRUE)
})

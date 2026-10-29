# ---- Excel (.xlsx) export backend -----------------------------------------
# The second synced-table backend for a magic.table, beside the Google Sheets
# one in R/write_sheet.R. It consumes the same cell tibble as_sheet_cells()
# materializes and embeds the formula columns as real `=` formulas in a local
# .xlsx via openxlsx. No account, no token: Excel and LibreOffice recalculate
# on open, and Google Sheets imports the file with its formulas intact.

#' Write a magic.table to an Excel workbook as live formulas
#'
#' Materializes `x` via [as_sheet_cells()] and writes the result to `sheet` in
#' the workbook at `path`, header at `start_row`. Formula columns land as live
#' `=` formulas (via [openxlsx::writeFormula()]); other columns pass through
#' their R values. The file is created, or its `sheet` replaced; other sheets
#' in an existing workbook are left alone.
#'
#' This is the Excel backend for a [magic.table]. The returned `magic.table`
#' carries a **bound backend** (`path` / `sheet` / `start_row` and a snapshot
#' of the file as written), so capture it (`mt <- write_excel(mt, ...)`) to
#' keep the connection.
#'
#' **No-clobber reconciliation.** On a re-write to the *same* target, the file
#' on disk is first compared against the snapshot from the previous write. If
#' it has changed since (any edit that re-saved the file), the write is
#' **refused with a warning** rather than silently overwriting the edit. Pass
#' `overwrite = TRUE` to write anyway. A bound file that no longer exists is
#' written again without complaint.
#'
#' @param x A [magic.table].
#' @param path Single character string. The `.xlsx` file to write.
#' @param sheet Single non-empty character string. The worksheet name.
#'   Defaults to `"Sheet1"`.
#' @param start_row Single positive integer. 1-based row of the header.
#'   Defaults to `1`.
#' @param overwrite Single logical. If `FALSE` (default), a re-write to the
#'   same target whose file has changed on disk is refused with a warning.
#'   `TRUE` writes unconditionally.
#'
#' @return The input `magic.table` with its backend bound/updated, invisibly.
#'   When a write is refused, the input is returned unchanged.
#'
#' @examples
#' path <- tempfile(fileext = ".xlsx")
#' mt <- magic.table(data.frame(sales = c(10, 20), cost = c(4, 8))) |>
#'   dplyr::mutate(margin = sales - cost) |>
#'   write_excel(path, sheet = "Sales")
#' mt
#' @export
write_excel <- function(x, path, sheet = "Sheet1", start_row = 1L,
                        overwrite = FALSE) {
  if (!inherits(x, "magic.table")) {
    stop("`x` must be a magic.table.", call. = FALSE)
  }
  if (!is.character(path) || length(path) != 1L || is.na(path) ||
      !nzchar(path)) {
    stop("`path` must be a single non-empty character string.", call. = FALSE)
  }
  if (!is.character(sheet) || length(sheet) != 1L || is.na(sheet) ||
      !nzchar(sheet)) {
    stop("`sheet` must be a single non-empty character string.", call. = FALSE)
  }
  if (!is.logical(overwrite) || length(overwrite) != 1L || is.na(overwrite)) {
    stop("`overwrite` must be a single TRUE or FALSE.", call. = FALSE)
  }

  cells <- as_sheet_cells(x, start_row = start_row)
  start_row <- as.integer(start_row)

  prior <- x$backend
  same_target <- !is.null(prior) && identical(prior$type, "excel") &&
    identical(prior$path, path) && identical(prior$sheet, sheet) &&
    identical(prior$start_row, start_row)

  if (same_target && !overwrite && file.exists(path) &&
      !identical(.file_snapshot(path), prior$snapshot)) {
    warning("The target workbook has changed since magic.table last wrote it; ",
            "not overwriting. Pass `overwrite = TRUE` to write anyway.",
            call. = FALSE)
    return(invisible(x))
  }

  .xlsx_write_cells(cells, path, sheet, start_row)
  x$backend <- list(type = "excel", path = path, sheet = sheet,
                    start_row = start_row, snapshot = .file_snapshot(path))
  invisible(x)
}

# Content hash of the file on disk: the no-clobber snapshot for this backend.
.file_snapshot <- function(path) {
  unname(tools::md5sum(path))
}

# Write a cell tibble (from as_sheet_cells()) to `sheet` in the workbook at
# `path`, header at `start_row`, column A onward. An existing workbook keeps
# its other sheets; the target sheet is replaced. Formula columns are written
# with writeFormula(), which wants the formula text without its leading "=".
.xlsx_write_cells <- function(cells, path, sheet, start_row) {
  is_formula <- vapply(cells, inherits, logical(1),
                       what = "googlesheets4_formula")

  # An existing file that is not a workbook is replaced, not loaded.
  wb <- if (file.exists(path)) {
    tryCatch(suppressWarnings(openxlsx::loadWorkbook(path)),
             error = function(e) openxlsx::createWorkbook())
  } else {
    openxlsx::createWorkbook()
  }
  # Replace an existing sheet in place: a re-written sheet keeps its position.
  pos <- match(sheet, names(wb))
  if (!is.na(pos)) {
    openxlsx::removeWorksheet(wb, sheet)
  }
  openxlsx::addWorksheet(wb, sheet)
  if (!is.na(pos)) {
    n <- length(names(wb))
    openxlsx::worksheetOrder(wb) <- append(seq_len(n - 1L), n, after = pos - 1L)
  }

  # Values and the full header row. Formula columns go in as blanks here and
  # are filled by writeFormula() below.
  plain <- as.data.frame(cells)
  plain[is_formula] <- lapply(plain[is_formula], function(col) rep(NA, length(col)))
  openxlsx::writeData(wb, sheet, plain, startRow = start_row, startCol = 1L,
                      colNames = TRUE)

  for (j in which(is_formula)) {
    formulas <- sub("^=", "", as.character(cells[[j]]))
    openxlsx::writeFormula(wb, sheet, formulas,
                           startRow = start_row + 1L, startCol = j)
  }

  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  invisible(path)
}

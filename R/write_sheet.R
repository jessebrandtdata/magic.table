# ---- Google Sheets export backend ----------------------------------------
# Sheets is the first synced-table backend for a magic.table. These functions
# translate a magic.table's recorded computations into live A1 formulas and
# write them. Other backends (Excel, on-disk, database) will sit alongside this
# file in future; the magic.table core (R/magic_table.R) is backend-agnostic.

#' Materialize a magic.table's recorded ops into a cell tibble (pure)
#'
#' Walks every recorded [mutate()][dplyr::mutate] op and translates each
#' captured expression into a column of `=`-prefixed
#' [googlesheets4::gs4_formula()] strings, anchored at `start_row`. Returns
#' the resulting tibble without touching Google Sheets.
#'
#' This is the testability lever: end-to-end correctness of the lazy
#' API can be exercised without auth.
#'
#' @param x A [magic.table].
#' @param start_row Single positive integer. The 1-based sheet row where the
#'   header lands; data cells live at rows `start_row + 1` .. `start_row + nrow`.
#'
#' @return A tibble; formula columns hold `gs4_formula()` strings.
#' @export
as_sheet_cells <- function(x, start_row = 1L) {
  if (!inherits(x, "magic.table")) {
    stop("`x` must be a magic.table.", call. = FALSE)
  }
  if (!is.numeric(start_row) || length(start_row) != 1L ||
      is.na(start_row) || start_row < 1 ||
      start_row != as.integer(start_row)) {
    stop("`start_row` must be a single positive integer.", call. = FALSE)
  }
  start_row <- as.integer(start_row)

  data <- x$data
  n_rows <- nrow(data)
  data_first_row <- start_row + 1L
  data_rows <- seq.int(data_first_row, length.out = n_rows)

  schema <- stats::setNames(col_letter(seq_along(data)), names(data))

  for (op in x$ops) {
    if (op$verb != "mutate") {
      stop("unsupported recorded op verb: ", op$verb, call. = FALSE)
    }
    for (nm in names(op$cols)) {
      q <- op$cols[[nm]]
      expr <- rlang::quo_get_expr(q)
      formulas <- vapply(data_rows, function(r) {
        paste0("=", walk_expr(expr, schema, row_n = r))
      }, character(1))
      data[[nm]] <- googlesheets4::gs4_formula(formulas)
      schema <- c(schema,
                  stats::setNames(col_letter(length(schema) + 1L), nm))
    }
  }
  tibble::as_tibble(data)
}

#' Write a magic.table to a Google Sheet as live formulas
#'
#' Materializes `x` via [as_sheet_cells()] and writes the resulting cell
#' tibble to `sheet` in `ss` starting at `start_row`. Formula columns land
#' as live `=`-prefixed cells; other columns pass through their R values.
#'
#' This is the Google Sheets backend for a [magic.table]. The returned
#' `magic.table` carries a **bound backend** (`ss` / `sheet` / `start_row` and a
#' snapshot of what was written), so capture it (`mt <- write_sheet(mt, ...)`) to
#' keep the connection.
#'
#' **No-clobber reconciliation.** On a re-write to the *same* target, the sheet
#' is first polled and compared against the snapshot from the previous write. If
#' it has changed externally, the write is **refused with a warning** rather than
#' silently overwriting an edit. Pass `overwrite = TRUE` to write anyway.
#'
#' v1 writes the header row + data rows in one call; it does not add title rows
#' or summary rows — compose with [make_summary_row()] +
#' [googlesheets4::sheet_append()] for richer layouts.
#'
#' @param x A [magic.table].
#' @param ss A Google Sheets identifier accepted by
#'   [googlesheets4::range_write()] (URL, sheet ID, or `dribble`).
#' @param sheet Single non-empty character string. The sheet (tab) name.
#' @param start_row Single positive integer. 1-based row of the header.
#'   Defaults to `1`.
#' @param overwrite Single logical. If `FALSE` (default), a re-write to the same
#'   target that has changed externally is refused with a warning. `TRUE` writes
#'   unconditionally (and skips the poll).
#' @param .writer Function used to perform the write. Defaults to
#'   [googlesheets4::range_write()]. Override in tests.
#' @param .reader Function `(ss, sheet, range)` returning the sheet's current
#'   cell contents as a character vector, used for the no-clobber poll. Defaults
#'   to a [googlesheets4::range_read_cells()]-based reader. Override in tests.
#'
#' @return The input `magic.table` with its backend bound/updated, invisibly.
#'   When a write is refused, the input is returned unchanged.
#' @export
write_sheet <- function(x, ss, sheet, start_row = 1L, overwrite = FALSE,
                        .writer = googlesheets4::range_write,
                        .reader = .gsheet_read_cell_strings) {
  if (!inherits(x, "magic.table")) {
    stop("`x` must be a magic.table.", call. = FALSE)
  }
  if (is.null(ss)) {
    stop("`ss` must not be NULL.", call. = FALSE)
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
  anchor <- paste0(sheet, "!A", start_row)
  block <- .block_range(sheet, start_row, cells)
  snapshot <- .cell_strings(cells)

  # No-clobber poll: only when re-writing the *same* target we previously bound.
  prior <- x$backend
  same_target <- !is.null(prior) && identical(prior$type, "gsheet") &&
    identical(prior$ss, ss) && identical(prior$sheet, sheet) &&
    identical(prior$start_row, start_row)

  if (same_target && !overwrite) {
    current <- .reader(ss, sheet, block)
    if (!identical(current, prior$snapshot)) {
      warning("The target sheet has changed since GsheetGenie last wrote it; ",
              "not overwriting. Pass `overwrite = TRUE` to write anyway.",
              call. = FALSE)
      return(invisible(x))
    }
  }

  .writer(ss, data = cells, range = anchor)
  x$backend <- list(type = "gsheet", ss = ss, sheet = sheet,
                    start_row = start_row, snapshot = snapshot)
  invisible(x)
}

# Character representation of a cell tibble, column-major. Formula cells render
# as their "=..." strings; other cells as their character value. Used as the
# snapshot for no-clobber reconciliation and as the comparison target for the
# reader.
.cell_strings <- function(cells) {
  unlist(lapply(cells, as.character), use.names = FALSE)
}

# A1 range covering the written block, e.g. "Sales!A3:C5".
.block_range <- function(sheet, start_row, cells) {
  last_col <- col_letter(ncol(cells))
  last_row <- start_row + nrow(cells)
  paste0(sheet, "!A", start_row, ":", last_col, last_row)
}

# Default no-clobber reader. Reads the written block's current cell contents and
# returns them column-major in the same representation as `.cell_strings()`:
# the formula text for formula cells, otherwise the entered value as character.
#
# Best-effort for v1 — the CellData extraction is conservative; if it cannot
# read a cell it yields NA, which reads as "changed" and so errs toward NOT
# clobbering. Robust formula-aware reconciliation against live Sheets is a
# follow-up (see docs/superpowers/specs/2026-06-29-magic-table-abstraction.md).
.gsheet_read_cell_strings <- function(ss, sheet, range) {
  cells <- googlesheets4::range_read_cells(
    ss, range = range, cell_data = "full", discard_empty = FALSE
  )
  # Order column-major (col then row) to match `.cell_strings()`.
  ord <- order(cells$col, cells$row)
  vapply(cells$cell[ord], function(cd) {
    uev <- cd[["userEnteredValue"]]
    if (is.null(uev)) return(NA_character_)
    if (!is.null(uev[["formulaValue"]])) return(uev[["formulaValue"]])
    v <- unlist(uev, use.names = FALSE)
    if (length(v)) as.character(v[[1]]) else NA_character_
  }, character(1))
}

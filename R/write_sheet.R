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
#' This is the Google Sheets backend for a [magic.table]. v1 writes the header
#' row + data rows in one call; it does not add title rows or summary rows —
#' compose with [make_summary_row()] + [googlesheets4::sheet_append()] for
#' richer layouts.
#'
#' @param x A [magic.table].
#' @param ss A Google Sheets identifier accepted by
#'   [googlesheets4::range_write()] (URL, sheet ID, or `dribble`).
#' @param sheet Single non-empty character string. The sheet (tab) name.
#' @param start_row Single positive integer. 1-based row of the header.
#'   Defaults to `1`.
#' @param .writer Function used to perform the write. Defaults to
#'   [googlesheets4::range_write()]. Override in tests.
#'
#' @return The cell tibble that was written, invisibly.
#' @export
write_sheet <- function(x, ss, sheet, start_row = 1L,
                        .writer = googlesheets4::range_write) {
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
  cells <- as_sheet_cells(x, start_row = start_row)
  range <- paste0(sheet, "!A", as.integer(start_row))
  .writer(ss, data = cells, range = range)
  invisible(cells)
}

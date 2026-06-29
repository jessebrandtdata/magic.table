#' Materialize a sheet_frame's pending ops into a cell tibble (pure)
#'
#' Walks every pending [mutate()][dplyr::mutate] op and translates each
#' captured expression into a column of `=`-prefixed
#' [googlesheets4::gs4_formula()] strings, anchored at `start_row`. Returns
#' the resulting tibble without touching Google Sheets.
#'
#' This is the testability lever: end-to-end correctness of the lazy
#' API can be exercised without auth.
#'
#' @param sf A [sheet_frame][as_sheet_frame].
#' @param start_row Single positive integer. The 1-based sheet row where the
#'   header lands; data cells live at rows `start_row + 1` .. `start_row + nrow`.
#'
#' @return A tibble; formula columns hold `gs4_formula()` strings.
#' @export
as_sheet_cells <- function(sf, start_row = 1L) {
  if (!inherits(sf, "sheet_frame")) {
    stop("`sf` must be a sheet_frame.", call. = FALSE)
  }
  if (!is.numeric(start_row) || length(start_row) != 1L ||
      is.na(start_row) || start_row < 1 ||
      start_row != as.integer(start_row)) {
    stop("`start_row` must be a single positive integer.", call. = FALSE)
  }
  start_row <- as.integer(start_row)

  data <- sf$data
  n_rows <- nrow(data)
  data_first_row <- start_row + 1L
  data_rows <- seq.int(data_first_row, length.out = n_rows)

  schema <- stats::setNames(col_letter(seq_along(data)), names(data))

  for (op in sf$ops) {
    if (op$verb != "mutate") {
      stop("unsupported pending op verb: ", op$verb, call. = FALSE)
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

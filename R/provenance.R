#' Column provenance of a magic.table
#'
#' Returns, for each column the table will have, whether it is an original
#' (`"source"`) column or one `"computed"` by a recorded
#' [mutate()][dplyr::mutate], and — for computed columns — the expression that
#' defines it. This is *derived* on demand from the table's data and recorded
#' ops; no provenance state is stored separately.
#'
#' Columns appear in their final order: original columns first, then any new
#' computed columns in the order they were recorded. Overwriting an existing
#' column (e.g. `mutate(sales = sales * 2)`) keeps its position but marks it
#' `"computed"` with the latest expression.
#'
#' @param x A [magic.table].
#'
#' @return A tibble with columns `column` (character), `origin`
#'   (`"source"`/`"computed"`), and `expr` (the deparsed defining expression,
#'   `NA` for source columns).
#'
#' @examples
#' magic.table(data.frame(sales = c(10, 20), cost = c(4, 8))) |>
#'   dplyr::mutate(margin = sales - cost) |>
#'   provenance()
#'
#' @export
provenance <- function(x) {
  if (!inherits(x, "magic.table")) {
    stop("`x` must be a magic.table.", call. = FALSE)
  }
  cols     <- names(x$data)
  origin   <- rep("source", length(cols))
  expr_chr <- rep(NA_character_, length(cols))

  for (op in x$ops) {
    if (op$verb != "mutate") next  # only mutate is recorded today
    for (nm in names(op$cols)) {
      e <- rlang::quo_get_expr(op$cols[[nm]])
      e_str <- paste(deparse(e), collapse = " ")
      idx <- match(nm, cols)
      if (is.na(idx)) {
        cols     <- c(cols, nm)
        origin   <- c(origin, "computed")
        expr_chr <- c(expr_chr, e_str)
      } else {
        origin[idx]   <- "computed"
        expr_chr[idx] <- e_str
      }
    }
  }

  tibble::tibble(column = cols, origin = origin, expr = expr_chr)
}

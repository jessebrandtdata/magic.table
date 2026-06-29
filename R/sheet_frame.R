#' A lazy sheet-bound data frame
#'
#' Wraps a data frame so that subsequent [mutate()][dplyr::mutate] calls record
#' pending formula columns instead of evaluating them. Materialize the result
#' with [write_sheet()] or inspect what would be written with [as_sheet_cells()].
#'
#' @param df A data frame.
#'
#' @return An object of class `c("sheet_frame", "tbl")`.
#'
#' @examples
#' df <- data.frame(region = c("E", "W"), sales = c(10, 20), cost = c(4, 8))
#' as_sheet_frame(df)
#'
#' @export
as_sheet_frame <- function(df) {
  if (!is.data.frame(df)) {
    stop("`df` must be a data frame.", call. = FALSE)
  }
  structure(
    list(data = tibble::as_tibble(df), ops = list()),
    class = c("sheet_frame", "tbl")
  )
}

# Internal accessors. Not exported.
sheet_frame_data <- function(x) x$data
sheet_frame_ops  <- function(x) x$ops

#' @export
print.sheet_frame <- function(x, ...) {
  cat("<sheet_frame> ", nrow(x$data), " rows x ", ncol(x$data), " cols\n",
      "  schema: ", paste(names(x$data), collapse = ", "), "\n",
      "  ", length(x$ops), " pending op", if (length(x$ops) != 1L) "s" else "",
      "\n", sep = "")
  invisible(x)
}

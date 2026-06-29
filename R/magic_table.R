#' A magic.table: a recorded-computation table
#'
#' `magic.table()` wraps a data frame in a lazy, computation-recording table
#' (S3 class `magic.table`, mirroring `data.frame`). Once a data frame is a
#' `magic.table`, operations on it — currently [mutate()][dplyr::mutate] — are
#' *recorded* rather than evaluated in R, so they can be **exported as live
#' formulas** to an external table (Google Sheets today; other backends later)
#' instead of collapsing to static values.
#'
#' A `magic.table` is designed around two ideas:
#'
#' \describe{
#'   \item{Recorded computation / provenance}{Every column added after creation
#'     is stored as the unevaluated expression that produced it (in `ops`), so
#'     the table knows the provenance of each derived column rather than only
#'     its values.}
#'   \item{Optional synced external table}{A `magic.table` may be bound to an
#'     external table — a Google Sheet, and in future an Excel file, on-disk
#'     table, or database — that it can write to and, eventually, reconcile
#'     against when edited externally. The binding (`backend`) is just a small
#'     piece of data carried on the object; it is `NULL` until the table is
#'     synced. Google Sheets is the first backend (see [write_sheet()]).}
#' }
#'
#' @param df A data frame.
#'
#' @return An object of class `c("magic.table", "tbl")`.
#'
#' @examples
#' df <- data.frame(region = c("E", "W"), sales = c(10, 20), cost = c(4, 8))
#' magic.table(df)
#'
#' @export
magic.table <- function(df) {
  if (!is.data.frame(df)) {
    stop("`df` must be a data frame.", call. = FALSE)
  }
  structure(
    list(
      data    = tibble::as_tibble(df),
      ops     = list(),    # recorded computations, in order (column provenance)
      backend = NULL        # optional synced external table; NULL until synced
    ),
    class = c("magic.table", "tbl")
  )
}

# Internal accessors. Not exported.
magic_table_data    <- function(x) x$data
magic_table_ops     <- function(x) x$ops
magic_table_backend <- function(x) x$backend

#' @export
print.magic.table <- function(x, ...) {
  cat("<magic.table> ", nrow(x$data), " rows x ", ncol(x$data), " cols\n",
      "  schema: ", paste(names(x$data), collapse = ", "), "\n",
      "  ", length(x$ops), " recorded op", if (length(x$ops) != 1L) "s" else "",
      "\n",
      "  backend: ", if (is.null(x$backend)) "none (not synced)" else
        format(x$backend), "\n",
      sep = "")
  invisible(x)
}

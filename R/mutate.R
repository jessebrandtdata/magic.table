#' Record pending formula columns on a magic.table
#'
#' S3 method for [dplyr::mutate()]. Captures the supplied expressions as
#' quosures without evaluating them; translation to Sheets formulas happens
#' at [write_sheet()] / [as_sheet_cells()] time. The captured expressions are
#' the column provenance — the record of how each derived column was computed.
#'
#' @param .data A [magic.table].
#' @param ... Named expressions, e.g. `margin = sales - cost`.
#'
#' @return The input `magic.table` with one additional recorded mutate op.
#' @export
#' @importFrom dplyr mutate
#' @method mutate magic.table
mutate.magic.table <- function(.data, ...) {
  quos <- rlang::enquos(...)
  if (length(quos) == 0L) return(.data)
  nms <- names(quos)
  if (is.null(nms) || any(!nzchar(nms))) {
    stop("all mutate arguments must be named (e.g. `margin = sales - cost`).",
         call. = FALSE)
  }
  .data$ops <- c(.data$ops, list(list(verb = "mutate", cols = quos)))
  .data
}

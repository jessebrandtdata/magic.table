#' Record pending formula columns on a sheet_frame
#'
#' S3 method for [dplyr::mutate()]. Captures the supplied expressions as
#' quosures without evaluating them; translation to Sheets formulas happens
#' at [write_sheet()] / [as_sheet_cells()] time.
#'
#' @param .data A [sheet_frame][as_sheet_frame].
#' @param ... Named expressions, e.g. `margin = sales - cost`.
#'
#' @return The input `sheet_frame` with one additional pending mutate op.
#' @export
#' @importFrom dplyr mutate
#' @method mutate sheet_frame
mutate.sheet_frame <- function(.data, ...) {
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

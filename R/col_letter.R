#' Convert a 1-based column index to its A1-style letter
#'
#' Vectorised. Used internally to build A1-style cell references, but exported
#' so you can assemble formulas by hand when composing custom layouts.
#'
#' @param i Integer-like vector. All values must be positive integers.
#'
#' @return A character vector the same length as `i`.
#'
#' @examples
#' col_letter(1)    # "A"
#' col_letter(27)   # "AA"
#' col_letter(c(1, 26, 27, 702))
#'
#' @export
col_letter <- function(i) {
  if (!is.numeric(i) || length(i) == 0L || any(is.na(i)) ||
      any(i < 1) || any(i != as.integer(i))) {
    stop("`i` must be a non-empty vector of positive integers.", call. = FALSE)
  }
  vapply(as.integer(i), function(n) {
    out <- ""
    while (n > 0L) {
      n <- n - 1L
      out <- paste0(LETTERS[(n %% 26L) + 1L], out)
      n <- n %/% 26L
    }
    out
  }, character(1))
}

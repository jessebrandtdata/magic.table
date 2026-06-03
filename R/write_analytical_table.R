#' Write a data table flanked by live-formula summary rows
#'
#' The headline workflow. Writes `df` to a Google Sheet using this layout:
#'
#' \describe{
#'   \item{Row 1}{`title`}
#'   \item{Row 2}{blank}
#'   \item{Row 3}{column headers}
#'   \item{Rows 4..N+3}{data}
#'   \item{Rows N+4..}{one row per element of `summaries`}
#' }
#'
#' Each summary row is built by [make_summary_row()] using the named element's
#' name as the row label and its value as the spreadsheet function.
#'
#' This function has side effects (it calls the Google Sheets API). For
#' assembling custom layouts without those side effects, see [make_summary_row()]
#' and [col_letter()].
#'
#' @param ss A spreadsheet identifier — anything
#'   [googlesheets4::range_write()] accepts.
#' @param df A data frame.
#' @param sheet Sheet (tab) name. If `NULL`, googlesheets4's default applies
#'   (typically the first visible sheet). If the named sheet doesn't exist,
#'   it is created.
#' @param title Single non-NA character string. Written to cell A1.
#' @param summaries Named character vector. Names are summary row labels;
#'   values are spreadsheet function names. Order determines row order.
#'   Defaults to `c(Total = "SUM")`.
#' @param cols Optional character vector. Restrict summary formulas to these
#'   columns. Defaults to all numeric columns of `df`.
#'
#' @return `ss`, invisibly.
#'
#' @examples
#' \dontrun{
#' library(googlesheets4)
#' ss <- gs4_create("Q1 sales analysis")
#' write_analytical_table(
#'   ss,
#'   data.frame(region = c("E", "W"), sales = c(10, 20)),
#'   sheet     = "Sales",
#'   title     = "Q1 Sales by Region",
#'   summaries = c(Total = "SUM", Average = "AVERAGE")
#' )
#' }
#'
#' @export
write_analytical_table <- function(ss, df, sheet = NULL, title,
                                   summaries = c(Total = "SUM"),
                                   cols = NULL) {
  if (!is.data.frame(df)) {
    stop("`df` must be a data frame.", call. = FALSE)
  }
  if (missing(title) || !is.character(title) || length(title) != 1L ||
      is.na(title)) {
    stop("`title` must be a single non-NA character string.", call. = FALSE)
  }
  if (!is.character(summaries) || length(summaries) == 0L ||
      is.null(names(summaries)) || any(!nzchar(names(summaries)))) {
    stop("`summaries` must be a named, non-empty character vector ",
         "(e.g. c(Total = \"SUM\")).", call. = FALSE)
  }

  ensure_sheet_exists(ss, sheet)

  title_block <- tibble::tibble(title = title)
  googlesheets4::range_write(
    ss, title_block, sheet = sheet, range = "A1",
    col_names = FALSE, reformat = FALSE
  )

  data_start_row <- 4L
  googlesheets4::range_write(
    ss, df, sheet = sheet, range = "A3",
    col_names = TRUE, reformat = FALSE
  )

  for (k in seq_along(summaries)) {
    row_index <- data_start_row + nrow(df) - 1L + k
    row <- make_summary_row(
      df,
      data_start_row = data_start_row,
      label          = names(summaries)[[k]],
      fn             = summaries[[k]],
      cols           = cols
    )
    googlesheets4::range_write(
      ss, row, sheet = sheet,
      range     = paste0("A", row_index),
      col_names = FALSE,
      reformat  = FALSE
    )
  }

  invisible(ss)
}

ensure_sheet_exists <- function(ss, sheet) {
  if (is.null(sheet)) return(invisible())
  existing <- googlesheets4::sheet_names(ss)
  if (!sheet %in% existing) {
    googlesheets4::sheet_add(ss, sheet = sheet)
  }
  invisible()
}

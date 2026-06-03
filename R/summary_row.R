#' Build a one-row summary tibble of live formulas
#'
#' Returns a one-row tibble whose numeric columns hold
#' [googlesheets4::gs4_formula()]-wrapped strings of the form
#' `=fn(<col>start:<col>end)`. The label goes in the first non-numeric column;
#' if every column is numeric, the label overwrites column 1.
#'
#' Pass the result to [googlesheets4::sheet_append()] (or
#' [googlesheets4::range_write()]) to write it to a sheet.
#'
#' @param df A data frame. Its column structure determines the shape of the
#'   returned row, and `nrow(df)` determines the formula end row.
#' @param data_start_row Single positive integer. The 1-based sheet row where
#'   `df`'s data block starts (i.e. the row just below the header row).
#' @param label Single non-NA character string.
#' @param fn Single non-empty character string — the spreadsheet function name
#'   to wrap each numeric column with (e.g. `"SUM"`, `"AVERAGE"`, `"COUNTA"`).
#' @param cols Optional character vector of column names to restrict the
#'   formulas to. All must be numeric and present in `df`. Defaults to every
#'   numeric column.
#'
#' @return A one-row tibble matching `df`'s column structure.
#'
#' @examples
#' df <- data.frame(region = c("E", "W"), sales = c(10, 20), units = c(1, 2))
#' make_summary_row(df, data_start_row = 4, label = "Total", fn = "SUM")
#'
#' @export
make_summary_row <- function(df, data_start_row, label, fn, cols = NULL) {
  if (!is.data.frame(df)) {
    stop("`df` must be a data frame.", call. = FALSE)
  }
  if (!is.numeric(data_start_row) || length(data_start_row) != 1L ||
      is.na(data_start_row) || data_start_row < 1 ||
      data_start_row != as.integer(data_start_row)) {
    stop("`data_start_row` must be a single positive integer.", call. = FALSE)
  }
  if (!is.character(label) || length(label) != 1L || is.na(label)) {
    stop("`label` must be a single non-NA character string.", call. = FALSE)
  }
  if (!is.character(fn) || length(fn) != 1L || is.na(fn) || !nzchar(fn)) {
    stop("`fn` must be a single non-empty character string.", call. = FALSE)
  }

  n <- nrow(df)
  data_start_row <- as.integer(data_start_row)
  data_end_row <- data_start_row + n - 1L

  numeric_mask <- vapply(df, is.numeric, logical(1))

  if (!is.null(cols)) {
    if (!is.character(cols)) {
      stop("`cols` must be a character vector or NULL.", call. = FALSE)
    }
    missing <- setdiff(cols, names(df))
    if (length(missing)) {
      stop("`cols` not found in `df`: ", paste(missing, collapse = ", "),
           call. = FALSE)
    }
    non_numeric <- cols[!numeric_mask[cols]]
    if (length(non_numeric)) {
      stop("`cols` includes non-numeric column(s): ",
           paste(non_numeric, collapse = ", "), call. = FALSE)
    }
    formula_mask <- numeric_mask & (names(df) %in% cols)
  } else {
    formula_mask <- numeric_mask
  }

  row <- vector("list", ncol(df))
  names(row) <- names(df)

  label_placed <- FALSE
  for (j in seq_along(df)) {
    if (formula_mask[[j]]) {
      letter <- col_letter(j)
      f <- sprintf("=%s(%s%d:%s%d)", fn, letter, data_start_row,
                   letter, data_end_row)
      row[[j]] <- googlesheets4::gs4_formula(f)
    } else if (!label_placed && !numeric_mask[[j]]) {
      row[[j]] <- label
      label_placed <- TRUE
    } else if (numeric_mask[[j]]) {
      row[[j]] <- NA_real_
    } else {
      row[[j]] <- NA_character_
    }
  }

  if (!label_placed && ncol(df) >= 1L) {
    row[[1]] <- label
  }

  tibble::as_tibble(row)
}

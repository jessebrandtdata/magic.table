# Pure AST walker. No I/O, no Sheets calls.
#
# walk_expr(expr, schema, row_n) -> character(1) formula fragment.
#
# - expr:   an unevaluated R expression (typically rlang::quo_get_expr(quosure))
# - schema: named character vector mapping column-name -> column-letter
#           (e.g. c(sales = "B", cost = "C"))
# - row_n:  1-based sheet row of the current data cell
walk_expr <- function(expr, schema, row_n) {
  ctx <- list(schema = schema, row_n = row_n)
  .walk(expr, ctx)
}

.walk <- function(expr, ctx) {
  if (rlang::is_symbol(expr)) {
    return(.translate_symbol(expr, ctx))
  }
  if (rlang::is_call(expr)) {
    return(.translate_call(expr, ctx))
  }
  # Anything else is a literal (numeric, logical, character, or NA).
  .translate_literal(expr, ctx)
}

.translate_symbol <- function(sym, ctx) {
  name <- as.character(sym)
  idx <- match(name, names(ctx$schema))
  if (is.na(idx)) {
    stop("column `", name, "` not found in magic.table; have: ",
         paste(names(ctx$schema), collapse = ", "), ".", call. = FALSE)
  }
  paste0(ctx$schema[[idx]], ctx$row_n)
}

.translate_literal <- function(lit, ctx) {
  if (length(lit) != 1L) {
    stop("only scalar literals are supported (got length ", length(lit), ").",
         call. = FALSE)
  }
  if (is.na(lit)) {
    stop("NA literals are not supported; use `is.na(col)` to test for blank cells.",
         call. = FALSE)
  }
  if (is.logical(lit))   return(if (isTRUE(lit)) "TRUE" else "FALSE")
  if (is.numeric(lit))   return(format(lit, scientific = FALSE, trim = TRUE))
  if (is.character(lit)) {
    escaped <- gsub('"', '""', lit, fixed = TRUE)
    return(paste0('"', escaped, '"'))
  }
  stop("unsupported literal type: ", typeof(lit), call. = FALSE)
}

.translate_call <- function(call, ctx) {
  head <- call[[1]]
  if (!rlang::is_symbol(head)) {
    stop("only named function calls are supported (got a complex call head).",
         call. = FALSE)
  }
  name <- as.character(head)
  translator <- the$translators[[name]]
  if (is.null(translator)) {
    stop("no Sheets translator for `", name,
         "`; register one with `register_sheet_translator()`.", call. = FALSE)
  }
  args <- lapply(as.list(call)[-1L], .walk, ctx = ctx)
  translator(args, ctx)
}

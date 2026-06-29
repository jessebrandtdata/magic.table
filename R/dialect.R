# Package-private environment holding the active translator dispatch table.
# Each entry is function(args, ctx) -> character(1), where:
#   args : list of already-translated child strings, in source order
#   ctx  : list with at least `schema` (named char vec: column-name -> letter)
#          and `row_n` (1-based sheet row of the current data cell)
the <- new.env(parent = emptyenv())
the$translators <- list()

#' Return the active Sheets-formula translator dispatch table
#'
#' Each entry is keyed by the R call head it translates (e.g. `"+"`,
#' `"ifelse"`) and is a function `function(args, ctx) -> character(1)`.
#'
#' @return A named list of translator functions.
#' @export
sheet_translators <- function() {
  as.list(the$translators)
}

#' Register or remove a Sheets-formula translator
#'
#' @param name Single non-empty character string. The R call head to
#'   translate (e.g. `"pmax"`, `"paste0"`).
#' @param fn A function `function(args, ctx) -> character(1)` that returns a
#'   formula fragment, or `NULL` to remove the translator.
#'
#' @return Invisibly, the previous translator at `name` (or `NULL`).
#' @export
register_sheet_translator <- function(name, fn) {
  if (!is.character(name) || length(name) != 1L || is.na(name) || !nzchar(name)) {
    stop("`name` must be a single non-empty character string.", call. = FALSE)
  }
  if (!is.null(fn) && !is.function(fn)) {
    stop("`fn` must be a function or NULL.", call. = FALSE)
  }
  prev <- the$translators[[name]]
  if (is.null(fn)) {
    the$translators[[name]] <- NULL
  } else {
    the$translators[[name]] <- fn
  }
  invisible(prev)
}

# ---- v1 defaults: binary arithmetic --------------------------------------

# Helper: build a translator for a left-associative binary infix operator.
# We parenthesize each arg so precedence is preserved when nested expressions
# bubble up. The parens are slightly noisy but correct.
.binop <- function(symbol) {
  force(symbol)
  function(args, ctx) {
    if (length(args) != 2L) {
      stop("operator `", symbol, "` expects 2 arguments, got ", length(args),
           ".", call. = FALSE)
    }
    paste0("(", args[[1]], ")", symbol, "(", args[[2]], ")")
  }
}

.install_defaults <- function() {
  the$translators[["+"]] <- .binop("+")
  the$translators[["-"]] <- function(args, ctx) {
    # `-` is unary or binary; handle both.
    if (length(args) == 1L) return(paste0("-(", args[[1]], ")"))
    if (length(args) == 2L) return(paste0("(", args[[1]], ")-(", args[[2]], ")"))
    stop("operator `-` expects 1 or 2 arguments, got ", length(args), ".",
         call. = FALSE)
  }
  the$translators[["*"]] <- .binop("*")
  the$translators[["/"]] <- .binop("/")
  the$translators[["^"]] <- .binop("^")

  # Grouping: `(x)` parses as a call to `(`. Pass the inner fragment through;
  # the surrounding operator's translator adds parens where precedence needs them.
  the$translators[["("]] <- function(args, ctx) {
    if (length(args) != 1L) {
      stop("grouping `(` expects 1 argument, got ", length(args), ".",
           call. = FALSE)
    }
    args[[1]]
  }
}

# Install defaults at package load.
.onLoad <- function(libname, pkgname) {
  .install_defaults()
}

# Also install at source time so devtools::load_all() / tests work without
# depending on .onLoad firing.
.install_defaults()

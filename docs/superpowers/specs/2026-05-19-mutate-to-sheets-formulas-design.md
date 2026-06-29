# Design: `mutate()` → Sheets formulas

**Status:** Draft — pending user review
**Date:** 2026-05-19
**Owner:** Jesse Brandt

## Goal

Let a user write tidy expressions in R and have them land in Google Sheets as
live formulas, not as pre-computed values. The model is "dbplyr, but the
backend is Sheets formula syntax instead of SQL": capture the unevaluated
expression, walk its AST, emit A1-style formula text, and write each data row
as a `gs4_formula()` cell.

```r
df |>
  as_sheet_frame() |>
  mutate(margin     = sales - cost,
         margin_pct = margin / sales) |>
  write_sheet(ss, sheet = "Sales", start_row = 3)
```

With `start_row = 3`, the header lands at row 3 and data fills rows 4..N+3.
Each row of the `margin` column holds `=B4-C4`, `=B5-C5`, …; each row of
`margin_pct` holds `=D4/B4`, `=D5/B5`, … . (`sales` is column B, `cost` is C,
`margin` ends up at D.)

## Non-goals (v1)

- Verbs other than `mutate`. `summarize`, `filter`, `select`, `group_by`,
  `arrange`, `transmute` are explicitly out of scope. `summarize` is the most
  obvious next step but stays as today's eager `make_summary_row()` for now.
- Formatting, styling, conditional formatting, number formats.
- Auto-detection of where to place the block (no "find next empty row" magic).
- Cross-sheet references (`='Other Sheet'!A1`). Single-sheet only.
- Compatibility shim for the legacy `write_analytical_table()` /
  `make_summary_row()` API — they remain untouched and continue to work.

## Public API (v1)

| Symbol                           | Kind            | Purpose                                                    |
| -------------------------------- | --------------- | ---------------------------------------------------------- |
| `as_sheet_frame(df)`             | Constructor     | Wrap a data frame in a `sheet_frame` (S3).                 |
| `mutate.sheet_frame(.data, ...)` | S3 method       | Record pending formula columns. Lazy — no translation yet. |
| `write_sheet(sf, ss, sheet, …)`  | Writer          | Materialize: pick row anchor, translate, write cells.      |
| `as_sheet_cells(sf, start_row)`  | Pure inspector  | Return the cell tibble that *would* be written. No I/O.    |
| `register_sheet_translator(name, fn)` | Extension  | Add or override a translator in the dispatch table.        |
| `sheet_translators()`            | Introspection   | Return the current translator dispatch table.              |
| `print.sheet_frame(x, …)`        | REPL display    | Show schema + pending ops compactly.                       |

The existing `col_letter()`, `make_summary_row()`, `write_analytical_table()`
remain exported and unchanged.

### `as_sheet_frame(df)`

Returns an object of class `c("sheet_frame", "tbl")` containing:

```r
list(
  data = <tibble: the original rows>,
  ops  = list()  # pending operations, in order
)
```

Each entry in `ops` is currently `list(verb = "mutate", cols = <named list of quosures>)`.
The list-of-ops shape leaves room for `filter`, `summarize`, etc. later
without a rewrite.

### `mutate.sheet_frame(.data, ...)`

Captures `rlang::enquos(...)` and appends a new `mutate` op. Returns the
updated `sheet_frame`. No translation, no Sheets work. Multiple `mutate()`
calls accumulate in order.

Within a single `mutate()` call, columns are processed in the order given, so
`mutate(a = x + 1, b = a * 2)` resolves `a` to its new column letter before
translating `b`. Same as `dplyr::mutate`.

### `write_sheet(sf, ss, sheet, start_row = 1)`

1. Compute the final **schema**: original columns plus every column added by
   pending `mutate` ops, in order. Assign each a column letter via
   `col_letter()`.
2. Compute the **data range**: rows `start_row` (header) through
   `start_row + nrow(data)`. Data cells live at rows `start_row + 1`
   through `start_row + nrow(data)`.
3. For each pending formula column, ask the translator for a **row template**:
   a function `function(row_n) -> character(1)` returning the A1 formula for
   that row. Apply it across all data rows to materialize cell values.
4. Build a single tibble of cell values (formula columns hold `gs4_formula()`
   strings; original columns pass through unchanged) and write it with
   `googlesheets4::range_write()` anchored at `start_row`.

v1 deliberately does **not** integrate with `write_analytical_table()`'s
title/blank/summary layout. A user who wants title + lazy mutate + summaries
can compose: `range_write(title)` → `write_sheet(sf, start_row = …)` →
`sheet_append(make_summary_row(...))`. Bundling that into a single high-level
writer is a follow-up.

### `as_sheet_cells(sf, start_row = 1)`

Pure function returning the cell tibble that `write_sheet()` would send to
Sheets. No googlesheets4 calls. **This is the testability lever** — almost
every test in the package can run against this and never touch a real
spreadsheet.

### `register_sheet_translator(name, fn)`

Adds an entry to the dispatch table. `name` is the R call head (e.g.
`"pmax"`, `"paste0"`); `fn` is a function `(args, schema, row_n) ->
character(1)` that returns the Sheets formula fragment. Returns the previous
entry invisibly (or `NULL`) so users can save and restore.

Registrations are stored in a package-level environment, so they persist for
the session.

## Translator architecture

### Pipeline

```
quosure  --[ rlang::quo_get_expr ]-->  R expression (AST)
                                            |
                                            v
                                  walk_expr(expr, schema, dialect)
                                            |
                                            v
                              row_template :: function(row_n) -> character(1)
                                            |
                                            v
                              applied per data row -> column of formula strings
```

`walk_expr()` recurses over the AST:

- **Symbol** that names a known column → emit `"<letter><row_n>"`.
- **Symbol** otherwise → error: "column `foo` not found in sheet_frame
  (have: …)".
- **Literal** (numeric, logical, string) → emit its Sheets-literal form
  (`TRUE`/`FALSE`, quoted strings, raw numbers).
- **Call** `f(args…)` → look up `f` in the dialect table; if missing, error
  with a "register a translator" hint. Each translator receives the
  already-translated arg strings plus the row context.

The output of `walk_expr` is a function `function(row_n)` that produces the
finished formula string. (Implementation note: we either build a closure that
captures the recursive structure, or do two passes — translate to a "template
expression" with row placeholders, then `sprintf` per row. Pick whichever is
simpler at implementation time; the public contract is the same.)

### Dialect dispatch table

Stored as a named list in an internal environment, seeded at package load
with the v1 default dialect. `register_sheet_translator()` mutates this
environment; `sheet_translators()` returns a snapshot.

Each translator has signature `function(args, ctx) -> character(1)`:

- `args` is a list of already-translated child strings, in source order.
  Arity-sensitive operators (e.g. `-` is both unary and binary) inspect
  `length(args)` to decide which form to emit.
- `ctx` is a list carrying at minimum `row_n` (the current data row, 1-based
  in sheet coordinates) and `schema` (named character vector of
  column-name → column-letter). Translators that don't need either ignore
  them.

Translation is single-pass: the walker recurses bottom-up, so by the time a
call's translator runs, its arguments are already strings.

### v1 default dialect

| R                                    | Sheets                              |
| ------------------------------------ | ----------------------------------- |
| `+ - * / ^`  (binary)                | `+ - * / ^`                         |
| `-x`  (unary minus)                  | `-x`                                |
| `( )` grouping                       | `( )`                               |
| `< <= > >= == !=`                    | `< <= > >= = <>`                    |
| `& | !`                              | `AND(…) OR(…) NOT(…)`               |
| `ifelse(c, y, n)`                    | `IF(c, y, n)`                       |
| `abs, round, sqrt`                   | `ABS, ROUND, SQRT`                  |
| `pmin, pmax`                         | `MIN, MAX`                          |
| `is.na(x)`                           | `ISBLANK(x)`                        |
| Numeric literal                      | Bare number                         |
| Logical literal                      | `TRUE` / `FALSE`                    |
| String literal `"foo"`               | `"foo"` (with `"` doubled if any)   |

That's the shipping set. Anything else errors with a clear message pointing
at `register_sheet_translator()`. String functions (`paste0` → `&`, `nchar` →
`LEN`, etc.) are deliberately omitted from v1 to keep the surface tight — they
can either ship as a follow-up "dialect pack" or be registered by users.

## Data flow & module layout

New files under `R/`:

- `R/sheet_frame.R` — `as_sheet_frame()`, `print.sheet_frame()`, internal
  accessors for `data` / `ops` / `schema`.
- `R/mutate.R` — `mutate.sheet_frame()`. Imports the `mutate` generic from
  dplyr via `@importFrom`.
- `R/translate.R` — `walk_expr()` and helpers. Pure, no Sheets I/O.
- `R/dialect.R` — internal environment holding the dispatch table, default
  translators, `register_sheet_translator()`, `sheet_translators()`.
- `R/write_sheet.R` — `write_sheet()` and `as_sheet_cells()`.

Existing files (`col_letter.R`, `summary_row.R`, `write_analytical_table.R`,
`GsheetGenie-package.R`) are not modified.

`DESCRIPTION` adds `rlang` (Imports) and `dplyr` (Imports — for the
`mutate` generic). `tibble` stays. `googlesheets4` stays.

## Error handling

All errors raised with `stop(..., call. = FALSE)` to match the package's
current style.

| Trigger                                            | Message                                                            |
| -------------------------------------------------- | ------------------------------------------------------------------ |
| `as_sheet_frame()` given a non-data-frame          | "`df` must be a data frame."                                       |
| `mutate.sheet_frame()` arg is not a bare name = expr | rely on rlang's quosure capture (errors propagate naturally)     |
| Unknown column symbol during translation           | "column `foo` not found in sheet_frame (have: a, b, c)"            |
| Unknown call head during translation               | "no Sheets translator for `f()`; register one with `register_sheet_translator()`" |
| Translator registration with non-character name    | "`name` must be a single non-empty character string."              |
| Translator registration with non-function `fn`     | "`fn` must be a function."                                         |
| `write_sheet()` `start_row` not a positive integer | mirror existing `make_summary_row()` validation                    |

## Testing strategy

The package is testthat-edition-3 already. New tests split across:

1. **`tests/testthat/test-translate.R`** — pure translator tests. Construct a
   schema by hand, feed quosures to `walk_expr()`, snapshot the output string
   for `row_n = 4`. Covers arithmetic, comparisons, `ifelse`, unary minus,
   precedence/parens, literal handling, error paths.

2. **`tests/testthat/test-mutate-sheet-frame.R`** — `mutate.sheet_frame()`
   semantics: accumulates ops, in-call column reuse (`a = x + 1, b = a * 2`),
   doesn't touch the original data tibble.

3. **`tests/testthat/test-as-sheet-cells.R`** — end-to-end without
   googlesheets4: build a `sheet_frame`, run mutate, call `as_sheet_cells()`,
   assert cell values for every column at multiple `start_row` values.

4. **`tests/testthat/test-dialect.R`** — `register_sheet_translator()` adds,
   overrides, and (via the returned invisible previous value) restores
   entries; validation errors fire correctly.

5. **`tests/testthat/test-write-sheet.R`** — mocked `range_write` (or skip on
   no-auth) to verify the writer assembles the right call. Small surface.

No live-Sheets tests in v1. All correctness lives in `as_sheet_cells()`.

## Open questions / explicit deferrals

- **String literals & escaping** — v1 emits R string literals into Sheets by
  doubling embedded `"` characters (Sheets' escape rule). Other characters
  pass through untouched. Newlines inside strings are not specially handled
  in v1.
- **NA handling in literals** — a bare `NA` / `NA_real_` / `NA_character_`
  appearing as a literal in an expression errors in v1 with "NA literals are
  not supported; use `is.na(col)` to test for blank cells". `is.na()` on a
  column reference is supported via the default dialect.
- **Locale-sensitive list separators** — Sheets uses `,` in English locales,
  `;` in some others. v1 emits `,`. Document as English-locale-only.
- **`across()` and `c_across()`** — explicitly unsupported in v1; reserved for
  the "more verbs" follow-up.
- **Title + summary integration** — left as user-composition; bundling is a
  follow-up after the lazy frame proves itself.

## Completion criteria

1. The example in §Goal runs end-to-end against a real spreadsheet and the
   cells round-trip as live formulas.
2. `as_sheet_cells()` is fully covered by tests at multiple `start_row`
   values, multi-mutate, and in-call self-reference.
3. The translator's error paths each have a dedicated test.
4. `register_sheet_translator()` can override a default and restore it.
5. A short vignette section (in the existing `vignettes/gsheetgenie.Rmd`)
   demonstrates the new lazy-frame flow alongside the existing eager helpers.

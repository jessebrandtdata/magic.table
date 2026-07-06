#!/usr/bin/env Rscript
# Verification demo: prove the offline R-expression -> A1 formula translation
# produces spreadsheet formulas that evaluate correctly when hand-pasted into a
# real Google Sheet / Excel. No googlesheets4 API, no auth, no token.
#
# What it does:
#   1. Wraps head(mtcars) as a magic.table.
#   2. Records lazy mutate columns (pure arithmetic + a mean-based ratio).
#   3. Adds a live-formula summary row (column averages).
#   4. Materializes the whole thing to an A1 cell grid via as_sheet_cells().
#   5. Emits it as tab-separated text (formula cells are literal "=..." strings)
#      whose paste target is cell A1, so relative references line up.
#   6. Prints the values the formulas SHOULD evaluate to (computed eagerly in R).
#
# Run from the package root:  Rscript verification/make-demo.R

suppressMessages(devtools::load_all(quiet = TRUE))

out_dir  <- "verification"
tsv_path <- file.path(out_dir, "demo-paste.tsv")

# ---- 1. Source data -------------------------------------------------------
# A small, universally-available dataset. Keep a readable label column so the
# pasted grid is legible; the numeric columns are what the formulas reference.
raw <- head(mtcars, 6L)
df  <- data.frame(
  car = rownames(raw),
  mpg = raw$mpg,
  hp  = raw$hp,
  wt  = raw$wt,
  cyl = raw$cyl,
  stringsAsFactors = FALSE
)

START_ROW       <- 1L                       # header lands on sheet row 1
DATA_FIRST_ROW  <- START_ROW + 1L           # -> row 2
DATA_LAST_ROW   <- DATA_FIRST_ROW + nrow(df) - 1L   # -> row 7

# ---- 2. A mean-based-ratio needs a whole-column aggregate -----------------
# The built-in dialect translates a bare column symbol to the CURRENT row's
# cell (e.g. `mpg` -> "B2"), so it cannot by itself express an aggregate over
# the whole column. We extend the dialect with the PUBLIC export
# register_sheet_translator() -- the showpiece extension point -- teaching it to
# turn mean(col) into an absolute-range AVERAGE(col$first:col$last). This is a
# genuinely live formula, not a baked-in constant.
register_sheet_translator("mean", function(args, ctx) {
  col <- sub("[0-9]+$", "", args[[1]])      # "B2" -> "B"
  sprintf("AVERAGE(%s$%d:%s$%d)", col, DATA_FIRST_ROW, col, DATA_LAST_ROW)
})

# ---- 3. Record lazy computations ------------------------------------------
mt <- magic.table(df) |>
  mutate(
    power_to_weight = hp / wt,        # pure arithmetic across two columns
    mpg_vs_avg      = mpg / mean(mpg) # mean-based ratio (uses the aggregate above)
  )

# ---- 4. Materialize to the A1 cell grid (pure; no network) ----------------
cells <- as_sheet_cells(mt, start_row = START_ROW)

# A live-formula summary row: column averages of the source numeric columns.
summary <- make_summary_row(
  df,
  data_start_row = DATA_FIRST_ROW,
  label          = "Average",
  fn             = "AVERAGE"
)

# ---- 5. Emit the TSV (formula cells as literal "=..." strings) ------------
# Stringify every column: gs4_formula cells render as their "=..." text;
# literal data cells render as their value. Blank-pad the summary row to the
# full grid width (it has no derived columns).
stringify <- function(x) vapply(x, as.character, character(1))
grid <- as.data.frame(lapply(cells, stringify), stringsAsFactors = FALSE)

summary_row <- setNames(rep("", ncol(cells)), names(cells))
for (nm in names(summary)) summary_row[[nm]] <- as.character(summary[[nm]])

block <- rbind(
  setNames(as.list(names(cells)), names(cells)),  # header row
  grid,
  summary_row
)

write.table(block, tsv_path, sep = "\t", quote = FALSE,
            row.names = FALSE, col.names = FALSE, na = "")

# ---- 6. Expected values (eager R evaluation of the same expressions) ------
mpg_mean <- mean(df$mpg)
expected <- data.frame(
  car             = df$car,
  power_to_weight = round(df$hp / df$wt, 4),
  mpg_vs_avg      = round(df$mpg / mpg_mean, 4)
)
avg_row <- round(sapply(df[c("mpg", "hp", "wt", "cyl")], mean), 4)

cat("\n==== wrote", tsv_path, "====\n\n")
cat("Grid that will be pasted (paste target = cell A1):\n\n")
print(block, right = FALSE)
cat("\nExpected computed values (evaluate the same expressions in R):\n\n")
print(expected, row.names = FALSE)
cat("\n'Average' summary row should show:\n")
cat(sprintf("  mpg=%s  hp=%s  wt=%s  cyl=%s\n",
            avg_row["mpg"], avg_row["hp"], avg_row["wt"], avg_row["cyl"]))
cat(sprintf("\n(mean(mpg) over the 6 rows = %s)\n", round(mpg_mean, 4)))

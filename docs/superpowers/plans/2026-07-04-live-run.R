#!/usr/bin/env Rscript
# GsheetGenie live end-to-end run — service-account auth, one command.
#
# Config (env vars, both required to actually write to Sheets):
#   GSHEETGENIE_SA_KEY   path to the GCP service-account JSON key
#   GSHEETGENIE_SHEET    URL or ID of a Google Sheet already shared with that
#                        service account's email (Editor access)
#
# Without both set, this runs in DRY-RUN mode: it exercises the full lazy
# pipeline (magic.table -> mutate -> as_sheet_cells) with no network calls,
# so the formula-generation path is proven even while the htask (service
# account creation) is still pending. See docs/superpowers/plans/2026-07-04-live-run-runbook.md.

devtools::load_all(".", quiet = TRUE)
suppressPackageStartupMessages({
  library(dplyr)
})

key_path   <- Sys.getenv("GSHEETGENIE_SA_KEY", unset = NA)
sheet_id   <- Sys.getenv("GSHEETGENIE_SHEET", unset = NA)
dry_run    <- is.na(key_path) || is.na(sheet_id) || !nzchar(key_path) || !nzchar(sheet_id)

df <- tibble::tibble(
  region = c("East", "West", "North"),
  sales  = c(120, 80, 95),
  cost   = c(40, 30, 50)
)

mt <- df |>
  magic.table() |>
  mutate(margin     = sales - cost,
         margin_pct = round(margin / sales, 2))

cat("Provenance:\n")
print(provenance(mt))

if (dry_run) {
  cat("\n[DRY RUN] GSHEETGENIE_SA_KEY / GSHEETGENIE_SHEET not set — ",
      "skipping the network write. Formula cells that WOULD be sent:\n", sep = "")
  print(as_sheet_cells(mt, start_row = 1))
  cat("\nSet both env vars and re-run this script to perform the live write.\n")
  quit(save = "no", status = 0)
}

library(googlesheets4)
gs4_auth(path = key_path)

result <- write_sheet(mt, sheet_id, sheet = "Sales", start_row = 1)

cat("\nWrote live formulas to:", googlesheets4::gs4_get(sheet_id)$spreadsheet_url, "\n")
cat("Backend binding:\n")
print(result$backend)

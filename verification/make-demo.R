#!/usr/bin/env Rscript
# Thin artifact regenerator — run from the package root:
#     Rscript verification/make-demo.R
#
# The canonical, narrated demo now lives in verification/magic-table-demo.qmd.
# This shim just executes that document's R code chunks to (re)write the
# verification artifacts (demo-formulas.xlsx, demo-paste.tsv) without producing
# rendered HTML. For the full rendered walkthrough instead, use:
#     quarto render verification/magic-table-demo.qmd
#
# (The .qmd's `library(GsheetGenie)` becomes `library(magic.table)` after the
# public rename; here we load the in-development package with devtools.)

suppressMessages(devtools::load_all(quiet = TRUE))

tmp <- tempfile(fileext = ".R")
knitr::purl("verification/magic-table-demo.qmd", output = tmp, quiet = TRUE)

old <- setwd("verification")
on.exit(setwd(old), add = TRUE)
source(tmp, local = new.env())
setwd(old)

cat("Regenerated verification/demo-formulas.xlsx and verification/demo-paste.tsv\n")

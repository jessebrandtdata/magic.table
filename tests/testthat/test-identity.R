# The source ships no person. The maintainer's name may appear only where it
# carries a function rather than an attribution: the package author field,
# the license copyright line, and the Rd roxygen generates from DESCRIPTION.
# This file spells the name in its allow-list, so it skips itself.
#
# Needs only base R + testthat, so `check` can run it in a box without the
# package's dependencies installed.

test_that("the source tree carries no personal name outside system identifiers", {
  root <- normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  # Under R CMD check the tests run from <pkg>.Rcheck/tests, two levels below
  # a directory of check logs, not the source tree. Only the checkout is swept.
  skip_if_not(file.exists(file.path(root, "DESCRIPTION")) &&
                dir.exists(file.path(root, "R")),
              "not run from the source checkout")

  allowed <- c(
    "DESCRIPTION",                      # Authors@R: the package author field
    "LICENSE", "LICENSE.md",            # copyright holder
    "man/magic.table-package.Rd",       # generated from DESCRIPTION
    "tests/testthat/test-identity.R"    # this file
  )
  skip_dirs <- c(".git", ".claude", ".Rproj.user", "docs", "inst/doc", "lost+found")

  walk <- function(dir) {
    entries <- tryCatch(list.files(dir, all.files = TRUE, no.. = TRUE,
                                   full.names = TRUE),
                        error = function(e) character())
    out <- character()
    for (e in entries) {
      rel <- substring(e, nchar(root) + 2L)
      # `.git` is a directory in a clone and a pointer file in a worktree.
      if (rel %in% skip_dirs || basename(e) %in% skip_dirs) next
      info <- file.info(e)
      if (isTRUE(info$isdir)) {
        out <- c(out, walk(e))
      } else if (!is.na(info$isdir)) {
        out <- c(out, e)
      }
    }
    out
  }

  files <- walk(root)
  rel <- substring(files, nchar(root) + 2L)
  binary <- grepl("\\.(xlsx|png|svg|rds|RData|bin)$", rel, ignore.case = TRUE)
  candidates <- files[!(rel %in% allowed) & !binary]

  hits <- character()
  for (f in candidates) {
    lines <- tryCatch(readLines(f, warn = FALSE, encoding = "UTF-8"),
                      error = function(e) character())
    bad <- grepl("\\bjesse\\b", lines, ignore.case = TRUE) |
      grepl("\\bbrandt\\b", lines, ignore.case = TRUE)
    if (any(bad)) {
      hits <- c(hits, paste0(substring(f, nchar(root) + 2L), ":",
                             which(bad)[1]))
    }
  }

  if (length(hits)) {
    fail(paste("personal name in source:", paste(hits, collapse = ", ")))
  } else {
    succeed()
  }
})

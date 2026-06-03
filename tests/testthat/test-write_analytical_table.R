# write_analytical_table() has side effects (calls the Google Sheets API).
# These tests cover only its pure input validation; the API-touching path is
# verified by inspection plus the make_summary_row tests.

test_that("write_analytical_table validates inputs before any API call", {
  expect_error(
    write_analytical_table("ss", "not a df", title = "T"),
    "`df`"
  )
  expect_error(
    write_analytical_table("ss", data.frame(x = 1), title = c("a", "b")),
    "`title`"
  )
  expect_error(
    write_analytical_table("ss", data.frame(x = 1), title = "T",
                           summaries = c("SUM")),
    "`summaries`"
  )
  expect_error(
    write_analytical_table("ss", data.frame(x = 1), title = "T",
                           summaries = character(0)),
    "`summaries`"
  )
})

# =============================================================================
# Final output writer tests
# =============================================================================
# Created: 2026-10-05
# =============================================================================

library(testthat)
source(file.path(here::here("R"), "save.R"))

test_that("final CSV and DTA writers write atomically to the requested output", {
  root <- tempfile("spi-output-")
  csv_path <- file.path(root, "SPI_data.csv")
  dta_path <- file.path(root, "SPI_data.dta")
  data <- data.frame(iso3c = "AAA", date = 2024, score = 1)

  expect_identical(write_output_csv(data, csv_path), csv_path)
  expect_identical(write_output_dta(data, dta_path), dta_path)
  expect_true(file.exists(csv_path))
  expect_true(file.exists(dta_path))
  expect_equal(readr::read_csv(csv_path, show_col_types = FALSE)$score, 1)
  expect_equal(as.numeric(haven::read_dta(dta_path)$score), 1)
})

test_that("failed output replacement preserves the existing file", {
  root <- tempfile("spi-output-failure-")
  dir.create(root, recursive = TRUE)
  target <- file.path(root, "output.csv")
  temporary <- file.path(root, "temporary.csv")
  writeLines("old", target)
  writeLines("new", temporary)

  expect_error(
    replace_output_file(temporary, target, rename_fn = function(...) FALSE),
    "OUTPUT WRITE FAILED"
  )
  expect_equal(readLines(target), "old")
})

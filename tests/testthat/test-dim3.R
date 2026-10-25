# =============================================================================
# Dimension 3 (UN SDG data products) estimation reader tests
# =============================================================================
# D3 history is frozen: each published year comes only from that year's own
# file (01_raw_data/3_DP/<year>/SPI_D3_UNSD_data_5yr.csv), even though newer
# files recompute earlier years.
#
# Created: 2026-10-23
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "dim3.R"))

d3_goal_columns <- paste0("SPI.D3.", 1:17)

write_d3_year_file <- function(raw_dir, year, rows) {
  dir.create(file.path(raw_dir, "3_DP", year), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(rows, file.path(raw_dir, "3_DP", year, "SPI_D3_UNSD_data_5yr.csv"))
}

d3_rows <- function(dates, value) {
  rows <- tibble::tibble(iso3c = "AAA", date = dates, country = "Alpha", region = "R", income = "I")
  for (column in d3_goal_columns) rows[[column]] <- value
  rows
}

test_that("D3 takes each year only from that year's own file", {
  raw <- withr::local_tempdir()
  # The 2024 file recomputes 2023 with a different value; it must be ignored.
  write_d3_year_file(raw, 2023, d3_rows(2023, 0.25))
  write_d3_year_file(raw, 2024, d3_rows(c(2023, 2024), 0.75))

  out <- combine_dim3(list(raw_dir = raw, span = 2023:2024))

  expect_equal(nrow(out), 2)
  expect_equal(out$SPI.D3.1.POV[out$date == 2023], 0.25)
  expect_equal(out$SPI.D3.1.POV[out$date == 2024], 0.75)
  expect_true(all(c("SPI.D3.1.POV", "SPI.D3.17.PTNS") %in% names(out)))
  expect_false(any(grepl("^SPI[.]D3[.]14", names(out))))
  expect_false("SPI.D3.1" %in% names(out))
})

test_that("a missing D3 year file fails loudly", {
  raw <- withr::local_tempdir()
  write_d3_year_file(raw, 2023, d3_rows(2023, 0.5))
  expect_error(
    combine_dim3(list(raw_dir = raw, span = 2023:2024)),
    "D3 YEAR FILE NOT FOUND"
  )
})

test_that("D3 for 2004-2024 equals the published 2024 vintage", {
  fixture <- readr::read_csv(
    here::here("tests", "fixtures", "SPI_data.csv"),
    show_col_types = FALSE, guess_max = 1e5
  )
  d3_columns <- grep("^SPI[.]D3[.]", names(fixture), value = TRUE)
  d3_columns <- d3_columns[d3_columns != "SPI.D3.NA"]

  out <- suppressMessages(combine_dim3(list(raw_dir = here::here("01_raw_data"), span = 2004:2024)))
  joined <- dplyr::inner_join(
    out[, c("iso3c", "date", d3_columns)],
    fixture[, c("iso3c", "date", d3_columns)],
    by = c("iso3c", "date"),
    suffix = c(".new", ".published")
  )
  expect_gt(nrow(joined), 4000)
  for (column in d3_columns) {
    expect_equal(
      joined[[paste0(column, ".new")]],
      joined[[paste0(column, ".published")]],
      tolerance = 1e-9,
      info = column
    )
  }
})

test_that("the estimation graph tracks every D3 year file", {
  network <- targets::tar_network(
    script = here::here("_targets.R"),
    targets_only = TRUE
  )
  expect_true(any(network$edges$from == "d3_year_files" & network$edges$to == "dim3"))
})

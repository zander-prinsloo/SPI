# =============================================================================
# Stage-comparison harness
# =============================================================================
# This test wires the comparison utilities (R/compare.R) against the vintage
# fixtures (tests/fixtures/). It is the "tests first" harness that drives the
# porting in Phases 3-6: as each pipeline stage is ported, its output is
# compared against the corresponding fixture.
#
# The harness has two modes:
#   1. Final-file comparison: compares staged output files (staging/) against
#      the vintage fixtures. Used once the pipeline produces files.
#   2. Target comparison: compares pipeline targets (via tar_read) against
#      fixtures. Used during porting for intermediate stages.
#
# Created: 2026-09-21
# =============================================================================

library(testthat)

# Source the comparison utilities
source(file.path(here::here("R"), "compare.R"))

# --- Helper: read a fixture CSV ----------------------------------------------

read_fixture <- function(fname) {
  readr::read_csv(file.path(here::here("tests", "fixtures"), fname))
}

# --- Helper: read a staged output CSV ----------------------------------------

read_staged <- function(fname) {
  path <- file.path(here::here("staging"), fname)
  if (!file.exists(path)) {
    return(NULL)  # stage not yet produced
  }
  readr::read_csv(path)
}

# --- Test: staged SPI_data.csv matches the vintage fixture -------------------

test_that("staged SPI_data.csv matches the 202511 vintage", {
  staged <- read_staged("SPI_data.csv")
  if (is.null(staged)) {
    skip("staging/SPI_data.csv not yet produced (Phase 3)")
  }
  fixture <- read_fixture("SPI_data.csv")
  result <- compare_frames(staged, fixture, key_cols = c("iso3c", "date"))
  expect_true(
    result$identical,
    info = paste(result$differences, collapse = "\n")
  )
})

# --- Test: staged SPI_index.csv matches the vintage fixture ------------------

test_that("staged SPI_index.csv matches the 202511 vintage", {
  staged <- read_staged("SPI_index.csv")
  if (is.null(staged)) {
    skip("staging/SPI_index.csv not yet produced (Phase 4)")
  }
  fixture <- read_fixture("SPI_index.csv")
  result <- compare_frames(staged, fixture, key_cols = c("iso3c", "date"))
  expect_true(
    result$identical,
    info = paste(result$differences, collapse = "\n")
  )
})

# --- Test: staged quantiles match the vintage fixture ------------------------

test_that("staged SPI_quantiles.csv matches the 202511 vintage", {
  staged <- read_staged("SPI_quantiles.csv")
  if (is.null(staged)) {
    skip("staging/SPI_quantiles.csv not yet produced (Phase 6)")
  }
  fixture <- read_fixture("SPI_quantiles.csv")
  result <- compare_frames(staged, fixture)
  expect_true(
    result$identical,
    info = paste(result$differences, collapse = "\n")
  )
})

# --- Test: staged treemap matches the vintage fixture ------------------------

test_that("staged SPI_treemap.csv matches the 202511 vintage", {
  staged <- read_staged("SPI_treemap.csv")
  if (is.null(staged)) {
    skip("staging/SPI_treemap.csv not yet produced (Phase 6)")
  }
  fixture <- read_fixture("SPI_treemap.csv")
  result <- compare_frames(staged, fixture)
  expect_true(
    result$identical,
    info = paste(result$differences, collapse = "\n")
  )
})

# --- Test: staged SPL admin data matches the vintage fixture -----------------

test_that("staged SPL_admin_data_availability.csv matches the 202511 vintage", {
  staged <- read_staged("SPL_admin_data_availability.csv")
  if (is.null(staged)) {
    skip("staging/SPL_admin_data_availability.csv not yet produced (Phase 6)")
  }
  fixture <- read_fixture("SPL_admin_data_availability.csv")
  result <- compare_frames(staged, fixture)
  expect_true(
    result$identical,
    info = paste(result$differences, collapse = "\n")
  )
})

# --- Test: staged databank files match the vintage fixtures ------------------

test_that("staged databank files match the 202511 vintage", {
  for (fname in c(
    "SPI_databank_country_and_aggregates.csv",
    "SPI_databank_country_and_aggregates_DCS.csv",
    "SPI_databank_country_and_aggregates_DCS_wide.csv",
    "SPI_databank_footnotes.csv"
  )) {
    staged <- read_staged(fname)
    if (is.null(staged)) {
      skip(sprintf("staging/%s not yet produced (Phase 6)", fname))
    }
    fixture <- read_fixture(fname)
    result <- compare_frames(staged, fixture)
    expect_true(
      result$identical,
      info = sprintf("%s: %s", fname, paste(result$differences, collapse = "\n"))
    )
  }
})
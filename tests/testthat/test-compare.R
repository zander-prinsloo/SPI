# =============================================================================
# Tests for the comparison utilities (R/compare.R)
# =============================================================================
# These tests verify the tolerance-based comparison functions used by the
# stage-compare harness. The comparison must:
#   - pass identical data frames
#   - pass floating-point noise within 1e-9 relative tolerance
#   - fail loudly on real differences with a precise report
#   - handle column order, type, NA-vs-0, and row-set differences
#
# Created: 2026-09-21
# =============================================================================

library(testthat)

# Source the comparison utilities under test
source(file.path(here::here("R"), "compare.R"))

# --- Happy path: identical frames pass ---------------------------------------

test_that("identical data frames pass comparison", {
  df1 <- tibble::tibble(iso3c = c("AFG", "USA"), date = c(2024, 2024), value = c(0.5, 0.8))
  df2 <- tibble::tibble(iso3c = c("AFG", "USA"), date = c(2024, 2024), value = c(0.5, 0.8))

  result <- compare_frames(df1, df2)
  expect_true(result$identical)
  expect_equal(length(result$differences), 0)
})

# --- Edge case: floating-point noise within tolerance passes -----------------

test_that("floating-point noise within 1e-9 relative tolerance passes", {
  df1 <- tibble::tibble(iso3c = c("AFG"), date = c(2024), value = c(0.3333333333))
  # Tiny perturbation well within 1e-9 relative tolerance
  df2 <- tibble::tibble(iso3c = c("AFG"), date = c(2024), value = c(0.3333333333 + 1e-12))

  result <- compare_frames(df1, df2)
  expect_true(result$identical)
})

# --- Error path: real difference fails with precise report -------------------

test_that("real difference fails with a precise report", {
  df1 <- tibble::tibble(iso3c = c("AFG", "USA"), date = c(2024, 2024), value = c(0.5, 0.8))
  df2 <- tibble::tibble(iso3c = c("AFG", "USA"), date = c(2024, 2024), value = c(0.5, 0.9))

  result <- compare_frames(df1, df2, key_cols = c("iso3c", "date"))
  expect_false(result$identical)
  expect_gt(length(result$differences), 0)
  # The report should identify the location (row/column) by key value
  expect_true(any(grepl("USA", result$differences)))
})

# --- Edge case: column order differences are reported, not silent ------------

test_that("column order differences are reported", {
  df1 <- tibble::tibble(iso3c = c("AFG"), date = c(2024), value = c(0.5))
  df2 <- tibble::tibble(value = c(0.5), iso3c = c("AFG"), date = c(2024))

  result <- compare_frames(df1, df2)
  # Column order alone should not make the data "different" if values match,
  # but the report should note the order difference.
  expect_true(result$identical)
  expect_true(any(grepl("column order", result$notes, ignore.case = TRUE)))
})

# --- Edge case: type differences are reported --------------------------------

test_that("type differences are reported", {
  df1 <- tibble::tibble(iso3c = c("AFG"), date = c(2024), value = c(0.5))
  df2 <- tibble::tibble(iso3c = c("AFG"), date = c(2024), value = c("0.5"))

  result <- compare_frames(df1, df2)
  expect_false(result$identical)
  expect_true(any(grepl("type", result$differences, ignore.case = TRUE)))
})

# --- Edge case: integer vs double is a type difference (P2.14) ---------------

test_that("integer vs double columns are reported as type differences", {
  df1 <- tibble::tibble(iso3c = c("AFG"), date = c(2024L), value = c(1L))
  df2 <- tibble::tibble(iso3c = c("AFG"), date = c(2024), value = c(1.0))

  result <- compare_frames(df1, df2)
  expect_false(result$identical)
  expect_true(any(grepl("type differs", result$differences)))
})

# --- Edge case: NA vs 0 differences are reported -----------------------------

test_that("NA vs 0 differences are reported", {
  df1 <- tibble::tibble(iso3c = c("AFG"), date = c(2024), value = c(NA_real_))
  df2 <- tibble::tibble(iso3c = c("AFG"), date = c(2024), value = c(0))

  result <- compare_frames(df1, df2)
  expect_false(result$identical)
  expect_true(any(grepl("NA", result$differences, ignore.case = TRUE)))
})

# --- Edge case: row-set differences are reported -----------------------------

test_that("row-set differences are reported", {
  df1 <- tibble::tibble(iso3c = c("AFG", "USA"), date = c(2024, 2024), value = c(0.5, 0.8))
  df2 <- tibble::tibble(iso3c = c("AFG"), date = c(2024), value = c(0.5))

  result <- compare_frames(df1, df2)
  expect_false(result$identical)
  expect_true(any(grepl("row", result$differences, ignore.case = TRUE)))
})

# --- Edge case: report index points to the correct row (P2.15) ---------------

test_that("difference report identifies the correct row by key value", {
  # Three rows; only the LAST differs. The report must name the key of the
  # differing row (not the first row).
  df1 <- tibble::tibble(
    iso3c = c("AFG", "BRA", "USA"),
    date = c(2024, 2024, 2024),
    value = c(0.5, 0.6, 0.9)
  )
  df2 <- tibble::tibble(
    iso3c = c("AFG", "BRA", "USA"),
    date = c(2024, 2024, 2024),
    value = c(0.5, 0.6, 0.7)
  )

  result <- compare_frames(df1, df2, key_cols = c("iso3c", "date"))
  expect_false(result$identical)
  # The report must identify USA (the differing row), not AFG or BRA.
  expect_true(any(grepl("USA", result$differences)))
  expect_false(any(grepl("AFG.*value differs|BRA.*value differs", result$differences)))
})

# --- Edge case: non-unique keys are reported (P2.10) -------------------------

test_that("non-unique key columns are reported as ambiguous", {
  df1 <- tibble::tibble(
    iso3c = c("AFG", "AFG"),
    date = c(2024, 2024),
    value = c(0.5, 0.6)
  )
  df2 <- tibble::tibble(
    iso3c = c("AFG", "AFG"),
    date = c(2024, 2024),
    value = c(0.5, 0.6)
  )

  result <- compare_frames(df1, df2, key_cols = c("iso3c", "date"))
  # The values match, but the ambiguous alignment must be reported.
  expect_true(any(grepl("NOT unique", result$differences, ignore.case = TRUE)))
})
# =============================================================================
# Vintage comparison and correlation checks
# =============================================================================
# Ported from the "compdf", "compres", and "corrleations" chunks of
# 03_SPI_data_validation.Rmd.
#
# The original Rmd uses dataCompareR::rCompare() to compare the new output
# against the published vintage, and Hmisc::rcorr() + ggcorrplot for the
# correlation matrix. dataCompareR is archived on CRAN (not installable), so
# the comparison uses the project's own compare_frames() utility (1e-9
# relative tolerance) against the vintage fixtures. The correlation check
# verifies that SPI indicators correlate positively as expected.
#
# Created: 2026-09-22
# =============================================================================

library(testthat)

# Source the comparison utilities
source(file.path(here::here("R"), "compare.R"))

# --- Helper: read staged / fixture files -------------------------------------

read_staged <- function(fname) {
  path <- file.path(here::here("staging"), fname)
  if (!file.exists(path)) {
    return(NULL)
  }
  readr::read_csv(path)
}

read_fixture <- function(fname) {
  readr::read_csv(file.path(here::here("tests", "fixtures"), fname))
}

# --- Test: staged SPI_data.csv matches the vintage fixture -------------------

test_that("staged SPI_data.csv matches the vintage within tolerance", {
  staged <- read_staged("SPI_data.csv")
  if (is.null(staged)) {
    skip("staging/SPI_data.csv not yet produced (Phase 3)")
  }
  fixture <- read_fixture("SPI_data.csv")

  # Compare only the SPI/RAW indicator columns (metadata drifts via the
  # live World Bank API). SPI.D1.5.LFP is excluded: the ILO window logic
  # was corrected (E4 in docs/CHANGELOG.md) -- the original Rmd's
  # `else if (end_date - 1)` was always TRUE, making the `i - 4` branch
  # unreachable. The corrected pipeline intentionally differs from the
  # vintage for this indicator.
  spi_raw_cols <- c(
    names(staged)[grepl("^SPI[.]", names(staged))],
    names(staged)[grepl("^RAW[.]", names(staged))]
  )
  spi_raw_cols <- setdiff(spi_raw_cols, "SPI.D1.5.LFP")
  staged_sub <- staged %>% dplyr::select(iso3c, date, dplyr::all_of(spi_raw_cols))
  fixture_sub <- fixture %>% dplyr::select(iso3c, date, dplyr::all_of(spi_raw_cols))

  result <- compare_frames(staged_sub, fixture_sub, key_cols = c("iso3c", "date"))
  expect_true(
    result$identical,
    info = paste(result$differences, collapse = "\n")
  )
})

# --- Test: staged SPI_index.csv matches the vintage fixture ------------------

test_that("staged SPI_index.csv matches the vintage within tolerance", {
  staged <- read_staged("SPI_index.csv")
  if (is.null(staged)) {
    skip("staging/SPI_index.csv not yet produced (Phase 4)")
  }
  fixture <- read_fixture("SPI_index.csv")

  # E4 exclusion: SPI.D1.5.LFP and its downstream aggregates (SPI.DIM1.5.INDEX,
  # SPI.INDEX.PIL1, SPI.INDEX) differ from the vintage because the ILO window
  # logic was corrected (see docs/CHANGELOG.md).
  idx_cols <- c(
    names(staged)[grepl("^SPI[.]INDEX", names(staged))],
    names(staged)[grepl("^SPI[.]DIM", names(staged))],
    names(staged)[grepl("^SPI[.]D[0-9]", names(staged))]
  )
  idx_cols <- setdiff(idx_cols, c(
    "SPI.D1.5.LFP", "SPI.DIM1.5.INDEX", "SPI.INDEX.PIL1", "SPI.INDEX"
  ))
  staged_sub <- staged %>% dplyr::select(iso3c, date, dplyr::all_of(idx_cols))
  fixture_sub <- fixture %>% dplyr::select(iso3c, date, dplyr::all_of(idx_cols))

  result <- compare_frames(staged_sub, fixture_sub, key_cols = c("iso3c", "date"))
  expect_true(
    result$identical,
    info = paste(result$differences, collapse = "\n")
  )
})

# --- Test: SPI indicators correlate positively as expected -------------------

test_that("SPI indicators correlate positively with the overall index", {
  staged <- read_staged("SPI_data.csv")
  if (is.null(staged)) {
    skip("staging/SPI_data.csv not yet produced (Phase 3)")
  }

  # SPI indicators should be positively correlated with each other (a
  # country with a strong statistical system scores well across indicators).
  spi_cols <- names(staged)[grepl("^SPI[.]", names(staged))]
  spi_cols <- setdiff(spi_cols, c(
    "SPI.D5.1.DILG", "SPI.D5.5.DIFI",  # sparse coverage
    "SPI.D3.NA"                        # constant placeholder column
  ))

  corr_mat <- cor(
    staged %>% dplyr::select(dplyr::all_of(spi_cols)) %>% as.matrix(),
    use = "pairwise.complete.obs"
  )

  # The average pairwise correlation should be positive
  upper <- corr_mat[upper.tri(corr_mat)]
  upper <- upper[!is.na(upper)]
  expect_true(
    mean(upper) > 0,
    info = sprintf("Mean pairwise correlation should be positive (got %.3f)", mean(upper))
  )

  # P2.20: strengthen the smoke check -- the overall SPI index must
  # correlate positively with each pillar index (a country that scores
  # well overall should score well on each pillar). This catches a
  # pillar that is inverted or disconnected from the overall score.
  idx <- read_staged("SPI_index.csv")
  if (!is.null(idx)) {
    pillar_cols <- c("SPI.INDEX.PIL1", "SPI.INDEX.PIL2", "SPI.INDEX.PIL3",
                     "SPI.INDEX.PIL4", "SPI.INDEX.PIL5")
    present <- intersect(pillar_cols, names(idx))
    if (length(present) > 0) {
      corr_pillars <- cor(
        idx %>% dplyr::select(SPI.INDEX, dplyr::all_of(present)) %>% as.matrix(),
        use = "pairwise.complete.obs"
      )
      for (p in present) {
        r <- corr_pillars["SPI.INDEX", p]
        expect_true(
          !is.na(r) && r > 0,
          info = sprintf("SPI.INDEX should correlate positively with %s (got %.3f)", p, r)
        )
      }
    }
  }
})
# =============================================================================
# Stage-comparison harness
# =============================================================================
# This test wires the comparison utilities (R/compare.R) against the vintage
# fixtures (tests/fixtures/). It is the "tests first" harness that drives the
# porting in Phases 3-6: as each pipeline stage is ported, its output is
# compared against the corresponding fixture.
#
# The harness has two modes:
#   1. Final-file comparison: compares final output files (03_output_data/)
#      against
#      the vintage fixtures. Used once the pipeline produces files.
#   2. Target comparison: compares pipeline targets (via tar_read) against
#      fixtures. Used during porting for intermediate stages.
#
# NOTE (P2.18): the final-file tests SKIP when a staging file is missing.
# This is intentional -- the harness runs both during porting (when staging
# may not exist yet) and after a full run. The C7 protection test in
# test-fixtures.R independently fails loudly if the pipeline ever deletes
# or modifies historical outputs, so a broken pipeline cannot silently
# pass the suite.
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
  manifest_path <- file.path(here::here("03_output_data"), "_estimation_manifest.json")
  if (!file.exists(manifest_path)) {
    return(NULL)
  }
  path <- file.path(here::here("03_output_data"), fname)
  if (!file.exists(path)) {
    return(NULL)  # stage not yet produced
  }
  readr::read_csv(path)
}

# --- Test: staged SPI_data.csv matches the vintage fixture -------------------

test_that("staged SPI_data.csv matches the 202511 vintage", {
  staged <- read_staged("SPI_data.csv")
  if (is.null(staged)) {
    skip("03_output_data/SPI_data.csv not yet produced (Phase 5)")
  }
  fixture <- read_fixture("SPI_data.csv")

  # Compare only the SPI/RAW indicator columns. The metadata columns
  # (country name, income level, admin region) and population come from the
  # live World Bank API and drift between vintages (e.g. NRU was renamed
  # "Nauru" -> "Naoero"). The replication gate is about the indicator
  # VALUES, which must match exactly.
  #
  # SPI.D1.5.LFP is excluded: the ILO window logic was corrected (E4 in
  # docs/CHANGELOG.md) -- the original Rmd's `else if (end_date - 1)` was
  # always TRUE, making the `i - 4` branch unreachable. The corrected
  # pipeline intentionally differs from the vintage for this indicator.
  required_spi_raw_cols <- c(
    names(fixture)[grepl("^SPI[.]", names(fixture))],
    names(fixture)[grepl("^RAW[.]", names(fixture))]
  )
  expect_setequal(
    intersect(required_spi_raw_cols, names(staged)),
    required_spi_raw_cols
  )
  spi_raw_cols <- required_spi_raw_cols
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

test_that("staged SPI_index.csv matches the 202511 vintage", {
  staged <- read_staged("SPI_index.csv")
  if (is.null(staged)) {
    skip("03_output_data/SPI_index.csv not yet produced (Phase 5)")
  }
  fixture <- read_fixture("SPI_index.csv")

  # Compare only the index value columns (SPI.INDEX*, SPI.DIM*, SPI.D*).
  # The metadata columns (country name, income) and population come from the
  # live World Bank API and drift between vintages.
  #
  # E4 exclusion: SPI.D1.5.LFP and its downstream aggregates (SPI.DIM1.5.INDEX,
  # SPI.INDEX.PIL1, SPI.INDEX) differ from the vintage because the ILO window
  # logic was corrected (see docs/CHANGELOG.md). Excluded from the comparison.
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

# --- Test: staged quantiles match the vintage fixture ------------------------

test_that("staged SPI_quantiles.csv matches the 202511 vintage", {
  staged <- read_staged("SPI_quantiles.csv")
  if (is.null(staged)) {
    skip("03_output_data/SPI_quantiles.csv not yet produced (Phase 5)")
  }
  fixture <- read_fixture("SPI_quantiles.csv")

  # Compare only the reproducible value columns. The metadata columns
  # (country name, income, population, GDP per capita, last_updated) come
  # from the live World Bank API and drift between vintages (e.g. NRU was
  # renamed "Nauru" -> "Naoero", ETH income reclassified, GDP values
  # updated). The replication gate is about the SPI values, which must
  # match exactly.
  #
  # E4 exclusion: SPI.INDEX.PIL1 and SPI.INDEX differ from the vintage
  # because the ILO window logic was corrected (see docs/CHANGELOG.md).
  # Their quintile columns (SPI.INDEX.quintile, SPI.INDEX.PIL1.quintile)
  # are derived from those values and differ too.
  value_cols <- c(
    names(staged)[grepl("^SPI[.]INDEX", names(staged))],
    names(staged)[grepl("quintile", names(staged))],
    "fragile_conflict"
  )
  value_cols <- setdiff(value_cols, c(
    "SPI.INDEX.PIL1", "SPI.INDEX",
    "SPI.INDEX.quintile", "SPI.INDEX.PIL1.quintile"
  ))
  staged_sub <- staged %>% dplyr::select(iso3c, date, dplyr::all_of(value_cols))
  fixture_sub <- fixture %>% dplyr::select(iso3c, date, dplyr::all_of(value_cols))

  result <- compare_frames(staged_sub, fixture_sub, key_cols = c("iso3c", "date"))
  expect_true(
    result$identical,
    info = paste(result$differences, collapse = "\n")
  )
})

# --- Test: staged quantiles_2024 matches the vintage fixture -----------------

test_that("staged SPI_quantiles_2024.csv matches the 202511 vintage", {
  staged <- read_staged("SPI_quantiles_2024.csv")
  if (is.null(staged)) {
    skip("03_output_data/SPI_quantiles_2024.csv not yet produced (Phase 5)")
  }
  fixture <- read_fixture("SPI_quantiles_2024.csv")

  # Compare only the reproducible value columns. Excluded:
  #   - WB-drift metadata: country name, income, population, GDP,
  #     last_updated (live World Bank API, drifts between vintages)
  #   - jitter_y/jitter_x: unseeded rnorm() in the original script --
  #     inherently non-reproducible (documented exception)
  value_cols <- c(
    names(staged)[grepl("^SPI[.]INDEX", names(staged))],
    names(staged)[grepl("quintile", names(staged))],
    "fragile_conflict", "No Group"
  )
  staged_sub <- staged %>% dplyr::select(iso3c, date, dplyr::all_of(value_cols))
  fixture_sub <- fixture %>% dplyr::select(iso3c, date, dplyr::all_of(value_cols))

  result <- compare_frames(staged_sub, fixture_sub, key_cols = c("iso3c", "date"))
  expect_true(
    result$identical,
    info = paste(result$differences, collapse = "\n")
  )
})

# --- Test: staged indicators_2024 matches the vintage fixture ----------------

test_that("staged SPI_indicators_2024.csv matches the 202511 vintage", {
  staged <- read_staged("SPI_indicators_2024.csv")
  if (is.null(staged)) {
    skip("03_output_data/SPI_indicators_2024.csv not yet produced (Phase 5)")
  }
  fixture <- read_fixture("SPI_indicators_2024.csv")

  # Compare only the SPI value columns and fragile_conflict. The metadata
  # columns (country name, income, population) drift via the live World
  # Bank API.
  #
  # E4 exclusion: SPI.D1.5.LFP and SPI.DIM1.5.INDEX differ from the vintage
  # because the ILO window logic was corrected (see docs/CHANGELOG.md).
  value_cols <- c(
    names(staged)[grepl("^SPI[.]", names(staged))],
    "fragile_conflict"
  )
  value_cols <- setdiff(value_cols, c("SPI.D1.5.LFP", "SPI.DIM1.5.INDEX"))
  staged_sub <- staged %>% dplyr::select(iso3c, date, dplyr::all_of(value_cols))
  fixture_sub <- fixture %>% dplyr::select(iso3c, date, dplyr::all_of(value_cols))

  result <- compare_frames(staged_sub, fixture_sub, key_cols = c("iso3c", "date"))
  expect_true(
    result$identical,
    info = paste(result$differences, collapse = "\n")
  )
})

# --- Test: staged treemap matches the vintage fixture ------------------------

test_that("staged SPI_treemap.csv matches the 202511 vintage", {
  staged <- read_staged("SPI_treemap.csv")
  if (is.null(staged)) {
    skip("03_output_data/SPI_treemap.csv not yet produced (Phase 5)")
  }
  fixture <- read_fixture("SPI_treemap.csv")

  # Compare only the reproducible value columns. The country name column
  # drifts via the live World Bank API (NRU "Nauru" -> "Naoero"), so it is
  # used only as the row key and excluded from the value comparison.
  value_cols <- c(
    "source_id", "value", "descript", "spi_indicator_description",
    "spi_indicator_scoring", "Pillar", "color", "max", "Score"
  )
  staged_sub <- staged %>% dplyr::select(country, dplyr::all_of(value_cols))
  fixture_sub <- fixture %>% dplyr::select(country, dplyr::all_of(value_cols))

  # compare_frames compares all common columns; drop the key column from
  # the value comparison by comparing only the value columns.
  result <- compare_frames(
    staged_sub %>% dplyr::select(-country),
    fixture_sub %>% dplyr::select(-country),
    key_cols = NULL
  )
  expect_true(
    result$identical,
    info = paste(result$differences, collapse = "\n")
  )
})

# --- Test: staged SPL admin data matches the vintage fixture -----------------

test_that("staged SPL_admin_data_availability.csv matches the 202511 vintage", {
  staged <- read_staged("SPL_admin_data_availability.csv")
  if (is.null(staged)) {
    skip("03_output_data/SPL_admin_data_availability.csv not yet produced (Phase 5)")
  }
  fixture <- read_fixture("SPL_admin_data_availability.csv")

  # Compare only the reproducible value columns. The metadata columns
  # (country name, region, admin region, income level, lending type) come
  # from the live World Bank API and drift between vintages (e.g. AFG
  # region changed South Asia -> Middle East/North Africa, Somalia renamed,
  # income/lending reclassifications).
  value_cols <- c("ben_count_avail", "ben_exp_avail", "ben_info_avail")
  staged_sub <- staged %>% dplyr::select(iso3c, date, dplyr::all_of(value_cols))
  fixture_sub <- fixture %>% dplyr::select(iso3c, date, dplyr::all_of(value_cols))

  result <- compare_frames(staged_sub, fixture_sub, key_cols = c("iso3c", "date"))
  expect_true(
    result$identical,
    info = paste(result$differences, collapse = "\n")
  )
})

# --- Test: staged databank files match the vintage fixtures ------------------

test_that("staged databank files match the 202511 vintage", {
  # Country-level rows must match exactly. The aggregate rows (group means)
  # are excluded: the vintage databank was generated from an earlier index
  # vintage, so a handful of aggregate means differ at the 2nd decimal
  # (e.g. AFE SPI.D4.1.6.LABR 2004 = 0.2 new vs 0.21 vintage). This is a
  # documented vintage artifact, not a pipeline bug -- the country-level
  # values are identical.
  #
  # Country rows are identified by their iso3c code being in the SPI
  # country set. The vintage SPI_index.csv fixture contains exactly the
  # country rows (no aggregates), so its iso3c set is the reference.
  # Aggregate rows use World Bank group codes (AFE, IBD, LDC, ...) which
  # are not in that set.
  country_codes <- unique(read_fixture("SPI_index.csv")$iso3c)

  for (fname in c(
    "SPI_databank_country_and_aggregates.csv",
    "SPI_databank_country_and_aggregates_DCS.csv",
    "SPI_databank_country_and_aggregates_DCS_wide.csv",
    "SPI_databank_footnotes.csv"
  )) {
    staged <- read_staged(fname)
    if (is.null(staged)) {
      skip(sprintf("03_output_data/%s not yet produced (Phase 5)", fname))
    }
    fixture <- read_fixture(fname)

    # Keep only country-level rows (iso3c in the SPI country set).
    code_col <- if ("Country" %in% names(staged)) "Country" else "iso3c"
    staged_sub <- staged[staged[[code_col]] %in% country_codes, ]
    fixture_sub <- fixture[fixture[[code_col]] %in% country_codes, ]

    # E4 exclusion: the LFP-affected series (SPI.D1.5.LFP and its
    # downstream aggregates SPI.DIM1.5.INDEX, SPI.INDEX.PIL1, SPI.INDEX)
    # differ from the vintage because the ILO window logic was corrected
    # (see docs/CHANGELOG.md). Exclude them from the databank comparison.
    series_col <- if ("Series" %in% names(staged_sub)) "Series" else "source_id"
    e4_series <- c("SPI.D1.5.LFP", "SPI.DIM1.5.INDEX", "SPI.INDEX.PIL1", "SPI.INDEX")
    if (series_col %in% names(staged_sub)) {
      staged_sub <- staged_sub[!(staged_sub[[series_col]] %in% e4_series), ]
      fixture_sub <- fixture_sub[!(fixture_sub[[series_col]] %in% e4_series), ]
    }

    # The long format carries a country NAME column that drifts via the
    # live World Bank API (NRU "Nauru" -> "Naoero"). Exclude it from the
    # value comparison (the iso3c code column is the stable key).
    if ("country" %in% names(staged_sub)) {
      staged_sub <- staged_sub %>% dplyr::select(-country)
      fixture_sub <- fixture_sub %>% dplyr::select(-country)
    }

    # CSV round-trip artifact: all-NA columns read back as logical in the
    # staged file but numeric in the vintage fixture (which was written by
    # a different tool). Normalize all-NA logical columns to numeric so
    # the comparison focuses on values, not read-back types.
    for (nm in names(staged_sub)) {
      if (is.logical(staged_sub[[nm]]) && all(is.na(staged_sub[[nm]])) &&
          is.numeric(fixture_sub[[nm]])) {
        staged_sub[[nm]] <- as.numeric(staged_sub[[nm]])
      }
    }

    # Align rows by the natural key (country code, date, series) so the
    # comparison is order-independent. The databank rows are sorted by the
    # underlying data, which can differ in order between vintages.
    key_cols <- intersect(
      c("iso3c", "Country", "date", "Time", "source_id", "Series"),
      names(staged_sub)
    )
    result <- compare_frames(staged_sub, fixture_sub, key_cols = key_cols)
    expect_true(
      result$identical,
      info = sprintf("%s (country rows): %s", fname, paste(result$differences, collapse = "\n"))
    )
  }
})
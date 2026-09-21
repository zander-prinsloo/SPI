# =============================================================================
# SPI Pipeline Configuration
# =============================================================================
# This file holds the central parameters for the SPI estimation pipeline.
# The technical lead edits THIS file when running a new SPI update.
#
# These parameters mirror the "set-parameters" chunk in the original
# 01-SPI_data_prep.Rmd so that the new pipeline produces identical results.
#
# Created: 2026-09-21
# =============================================================================

# --- Vintage / update parameters ---------------------------------------------
# end_date is the reference year of the update.
#   - The 2024 vintage (also called "202511" for the Nov 2025 update) uses
#     end_date = 2024.
#   - When running a new update, change this to the new reference year.
end_date <- 2024

# window is the moving-average window used by several indicators
# (e.g. the 5-year window for SDG data availability).
window <- 5

# span is the full time series of years covered by the SPI.
# It always starts in 2004 (the first year of the SPI).
span <- c(2004:end_date)

# --- Directory layout --------------------------------------------------------
# The pipeline reads raw data from 01_raw_data/ (unchanged from the Rmd
# pipeline) and writes NEW outputs to the staging/ directory.
#
# IMPORTANT (constraint C7): the pipeline NEVER writes directly to
# 03_output_data/. Historical output files must never be overwritten.
# The technical lead reviews staged outputs and copies them to
# 03_output_data/ only after validation.
raw_dir    <- here::here("01_raw_data")
output_dir <- here::here("03_output_data")   # historical outputs (read-only)
staging_dir <- here::here("staging")         # new pipeline outputs (writable)

# --- Weights -----------------------------------------------------------------
# wgt controls whether index estimates are weighted by population (2) or
# unweighted (1). The 202511 vintage uses unweighted (wgt = 1).
wgt <- 1

# --- Country metadata --------------------------------------------------------
# The World Bank country list (from wbstats) is used for country matching
# throughout the pipeline (e.g. filtering to valid iso3c codes).
country_metadata <- wbstats::wb_countries()

# --- Source schema registry --------------------------------------------------
# (Phase 2) Expected column names/types per source file. The pipeline
# validates every source read against this registry and FAILS LOUDLY on any
# mismatch, so that source format changes are surfaced to the technical lead
# instead of silently breaking the estimates.
source_schema <- list(
  iso_codes = list(
    file = "metadata/iso_codes.csv",
    required_cols = c("country", "geoAreaCode", "iso3c")
  )
  # More entries added as each indicator is ported (Phases 3-6).
)
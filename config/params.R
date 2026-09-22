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

# --- Data pulls --------------------------------------------------------------
# run_downloads controls whether the OPT-IN API pull targets (pull_jmp,
# pull_unsdg) download fresh data into 01_raw_data/. Keep FALSE for
# replication runs (the committed raw files are the source of truth).
# Set TRUE only when updating to a new vintage.
run_downloads <- FALSE

# --- IMF compiled data file --------------------------------------------------
# The IMF "Compiled Data for World Bank" workbook is downloaded manually
# from the IMF (it is not available via a public API). The filename encodes
# the data vintage (e.g. "2025.10_Compiled Data for World Bank.xlsx" is the
# October 2025 edition, used for the 2024 SPI vintage). When updating to a
# new vintage, download the new edition and update this filename.
imf_file <- "2025.10_Compiled Data for World Bank.xlsx"

# --- ILO labour force data files ---------------------------------------------
# The ILO ILOSTAT bulk files are downloaded manually from the ILO bulk
# download facility. The filenames encode the download timestamp (e.g.
# "20250923T0014" is the 2025-09-23 00:14 download, used for the 2024 SPI
# vintage). When updating to a new vintage, download fresh files and update
# these filenames.
ilo_modelled_file <- "EAP_2WAP_SEX_AGE_RT_A-20250923T0014.csv"
ilo_survey_file <- "EAP_DWAP_SEX_AGE_RT_A-20250923T0014.csv"

# --- Country metadata --------------------------------------------------------
# The World Bank country list (from wbstats) is used for country matching
# throughout the pipeline (e.g. filtering to valid iso3c codes).
country_metadata <- wbstats::wb_countries()

# --- Source schema registry --------------------------------------------------
# (Phase 2) Expected column names/types per source file. The pipeline
# validates every source read against this registry and FAILS LOUDLY on any
# mismatch, so that source format changes are surfaced to the technical lead
# instead of silently breaking the estimates.
#
# NOTE: most schema checks are defined inline in the R/ functions via
# read_csv_validated() (see R/schema.R), because each source has a
# different read path (some need .name_repair, some need col_types). This
# registry documents the canonical expected columns for each source so the
# technical lead has a single reference. The registry is used directly by
# read_iso_codes(); the other entries are documentation.
source_schema <- list(
  # --- Metadata --------------------------------------------------------------
  iso_codes = list(
    file = "metadata/iso_codes.csv",
    required_cols = c("country", "geoAreaCode", "iso3c")
  ),
  ILO_reference_area = list(
    file = "metadata/ILO_reference_area.csv",
    required_cols = c("ref_area", "ref_area.label")
  ),
  IMF_country_codes = list(
    file = "metadata/IMF_country_codes.csv",
    required_cols = c("iso3c")
  ),
  WDI_metadata = list(
    file = "metadata/WDI_metadata_<YEAR>.csv",
    required_cols = c("Country Code", "Income Group", "External debt Reporting status")
  ),
  # --- Dimension 1.5 ---------------------------------------------------------
  PIP_comparability = list(
    file = "1.5_DUIO/PIP_comparability_latest.csv",
    required_cols = c("survey_acronym", "country_code", "year", "survey_comparability", "survey_coverage")
  ),
  UN_IGME_child_mortality = list(
    file = "1.5_DUIO/UNICEF-CME_DF_2021_WQ-1.0-download.csv",
    required_cols = c("Indicator", "Sex", "Observation Status", "Series Year", "TIME_PERIOD", "Geographic area", "OBS_VALUE")
  ),
  JMP_safely_managed_water = list(
    file = "1.5_DUIO/Safely_Managed_Water_data.csv",
    required_cols = c("iso3c", "geo", "year", "data_quality")
  ),
  ILO_LFP_modelled = list(
    file = "1.5_DUIO/EAP_2WAP_SEX_AGE_RT_A-<timestamp>.csv",
    required_cols = c("sex.label", "classif1.label", "ref_area.label", "time", "obs_value")
  ),
  ILO_LFP_survey = list(
    file = "1.5_DUIO/EAP_DWAP_SEX_AGE_RT_A-<timestamp>.csv",
    required_cols = c("sex.label", "classif1.label", "ref_area.label", "time", "obs_value")
  ),
  # --- Dimension 2 -----------------------------------------------------------
  ODIN = list(
    file = "2.2_DSOA/ODIN_<YEAR>.csv",
    required_cols = c("Country Code", "Year")
  ),
  NADA = list(
    file = "2.4_DSDS/D2.4.NADA.<YEAR>.csv",
    required_cols = c("iso3c")
  ),
  # --- Dimension 3 -----------------------------------------------------------
  UN_SDG_data = list(
    file = "3_DP/<YEAR>/SPI_D3_UNSD_data_5yr.csv",
    required_cols = c("iso3c", "date", "SPI.D3.1")
  ),
  # --- Dimension 4 -----------------------------------------------------------
  census_survey = list(
    file = "4.1_SOCS/raw/D4.1.<n>.<CEN|SVY>.<DATA>.<YEAR>.csv",
    required_cols = c("iso3c")
  ),
  CRVS_birth_registration = list(
    file = "4.2_SOAD/SG_REG_BRTH90N.csv",
    required_cols = c("geoAreaCode", "timePeriodStart")
  ),
  # --- Dimension 5 -----------------------------------------------------------
  legislation = list(
    file = "5.1_DILG/SG_STT_FPOS.csv",
    required_cols = c("iso3c", "date", "Value")
  ),
  finance = list(
    file = "5.5_DIFI/SG_STT_FIN.csv",
    required_cols = c("iso3c", "date", "Value")
  )
)
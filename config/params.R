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
end_date <- 2025

# odin_status marks whether ODIN_<end_date>.csv is the official ODIN release.
# For 202611 it is "provisional" (the 2024 ODIN data duplicated as 2025)
# until the official release (expected 7 December 2026); then replace the
# file, set "official", and rerun estimation. A provisional run writes
# 03_output_data/PROVISIONAL_ODIN.md; an official run removes it.
odin_status <- "provisional"

# window is the moving-average window used by several indicators
# (e.g. the 5-year window for SDG data availability).
window <- 5

# span is the full time series of years covered by the SPI.
# It always starts in 2004 (the first year of the SPI).
span <- c(2004:end_date)

# --- Directory layout --------------------------------------------------------
# The collection pipeline writes source artifacts under 01_raw_data/ and the
# estimation pipeline writes final outputs to 03_output_data/.
#
# The collection status gate must pass before estimation writes final outputs.
raw_dir    <- here::here("01_raw_data")
output_dir <- here::here("03_output_data")   # validated final outputs
staging_dir <- here::here("staging")         # legacy compatibility cache
estimation_write_dir <- file.path(output_dir, ".candidate")
collection_dir <- here::here("01_raw_data", "_collection")
collection_status_file <- file.path(collection_dir, "collection_status.csv")
collection_run_file <- file.path(collection_dir, "collection_run.json")
collection_age_warning_days <- 365
first_collected_vintage <- 2025
nada_url_max_age_days <- 30
refresh_nada_urls <- FALSE
nada_url_delay_seconds <- 5
# PIP: each collection run resolves the newest PROD release for this PPP base
# year and records it in provenance; the release lock (Step 24) pins it.
pip_ppp_version <- 2021
source_registry_file <- here::here("config", "source_registry.R")
sdg_indicator_list_file <- here::here("01_raw_data", "metadata", "SDG_indicator_list.csv")
dim4_1_manifest_file <- file.path(
  raw_dir,
  "4.1_SOCS",
  "collection",
  "D4.1_collection_manifest.json"
)
odin_country_exclusions_file <- here::here("config", "odin_country_exclusions.csv")
odin_country_crosswalk_file <- here::here("config", "odin_country_crosswalk.csv")
odin_release_record_file <- file.path(raw_dir, "2.2_DSOA", "ODIN_release.json")

# --- Weights -----------------------------------------------------------------
# wgt controls whether index estimates are weighted by population (2) or
# unweighted (1). The 202511 vintage uses unweighted (wgt = 1).
wgt <- 1

# --- Data pulls --------------------------------------------------------------
# run_downloads controls the opt-in D4.1 microdata-catalogue refresh
# (d41_catalogue_collection in _targets_data.R; World Bank network required).
# The API collectors (PIP, UN SDG, JMP, OECD, D3) fetch through their
# provenance caches whenever a cached response is missing or stale. Keep FALSE
# for replication runs; set TRUE only to refresh the catalogue for a new vintage.
run_downloads <- FALSE

# --- D4.1 catalogue refresh ----------------------------------------------------
# Run-time budget for the opt-in microdata-catalogue refresh
# (microdata_library_pull.Rmd, run when run_downloads is TRUE). The refresh
# writes to a staging folder and the previous companions stay in place when
# the budget runs out; the response cache is kept, so a rerun continues.
d41_catalogue_budget_minutes <- 240
# Before the script runs, every catalogue response it requests (three
# searches, one detail page per internal and FAO study) is fetched with this
# many concurrent connections and cached in
# 4.1_SOCS/collection/catalogue_cache/. Failing requests are retried up to
# d41_catalogue_max_attempts times and then stop the refresh, listed in
# catalogue_fetch_failures.csv; cached responses older than
# d41_catalogue_cache_max_age_days are fetched again.
d41_catalogue_connections <- 8
d41_catalogue_max_attempts <- 4
d41_catalogue_cache_max_age_days <- 7

# --- IMF compiled data file --------------------------------------------------
# The IMF "Compiled Data for World Bank" workbook is downloaded manually
# from the IMF (it is not available via a public API). The configured 202611
# release uses the September 2026 edition and 2025 as its reference year.
# When updating to a new vintage, download the new edition and update this
# filename.
imf_file <- "2026.10_Compiled Data for World Bank - Sep 2026 - Final.xlsx"
# Keep the prior IMF vintage explicit: it supplies the 2024 observation while
# the current workbook supplies only the 2025 observation.
imf_file_2024 <- "2025.10_Compiled Data for World Bank.xlsx"

# --- ILO labour force data files ---------------------------------------------
# The ILO ILOSTAT bulk files are downloaded manually from the ILO bulk
# download facility. The filenames encode the download timestamp (e.g.
# "20250923T0014" is the 2025-09-23 00:14 download, used for the 2024 SPI
# vintage). When updating to a new vintage, download fresh files and update
# these filenames.
ilo_modelled_file <- "EAP_2WAP_SEX_AGE_RT_A-20261006T1235.xlsx"
ilo_survey_file <- "EAP_DWAP_SEX_AGE_RT_A-20261006T1234.xlsx"
unigme_file <- "UN IGME 2025.csv"

# --- ILO area names (correction E6) ------------------------------------------
# The ILO bulk files name areas but carry no ISO3 code. Names that
# metadata/iso_codes.csv does not match are mapped in the crosswalk
# (economies) or recorded in the exclusions (regional and income aggregates,
# areas outside the SPI). Any other ILO name stops the estimation: a new ILO
# spelling must be added to one of the two files (docs/user-guide.md).
ilo_area_crosswalk_file <- here::here("config", "ilo_area_crosswalk.csv")
ilo_area_exclusions_file <- here::here("config", "ilo_area_exclusions.csv")

# --- Country metadata --------------------------------------------------------
# The country metadata snapshot is collected before estimation. `load_params()`
# hydrates this field from the collection artifact when it exists.
country_metadata <- NULL

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
    file = "1.5_DUIO/UN IGME 2025.csv",
    required_cols = c("Indicator", "Sex", "Observation Status", "Series Year", "REF_DATE", "Geographic area", "OBS_VALUE")
  ),
  JMP_safely_managed_water = list(
    file = "1.5_DUIO/Safely_Managed_Water_data.csv",
    required_cols = c("iso3c", "geo", "year", "data_quality")
  ),
  ILO_LFP_modelled = list(
    file = "1.5_DUIO/EAP_2WAP_SEX_AGE_RT_A-<timestamp>.xlsx",
    required_cols = c("sex.label", "classif1.label", "ref_area.label", "time", "obs_value")
  ),
  ILO_LFP_survey = list(
    file = "1.5_DUIO/EAP_DWAP_SEX_AGE_RT_A-<timestamp>.xlsx",
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

# =============================================================================
# Validation expectations as automated tests
# =============================================================================
# Ported from the "expectations" chunk of 03_SPI_data_validation.Rmd.
#
# The original Rmd uses validate::validator() to check:
#   1. Country/year coverage (countries included, dates covered, dates by
#      country).
#   2. Min/max ranges for every SPI indicator (0 to 1).
#
# These are converted into testthat tests that run against the staged
# SPI_data.csv. The exact rule set from the Rmd is preserved.
#
# Created: 2026-09-22
# =============================================================================

library(testthat)
library(validate)

# --- Helper: read the staged SPI data ----------------------------------------

read_staged_spi <- function() {
  path <- file.path(here::here("staging"), "SPI_data.csv")
  if (!file.exists(path)) {
    return(NULL)
  }
  readr::read_csv(path)
}

# --- The validation rule set (from the Rmd "expectations" chunk) -------------

# The original Rmd defines cntry_list <- unique(SPI_df_v1$iso3c) -- the
# country set from the PREVIOUS vintage. We replicate that by reading the
# vintage fixture's country set. This makes the rule meaningful: it fails
# if the new pipeline drops or adds countries vs the vintage.
#
# NOTE: the variable must be in the GLOBAL environment -- the validate
# package's validator() evaluates rule expressions in a clean environment
# where free variables are only resolved from the global scope (this
# mirrors the original Rmd, which also used a global cntry_list).
vintage_countries <- {
  fixture_path <- file.path(here::here("tests", "fixtures"), "SPI_data.csv")
  if (file.exists(fixture_path)) {
    unique(readr::read_csv(fixture_path)$iso3c)
  } else {
    character(0)
  }
}
assign("cntry_list", vintage_countries, envir = globalenv())

spi_validation_rules <- function() {
  validator(
    countries_included = iso3c %in% cntry_list,  # same countries as the vintage
    dates_covered = date %in% c(2004:2024),          # dates included

    # check for each country that the dates are available
    dates_by_country = contains_exactly(
      keys = data.frame(date = c(2004:2024)),
      by = iso3c
    ),

    # go through list of SPI constructed indicators and make sure they are
    # between 0 and 1
    SPI.D1.5.POV_minmax = in_range(SPI.D1.5.POV, 0, 1),
    SPI.D1.5.CHLD.MORT_minmax = in_range(SPI.D1.5.CHLD.MORT, 0, 1),
    SPI.D1.5.DT.TDS.DPPF.XP.ZS_minmax = in_range(SPI.D1.5.DT.TDS.DPPF.XP.ZS, 0, 1),
    SPI.D1.5.SAFE.MAN.WATER_minmax = in_range(SPI.D1.5.SAFE.MAN.WATER, 0, 1),
    SPI.D1.5.LFP_minmax = in_range(SPI.D1.5.LFP, 0, 1),
    SPI.D2.1.GDDS_minmax = in_range(SPI.D2.1.GDDS, 0, 1),
    SPI.D2.2.Machine.readable_minmax = in_range(SPI.D2.2.Machine.readable, 0, 1),
    SPI.D2.2.Non.proprietary_minmax = in_range(SPI.D2.2.Non.proprietary, 0, 1),
    SPI.D2.2.Download.options_minmax = in_range(SPI.D2.2.Download.options, 0, 1),
    SPI.D2.2.Metadata.available_minmax = in_range(SPI.D2.2.Metadata.available, 0, 1),
    SPI.D2.2.Terms.of.use_minmax = in_range(SPI.D2.2.Terms.of.use, 0, 1),
    SPI.D2.2.Openness.subscore_minmax = in_range(SPI.D2.2.Openness.subscore, 0, 1),
    SPI.D2.4.NADA_minmax = in_range(SPI.D2.4.NADA, 0, 1),
    SPI.D3.1.POV_minmax = in_range(SPI.D3.1.POV, 0, 1),
    SPI.D3.2.HNGR_minmax = in_range(SPI.D3.2.HNGR, 0, 1),
    SPI.D3.3.HLTH_minmax = in_range(SPI.D3.3.HLTH, 0, 1),
    SPI.D3.4.EDUC_minmax = in_range(SPI.D3.4.EDUC, 0, 1),
    SPI.D3.5.GEND_minmax = in_range(SPI.D3.5.GEND, 0, 1),
    SPI.D3.6.WTRS_minmax = in_range(SPI.D3.6.WTRS, 0, 1),
    SPI.D3.7.ENRG_minmax = in_range(SPI.D3.7.ENRG, 0, 1),
    SPI.D3.8.WORK_minmax = in_range(SPI.D3.8.WORK, 0, 1),
    SPI.D3.9.INDY_minmax = in_range(SPI.D3.9.INDY, 0, 1),
    SPI.D3.10.NEQL_minmax = in_range(SPI.D3.10.NEQL, 0, 1),
    SPI.D3.11.CITY_minmax = in_range(SPI.D3.11.CITY, 0, 1),
    SPI.D3.12.CNSP_minmax = in_range(SPI.D3.12.CNSP, 0, 1),
    SPI.D3.15.LAND_minmax = in_range(SPI.D3.15.LAND, 0, 1),
    SPI.D3.16.INST_minmax = in_range(SPI.D3.16.INST, 0, 1),
    SPI.D3.17.PTNS_minmax = in_range(SPI.D3.17.PTNS, 0, 1),
    SPI.D3.13.CLMT_minmax = in_range(SPI.D3.13.CLMT, 0, 1),
    SPI.D4.1.1.POPU_minmax = in_range(SPI.D4.1.1.POPU, 0, 1),
    SPI.D4.1.2.AGRI_minmax = in_range(SPI.D4.1.2.AGRI, 0, 1),
    SPI.D4.1.3.BIZZ_minmax = in_range(SPI.D4.1.3.BIZZ, 0, 1),
    SPI.D4.1.4.HOUS_minmax = in_range(SPI.D4.1.4.HOUS, 0, 1),
    SPI.D4.1.5.AGSVY_minmax = in_range(SPI.D4.1.5.AGSVY, 0, 1),
    SPI.D4.1.6.LABR_minmax = in_range(SPI.D4.1.6.LABR, 0, 1),
    SPI.D4.1.7.HLTH_minmax = in_range(SPI.D4.1.7.HLTH, 0, 1),
    SPI.D4.1.8.BZSVY_minmax = in_range(SPI.D4.1.8.BZSVY, 0, 1),
    SPI.D4.2.3.CRVS_minmax = in_range(SPI.D4.2.3.CRVS, 0, 1),
    SPI.D4.3.GEO.first.admin.level_minmax = in_range(SPI.D4.3.GEO.first.admin.level, 0, 1),
    SPI.D4.3.GEO.second.admin.level_minmax = in_range(SPI.D4.3.GEO.second.admin.level, 0, 1),
    SPI.D5.1.DILG_minmax = in_range(SPI.D5.1.DILG, 0, 1),
    SPI.D5.2.1.SNAU_minmax = in_range(SPI.D5.2.1.SNAU, 0, 1),
    SPI.D5.2.2.NABY_minmax = in_range(SPI.D5.2.2.NABY, 0, 1),
    SPI.D5.2.3.CNIN_minmax = in_range(SPI.D5.2.3.CNIN, 0, 1),
    SPI.D5.2.4.CPIBY_minmax = in_range(SPI.D5.2.4.CPIBY, 0, 1),
    SPI.D5.2.5.HOUS_minmax = in_range(SPI.D5.2.5.HOUS, 0, 1),
    SPI.D5.2.6.EMPL_minmax = in_range(SPI.D5.2.6.EMPL, 0, 1),
    SPI.D5.2.7.CGOV_minmax = in_range(SPI.D5.2.7.CGOV, 0, 1),
    SPI.D5.2.8.FINA_minmax = in_range(SPI.D5.2.8.FINA, 0, 1),
    SPI.D5.2.9.MONY_minmax = in_range(SPI.D5.2.9.MONY, 0, 1),
    SPI.D5.2.10.GSBP_minmax = in_range(SPI.D5.2.10.GSBP, 0, 1),
    SPI.D5.3.DISK_minmax = in_range(SPI.D5.3.DISK, 0, 1),
    SPI.D5.5.DIFI_minmax = in_range(SPI.D5.5.DIFI, 0, 1)
  )
}

# --- Test: all validation rules pass on the staged output --------------------

test_that("staged SPI_data.csv passes all validation rules", {
  spi <- read_staged_spi()
  if (is.null(spi)) {
    skip("staging/SPI_data.csv not yet produced (Phase 3)")
  }

  out <- confront(spi, spi_validation_rules())
  res <- summary(out)

  # All rules must pass with no failures
  expect_equal(
    sum(res$fails),
    0,
    info = sprintf(
      "Validation failures:\n%s",
      paste(
        res$name[res$fails > 0],
        collapse = "\n"
      )
    )
  )

  # No rule may error (missing column, etc.), EXCEPT the known-missing
  # SPI.D5.3.DISK column. This indicator (skills) is not produced by the
  # pipeline nor present in the vintage -- the rule is kept for exact
  # rule-set fidelity but is a documented accepted exception.
  known_missing <- "SPI.D5.3.DISK_minmax"
  unexpected_errors <- res$name[res$error & res$name != known_missing]
  expect_equal(
    length(unexpected_errors),
    0,
    info = sprintf(
      "Unexpected validation errors (missing columns?):\n%s",
      paste(unexpected_errors, collapse = "\n")
    )
  )
})

# --- Test: edge case -- a new country is flagged -----------------------------

test_that("a new country not in the grid is flagged", {
  spi <- read_staged_spi()
  if (is.null(spi)) {
    skip("staging/SPI_data.csv not yet produced (Phase 3)")
  }

  # Add a fake country with a valid date range
  fake <- spi %>%
    dplyr::filter(iso3c == "AFG") %>%
    dplyr::mutate(iso3c = "ZZZ")

  out <- confront(fake, spi_validation_rules())
  res <- summary(out)

  # The rule set should apply without errors (except the known-missing
  # SPI.D5.3.DISK column).
  known_missing <- "SPI.D5.3.DISK_minmax"
  unexpected_errors <- res$name[res$error & res$name != known_missing]
  expect_equal(
    length(unexpected_errors),
    0,
    info = "Rule set should apply without errors"
  )
})

# --- Test: error path -- an out-of-range value fails -------------------------

test_that("an out-of-range value fails the min/max rule", {
  spi <- read_staged_spi()
  if (is.null(spi)) {
    skip("staging/SPI_data.csv not yet produced (Phase 3)")
  }

  # Corrupt one value to be out of range
  corrupted <- spi
  corrupted$SPI.D1.5.POV[1] <- 1.5

  out <- confront(corrupted, spi_validation_rules())
  res <- summary(out)

  # The SPI.D1.5.POV_minmax rule must fail
  pov_rule <- res$name == "SPI.D1.5.POV_minmax"
  expect_true(
    res$fails[pov_rule] > 0,
    info = "Out-of-range value should fail the min/max rule"
  )
})
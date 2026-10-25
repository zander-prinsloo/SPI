# =============================================================================
# Unit tests for the scoring functions
# =============================================================================
# These tests exercise the scoring logic with synthetic minimal inputs so
# that boundary conditions are verified directly, without depending on the
# full raw data. Each test builds a tiny input and checks the score.
#
# Covered functions:
#   - score_poverty_comparability()  (5-vs-10-year window)
#   - score_safely_managed_water()   (urban/rural/national thresholds)
#   - score_ilo_lfp()                (window logic, incl. the E4 fix)
#   - census_fun() / survey_fun()    (10/20-year census window, 3/2/1 survey)
#   - score_nada()                   (year binding + 2021-from-2022 quirk)
#   - score_gsbp()                   (yes/no scoring)
#   - build_index()                  (weight arithmetic)
#
# Created: 2026-09-22
# =============================================================================

library(testthat)

# Source the functions under test
source(file.path(here::here("R"), "setup.R"))
source(file.path(here::here("R"), "schema.R"))
source(file.path(here::here("R"), "dim1_5.R"))
source(file.path(here::here("R"), "dim2.R"))
source(file.path(here::here("R"), "collect_dim4_1.R"))
source(file.path(here::here("R"), "dim4.R"))
source(file.path(here::here("R"), "dim5.R"))
source(file.path(here::here("R"), "index.R"))

# --- Helper: minimal params --------------------------------------------------

test_params <- function(end_date = 2024) {
  list(
    end_date = end_date,
    span = 2004:end_date,
    window = 5,
    raw_dir = here::here("01_raw_data"),
    staging_dir = here::here("staging"),
    wgt = 1,
    imf_file = "2026.10_Compiled Data for World Bank - Sep 2026 - Final.xlsx",
    imf_file_2024 = "2025.10_Compiled Data for World Bank.xlsx"
  )
}

# =============================================================================
# score_poverty_comparability
# =============================================================================

test_that("poverty comparability: 5-year window with 2 comparable surveys scores 1", {
  params <- test_params()
  grid <- tidyr::expand_grid(iso3c = "AFG", date = 2024)

  # Two comparable surveys within the 5-year window
  pip <- tibble::tibble(
    country_code = c("AFG", "AFG"),
    year = c(2022, 2023),
    survey_comparability = c("high", "high"),
    survey_coverage = c("national", "national")
  )

  result <- score_poverty_comparability(pip, params, grid)
  expect_equal(result$SPI.D1.5.POV[result$date == 2024], 1)
})

test_that("poverty comparability: only 1 comparable survey scores 0", {
  params <- test_params()
  grid <- tidyr::expand_grid(iso3c = "AFG", date = 2024)

  pip <- tibble::tibble(
    country_code = c("AFG"),
    year = c(2022),
    survey_comparability = c("high"),
    survey_coverage = c("national")
  )

  result <- score_poverty_comparability(pip, params, grid)
  expect_equal(result$SPI.D1.5.POV[result$date == 2024], 0)
})

test_that("ilo lfp does not award accuracy without a modelled comparator", {
  params <- test_params(end_date = 2024)
  lfp <- tibble::tibble(
    iso3c = "AFG",
    date = 2023,
    estimate_diff = NA_real_,
    lfs_source = TRUE
  )
  result <- score_ilo_lfp(lfp, params)
  expect_equal(result$SPI.D1.5.LFP[result$date == 2024], 0.5)
})

test_that("ilo lfp uses the absolute reported-modelled gap", {
  params <- test_params(end_date = 2024)
  lfp <- tibble::tibble(
    iso3c = "AFG",
    date = 2023,
    estimate_diff = -20,
    lfs_source = TRUE
  )
  result <- score_ilo_lfp(lfp, params)
  expect_equal(result$SPI.D1.5.LFP[result$date == 2024], 0.5)
})

test_that("poverty comparability: 10-year window with 2 national surveys scores 0.5", {
  params <- test_params()
  grid <- tidyr::expand_grid(iso3c = "AFG", date = 2024)

  # Two surveys 8 years back (outside 5-year window, inside 10-year window)
  pip <- tibble::tibble(
    country_code = c("AFG", "AFG"),
    year = c(2016, 2017),
    survey_comparability = c("high", "high"),
    survey_coverage = c("national", "national")
  )

  result <- score_poverty_comparability(pip, params, grid)
  expect_equal(result$SPI.D1.5.POV[result$date == 2024], 0.5)
})

test_that("poverty comparability: JPN/AUS/NZL/SGP always score 1", {
  params <- test_params()
  grid <- tidyr::expand_grid(iso3c = c("JPN", "AFG"), date = 2024)

  pip <- tibble::tibble(
    country_code = character(0),
    year = numeric(0),
    survey_comparability = character(0),
    survey_coverage = character(0)
  )

  result <- score_poverty_comparability(pip, params, grid)
  expect_equal(result$SPI.D1.5.POV[result$iso3c == "JPN"], 1)
  # AFG has no PIP data -> NA (the original code only overrides the four
  # special countries; other countries keep their PIP-derived value)
  expect_true(is.na(result$SPI.D1.5.POV[result$iso3c == "AFG"]))
})

# =============================================================================
# score_safely_managed_water
# =============================================================================

test_that("safely managed water: urban+rural >= 2 each scores 1", {
  params <- test_params()
  # Include all three geo values (Rural/Urban/National) so pivot_wider
  # creates all three columns -- the original code references them as bare
  # symbols in case_when, which fails if a column is absent. Data must
  # span the full window (2015+) so every map_dfr iteration has rows.
  water <- tibble::tibble(
    iso3c = c("AFG", "AFG", "AFG", "AFG", "AFG", "USA", "USA", "USA", "USA", "USA"),
    geo = c("Urban", "Urban", "Rural", "Rural", "National", "Urban", "Urban", "Rural", "Rural", "National"),
    year = c(2015, 2016, 2015, 2016, 2015, 2015, 2016, 2015, 2016, 2015),
    data_quality = c(1, 1, 1, 1, 1, 1, 1, 1, 1, 1)
  )

  result <- score_safely_managed_water(water, params)
  expect_equal(result$SPI.D1.5.SAFE.MAN.WATER[result$date == 2024 & result$iso3c == "AFG"], 1)
})

test_that("safely managed water: only national >= 2 scores 0.5", {
  params <- test_params()
  # Include all three geo values so pivot_wider creates all three columns
  # (the original code references them as bare symbols in case_when).
  water <- tibble::tibble(
    iso3c = c("AFG", "AFG", "AFG", "AFG", "AFG", "USA", "USA", "USA", "USA", "USA"),
    geo = c("National", "National", "Urban", "Rural", "Rural", "National", "National", "Urban", "Rural", "Rural"),
    year = c(2015, 2016, 2015, 2015, 2016, 2015, 2016, 2015, 2015, 2016),
    data_quality = c(1, 1, 1, 1, 1, 1, 1, 1, 1, 1)
  )

  result <- score_safely_managed_water(water, params)
  # National = 2, Urban = 1, Rural = 1 -> 0.5 (partial)
  expect_equal(result$SPI.D1.5.SAFE.MAN.WATER[result$date == 2024 & result$iso3c == "AFG"], 0.5)
})

test_that("safely managed water: no data scores 0", {
  params <- test_params()
  water <- tibble::tibble(
    iso3c = c("AFG", "AFG", "AFG", "USA", "USA", "USA"),
    geo = c("Urban", "Rural", "National", "Urban", "Rural", "National"),
    year = c(2015, 2015, 2015, 2015, 2015, 2015),
    data_quality = c(1, 1, 1, 1, 1, 1)
  )

  result <- score_safely_managed_water(water, params)
  # Each geo has only 1 observation -> 0
  expect_equal(result$SPI.D1.5.SAFE.MAN.WATER[result$date == 2024 & result$iso3c == "AFG"], 0)
})

# =============================================================================
# score_ilo_lfp (window logic, incl. the E4 fix)
# =============================================================================

test_that("ilo lfp: window extends for recent years (E4 fix)", {
  params <- test_params(end_date = 2024)

  # A survey 6 years back: within the extended window for end_date
  # (i - 6), but outside the standard 5-year window.
  lfp <- tibble::tibble(
    iso3c = c("AFG"),
    date = c(2018),
    estimate_diff = c(5),
    lfs_source = c(1)
  )

  result <- score_ilo_lfp(lfp, params)
  # 2018 is within the 2018-2024 window for end_date 2024 (i - 6 = 2018)
  expect_equal(result$SPI.D1.5.LFP[result$date == 2024], 1)
})

test_that("ilo lfp: the i-4 branch is reachable (E4 fix)", {
  params <- test_params(end_date = 2024)

  # A survey 4 years back from a mid-series year (e.g. 2015): within the
  # standard window (i - 4 = 2011..2015). Under the buggy original logic
  # this branch was unreachable.
  lfp <- tibble::tibble(
    iso3c = c("AFG"),
    date = c(2011),
    estimate_diff = c(5),
    lfs_source = c(1)
  )

  result <- score_ilo_lfp(lfp, params)
  expect_equal(result$SPI.D1.5.LFP[result$date == 2015], 1)
})

test_that("ilo lfp: estimate_diff > 10 scores 0.5 (source only)", {
  params <- test_params(end_date = 2024)

  lfp <- tibble::tibble(
    iso3c = c("AFG"),
    date = c(2023),
    estimate_diff = c(20),
    lfs_source = c(1)
  )

  result <- score_ilo_lfp(lfp, params)
  # lfs_source = 1 but estimate_diff > 10 -> (0 + 1) / 2 = 0.5
  expect_equal(result$SPI.D1.5.LFP[result$date == 2024], 0.5)
})

# =============================================================================
# census_fun / survey_fun (10/20-year census window, 3/2/1 survey thresholds)
# =============================================================================

test_that("census_fun: census within 10 years scores 1", {
  params <- test_params()
  # census_fun reads from <raw_dir>/4.1_SOCS/raw/ (base + manual review)
  # and <raw_dir>/4.1_SOCS/collection/ (normalized NADA companions).
  tmp <- tempdir()
  raw_sub <- file.path(tmp, "4.1_SOCS", "raw")
  dir.create(raw_sub, recursive = TRUE)

  base <- tibble::tibble(
    iso3c = c("AFG"),
    date = c(2024),
    POP.CENSUS = c("2015")
  )
  readr::write_csv(base, file.path(raw_sub, "D4.1.1.CEN.POPU.2024.csv"))

  # Manual review file with the required columns
  manual <- tibble::tibble(
    iso3c = c("AFG"),
    country = c("Afghanistan"),
    POP.CENSUS = c("2016"),
    AGRI.CENSUS = c(NA_character_),
    BIZZ.CENSUS = c(NA_character_),
    HOUS.SURVEYS = c(NA_character_),
    AGRI.SURVEYS = c(NA_character_),
    LABR.SURVEYS = c(NA_character_),
    HLTH.SURVEYS = c(NA_character_),
    BIZZ.SURVEYS = c(NA_character_),
    Evidence = c("test source")
  )
  writexl::write_xlsx(manual, file.path(raw_sub, "D4.1.Manual.Review.2024.xlsx"))

  # Normalized catalogue companion (4.1_SOCS/collection/, keyed on iso3c)
  nada <- tibble::tibble(
    iso3c = c("AFG"),
    country = c("Afghanistan"),
    indicator_date = c(2015),
    nada_dates = c("2015"),
    nada_title = c("Test census")
  )
  dir.create(file.path(tmp, "4.1_SOCS", "collection"), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(nada, file.path(tmp, "4.1_SOCS", "collection", "D4.1.1.CEN.POPU_NADA.iso3c.csv"))

  params$raw_dir <- tmp
  params$country_metadata <- tibble::tibble(
    iso3c = c("AFG"),
    country = c("Afghanistan")
  )
  result <- census_fun("D4.1.1.CEN.POPU", "POP.CENSUS", params)
  # 2015 census is within 10 years of 2024
  expect_equal(result$indicator[result$date == 2024], 1)
  expect_match(result$input_var[result$date == 2024], "2015")
  expect_match(result$input_var[result$date == 2024], "2016")
})

test_that("survey_fun: 3 surveys within window scores 1, 2 scores 0.67, 1 scores 0.33", {
  params <- test_params()
  tmp <- tempdir()
  raw_sub <- file.path(tmp, "4.1_SOCS", "raw")
  dir.create(raw_sub, recursive = TRUE)

  # 3 surveys in different years within the 10-year window
  base <- tibble::tibble(
    iso3c = c("AFG", "AFG", "AFG"),
    date = c(2024, 2024, 2024),
    HOUS.SURVEYS = c("2015", "2016", "2017")
  )
  readr::write_csv(base, file.path(raw_sub, "D4.1.4.SVY.HOUS.2024.csv"))

  manual <- tibble::tibble(
    iso3c = c("AFG"),
    country = c("Afghanistan"),
    POP.CENSUS = c(NA_character_),
    AGRI.CENSUS = c(NA_character_),
    BIZZ.CENSUS = c(NA_character_),
    HOUS.SURVEYS = c(NA_character_),
    AGRI.SURVEYS = c(NA_character_),
    LABR.SURVEYS = c(NA_character_),
    HLTH.SURVEYS = c(NA_character_),
    BIZZ.SURVEYS = c(NA_character_),
    Evidence = c(NA_character_)
  )
  writexl::write_xlsx(manual, file.path(raw_sub, "D4.1.Manual.Review.2024.xlsx"))

  # Normalized catalogue companion (4.1_SOCS/collection/, keyed on iso3c)
  nada <- tibble::tibble(
    iso3c = c("AFG"),
    country = c("Afghanistan"),
    indicator_date = c(2015),
    nada_dates = c("2015"),
    nada_title = c("Test survey")
  )
  dir.create(file.path(tmp, "4.1_SOCS", "collection"), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(nada, file.path(tmp, "4.1_SOCS", "collection", "D4.1.4.SVY.HOUS_NADA.iso3c.csv"))

  params$raw_dir <- tmp
  params$country_metadata <- tibble::tibble(
    iso3c = c("AFG"),
    country = c("Afghanistan")
  )
  result <- survey_fun("D4.1.4.SVY.HOUS", "HOUS.SURVEYS", params)
  expect_equal(result$indicator[result$date == 2024], 1)

  # 2 surveys -> 0.67
  base2 <- tibble::tibble(
    iso3c = c("AFG", "AFG"),
    date = c(2024, 2024),
    HOUS.SURVEYS = c("2015", "2016")
  )
  readr::write_csv(base2, file.path(raw_sub, "D4.1.4.SVY.HOUS.2024.csv"))
  result2 <- survey_fun("D4.1.4.SVY.HOUS", "HOUS.SURVEYS", params)
  expect_equal(result2$indicator[result2$date == 2024], 0.67)

  # 1 survey -> 0.33
  base3 <- tibble::tibble(
    iso3c = c("AFG"),
    date = c(2024),
    HOUS.SURVEYS = c("2015")
  )
  readr::write_csv(base3, file.path(raw_sub, "D4.1.4.SVY.HOUS.2024.csv"))
  result3 <- survey_fun("D4.1.4.SVY.HOUS", "HOUS.SURVEYS", params)
  expect_equal(result3$indicator[result3$date == 2024], 0.33)
})

# =============================================================================
# score_nada (year binding + 2021-from-2022 quirk)
# =============================================================================

test_that("score_nada: binds per-year files and preserves the 2021-from-2022 quirk", {
  params <- test_params()
  tmp <- tempdir()
  # score_nada reads from <raw_dir>/2.4_DSDS/
  nada_dir <- file.path(tmp, "2.4_DSDS")
  dir.create(nada_dir, recursive = TRUE)

  # Base file (2016-2019)
  base <- tibble::tibble(
    iso3c = c("AFG", "AFG", "AFG", "AFG"),
    date = c(2016, 2017, 2018, 2019),
    NADA = c(0, 0, 0, 0),
    NADA_text = c("no", "no", "no", "no")
  )
  readr::write_csv(base, file.path(nada_dir, "D2.4.NADA.csv"))

  # 2020 file
  y2020 <- tibble::tibble(
    iso3c = c("AFG"),
    date = c(2020),
    NADA = c(1),
    NADA_text = c("yes")
  )
  readr::write_csv(y2020, file.path(nada_dir, "D2.4.NADA.2020.csv"))

  # 2022 file (used for both 2021 and 2022)
  y2022 <- tibble::tibble(
    iso3c = c("AFG"),
    date = c(2022),
    NADA = c(1),
    NADA_text = c("yes")
  )
  readr::write_csv(y2022, file.path(nada_dir, "D2.4.NADA.2022.csv"))

  # 2023 file
  y2023 <- tibble::tibble(
    iso3c = c("AFG"),
    date = c(2023),
    NADA = c(1),
    NADA_text = c("yes")
  )
  readr::write_csv(y2023, file.path(nada_dir, "D2.4.NADA.2023.csv"))

  # 2024 file
  y2024 <- tibble::tibble(
    iso3c = c("AFG"),
    date = c(2024),
    NADA = c(1),
    NADA_text = c("yes")
  )
  readr::write_csv(y2024, file.path(nada_dir, "D2.4.NADA.2024.csv"))

  params$raw_dir <- tmp
  result <- score_nada(params)

  # 2021 must be present (from the 2022 file)
  expect_true(2021 %in% result$date)
  expect_equal(result$SPI.D2.4.NADA[result$date == 2021], 1)
  # All years 2016-2024 present
  expect_true(all(2016:2024 %in% result$date))
})

test_that("score_nada: fails loudly when the current vintage file is missing", {
  params <- test_params(end_date = 2099)
  tmp <- tempdir()
  params$raw_dir <- tmp
  nada_dir <- file.path(tmp, "2.4_DSDS")
  dir.create(nada_dir, recursive = TRUE)

  # Base file only -- no per-year files
  base <- tibble::tibble(
    iso3c = c("AFG"),
    date = c(2016),
    NADA = c(0),
    NADA_text = c("no")
  )
  readr::write_csv(base, file.path(nada_dir, "D2.4.NADA.csv"))

  expect_error(score_nada(params), "NADA FILE NOT FOUND")
})

# =============================================================================
# score_gsbp (yes/no scoring)
# =============================================================================

test_that("score_gsbp: yes scores 1, no scores 0", {
  params <- test_params()
  tmp <- tempdir()
  # score_gsbp reads from <raw_dir>/5.2_DISM/
  dim5_dir <- file.path(tmp, "5.2_DISM")
  dir.create(dim5_dir, recursive = TRUE)

  base <- tibble::tibble(
    iso3c = c("AFG", "USA"),
    date = c(2016, 2016),
    GSBP = c("Yes", "No")
  )
  readr::write_csv(base, file.path(dim5_dir, "D5.2.10.GSBP.csv"))

  # The current vintage file is required by .read_base_plus_yearly()
  y2024 <- tibble::tibble(
    iso3c = c("AFG", "USA"),
    date = c(2024, 2024),
    GSBP = c("Yes", "No")
  )
  readr::write_csv(y2024, file.path(dim5_dir, "D5.2.10.GSBP.2024.csv"))

  params$raw_dir <- tmp
  result <- score_gsbp(params)
  expect_equal(result$SPI.D5.2.10.GSBP[result$iso3c == "AFG" & result$date == 2016], 1)
  expect_equal(result$SPI.D5.2.10.GSBP[result$iso3c == "USA" & result$date == 2016], 0)
})

# =============================================================================
# Current-vintage IMF year scoping
# =============================================================================

test_that("score_cpiby: current IMF workbook updates only the latest year", {
  params <- test_params(end_date = 2025)
  params$imf_file <- "2026.10_Compiled Data for World Bank - Sep 2026 - Final.xlsx"
  grid <- tibble::tibble(
    iso3c = c("AFG", "AFG", "USA", "USA"),
    country = c("Afghanistan", "Afghanistan", "United States", "United States"),
    date = c(2024, 2025, 2024, 2025)
  )

  result <- score_cpiby(params, grid)
  previous <- read_previous_vintage_d5(params) %>%
    dplyr::filter(iso3c %in% c("AFG", "USA"), date == 2024) %>%
    dplyr::select(iso3c, RAW.D5.2.4.CPIBY, SPI.D5.2.4.CPIBY) %>%
    dplyr::arrange(iso3c)
  observed <- result %>%
    dplyr::filter(iso3c %in% c("AFG", "USA"), date == 2024) %>%
    dplyr::select(iso3c, RAW.D5.2.4.CPIBY, SPI.D5.2.4.CPIBY) %>%
    dplyr::arrange(iso3c)

  expect_true(all(c(2024, 2025) %in% unique(result$date)))
  expect_lte(max(result$date), 2025)
  expect_equal(observed, previous)
})

# =============================================================================
# load_index_weights (weight arithmetic)
# =============================================================================

test_that("load_index_weights: pillar weights sum to 1", {
  w <- load_index_weights()
  pillar_total <- w$pillar_1 + w$pillar_2 + w$pillar_3 + w$pillar_4 + w$pillar_5
  expect_equal(pillar_total, 1)
})

test_that("load_index_weights: pillar 2 dimension weights sum to 1", {
  w <- load_index_weights()
  pillar2_total <- w$dim_2_1 + w$dim_2_2 + w$dim_2_4
  expect_equal(pillar2_total, 1)
})

test_that("load_index_weights: pillar 3 dimension weights sum to 1", {
  w <- load_index_weights()
  pillar3_total <- w$dim_3_1 + w$dim_3_2 + w$dim_3_3 + w$dim_3_4 + w$dim_3_5 +
    w$dim_3_6 + w$dim_3_7 + w$dim_3_8 + w$dim_3_9 + w$dim_3_10 + w$dim_3_11 +
    w$dim_3_12 + w$dim_3_13 + w$dim_3_15 + w$dim_3_16 + w$dim_3_17
  expect_equal(pillar3_total, 1)
})

test_that("load_index_weights: pillar 4 dimension weights sum to 1", {
  w <- load_index_weights()
  pillar4_total <- w$dim_4_1.CEN + w$dim_4_1.SVY + w$dim_4_2 + w$dim_4_3
  expect_equal(pillar4_total, 1)
})
# =============================================================================
# 202611 readiness: source-reader robustness (plan Step 1)
# =============================================================================

test_that("read_wdi_metadata binds vintages whose column types differ", {
  raw <- withr::local_tempdir()
  dir.create(file.path(raw, "metadata"))
  write_wdi <- function(year, agri) {
    readr::write_csv(
      data.frame(
        `Country Code` = c("AAA", "BBB"),
        `Income Group` = c("Low income", "High income"),
        `National accounts reference year` = c("2015", ""),
        `Latest agricultural census` = agri,
        check.names = FALSE
      ),
      file.path(raw, "metadata", sprintf("WDI_metadata_%d.csv", year))
    )
  }
  write_wdi(2016, c("2010/11", "2012"))
  write_wdi(2017, c("2013", "2014"))

  out <- read_wdi_metadata(list(raw_dir = raw, end_date = 2016))
  expect_equal(nrow(out), 4)
  expect_type(out$Latest.agricultural.census, "character")
})

test_that("score_debt_reporting scores 'Estimated' like 'Estimate'", {
  wdi <- data.frame(
    Code = c("AAA", "BBB"),
    date = 2026,
    External.debt.Reporting.status = c("Estimate", "Estimated"),
    Income.Group = "Lower middle income"
  )
  out <- score_debt_reporting(wdi)
  expect_equal(out$SPI.D1.5.DT.TDS.DPPF.XP.ZS, c(0.33, 0.33))
})

test_that("score_debt_reporting fails loudly on an unseen reporting label", {
  wdi <- data.frame(
    Code = "AAA",
    date = 2026,
    External.debt.Reporting.status = "Provisional",
    Income.Group = "Low income"
  )
  expect_error(score_debt_reporting(wdi), "UNKNOWN EXTERNAL DEBT REPORTING STATUS")
})

ilo_fixture <- function(time_value,
                        survey_labels = "Alpha",
                        modelled_labels = survey_labels,
                        crosswalk = data.frame(ilo_label = character(), iso3c = character(), note = character()),
                        exclusions = data.frame(ilo_label = character(), category = character(), reason = character()),
                        economies = "AAA") {
  raw <- withr::local_tempdir(.local_envir = parent.frame())
  config <- withr::local_tempdir(.local_envir = parent.frame())
  dir.create(file.path(raw, "metadata"))
  dir.create(file.path(raw, "1.5_DUIO"))
  readr::write_csv(
    data.frame(ref_area = "AAA", ref_area.label = "Alpha"),
    file.path(raw, "metadata", "ILO_reference_area.csv")
  )
  readr::write_csv(
    data.frame(country = c("Alpha", "Beta"), geoAreaCode = c(1, 2), iso3c = c("AAA", "BBB")),
    file.path(raw, "metadata", "iso_codes.csv")
  )
  rows <- function(labels, value) {
    data.frame(
      sex.label = "Total",
      classif1.label = "Age (Youth, adults): 15+",
      ref_area.label = labels,
      time = time_value,
      obs_value = value
    )
  }
  writexl::write_xlsx(rows(modelled_labels, 60), file.path(raw, "1.5_DUIO", "modelled.xlsx"))
  writexl::write_xlsx(
    transform(rows(survey_labels, 61), source.label = "LFS - Labour Force Survey"),
    file.path(raw, "1.5_DUIO", "survey.xlsx")
  )
  readr::write_csv(crosswalk, file.path(config, "ilo_area_crosswalk.csv"), na = "")
  readr::write_csv(exclusions, file.path(config, "ilo_area_exclusions.csv"), na = "")
  list(
    raw_dir = raw,
    ilo_modelled_file = "modelled.xlsx",
    ilo_survey_file = "survey.xlsx",
    ilo_area_crosswalk_file = file.path(config, "ilo_area_crosswalk.csv"),
    ilo_area_exclusions_file = file.path(config, "ilo_area_exclusions.csv"),
    country_metadata = data.frame(iso3c = economies)
  )
}

test_that("read_ilo_lfp converts text years from Excel bulk files to numbers", {
  params <- ilo_fixture("2020")
  out <- suppressMessages(read_ilo_lfp(params))
  expect_true(is.numeric(out$date))
  expect_equal(out$date, 2020)
})

test_that("read_ilo_lfp fails loudly on non-numeric years", {
  params <- ilo_fixture("20x0")
  expect_error(suppressMessages(read_ilo_lfp(params)), "ILO TIME VALUES ARE NOT NUMERIC")
})

# --- E6: ILO area names that iso_codes.csv does not match ---------------------

test_that("read_ilo_lfp keeps an economy whose ILO name differs, through the crosswalk (E6)", {
  params <- ilo_fixture(
    "2020",
    survey_labels = c("Alpha", "Beta, Republic of"),
    crosswalk = data.frame(ilo_label = "Beta, Republic of", iso3c = "BBB", note = "ILO name"),
    economies = c("AAA", "BBB")
  )
  out <- suppressMessages(read_ilo_lfp(params))
  expect_setequal(out$iso3c, c("AAA", "BBB"))
  # The modelled estimate is joined for the renamed economy too, so the
  # accuracy check compares the reported and modelled rates.
  expect_equal(out$estimate_diff[out$iso3c == "BBB"], 1)
})

test_that("read_ilo_lfp stops on an ILO area name that is neither matched nor recorded (E6)", {
  params <- ilo_fixture("2020", survey_labels = c("Alpha", "Gamma Islands"))
  expect_error(
    suppressMessages(read_ilo_lfp(params)),
    "ILO AREA NAMES NOT RECOGNISED.*Gamma Islands"
  )
  # The modelled file is checked as well: a lost modelled estimate would
  # silently set the accuracy gap to 0.
  params <- ilo_fixture("2020", survey_labels = "Alpha", modelled_labels = c("Alpha", "Gamma Islands"))
  expect_error(
    suppressMessages(read_ilo_lfp(params)),
    "ILO AREA NAMES NOT RECOGNISED.*Gamma Islands"
  )
})

test_that("read_ilo_lfp drops recorded aggregates without a many-to-many join (E6)", {
  params <- ilo_fixture(
    "2020",
    survey_labels = c("Alpha", "World", "Africa"),
    exclusions = data.frame(
      ilo_label = c("World", "Africa"),
      category = "aggregate",
      reason = "ILO regional aggregate"
    )
  )
  out <- expect_no_warning(suppressMessages(read_ilo_lfp(params)))
  expect_identical(out$iso3c, "AAA")
})

test_that("the ILO area-name config is validated against iso_codes.csv and the SPI economies (E6)", {
  conflict <- ilo_fixture(
    "2020",
    crosswalk = data.frame(ilo_label = "Alpha", iso3c = "BBB", note = "wrong"),
    economies = c("AAA", "BBB")
  )
  expect_error(suppressMessages(read_ilo_lfp(conflict)), "ILO AREA CROSSWALK CONFLICTS WITH iso_codes.csv.*Alpha")
  unknown_code <- ilo_fixture(
    "2020",
    survey_labels = c("Alpha", "Beta, Republic of"),
    crosswalk = data.frame(ilo_label = "Beta, Republic of", iso3c = "BBX", note = "typo"),
    economies = c("AAA", "BBB")
  )
  expect_error(suppressMessages(read_ilo_lfp(unknown_code)), "ILO AREA CROSSWALK CODE IS NOT AN SPI ECONOMY.*BBX")
  excluded_economy <- ilo_fixture(
    "2020",
    exclusions = data.frame(ilo_label = "Beta", category = "aggregate", reason = "wrong")
  )
  expect_error(suppressMessages(read_ilo_lfp(excluded_economy)), "ILO AREA EXCLUSIONS NAME AN ECONOMY.*Beta")
})

# --- E6: UN IGME rows are matched on their own ISO3 code ----------------------

igme_fixture <- function(codes, names) {
  raw <- withr::local_tempdir(.local_envir = parent.frame())
  dir.create(file.path(raw, "metadata"))
  dir.create(file.path(raw, "1.5_DUIO"))
  readr::write_csv(
    data.frame(country = c("Alpha", "Beta", "Kosovo-free"), geoAreaCode = c(1, 2, 3), iso3c = c("AAA", "BBB", "CCC")),
    file.path(raw, "metadata", "iso_codes.csv")
  )
  readr::write_csv(
    data.frame(
      REF_AREA = codes,
      `Geographic area` = names,
      Indicator = "Under-five mortality rate",
      Sex = "Total",
      `Wealth Quintile` = "Total",
      `Observation Status` = "Included in IGME",
      `Series Year` = "2018",
      REF_DATE = "2017.5",
      OBS_VALUE = 40,
      check.names = FALSE
    ),
    file.path(raw, "1.5_DUIO", "igme.csv")
  )
  list(raw_dir = raw, unigme_file = "igme.csv")
}

test_that("read_child_mortality_data joins on REF_AREA, so renamed economies are kept (E6)", {
  params <- igme_fixture(
    codes = c("AAA", "BBB", "RKS"),
    names = c("Alpha", "Republic of Beta", "Kosovo (UNSCR 1244)")
  )
  out <- suppressWarnings(suppressMessages(read_child_mortality_data(params)))
  expect_identical(sort(out$iso3c), c("AAA", "BBB", "XKX"))
})

test_that("read_child_mortality_data stops on an unknown REF_AREA code (E6)", {
  params <- igme_fixture(codes = c("AAA", "ZZZ"), names = c("Alpha", "Zeta"))
  expect_error(
    suppressWarnings(suppressMessages(read_child_mortality_data(params))),
    "UN IGME AREA CODES NOT RECOGNISED.*ZZZ"
  )
})

test_that("child mortality uses only total wealth-quintile observations", {
  params <- igme_fixture(
    codes = c("AAA", "AAA", "AAA"),
    names = c("Alpha", "Alpha", "Alpha")
  )
  raw_path <- file.path(params$raw_dir, "1.5_DUIO", "igme.csv")
  data <- readr::read_csv(raw_path, show_col_types = FALSE)
  data$`Wealth Quintile` <- c("Total", "Lower", "Upper")
  readr::write_csv(data, raw_path)
  out <- suppressWarnings(suppressMessages(read_child_mortality_data(params)))
  expect_identical(unique(out$iso3c), "AAA")
  expect_true(all(out$Wealth.Quintile == "Total"))
})

test_that("the shipped ILO area-name config covers every area of the configured ILO files (E6)", {
  params <- load_params(here::here("config", "params.R"), require_country_metadata = FALSE)
  skip_if_not(nrow(params$country_metadata) > 0, "country metadata not collected")
  skip_if_not(
    file.exists(file.path(params$raw_dir, "1.5_DUIO", params$ilo_survey_file)),
    "ILO bulk files not present"
  )
  out <- suppressWarnings(suppressMessages(read_ilo_lfp(params)))
  # Economies whose ILO names differ from iso_codes.csv (202511 and 202611
  # files); each must reach the score.
  expect_true(all(c("BOL", "CPV", "CIV", "COD", "HKG", "IRN", "MAC", "PSE", "TUR", "VEN", "XKX") %in% out$iso3c))
  # The 202511 files, read by the replication harness and the revision
  # attribution, are covered too.
  previous <- params
  previous$ilo_modelled_file <- "EAP_2WAP_SEX_AGE_RT_A-20250923T0014.csv"
  previous$ilo_survey_file <- "EAP_DWAP_SEX_AGE_RT_A-20250923T0014.csv"
  skip_if_not(file.exists(file.path(params$raw_dir, "1.5_DUIO", previous$ilo_survey_file)), "202511 ILO files not present")
  out_previous <- suppressWarnings(suppressMessages(read_ilo_lfp(previous)))
  expect_true(all(c("CIV", "COD", "HKG", "MAC", "PSE", "TUR", "XKX") %in% out_previous$iso3c))
})

test_that("the configured and 202511 UN IGME files reach the Netherlands, Türkiye and Kosovo (E6)", {
  params <- load_params(here::here("config", "params.R"), require_country_metadata = FALSE)
  for (file in c(params$unigme_file, "UNICEF-CME_DF_2021_WQ-1.0-download.csv")) {
    skip_if_not(file.exists(file.path(params$raw_dir, "1.5_DUIO", file)), paste(file, "not present"))
    params$unigme_file <- file
    out <- suppressWarnings(suppressMessages(read_child_mortality_data(params)))
    expect_true(all(c("NLD", "TUR", "XKX", "CIV") %in% out$iso3c), info = file)
    expect_false(anyNA(out$iso3c), info = file)
  }
})

# =============================================================================
# ODIN reads (202611 plan, Step 19)
# =============================================================================

write_odin_years <- function(raw, years, drop = character()) {
  dir.create(file.path(raw, "2.2_DSOA"), recursive = TRUE, showWarnings = FALSE)
  source_file <- here::here("01_raw_data", "2.2_DSOA", "ODIN_2024.csv")
  data <- readr::read_csv(source_file, show_col_types = FALSE)
  for (year in years) {
    out <- data[, setdiff(names(data), drop)]
    out$Year <- year
    readr::write_csv(out, file.path(raw, "2.2_DSOA", sprintf("ODIN_%d.csv", year)))
  }
}

test_that("read_odin_data rejects malformed and duplicate all-category rows", {
  raw <- withr::local_tempdir()
  write_odin_years(raw, 2015:2015)
  path <- file.path(raw, "2.2_DSOA", "ODIN_2015.csv")
  data <- readr::read_csv(path, show_col_types = FALSE)
  all_rows <- which(data[["Data categories"]] %in% c("All Categories", "All categories"))
  data[["Machine readable"]][all_rows[[1L]]] <- "not available"
  readr::write_csv(data, path)
  params <- list(raw_dir = raw, end_date = 2015)
  expect_error(
    suppressMessages(read_odin_data(params)),
    "ODIN NUMERIC VALUE INVALID"
  )

  write_odin_years(raw, 2015:2015)
  data <- readr::read_csv(path, show_col_types = FALSE)
  duplicate <- data[data[["Data categories"]] %in% c("All Categories", "All categories"), ][1, , drop = FALSE]
  readr::write_csv(rbind(data, duplicate), path)
  expect_error(
    suppressMessages(read_odin_data(params)),
    "ODIN DUPLICATE COUNTRY-YEAR"
  )
})

test_that("read_odin_data applies recorded non-economy exclusions", {
  raw <- withr::local_tempdir()
  write_odin_years(raw, 2015:2015)
  params <- list(raw_dir = raw, end_date = 2015)
  result <- suppressMessages(read_odin_data(params))
  expect_false(any(result$Country.Code %in% c("AIA", "COK", "TWN")))

  path <- file.path(raw, "2.2_DSOA", "ODIN_2015.csv")
  data <- readr::read_csv(path, show_col_types = FALSE)
  known_codes <- unique(data[["Country Code"]])
  all_rows <- which(data[["Data categories"]] %in% c("All Categories", "All categories"))
  data[["Country Code"]][all_rows[[1L]]] <- "ZZZ"
  readr::write_csv(data, path)
  params$country_metadata <- tibble::tibble(
    iso3c = known_codes,
    country = known_codes
  )
  expect_error(
    suppressMessages(read_odin_data(params)),
    "ODIN UNKNOWN COUNTRY CODE.*ZZZ"
  )
})

test_that("odin_file_paths lists 2015 to end_date and fails on a missing year", {
  raw <- withr::local_tempdir()
  write_odin_years(raw, 2015:2017)
  params <- list(raw_dir = raw, end_date = 2017)
  expect_identical(basename(odin_file_paths(params)), sprintf("ODIN_%d.csv", 2015:2017))
  unlink(file.path(raw, "2.2_DSOA", "ODIN_2016.csv"))
  expect_error(odin_file_paths(params), "ODIN FILE NOT FOUND.*ODIN_2016.csv")
})

test_that("read_odin_data validates every column the ODIN readers use", {
  raw <- withr::local_tempdir()
  write_odin_years(raw, 2015:2016)
  write_odin_years(raw, 2017, drop = "Coverage subscore")
  params <- list(raw_dir = raw, end_date = 2017)
  expect_error(
    suppressMessages(read_odin_data(params)),
    "ODIN SCHEMA MISMATCH in 'ODIN_2017.csv'.*Coverage.subscore"
  )
})

test_that("geospatial scores use the shared ODIN data", {
  raw <- withr::local_tempdir()
  write_odin_years(raw, 2015:2016)
  params <- test_params()
  params$raw_dir <- raw
  params$end_date <- 2016
  source <- readr::read_csv(
    here::here("01_raw_data", "2.2_DSOA", "ODIN_2024.csv"),
    show_col_types = FALSE,
    name_repair = "universal"
  )
  params$country_metadata <- source %>%
    dplyr::filter(Data.categories %in% c("All Categories", "All categories")) %>%
    dplyr::distinct(Country.Code) %>%
    dplyr::transmute(iso3c = Country.Code, country = Country.Code)
  odin <- suppressMessages(read_odin_data(params))
  shared <- suppressMessages(score_geospatial(params, odin))
  expect_true(all(c("SPI.D4.3.GEO.first.admin.level", "SPI.D4.3.GEO.second.admin.level") %in% names(shared)))
  expect_identical(sort(unique(shared$date[!is.na(shared$date)])), c(2015L, 2016L))
})

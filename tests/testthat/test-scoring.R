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
source(file.path(here::here("R"), "dim1_5.R"))
source(file.path(here::here("R"), "dim2.R"))
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
    wgt = 1
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
  # and <raw_dir>/4.1_SOCS/ (NADA files).
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

  # NADA file (read from 4.1_SOCS/, keyed on country name)
  nada <- tibble::tibble(
    country = c("Afghanistan"),
    indicator_date = c(2015),
    nada_dates = c("2015"),
    nada_title = c("Test census")
  )
  readr::write_csv(nada, file.path(tmp, "4.1_SOCS", "D4.1.1.CEN.POPU_NADA.csv"))

  params$raw_dir <- tmp
  params$country_metadata <- tibble::tibble(
    iso3c = c("AFG"),
    country = c("Afghanistan")
  )
  result <- census_fun("D4.1.1.CEN.POPU", "POP.CENSUS", params)
  # 2015 census is within 10 years of 2024
  expect_equal(result$indicator[result$date == 2024], 1)
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

  # NADA file (read from 4.1_SOCS/, keyed on country name)
  nada <- tibble::tibble(
    country = c("Afghanistan"),
    indicator_date = c(2015),
    nada_dates = c("2015"),
    nada_title = c("Test survey")
  )
  readr::write_csv(nada, file.path(tmp, "4.1_SOCS", "D4.1.4.SVY.HOUS_NADA.csv"))

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
# =============================================================================
# Dimension 4: Data Sources
# =============================================================================
# Ported from the "cs", "crvs", and "geo" chunks of 01-SPI_data_prep.Rmd.
#
# Three sub-dimensions:
#   1. SPI.D4.1.* -- censuses and surveys (8 indicators)
#   2. SPI.D4.2.3.CRVS -- civil registration and vital statistics
#   3. SPI.D4.3.GEO.* -- geospatial data availability (ODIN admin levels)
#
# Created: 2026-09-21
# =============================================================================

# The pipe operator (%>%) comes from magrittr (loaded via tidyverse in the
# original Rmds). We import it explicitly so this file is self-contained.
`%>%` <- magrittr::`%>%`

# dplyr functions (if_else, case_when, etc.) are used unqualified throughout
# this file, matching the tidyverse style of the original Rmds.
library(dplyr)

# =============================================================================
# 4.1 Censuses and surveys
# =============================================================================
# Eight indicators: population census, agriculture census, business census,
# household survey, agriculture survey, labor force survey, health survey,
# business survey. Censuses use a 10/20-year window; surveys use a 10-year
# window with 3/2/1 survey thresholds.

# Country-name aliases: the NADA files use the country names as they were
# when the files were created, but the World Bank API (wb_countries) may
# have renamed countries since. Map old names to current metadata names so
# the NADA join is robust to API drift.
.country_name_aliases <- c(
  "Nauru" = "Naoero"
  # Add more aliases here as the World Bank API renames countries.
)

#' Map a NADA country name to the current metadata name
#'
#' @param name Character: the country name as it appears in a NADA file.
#' @return The current metadata name (or the input if no alias applies).
#' @noRd
.map_nada_country <- function(name) {
  if (name %in% names(.country_name_aliases)) {
    .country_name_aliases[[name]]
  } else {
    name
  }
}

#' Combine year strings from base and manual review sources
#'
#' Helper used by census_fun. Merges the year lists from two character
#' vectors, extracts 4-digit years, and returns a sorted unique list.
#'
#' @param a Character: base data year string.
#' @param b Character: manual review year string.
#' @return A sorted, comma-separated string of years.
#' @noRd
.combine_years_register <- function(a, b) {
  ax <- if (is.na(a)) "" else trimws(a)
  bx <- if (is.na(b)) "" else trimws(b)

  # Detect "Register based census" robustly
  has_reg <- grepl("\\bregister\\b.*\\bbased\\b.*\\bcensus\\b", ax, ignore.case = TRUE) ||
    grepl("\\bregister\\b.*\\bbased\\b.*\\bcensus\\b", bx, ignore.case = TRUE)

  # Extract 4-digit years from both strings
  yrs <- c(
    stringr::str_extract_all(ax, "\\d{4}")[[1]],
    stringr::str_extract_all(bx, "\\d{4}")[[1]]
  )
  yrs <- unique(yrs[nzchar(yrs)])

  parts <- character(0)
  if (has_reg) parts <- c(parts, "Register based census")
  if (length(yrs)) parts <- c(parts, paste(sort(as.integer(yrs)), collapse = ", "))

  if (!length(parts)) return(NA_character_)
  paste(parts, collapse = ", ")
}

#' Combine year strings (survey version)
#'
#' Helper used by survey_fun. Merges the year lists from two character
#' vectors, extracts 4-digit years, and returns a sorted unique list.
#'
#' @param a Character: base data year string.
#' @param b Character: manual review year string.
#' @return A sorted, comma-separated string of years.
#' @noRd
.combine_years <- function(a, b) {
  ax <- if (is.na(a)) "" else a
  bx <- if (is.na(b)) "" else b
  yrs <- c(
    stringr::str_extract_all(ax, "\\d{4}")[[1]],
    stringr::str_extract_all(bx, "\\d{4}")[[1]]
  )
  yrs <- unique(yrs[nzchar(yrs)])
  if (!length(yrs)) return(NA_character_)
  paste(sort(as.integer(yrs)), collapse = ", ")
}

#' Process a census indicator
#'
#' Mirrors census_fun() from the Rmd. Reads the base CSV and manual review
#' data, merges year strings, and scores within 10/20-year windows.
#' Register-based censuses score 1 from 2021 onward.
#'
#' @param data      Character: the base data file name (e.g. "D4.1.1.CEN.POPU").
#' @param input_var Character: the input variable column name
#'                  (e.g. "POP.CENSUS").
#' @param params    List of pipeline parameters.
#' @return A tibble with iso3c, date, input_var, nada_dates, indicator.
#' @export
census_fun <- function(data, input_var, params) {
  end_date <- params$end_date
  raw_dir <- params$raw_dir

  # --- 0) Read the base CSV --------------------------------------------------
  base_raw <- readr::read_csv(file.path(raw_dir, "4.1_SOCS", "raw", paste0(data, ".2024.csv")))

  # --- 1) Read the manual review file ----------------------------------------
  manual_path <- file.path(raw_dir, "4.1_SOCS", "raw", "D4.1.Manual.Review.xlsx")
  manual_raw <- readxl::read_xlsx(manual_path) %>%
    dplyr::select(iso3c, dplyr::all_of(input_var))

  # --- Merge base + manual and combine year strings --------------------------
  cs_start <- base_raw %>%
    dplyr::left_join(manual_raw, by = "iso3c", suffix = c("", "_manual")) %>%
    dplyr::mutate(
      !!input_var := mapply(
        .combine_years_register,
        .data[[input_var]],
        .data[[paste0(input_var, "_manual")]]
      )
    ) %>%
    dplyr::select(-dplyr::all_of(paste0(input_var, "_manual")))

  # --- Split the year strings into separate rows -----------------------------
  cs_df <- cs_start %>%
    dplyr::distinct() %>%
    dplyr::group_by(iso3c) %>%
    dplyr::rename(input_var = !!input_var) %>%
    tidyr::nest() %>%
    dplyr::mutate(
      temp_col = purrr::map(
        data,
        ~ stringr::str_extract_all(.x$input_var, "\\d{4}") %>%
          purrr::flatten_chr() %>%
          as_tibble()
      )
    ) %>%
    tidyr::unnest(keep_empty = TRUE) %>%
    dplyr::mutate(indicator_date = as.numeric(value)) %>%
    dplyr::select(iso3c, indicator_date, input_var)

  # --- Append NADA data on censuses ------------------------------------------
  # The NADA files key on country NAME (e.g. "Nauru"), not iso3c. We map
  # through country_metadata to iso3c. This is robust to World Bank API
  # country-name drift (e.g. NRU was renamed "Nauru" -> "Naoero").
  cs_df <- cs_df %>%
    dplyr::bind_rows(
      readr::read_csv(file.path(raw_dir, "4.1_SOCS", paste0(data, "_NADA.csv"))) %>%
        dplyr::mutate(country = purrr::map_chr(country, .map_nada_country)) %>%
        dplyr::left_join(params$country_metadata, by = "country") %>%
        dplyr::select(iso3c, indicator_date, nada_dates)
    ) %>%
    dplyr::group_by(iso3c, indicator_date) %>%
    dplyr::summarise(
      input_var = dplyr::first(stats::na.omit(input_var)),
      nada_dates = dplyr::first(stats::na.omit(nada_dates)),
      .groups = "drop"
    ) %>%
    dplyr::mutate(indicator_date = if_else(is.na(indicator_date), -99, indicator_date))

  # --- Score for each year 2004:end_date -------------------------------------
  purrr::map_dfr(2004:end_date, function(i) {
    cs_df %>%
      dplyr::mutate(date = i) %>%
      dplyr::mutate(
        recency_indicator = (date >= indicator_date)
      ) %>%
      # Restrict to censuses that do not occur after the reference date
      dplyr::mutate(
        indicator_date = if_else(recency_indicator == TRUE, indicator_date, as.numeric(NA)),
        register = if_else(stringr::str_detect(input_var, "Register based census"), 1, 0)
      ) %>%
      dplyr::group_by(iso3c, date) %>%
      dplyr::summarise(
        last_val = max(indicator_date, na.rm = TRUE),
        register = max(register, na.rm = TRUE),
        input_var = paste(unique(indicator_date), collapse = ","),
        nada_dates = dplyr::first(nada_dates),
        .groups = "drop"
      ) %>%
      dplyr::mutate(indicator = dplyr::case_when(
        (date >= 2021 & register == 1) ~ 1,  # score register-based censuses
        (date - last_val <= 10) & (date - last_val >= 0) ~ 1,
        (date - last_val <= 20) & (date - last_val >= 0) ~ 0.5,
        TRUE ~ 0
      )) %>%
      dplyr::select(iso3c, date, input_var, nada_dates, indicator) %>%
      dplyr::arrange(date, iso3c)
  })
}

#' Process a survey indicator
#'
#' Mirrors survey_fun() from the Rmd. Reads the base CSV and manual review
#' data, merges year strings, and scores within a 10-year window with
#' 3/2/1 survey thresholds.
#'
#' @param data      Character: the base data file name (e.g. "D4.1.4.SVY.HOUS").
#' @param input_var Character: the input variable column name
#'                  (e.g. "HOUS.SURVEYS").
#' @param params    List of pipeline parameters.
#' @return A tibble with iso3c, date, input_var, nada_dates, indicator.
#' @export
survey_fun <- function(data, input_var, params) {
  end_date <- params$end_date
  raw_dir <- params$raw_dir

  # --- 0) Read the base CSV --------------------------------------------------
  base_raw <- readr::read_csv(file.path(raw_dir, "4.1_SOCS", "raw", paste0(data, ".2024.csv")))

  # --- 1) Read the manual review file ----------------------------------------
  manual_path <- file.path(raw_dir, "4.1_SOCS", "raw", "D4.1.Manual.Review.xlsx")
  manual_raw <- readxl::read_xlsx(manual_path) %>%
    dplyr::select(iso3c, dplyr::all_of(input_var))

  # --- Merge base + manual and combine year strings --------------------------
  cs_start <- base_raw %>%
    dplyr::left_join(manual_raw, by = "iso3c", suffix = c("", "_manual")) %>%
    dplyr::mutate(
      !!input_var := mapply(
        .combine_years,
        .data[[input_var]],
        .data[[paste0(input_var, "_manual")]]
      )
    ) %>%
    dplyr::select(-dplyr::all_of(paste0(input_var, "_manual")))

  # --- Split the year strings into separate rows -----------------------------
  cs_df <- cs_start %>%
    dplyr::distinct() %>%
    dplyr::group_by(iso3c) %>%
    dplyr::rename(input_var = !!input_var) %>%
    tidyr::nest() %>%
    dplyr::mutate(
      temp_col = purrr::map(
        data,
        ~ stringr::str_extract_all(.x$input_var, "\\d{4}") %>%
          purrr::flatten_chr() %>%
          as_tibble()
      )
    ) %>%
    tidyr::unnest(keep_empty = TRUE) %>%
    dplyr::mutate(indicator_date = as.numeric(value)) %>%
    dplyr::select(iso3c, indicator_date, input_var)

  # --- Append NADA data on surveys -------------------------------------------
  # The NADA files key on country NAME (e.g. "Nauru"), not iso3c. We map
  # through country_metadata to iso3c. This is robust to World Bank API
  # country-name drift (e.g. NRU was renamed "Nauru" -> "Naoero").
  cs_df <- cs_df %>%
    dplyr::bind_rows(
      readr::read_csv(
        file.path(raw_dir, "4.1_SOCS", paste0(data, "_NADA.csv")),
        col_types = list(readr::col_character(), readr::col_double(), readr::col_character())
      ) %>%
        dplyr::mutate(country = purrr::map_chr(country, .map_nada_country)) %>%
        dplyr::left_join(params$country_metadata, by = "country") %>%
        dplyr::select(iso3c, indicator_date, nada_dates)
    ) %>%
    dplyr::group_by(iso3c, indicator_date) %>%
    dplyr::summarise(
      input_var = dplyr::first(stats::na.omit(input_var)),
      nada_dates = dplyr::first(stats::na.omit(nada_dates)),
      .groups = "drop"
    ) %>%
    dplyr::mutate(indicator_date = if_else(is.na(indicator_date), -99, indicator_date))

  # --- Score for each year 2004:end_date -------------------------------------
  purrr::map_dfr(2004:end_date, function(i) {
    cs_df %>%
      dplyr::mutate(date = i) %>%
      dplyr::mutate(window = dplyr::case_when(
        # Extend the window for recent years (surveys reported with a lag)
        date == end_date ~ 12,
        date == (end_date - 1) ~ 11,
        TRUE ~ 10
      )) %>%
      dplyr::mutate(recency_indicator = ((date - indicator_date <= window) &
        (date - indicator_date >= 0))) %>%
      dplyr::group_by(iso3c, date) %>%
      dplyr::summarise(
        indicator = dplyr::case_when(
          sum(recency_indicator) >= 3 ~ 1,
          sum(recency_indicator) == 2 ~ 0.67,
          sum(recency_indicator) == 1 ~ 0.33,
          TRUE ~ 0
        ),
        input_var = paste(unique(indicator_date), collapse = ", "),
        nada_dates = dplyr::first(nada_dates),
        .groups = "drop"
      ) %>%
      dplyr::select(iso3c, date, input_var, nada_dates, indicator) %>%
      dplyr::arrange(date, iso3c)
  })
}

#' Combine all eight census and survey indicators
#'
#' Mirrors the "cs" chunk. Runs census_fun/survey_fun for each of the 8
#' indicators and joins them onto the country grid.
#'
#' @param params List of pipeline parameters.
#' @param grid   The country x year grid.
#' @return A tibble with iso3c, date, and the D4.1 columns.
#' @export
combine_censuses_surveys <- function(params, grid) {
  # Population census
  cs1_df <- census_fun("D4.1.1.CEN.POPU", "POP.CENSUS", params) %>%
    dplyr::rename(
      RAW.D4.1.1.POPU = input_var,
      SPI.D4.1.1.POPU = indicator
    ) %>%
    dplyr::select(iso3c, date, dplyr::starts_with("SPI"), dplyr::starts_with("RAW"))

  # Agriculture census
  cs2_df <- census_fun("D4.1.2.CEN.AGRI", "AGRI.CENSUS", params) %>%
    dplyr::rename(
      RAW.D4.1.2.AGRI = input_var,
      SPI.D4.1.2.AGRI = indicator
    ) %>%
    dplyr::select(iso3c, date, dplyr::starts_with("SPI"), dplyr::starts_with("RAW"))

  # Business/establishment census
  cs3_df <- census_fun("D4.1.3.CEN.BIZZ", "BIZZ.CENSUS", params) %>%
    dplyr::rename(
      RAW.D4.1.3.BIZZ = input_var,
      RAW.D4.1.3.BIZZ.CENSUS_nada = nada_dates,
      SPI.D4.1.3.BIZZ = indicator
    ) %>%
    dplyr::select(iso3c, date, dplyr::starts_with("SPI"), dplyr::starts_with("RAW"))

  # Household survey
  cs4_df <- survey_fun("D4.1.4.SVY.HOUS", "HOUS.SURVEYS", params) %>%
    dplyr::rename(
      RAW.D4.1.4.HOUS = input_var,
      RAW.D4.1.4.HOUS.SURVEYS_nada = nada_dates,
      SPI.D4.1.4.HOUS = indicator
    ) %>%
    dplyr::select(iso3c, date, dplyr::starts_with("SPI"), dplyr::starts_with("RAW"))

  # Agriculture survey
  cs5_df <- survey_fun("D4.1.5.SVY.AGRI", "AGRI.SURVEYS", params) %>%
    dplyr::rename(
      RAW.D4.1.5.AGSVY = input_var,
      RAW.D4.1.5.AGRI.SURVEYS_nada = nada_dates,
      SPI.D4.1.5.AGSVY = indicator
    ) %>%
    dplyr::select(iso3c, date, dplyr::starts_with("SPI"), dplyr::starts_with("RAW"))

  # Labor force survey
  cs6_df <- survey_fun("D4.1.6.SVY.LABR", "LABR.SURVEYS", params) %>%
    dplyr::rename(
      RAW.D4.1.6.LABR = input_var,
      RAW.D4.1.6.LABR.SURVEYS_nada = nada_dates,
      SPI.D4.1.6.LABR = indicator
    ) %>%
    dplyr::select(iso3c, date, dplyr::starts_with("SPI"), dplyr::starts_with("RAW"))

  # Health/Demographic survey
  cs7_df <- survey_fun("D4.1.7.SVY.HLTH", "HLTH.SURVEYS", params) %>%
    dplyr::rename(
      RAW.D4.1.7.HLTH = input_var,
      RAW.D4.1.7.HLTH.SURVEYS_nada = nada_dates,
      SPI.D4.1.7.HLTH = indicator
    ) %>%
    dplyr::select(iso3c, date, dplyr::starts_with("SPI"), dplyr::starts_with("RAW"))

  # Business/establishment survey
  cs8_df <- survey_fun("D4.1.8.SVY.BIZZ", "BIZZ.SURVEYS", params) %>%
    dplyr::rename(
      RAW.D4.1.8.BZSVY = input_var,
      RAW.D4.1.8.BIZZ.SURVEYS_nada = nada_dates,
      SPI.D4.1.8.BZSVY = indicator
    ) %>%
    dplyr::select(iso3c, date, dplyr::starts_with("SPI"), dplyr::starts_with("RAW"))

  # Bind all censuses and surveys together
  grid %>%
    dplyr::left_join(cs1_df %>% dplyr::filter(!is.na(iso3c))) %>%
    dplyr::left_join(cs2_df %>% dplyr::filter(!is.na(iso3c))) %>%
    dplyr::left_join(cs3_df %>% dplyr::filter(!is.na(iso3c))) %>%
    dplyr::left_join(cs4_df %>% dplyr::filter(!is.na(iso3c))) %>%
    dplyr::left_join(cs5_df %>% dplyr::filter(!is.na(iso3c))) %>%
    dplyr::left_join(cs6_df %>% dplyr::filter(!is.na(iso3c))) %>%
    dplyr::left_join(cs7_df %>% dplyr::filter(!is.na(iso3c))) %>%
    dplyr::left_join(cs8_df %>% dplyr::filter(!is.na(iso3c))) %>%
    dplyr::filter(!is.na(iso3c))
}

# =============================================================================
# 4.2 Civil registration and vital statistics (CRVS)
# =============================================================================
# Source: UN SDG database (birth/death registration completeness) plus WDI
# metadata supplement. Only D4.2.3 (CRVS) is included in the index.

#' Score the CRVS indicator
#'
#' Mirrors the "crvs" chunk. Combines birth registration (>=90% complete)
#' and death registration (>=75% complete) data with the WDI supplement,
#' using forward-fill to carry values forward.
#'
#' @param wdi_metadata Tibble from read_wdi_metadata().
#' @param params       List of pipeline parameters.
#' @param grid         The country x year grid.
#' @return A tibble with iso3c, date, and the CRVS columns.
#' @export
score_crvs <- function(wdi_metadata, params, grid) {
  end_date <- params$end_date
  raw_dir <- params$raw_dir

  # Birth registration data (>=90% complete)
  df_birth <- readr::read_csv(file.path(raw_dir, "4.2_SOAD", "SG_REG_BRTH90N.csv")) %>%
    dplyr::filter(date >= 2015 & date <= end_date) %>%
    dplyr::left_join(grid, by = c("iso3c", "date")) %>%
    dplyr::transmute(
      iso3c = iso3c,
      date = date,
      RAW.D4.2.3.BRTH90 = Value,
      SPI.D4.2.3.BRTH90 = if_else(Value == 1, 0.5, 0)
    ) %>%
    # Carry forward last value if missing
    dplyr::group_by(iso3c) %>%
    dplyr::mutate(dplyr::across(dplyr::starts_with("SPI"), zoo::na.locf, na.rm = FALSE)) %>%
    dplyr::mutate(dplyr::across(dplyr::starts_with("SPI"), ~ if_else(is.na(.), 0, .))) %>%
    dplyr::ungroup()

  # Death registration data (>=75% complete)
  df_death <- readr::read_csv(file.path(raw_dir, "4.2_SOAD", "SG_REG_DETH75N.csv")) %>%
    dplyr::filter(date >= 2015 & date <= end_date) %>%
    dplyr::left_join(grid, by = c("iso3c", "date")) %>%
    dplyr::transmute(
      iso3c = iso3c,
      date = date,
      RAW.D4.2.3.DETH75 = Value,
      SPI.D4.2.3.DETH75 = if_else(Value == 1, 0.5, 0)
    ) %>%
    dplyr::group_by(iso3c) %>%
    dplyr::mutate(dplyr::across(dplyr::starts_with("SPI"), zoo::na.locf, na.rm = FALSE)) %>%
    dplyr::mutate(dplyr::across(dplyr::starts_with("SPI"), ~ if_else(is.na(.), 0, .))) %>%
    dplyr::ungroup()

  # WDI supplement: vital registration completeness
  crvs_wdi <- wdi_metadata %>%
    dplyr::select(Code, date, Vital.registration.complete) %>%
    dplyr::mutate(
      iso3c = Code,
      SPI.D4.2.3.WDI = if_else(!is.na(Vital.registration.complete),
        if_else(grepl("Yes", Vital.registration.complete), 1, 0),
        NA_real_
      ),
      RAW.D4.2.3.CRVS.WDI = Vital.registration.complete
    )

  # Combine birth + death + WDI, carry forward
  crvs_df <- grid %>%
    dplyr::left_join(df_birth, by = c("iso3c", "date")) %>%
    dplyr::left_join(df_death, by = c("iso3c", "date")) %>%
    dplyr::left_join(crvs_wdi, by = c("iso3c", "date")) %>%
    dplyr::mutate(SPI.D4.2.3.CRVS = SPI.D4.2.3.DETH75 + SPI.D4.2.3.BRTH90) %>%
    dplyr::select(-SPI.D4.2.3.WDI) %>%
    dplyr::group_by(iso3c) %>%
    dplyr::mutate(dplyr::across(dplyr::starts_with("SPI"), zoo::na.locf, na.rm = FALSE)) %>%
    dplyr::mutate(dplyr::across(dplyr::starts_with("SPI"), ~ if_else(is.na(.), 0, .))) %>%
    dplyr::ungroup() %>%
    dplyr::select(iso3c, date, RAW.D4.2.3.BRTH90, RAW.D4.2.3.DETH75, RAW.D4.2.3.CRVS.WDI, SPI.D4.2.3.CRVS)

  crvs_df
}

# =============================================================================
# 4.3 Geospatial data (ODIN administrative levels)
# =============================================================================
# Source: Open Data Watch ODIN. Uses the First/Second administrative level
# scores (0-100), converted to 0-1. Small countries without first-level
# data use the coverage subscore instead.

#' Score the geospatial indicator
#'
#' Mirrors the "geo" chunk. Reads the ODIN data, applies the small-country
#' adjustment, and produces RAW (0-100) and SPI (0-1) admin level scores.
#'
#' @param params List of pipeline parameters.
#' @return A tibble with iso3c, date, and the GEO columns.
#' @export
score_geospatial <- function(params) {
  end_date <- params$end_date

  # Countries where 1st admin level data is not included (small countries)
  geo_country_list <- c(
    "ADO", "AIA", "ATG", "BHR", "DMA", "HKG", "MAC", "MDV", "MLT", "MHL",
    "FSM", "MCO", "PLW", "STP", "SMR", "SYC", "SGP", "KNA", "LCA", "VCT",
    "TON", "LIE"
  )

  # Read ODIN data for each year (same files as D2.2)
  geo_df <- purrr::map_dfr(2015:end_date, function(i) {
    readr::read_csv(file.path(params$raw_dir, "2.2_DSOA", sprintf("ODIN_%d.csv", i))) %>%
      tibble::as_tibble(.name_repair = "universal") %>%
      dplyr::mutate(date = i) %>%
      dplyr::filter(Data.categories %in% c("All Categories", "All categories")) %>%
      dplyr::mutate(dplyr::across(
        c(
          "Indicator.coverage.and.disaggregation",
          "Data.available.last.5.years",
          "Data.available.last.10.years",
          "First.administrative.level",
          "Second.administrative.level",
          "Coverage.subscore",
          "Machine.readable",
          "Non.proprietary",
          "Download.options",
          "Metadata.available",
          "Terms.of.use",
          "Openness.subscore",
          "Overall.score"
        ),
        as.numeric
      )) %>%
      dplyr::select(-Year)
  })

  # Small countries: use coverage subscore for admin levels
  geo_df <- geo_df %>%
    dplyr::mutate(
      First.administrative.level = dplyr::case_when(
        Country.Code %in% geo_country_list ~ Coverage.subscore,
        TRUE ~ First.administrative.level
      ),
      Second.administrative.level = dplyr::case_when(
        Country.Code %in% geo_country_list ~ Coverage.subscore,
        TRUE ~ Second.administrative.level
      )
    )

  # Create geo scores
  geo_df <- geo_df %>%
    dplyr::select(Country.Code, date, First.administrative.level, Second.administrative.level) %>%
    dplyr::rename(iso3c = Country.Code) %>%
    dplyr::group_by(iso3c) %>%
    dplyr::right_join(params$country_metadata, by = "iso3c") %>%
    dplyr::mutate(
      D4.3.GEO.first.admin.level = if_else(is.na(First.administrative.level), 0, First.administrative.level),
      D4.3.GEO.second.admin.level = if_else(is.na(Second.administrative.level), 0, Second.administrative.level)
    )

  # RAW (0-100) and SPI (0-1) versions
  geo_df_temp1 <- geo_df %>%
    dplyr::rename_with(
      ~ paste("RAW", ., sep = "."),
      .cols = c("D4.3.GEO.first.admin.level", "D4.3.GEO.second.admin.level")
    )

  geo_df_temp2 <- geo_df %>%
    dplyr::mutate(dplyr::across(
      c("D4.3.GEO.first.admin.level", "D4.3.GEO.second.admin.level"),
      ~ ./100
    )) %>%
    dplyr::rename_with(
      ~ paste("SPI", ., sep = "."),
      .cols = c("D4.3.GEO.first.admin.level", "D4.3.GEO.second.admin.level")
    )

  geo_df_temp1 %>%
    dplyr::left_join(geo_df_temp2)
}

# =============================================================================
# Combine all D4 indicators
# =============================================================================

#' Combine all D4 indicators
#'
#' Joins censuses/surveys, CRVS, and geospatial onto the country grid.
#'
#' @param params List of pipeline parameters.
#' @param grid   The country x year grid.
#' @return A tibble with iso3c, date, and the D4 indicator columns.
#' @export
combine_dim4 <- function(params, grid) {
  wdi_metadata <- read_wdi_metadata(params)

  cs <- combine_censuses_surveys(params, grid)
  crvs <- score_crvs(wdi_metadata, params, grid)
  geo <- score_geospatial(params)

  grid %>%
    dplyr::left_join(cs, by = c("iso3c", "date")) %>%
    dplyr::left_join(crvs, by = c("iso3c", "date")) %>%
    dplyr::left_join(geo)
}
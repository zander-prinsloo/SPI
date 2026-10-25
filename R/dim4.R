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

# Catalogue companions: the microdata-catalogue evidence (<stem>_NADA.csv) is
# normalized at collection time to CLASS.xlsx economy names plus ISO3 codes
# (normalize_dim4_1_companions() in R/collect_dim4_1.R), with non-economies,
# multi-country studies and blank-country rows recorded as exclusions in the
# D4.1 manifest. Estimation joins the normalized companions by iso3c, so World
# Bank API country-name changes cannot drop catalogue evidence.

#' Read a normalized D4.1 catalogue companion
#'
#' @param raw_dir Root raw-data directory.
#' @param data Companion stem (for example "D4.1.1.CEN.POPU").
#' @param end_date Reference year.
#' @return A tibble with iso3c, indicator_date and nada_dates.
#' @noRd
.read_d41_companion <- function(raw_dir, data, end_date) {
  path <- dim4_1_artifact_paths(raw_dir, end_date)$normalized_companion_files[[data]]
  if (is.null(path)) {
    stop("UNKNOWN D4.1 CATALOGUE COMPANION: ", data, call. = FALSE)
  }
  if (!file.exists(path)) {
    stop(
      sprintf("D4.1 NORMALIZED COMPANION NOT FOUND: %s\n", path),
      "Run the collection pipeline (_targets_data.R) to normalize the ",
      "catalogue companions.",
      call. = FALSE
    )
  }
  companion <- readr::read_csv(
    path,
    col_types = readr::cols_only(
      iso3c = readr::col_character(),
      indicator_date = readr::col_double(),
      nada_dates = readr::col_character()
    ),
    progress = FALSE
  )
  if (anyNA(companion$iso3c) || anyNA(companion$indicator_date)) {
    stop("D4.1 NORMALIZED COMPANION HAS MISSING KEYS: ", path, call. = FALSE)
  }
  companion
}

#' Read the manual review files for all vintages up to the current one
#'
#' The manual review files contain country-economist evidence for the
#' census/survey indicators, produced during the data review for each vintage.
#' Files are versioned by vintage year:
#'
#'   D4.1.Manual.Review.<YEAR>.xlsx   (e.g. D4.1.Manual.Review.2024.xlsx)
#'
#' The file for the CURRENT vintage (params$end_date) is always required.
#' Historical vintage files are read when present so that earlier evidence is
#' kept. Reviews are an additive evidence layer: all vintages are collapsed to
#' one row per country, taking the union of the recorded values (a value is
#' never dropped). With a single vintage the result equals that file.
#'
#' @param params List of pipeline parameters.
#' @return A tibble with one row per iso3c and the manual override columns.
#' @noRd
.read_manual_review <- function(params, review_path = NULL) {
  end_date <- params$end_date
  raw_dir <- params$raw_dir
  dir_path <- file.path(raw_dir, "4.1_SOCS", "raw")

  # The current vintage file is REQUIRED -- fail loudly if missing (R8).
  current_path <- if (is.null(review_path)) {
    file.path(dir_path, sprintf("D4.1.Manual.Review.%d.xlsx", end_date))
  } else {
    review_path
  }
  if (!file.exists(current_path)) {
    stop(
      sprintf("MANUAL REVIEW FILE NOT FOUND: %s\n", current_path),
      "\nThe manual review file for the current vintage is required.",
      "Create it from the previous vintage's file (e.g. copy",
      "D4.1.Manual.Review.2024.xlsx to D4.1.Manual.Review.2025.xlsx)",
      "and update the manual overrides for the new vintage.",
      call. = FALSE
    )
  }

  # Historical vintage files are optional -- read them when present so
  # earlier years keep their manual overrides.
  historical_years <- setdiff(2004:end_date, end_date)
  historical_paths <- file.path(
    dir_path,
    sprintf("D4.1.Manual.Review.%d.xlsx", historical_years)
  )
  historical_paths <- historical_paths[file.exists(historical_paths)]

  all_paths <- c(current_path, historical_paths)
  reviews <- purrr::map_dfr(all_paths, function(p) {
    review <- readxl::read_xlsx(p) %>%
      dplyr::mutate(dplyr::across(dplyr::everything(), as.character))
    if (exists("validate_dim4_1_review", mode = "function")) {
      validate_dim4_1_review(
        review,
        country_metadata = params$country_metadata
      )
    }
    keys <- trimws(review$iso3c)
    keys <- keys[!is.na(keys) & nzchar(keys)]
    if (anyDuplicated(keys) > 0L) {
      stop(
        sprintf("D4.1 MANUAL REVIEW HAS DUPLICATE COUNTRY KEYS in '%s'", basename(p)),
        call. = FALSE
      )
    }
    review %>%
      dplyr::mutate(.vintage = stringr::str_extract(basename(p), "[0-9]{4}"))
  })

  value_columns <- setdiff(names(reviews), c("iso3c", "country", "Evidence", ".vintage"))
  union_values <- function(values) {
    values <- trimws(values)
    values <- unique(values[!is.na(values) & nzchar(values)])
    if (length(values) == 0L) NA_character_ else paste(values, collapse = ", ")
  }

  labelled_evidence <- function(evidence, vintage) {
    keep <- !is.na(evidence) & nzchar(trimws(evidence))
    if (!any(keep)) return(NA_character_)
    paste(unique(sprintf("%s: %s", vintage[keep], trimws(evidence[keep]))), collapse = "; ")
  }

  reviews %>%
    dplyr::group_by(iso3c) %>%
    dplyr::summarise(
      country = dplyr::first(stats::na.omit(country)),
      dplyr::across(dplyr::all_of(value_columns), union_values),
      Evidence = if ("Evidence" %in% names(reviews)) labelled_evidence(Evidence, .vintage) else NA_character_,
      .groups = "drop"
    )
}

.d41_assert_review_keys <- function(base, review, input_var) {
  nonempty <- !is.na(review[[input_var]]) &
    nzchar(trimws(as.character(review[[input_var]])))
  missing <- setdiff(review$iso3c[nonempty], base$iso3c)
  if (length(missing) > 0L) {
    stop(
      "D4.1 MANUAL REVIEW HAS NONBLANK KEYS ABSENT FROM BASE WORKBOOK for ",
      input_var,
      ": ",
      paste(sort(unique(missing)), collapse = ", "),
      call. = FALSE
    )
  }
  invisible(TRUE)
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
  if (exists("dim4_1_merge_review_values", mode = "function")) {
    return(dim4_1_merge_review_values(a, b, register_based = TRUE))
  }
  ax <- if (is.na(a)) "" else trimws(a)
  bx <- if (is.na(b)) "" else trimws(b)

  # Detect "Register based census" robustly
  has_reg <- any(grepl(
    "^register[ -]based[ -]census$",
    trimws(unlist(strsplit(paste(c(ax, bx), collapse = ","), ",", fixed = TRUE))),
    ignore.case = TRUE
  ))

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
  if (exists("dim4_1_merge_review_values", mode = "function")) {
    return(dim4_1_merge_review_values(a, b, register_based = FALSE))
  }
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
census_fun <- function(data, input_var, params, review_path = NULL) {
  end_date <- params$end_date
  raw_dir <- params$raw_dir

  # --- 0) Read the base CSV --------------------------------------------------
  # The base CSV is versioned by vintage year (e.g. D4.1.1.CEN.POPU.2024.csv),
  # produced by 02_programs/misc_scripts/preprocess-manual-data-4.1-and-5.2.10.R
  # from the input/ Excel files. Fail loudly if the current vintage file is
  # missing (R8) -- the preprocess script must be run first.
  base_path <- file.path(raw_dir, "4.1_SOCS", "raw", sprintf("%s.%d.csv", data, end_date))
  if (!file.exists(base_path)) {
    stop(
      sprintf("BASE CSV NOT FOUND: %s\n", base_path),
      "\nRun the preprocess script to generate the current vintage file:",
      "  02_programs/misc_scripts/preprocess-manual-data-4.1-and-5.2.10.R",
      "This reads the input/ Excel files and writes the per-year CSVs",
      sprintf("(e.g. %s.%d.csv).", data, end_date),
      call. = FALSE
    )
  }
  base_raw <- readr::read_csv(base_path)

  # --- 1) Read the manual review file ----------------------------------------
  # Versioned by vintage year (D4.1.Manual.Review.<YEAR>.xlsx). The current
  # vintage file is required; historical files are read when present.
  manual_raw <- .read_manual_review(params, review_path = review_path) %>%
    dplyr::select(iso3c, dplyr::all_of(input_var))
  .d41_assert_review_keys(base_raw, manual_raw, input_var)

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
  # The normalized catalogue companion is keyed on iso3c (CLASS.xlsx names
  # plus a recorded crosswalk), so the join does not depend on World Bank API
  # country names.
  cs_df <- cs_df %>%
    dplyr::bind_rows(.read_d41_companion(raw_dir, data, end_date)) %>%
    dplyr::group_by(iso3c, indicator_date) %>%
    dplyr::summarise(
      input_var = dplyr::first(stats::na.omit(input_var)),
      nada_dates = paste(
        unique(nada_dates[!is.na(nada_dates) & nzchar(trimws(nada_dates))]),
        collapse = "; "
      ),
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
      nada_dates = paste(
          unique(nada_dates[!is.na(nada_dates) & nzchar(trimws(nada_dates))]),
          collapse = "; "
        ),
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
survey_fun <- function(data, input_var, params, review_path = NULL) {
  end_date <- params$end_date
  raw_dir <- params$raw_dir

  # --- 0) Read the base CSV --------------------------------------------------
  # The base CSV is versioned by vintage year (e.g. D4.1.4.SVY.HOUS.2024.csv),
  # produced by 02_programs/misc_scripts/preprocess-manual-data-4.1-and-5.2.10.R
  # from the input/ Excel files. Fail loudly if the current vintage file is
  # missing (R8) -- the preprocess script must be run first.
  base_path <- file.path(raw_dir, "4.1_SOCS", "raw", sprintf("%s.%d.csv", data, end_date))
  if (!file.exists(base_path)) {
    stop(
      sprintf("BASE CSV NOT FOUND: %s\n", base_path),
      "\nRun the preprocess script to generate the current vintage file:",
      "  02_programs/misc_scripts/preprocess-manual-data-4.1-and-5.2.10.R",
      "This reads the input/ Excel files and writes the per-year CSVs",
      sprintf("(e.g. %s.%d.csv).", data, end_date),
      call. = FALSE
    )
  }
  base_raw <- readr::read_csv(base_path)

  # --- 1) Read the manual review file ----------------------------------------
  # Versioned by vintage year (D4.1.Manual.Review.<YEAR>.xlsx). The current
  # vintage file is required; historical files are read when present.
  manual_raw <- .read_manual_review(params, review_path = review_path) %>%
    dplyr::select(iso3c, dplyr::all_of(input_var))
  .d41_assert_review_keys(base_raw, manual_raw, input_var)

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
  # The normalized catalogue companion is keyed on iso3c (CLASS.xlsx names
  # plus a recorded crosswalk), so the join does not depend on World Bank API
  # country names.
  cs_df <- cs_df %>%
    dplyr::bind_rows(.read_d41_companion(raw_dir, data, end_date)) %>%
    dplyr::group_by(iso3c, indicator_date) %>%
    dplyr::summarise(
      input_var = dplyr::first(stats::na.omit(input_var)),
        nada_dates = paste(
          unique(nada_dates[!is.na(nada_dates) & nzchar(trimws(nada_dates))]),
          collapse = "; "
        ),
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
        nada_dates = paste(
          unique(nada_dates[!is.na(nada_dates) & nzchar(trimws(nada_dates))]),
          collapse = "; "
        ),
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
combine_censuses_surveys <- function(params, grid, d41_manifest = NULL) {
  review_path <- if (is.null(d41_manifest)) {
    NULL
  } else {
    d41_manifest$review$path
  }

  # Population census
  cs1_df <- census_fun("D4.1.1.CEN.POPU", "POP.CENSUS", params, review_path) %>%
    dplyr::rename(
      RAW.D4.1.1.POPU = input_var,
      SPI.D4.1.1.POPU = indicator
    ) %>%
    dplyr::select(iso3c, date, dplyr::starts_with("SPI"), dplyr::starts_with("RAW"))

  # Agriculture census
  cs2_df <- census_fun("D4.1.2.CEN.AGRI", "AGRI.CENSUS", params, review_path) %>%
    dplyr::rename(
      RAW.D4.1.2.AGRI = input_var,
      SPI.D4.1.2.AGRI = indicator
    ) %>%
    dplyr::select(iso3c, date, dplyr::starts_with("SPI"), dplyr::starts_with("RAW"))

  # Business/establishment census
  cs3_df <- census_fun("D4.1.3.CEN.BIZZ", "BIZZ.CENSUS", params, review_path) %>%
    dplyr::rename(
      RAW.D4.1.3.BIZZ = input_var,
      RAW.D4.1.3.BIZZ.CENSUS_nada = nada_dates,
      SPI.D4.1.3.BIZZ = indicator
    ) %>%
    dplyr::select(iso3c, date, dplyr::starts_with("SPI"), dplyr::starts_with("RAW"))

  # Household survey
  cs4_df <- survey_fun("D4.1.4.SVY.HOUS", "HOUS.SURVEYS", params, review_path) %>%
    dplyr::rename(
      RAW.D4.1.4.HOUS = input_var,
      RAW.D4.1.4.HOUS.SURVEYS_nada = nada_dates,
      SPI.D4.1.4.HOUS = indicator
    ) %>%
    dplyr::select(iso3c, date, dplyr::starts_with("SPI"), dplyr::starts_with("RAW"))

  # Agriculture survey
  cs5_df <- survey_fun("D4.1.5.SVY.AGRI", "AGRI.SURVEYS", params, review_path) %>%
    dplyr::rename(
      RAW.D4.1.5.AGSVY = input_var,
      RAW.D4.1.5.AGRI.SURVEYS_nada = nada_dates,
      SPI.D4.1.5.AGSVY = indicator
    ) %>%
    dplyr::select(iso3c, date, dplyr::starts_with("SPI"), dplyr::starts_with("RAW"))

  # Labor force survey
  cs6_df <- survey_fun("D4.1.6.SVY.LABR", "LABR.SURVEYS", params, review_path) %>%
    dplyr::rename(
      RAW.D4.1.6.LABR = input_var,
      RAW.D4.1.6.LABR.SURVEYS_nada = nada_dates,
      SPI.D4.1.6.LABR = indicator
    ) %>%
    dplyr::select(iso3c, date, dplyr::starts_with("SPI"), dplyr::starts_with("RAW"))

  # Health/Demographic survey
  cs7_df <- survey_fun("D4.1.7.SVY.HLTH", "HLTH.SURVEYS", params, review_path) %>%
    dplyr::rename(
      RAW.D4.1.7.HLTH = input_var,
      RAW.D4.1.7.HLTH.SURVEYS_nada = nada_dates,
      SPI.D4.1.7.HLTH = indicator
    ) %>%
    dplyr::select(iso3c, date, dplyr::starts_with("SPI"), dplyr::starts_with("RAW"))

  # Business/establishment survey
  cs8_df <- survey_fun("D4.1.8.SVY.BIZZ", "BIZZ.SURVEYS", params, review_path) %>%
    dplyr::rename(
      RAW.D4.1.8.BZSVY = input_var,
      RAW.D4.1.8.BIZZ.SURVEYS_nada = nada_dates,
      SPI.D4.1.8.BZSVY = indicator
    ) %>%
    dplyr::select(iso3c, date, dplyr::starts_with("SPI"), dplyr::starts_with("RAW"))

  evidence <- list(
    POPU = cs1_df, AGRI = cs2_df, BIZZ = cs3_df, HOUS = cs4_df,
    AGSVY = cs5_df, LABR = cs6_df, HLTH = cs7_df, BZSVY = cs8_df
  )
  outside <- lapply(evidence, function(data) {
    sort(setdiff(unique(data$iso3c), unique(grid$iso3c)))
  })
  outside <- outside[lengths(outside) > 0L]
  if (length(outside) > 0L) {
    stop(
      "D4.1 EVIDENCE OUTSIDE ESTIMATION COUNTRY UNIVERSE: ",
      paste(
        sprintf("%s=%s", names(outside), vapply(outside, paste, character(1), collapse = ", ")),
        collapse = "; "
      ),
      call. = FALSE
    )
  }

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
#' Mirrors the "geo" chunk. Uses the ODIN data, applies the small-country
#' adjustment, and produces RAW (0-100) and SPI (0-1) admin level scores.
#'
#' @param params List of pipeline parameters.
#' @param odin_data Tibble from read_odin_data() (the same files as D2.2).
#' @return A tibble with iso3c, date, and the GEO columns.
#' @export
score_geospatial <- function(params, odin_data = read_odin_data(params)) {
  # Countries where 1st admin level data is not included (small countries)
  geo_country_list <- c(
    "ADO", "AIA", "ATG", "BHR", "DMA", "HKG", "MAC", "MDV", "MLT", "MHL",
    "FSM", "MCO", "PLW", "STP", "SMR", "SYC", "SGP", "KNA", "LCA", "VCT",
    "TON", "LIE"
  )

  geo_df <- odin_data

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
#' @param odin_data Tibble from read_odin_data().
#' @return A tibble with iso3c, date, and the D4 indicator columns.
#' @export
combine_dim4 <- function(params, grid, d41_manifest = NULL,
                         odin_data = read_odin_data(params)) {
  combine_dim4_parts(
    combine_dim4_core(params, grid, d41_manifest = d41_manifest),
    score_geospatial(params, odin_data),
    grid
  )
}

#' Score the D4 indicators that do not use ODIN (D4.1 and CRVS)
#'
#' @param params List of pipeline parameters.
#' @param grid   The country x year grid.
#' @param d41_manifest Validated D4.1 collection manifest.
#' @return A list with the `cs` (censuses and surveys) and `crvs` tables.
#' @export
combine_dim4_core <- function(params, grid, d41_manifest = NULL) {
  wdi_metadata <- read_wdi_metadata(params)
  list(
    cs = combine_censuses_surveys(params, grid, d41_manifest = d41_manifest),
    crvs = score_crvs(wdi_metadata, params, grid)
  )
}

#' Join the D4 parts onto the grid in the published column order
#'
#' @param core Result of combine_dim4_core().
#' @param geo  Result of score_geospatial().
#' @param grid The country x year grid.
#' @return A tibble with iso3c, date, and the D4 indicator columns.
#' @export
combine_dim4_parts <- function(core, geo, grid) {
  grid %>%
    dplyr::left_join(core$cs, by = c("iso3c", "date")) %>%
    dplyr::left_join(core$crvs, by = c("iso3c", "date")) %>%
    dplyr::left_join(geo)
}

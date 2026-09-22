# =============================================================================
# Append and save logic
# =============================================================================
# Ported from the "append" and "save" chunks of 01-SPI_data_prep.Rmd.
#
# This is the FINAL assembly step of the data prep pipeline. It:
#   1. Selects SPI/RAW columns from all dimensions and joins them onto the
#      full country grid.
#   2. Adds population data (from the World Bank API).
#   3. Carries forward missing SPI values within each country (na.locf).
#   4. Applies the OECD high-income adjustment (sets several indicators to
#      1 for high-income OECD countries).
#   5. Writes the final SPI_data.csv and SPI_data.dta to the staging
#      directory (constraint C7: never overwrite 03_output_data/).
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
# OECD country list
# =============================================================================

#' Get the list of OECD countries (as iso3c codes)
#'
#' The original pipeline fetches this from the World Bank API
#' (region=OED) at runtime and matches by country NAME. Matching by name is
#' fragile: the World Bank API renames countries over time (e.g. NRU was
#' renamed "Nauru" -> "Naoero"), which would silently drop countries from
#' the adjustment. We match by iso3c code instead (the API's `id` field),
#' which is stable across renames.
#'
#' To keep the pipeline reproducible and offline-friendly, we fetch it once
#' and cache it in the staging directory. If the cache exists, it is reused.
#'
#' @param params List of pipeline parameters.
#' @return A character vector of OECD iso3c codes (plus "SGP" for
#'   Singapore, which participates in OECD standards but is not a member).
#' @export
get_oecd_countries <- function(params) {
  # Cache filename is versioned: v1 stored country NAMES, v2 stores iso3c
  # codes. The version bump invalidates any stale v1 cache from earlier
  # runs (a name-based cache would silently break iso3c matching).
  cache_path <- file.path(params$staging_dir, "oecd_countries_v2.rds")

  if (file.exists(cache_path)) {
    return(readr::read_rds(cache_path))
  }

  # Fetch from the World Bank API (region=OED)
  query <- httr::GET(
    url = "https://api.worldbank.org/v2/country?region=OED&format=json",
    timeout = 60
  )
  oecd_country_df <- query %>%
    httr::content(as = "text", encoding = "UTF-8") %>%
    jsonlite::fromJSON(flatten = TRUE)

  # The API's `id` field is the iso3c code (e.g. "AUS"). Match by iso3c,
  # not by name, so the adjustment is robust to World Bank API country
  # renames (e.g. NRU "Nauru" -> "Naoero").
  country_mod_list <- oecd_country_df[[2]]$id
  # Singapore participates in OECD standards but is not an OECD member
  country_mod_list <- c(country_mod_list, "SGP")

  # Fail loudly if the API returned no countries (R8) -- a silent empty
  # list would silently skip the OECD adjustment for every country.
  if (length(country_mod_list) == 0) {
    stop(
      "OECD country list is EMPTY after fetching the World Bank API.\n",
      "The OECD high-income adjustment would be silently skipped.\n",
      "Check the API response (https://api.worldbank.org/v2/country?region=OED&format=json).",
      call. = FALSE
    )
  }

  # Cache for reproducibility
  dir.create(params$staging_dir, recursive = TRUE, showWarnings = FALSE)
  readr::write_rds(country_mod_list, cache_path)

  country_mod_list
}

# =============================================================================
# Population data
# =============================================================================

#' Get population data from the World Bank API
#'
#' Mirrors the "append" chunk's population pull. Fetches SP.POP.TOTL for
#' all countries 2004:end_date.
#'
#' The result is cached in the staging directory (keyed by end_date) so
#' repeated runs within a vintage use the same population snapshot (P2.2).
#' The cache is invalidated when end_date changes.
#'
#' @param params List of pipeline parameters.
#' @return A tibble with iso3c, date, population.
#' @export
get_population <- function(params) {
  cache_path <- file.path(
    params$staging_dir,
    sprintf("population_%d.rds", params$end_date)
  )

  if (file.exists(cache_path)) {
    return(readr::read_rds(cache_path))
  }

  pop_df <- wbstats::wb_data(
    country = "all",
    indicator = "SP.POP.TOTL",
    start_date = 2004,
    end_date = params$end_date
  ) %>%
    dplyr::mutate(
      date = as.numeric(date),
      population = SP.POP.TOTL
    ) %>%
    dplyr::select(iso3c, date, population)

  # Cache for reproducibility within a vintage
  dir.create(params$staging_dir, recursive = TRUE, showWarnings = FALSE)
  readr::write_rds(pop_df, cache_path)

  pop_df
}

# =============================================================================
# Append
# =============================================================================

#' Append all dimensions and apply final adjustments
#'
#' Mirrors the "append" chunk. Joins all dimension outputs onto the grid,
#' adds population, carries forward SPI values, and applies the OECD
#' high-income adjustment.
#'
#' @param dims  A list of dimension tibbles (dim1_5, dim2, dim3, dim4, dim5).
#' @param params List of pipeline parameters.
#' @param grid   The country x year grid.
#' @return The final SPI data frame (SPI + RAW columns + metadata + population).
#' @export
append_spi <- function(dims, params, grid) {
  # --- Combine all dimensions ------------------------------------------------
  spi_df <- grid
  for (dim in dims) {
    spi_df <- spi_df %>%
      dplyr::left_join(dim, by = c("iso3c", "date"))
  }

  # --- Add population --------------------------------------------------------
  pop_df <- get_population(params)

  # Create final dataset
  spi_df_final <- spi_df %>%
    dplyr::select(iso3c, date, dplyr::starts_with("SPI"), dplyr::starts_with("RAW")) %>%
    dplyr::right_join(grid, by = c("iso3c", "date")) %>%
    dplyr::left_join(pop_df, by = c("iso3c", "date")) %>%
    dplyr::arrange(-date, iso3c)

  # --- OECD high-income adjustment -------------------------------------------
  # Match by iso3c (not country name) so the adjustment is robust to World
  # Bank API country renames (e.g. NRU "Nauru" -> "Naoero"). See
  # get_oecd_countries().
  #
  # NOTE (P2.4): the income_level column comes from params$country_metadata
  # (a single live snapshot loaded in config/params.R). This mirrors the
  # original Rmd, which also used the live wb_countries() income levels.
  # The snapshot is consistent within a run; income reclassifications
  # between vintages are documented WB API drift.
  country_mod_list <- get_oecd_countries(params)

  spi_df_final <- spi_df_final %>%
    dplyr::arrange(country, date) %>%
    dplyr::group_by(iso3c) %>%
    dplyr::mutate(dplyr::across(
      dplyr::starts_with("SPI"),
      zoo::na.locf,
      na.rm = FALSE
    )) %>%
    dplyr::mutate(dplyr::across(
      c(
        "SPI.D2.1.GDDS",
        "SPI.D5.1.DILG",
        "SPI.D5.2.3.CNIN",
        "SPI.D5.2.5.HOUS",
        "SPI.D5.2.6.EMPL",
        "SPI.D5.2.8.FINA",
        "SPI.D5.2.10.GSBP",
        "SPI.D5.5.DIFI"
      ),
      ~ dplyr::if_else(
        (income_level == "High income") & (iso3c %in% country_mod_list),
        1,
        .
      )
    )) %>%
    dplyr::ungroup()

  spi_df_final
}

# =============================================================================
# Save
# =============================================================================

#' Save the final SPI data to CSV and Stata
#'
#' Mirrors the "save" chunk. Writes SPI_data.csv and SPI_data.dta to the
#' staging directory (constraint C7: never overwrite 03_output_data/).
#'
#' @param spi_df_final The final SPI data frame from append_spi().
#' @param params       List of pipeline parameters.
#' @return A list with the paths written.
#' @export
save_spi <- function(spi_df_final, params) {
  # --- Write to CSV ----------------------------------------------------------
  csv_path <- file.path(params$staging_dir, "SPI_data.csv")
  spi_df_final %>%
    dplyr::distinct() %>%
    dplyr::mutate(dplyr::across(is.list, as.character)) %>%
    readr::write_csv(csv_path)

  # --- Write to Stata --------------------------------------------------------
  dta_path <- file.path(params$staging_dir, "SPI_data.dta")
  spi_df_final %>%
    dplyr::mutate(dplyr::across(is.list, as.character)) %>%
    dplyr::rename_with(~ gsub(".", "_", .x, fixed = TRUE)) %>%
    dplyr::select(-latitude, -longitude) %>%
    haven::write_dta(dta_path)

  list(csv = csv_path, dta = dta_path)
}
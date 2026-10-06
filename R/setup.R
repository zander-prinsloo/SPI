# =============================================================================
# Pipeline setup: parameters and country grid
# =============================================================================
# Ported from the "set-parameters" and "spi_df" chunks of
# 01-SPI_data_prep.Rmd. These functions build the country x year grid that
# every indicator is joined onto.
#
# Created: 2026-09-21
# =============================================================================

# The pipe operator (%>%) comes from magrittr (loaded via tidyverse in the
# original Rmds). We import it explicitly so this file is self-contained.
`%>%` <- magrittr::`%>%`

#' Load the pipeline parameters
#'
#' Sources config/params.R and returns the parameters as a list, so that
#' targets can track parameter changes as a dependency.
#'
#' @param params_file Character: path to config/params.R (from the
#'   params_file target). Used to create the targets dependency; the file
#'   is sourced regardless.
#' @return A list of pipeline parameters.
#' @export
load_params <- function(params_file = here::here("config", "params.R")) {
  # Source the config file in a clean environment and capture its objects
  env <- new.env(parent = globalenv())
  sys.source(params_file, envir = env)
  country_metadata_path <- file.path(
    env$collection_dir,
    "world_bank",
    "country_metadata.rds"
  )
  if (file.exists(country_metadata_path)) {
    env$country_metadata <- readRDS(country_metadata_path)
  } else {
    env$country_metadata <- data.frame()
  }
  as.list(env, all.names = TRUE)
}

#' Read the UN iso3c country code table
#'
#' Ported from the "set-parameters" chunk. Reads the iso_codes.csv metadata
#' file used for matching country names to iso3c codes.
#'
#' @param params List of pipeline parameters (from load_params()).
#' @return A tibble with country, geoAreaCode, iso3c columns.
#' @export
read_iso_codes <- function(params) {
  file_path <- file.path(params$raw_dir, "metadata", "iso_codes.csv")

  # Schema validation (R8): fail loudly if the file format changes
  read_csv_validated(
    file_path,
    schema = list(
      required_cols = c("country", "geoAreaCode", "iso3c")
    ),
    col_types = list(
      readr::col_character(),
      readr::col_double(),
      readr::col_character()
    )
  )
}

#' Build the empty country x year grid
#'
#' Ported from the "spi_df" chunk. Creates the blank SPI dataset containing
#' one row per country per year (2004:end_date), which indicators are joined
#' onto. Uses params$country_metadata (loaded once in config/params.R) for
#' the country list and drops the regional aggregates.
#'
#' @param params List of pipeline parameters (from load_params()).
#' @return A tibble with one row per country x year.
#' @export
build_country_grid <- function(params) {
  span <- params$span

  # Replicate the country list once per year, then convert the .id column
  # (1, 2, 3, ...) into actual years (2004, 2005, ...).
  # NOTE: uses params$country_metadata (loaded once in config/params.R)
  # instead of calling wb_countries() again -- the metadata is a single
  # live snapshot, so the grid and the append step see the SAME country
  # list (P2.1/P2.12).
  grid <- dplyr::bind_rows(
    replicate(length(span), params$country_metadata, simplify = FALSE),
    .id = "date"
  ) %>%
    dplyr::mutate(date = as.numeric(date) + span[1] - 1) %>%
    # Take out the aggregates (LAC, SAR, etc.)
    dplyr::filter(region != "Aggregates")

  grid
}
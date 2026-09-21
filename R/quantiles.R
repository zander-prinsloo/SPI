# =============================================================================
# SPI quantiles and indicators outputs
# =============================================================================
# Ported from misc_scripts/SPI_quantiles.R.
#
# Produces:
#   1. SPI_quantiles.csv -- SPI index with quintile categories, fragile/
#      conflict classification, and GDP per capita.
#   2. SPI_quantiles_2024.csv -- latest-year quantiles with jitter columns.
#   3. SPI_indicators_2024.csv -- latest-year indicator scores with
#      human-readable pillar names.
#
# Created: 2026-09-22
# =============================================================================

# The pipe operator (%>%) comes from magrittr (loaded via tidyverse in the
# original Rmds). We import it explicitly so this file is self-contained.
`%>%` <- magrittr::`%>%`

# dplyr functions (if_else, case_when, etc.) are used unqualified throughout
# this file, matching the tidyverse style of the original Rmds.
library(dplyr)

# Countries classified as conflict-affected or fragile (from the original
# script). Used for the fragile_conflict column.
.fragile_conflict_list <- list(
  conflict = c(
    "Afghanistan", "Burkina Faso", "Cameroon", "Central African Republic",
    "Congo, Dem. Rep.", "Ethiopia", "Iraq", "Mali", "Mozambique", "Myanmar",
    "Niger", "Nigeria", "Somalia", "South Sudan", "Sudan",
    "Syrian Arab Republic", "Ukraine", "West Bank and Gaza", "Yemen, Rep."
  ),
  institutional = c(
    "Burundi", "Chad", "Comoros", "Congo, Rep.", "Eritrea", "Guinea-Bissau",
    "Haiti", "Kiribati", "Kosovo", "Lebanon", "Libya", "Marshall Islands",
    "Micronesia, Fed. Sts.", "Papua New Guinea", "Sao Tome and Principe",
    "Solomon Islands", "Timor-Leste", "Tuvalu", "Venezuela, RB", "Zimbabwe"
  )
)

#' Build the SPI quantiles dataset
#'
#' Mirrors misc_scripts/SPI_quantiles.R. Adds the fragile/conflict
#' classification, GDP per capita, and quintile categories for the index
#' and pillar scores.
#'
#' NOTE: the original script reads SPI_index.csv from disk
#' (`read_csv(paste0(dir, "/03_output_data/SPI_index.csv"))`). We mirror
#' that CSV round-trip by reading the staged SPI_index.csv, because the
#' round-trip changes binary representations at the 15th significant digit
#' and this flips boundary rounding (e.g. Tanzania PIL4 = 52.95 rounds to
#' 53 from the CSV value but 52.9 from the in-memory value). Reading the
#' CSV is required for exact replication.
#'
#' @param spi_index The index data frame from build_index(). Retained only
#'   to create the targets dependency (the index target must run first so
#'   staging/SPI_index.csv exists); the values come from the staged CSV to
#'   mirror the original script.
#' @param params    List of pipeline parameters.
#' @return A tibble with country, region, income, fragile_conflict, iso3c,
#'   date, SPI.INDEX*, quintile columns, population, GDP per capita.
#' @export
build_quantiles <- function(spi_index, params) {
  # Mirror the original script: read the saved index CSV (CSV round-trip).
  # The in-memory spi_index argument is unused for the values -- the
  # original script read SPI_index.csv from disk, and the round-trip
  # changes binary representations at the 15th significant digit, which
  # flips boundary rounding (e.g. Tanzania PIL4 = 52.95 rounds to 53 from
  # the CSV value but 52.9 from the in-memory value).
  SPI <- readr::read_csv(file.path(params$staging_dir, "SPI_index.csv"), show_col_types = FALSE) %>%
    dplyr::mutate(
      fragile_conflict = dplyr::case_when(
        country %in% .fragile_conflict_list$conflict ~ "Conflict",
        country %in% .fragile_conflict_list$institutional ~ "Institutional and Social Fragility",
        TRUE ~ "Other"
      )
    )

  # Add GDP per capita from the World Bank
  gdp_df <- wbstats::wb_data(
    indicator = "NY.GDP.PCAP.PP.KD",
    start_date = 2004,
    end_date = params$end_date
  )

  # Add quintiles of SPI.INDEX and pillar scores as categorical variables
  SPI_quantiles <- SPI %>%
    dplyr::filter(date > 2015) %>%
    dplyr::group_by(date) %>%
    dplyr::mutate(
      SPI.INDEX.quintile = cut(
        SPI.INDEX,
        quantile(SPI.INDEX, probs = c(0, 0.2, 0.4, 0.6, 0.8, 1), na.rm = TRUE),
        right = FALSE, include.lowest = TRUE,
        labels = c("Bottom 20%", "2nd Quintile", "3rd Quintile", "4th Quintile", "Top Quintile")
      ),
      SPI.INDEX.PIL1.quintile = cut(
        SPI.INDEX.PIL1,
        breaks = c(0, 60, 80, 85, 90, 100),
        right = FALSE, include.lowest = TRUE,
        labels = c("Bottom 20%", "2nd Quintile", "3rd Quintile", "4th Quintile", "Top Quintile")
      ),
      SPI.INDEX.PIL2.quintile = cut(
        SPI.INDEX.PIL2,
        quantile(SPI.INDEX.PIL2, probs = c(0, 1, 2, 3, 4, 5) / 5, na.rm = TRUE),
        right = FALSE, include.lowest = TRUE,
        labels = c("Bottom 20%", "2nd Quintile", "3rd Quintile", "4th Quintile", "Top Quintile")
      ),
      SPI.INDEX.PIL3.quintile = cut(
        SPI.INDEX.PIL3,
        quantile(SPI.INDEX.PIL3, probs = c(0, 1, 2, 3, 4, 5) / 5, na.rm = TRUE),
        right = FALSE, include.lowest = TRUE,
        labels = c("Bottom 20%", "2nd Quintile", "3rd Quintile", "4th Quintile", "Top Quintile")
      ),
      SPI.INDEX.PIL4.quintile = cut(
        SPI.INDEX.PIL4,
        quantile(SPI.INDEX.PIL4, probs = c(0, 1, 2, 3, 4, 5) / 5, na.rm = TRUE),
        right = FALSE, include.lowest = TRUE,
        labels = c("Bottom 20%", "2nd Quintile", "3rd Quintile", "4th Quintile", "Top Quintile")
      ),
      SPI.INDEX.PIL5.quintile = cut(
        SPI.INDEX.PIL5,
        quantile(SPI.INDEX.PIL5, probs = c(0, 1, 2, 3, 4, 5) / 5, na.rm = TRUE),
        right = FALSE, include.lowest = TRUE,
        labels = c("Bottom 20%", "2nd Quintile", "3rd Quintile", "4th Quintile", "Top Quintile")
      )
    ) %>%
    dplyr::select(country, region, income, fragile_conflict, iso3c, date,
      dplyr::starts_with("SPI.INDEX"), population
    ) %>%
    # Default join (no `by`): gdp_df shares country/iso2c/iso3c/date with
    # the SPI data, so the shared columns are used as join keys (matching
    # values) instead of creating .x/.y suffixes.
    dplyr::left_join(gdp_df) %>%
    dplyr::ungroup()

  SPI_quantiles
}

#' Build the latest-year quantiles and indicators outputs
#'
#' Mirrors the tail of misc_scripts/SPI_quantiles.R. Produces the
#' SPI_quantiles_2024.csv (with jitter columns) and SPI_indicators_2024.csv
#' (with human-readable pillar names).
#'
#' @param spi_index The index data frame from build_index(). Retained only
#'   to create the targets dependency; the values come from the staged CSV
#'   (see build_quantiles()).
#' @param quantiles The quantiles data frame from build_quantiles().
#' @param params    List of pipeline parameters.
#' @return A list with `quantiles_2024` and `indicators_2024`.
#' @export
build_quantiles_2024 <- function(spi_index, quantiles, params) {
  end_date <- params$end_date

  SPI_quantiles_2024 <- quantiles %>%
    dplyr::filter(date == end_date) %>%
    dplyr::mutate(dplyr::across(is.numeric, round, 1))

  SPI_quantiles_2024 <- SPI_quantiles_2024 %>%
    dplyr::mutate(
      `No Group` = 1,
      jitter_y = rnorm(nrow(SPI_quantiles_2024), sd = 0.1),
      jitter_x = rnorm(nrow(SPI_quantiles_2024), sd = 0.1)
    )

  # SPI Indicators data (latest year, human-readable pillar names)
  # NOTE: the original script writes the full SPI index (which includes
  # fragile_conflict from the quantiles step) with renamed pillar columns.
  # It reads SPI_index.csv from disk, so we mirror that CSV round-trip.
  indicators_2024 <- readr::read_csv(file.path(params$staging_dir, "SPI_index.csv"), show_col_types = FALSE) %>%
    dplyr::mutate(
      fragile_conflict = dplyr::case_when(
        country %in% .fragile_conflict_list$conflict ~ "Conflict",
        country %in% .fragile_conflict_list$institutional ~ "Institutional and Social Fragility",
        TRUE ~ "Other"
      )
    ) %>%
    dplyr::rename(
      `Data Use Score` = SPI.INDEX.PIL1,
      `Data Services Score` = SPI.INDEX.PIL2,
      `Data Products Score` = SPI.INDEX.PIL3,
      `Data Sources Score` = SPI.INDEX.PIL4,
      `Data Infrastructure Score` = SPI.INDEX.PIL5,
      `SPI Overall Score` = SPI.INDEX
    )

  list(
    quantiles_2024 = SPI_quantiles_2024,
    indicators_2024 = indicators_2024
  )
}

#' Save the quantiles and indicators outputs
#'
#' Writes SPI_quantiles.csv, SPI_quantiles_2024.csv, and
#' SPI_indicators_2024.csv to the staging directory (constraint C7).
#'
#' @param quantiles      The quantiles data frame.
#' @param quantiles_2024 The latest-year quantiles data frame.
#' @param indicators_2024 The latest-year indicators data frame.
#' @param params         List of pipeline parameters.
#' @return A list of paths written.
#' @export
save_quantiles <- function(quantiles, quantiles_2024, indicators_2024, params) {
  paths <- c(
    file.path(params$staging_dir, "SPI_quantiles.csv"),
    file.path(params$staging_dir, "SPI_quantiles_2024.csv"),
    file.path(params$staging_dir, "SPI_indicators_2024.csv")
  )
  readr::write_csv(quantiles, paths[1])
  readr::write_csv(quantiles_2024, paths[2])
  readr::write_csv(indicators_2024, paths[3])
  paths
}
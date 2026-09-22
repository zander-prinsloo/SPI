# =============================================================================
# SPI Index construction
# =============================================================================
# Ported from the "data", "index_weights", "index", and "saver" chunks of
# 02-SPI_index.Rmd.
#
# The SPI overall score is a nested index:
#   indicators -> dimension indices -> pillar indices -> SPI.INDEX
# Weights are unity (wgt = 1) for the 202511 vintage.
#
# Sentinel convention (P2.28): SPI.DIM5.1.INDEX and SPI.DIM5.5.INDEX use
# -99 as a sentinel for "no data" (the D5.1 legislation and D5.5 finance
# dimensions are not part of the index). The -99 value is set BEFORE the
# pillar aggregation so those dimensions contribute 0 to the overall
# index. This mirrors the original Rmd exactly.
#
# Created: 2026-09-22
# =============================================================================

# The pipe operator (%>%) comes from magrittr (loaded via tidyverse in the
# original Rmds). We import it explicitly so this file is self-contained.
`%>%` <- magrittr::`%>%`

# dplyr functions (if_else, case_when, etc.) are used unqualified throughout
# this file, matching the tidyverse style of the original Rmds.
library(dplyr)

# =============================================================================
# Index weights
# =============================================================================
# These mirror the "index_weights" chunk exactly. The weights are unity
# (1/5 per pillar, equal weights within pillars) for the 202511 vintage.

#' Load the index weights
#'
#' Mirrors the "index_weights" chunk. Returns a list of pillar and dimension
#' weights used to build the nested index.
#'
#' @return A list of weights.
#' @export
load_index_weights <- function() {
  list(
    # Pillar 1 - Overall Weight
    pillar_1 = 1 / 5,
    # Dimension 1.5: Data Use by International Organizations
    dim_1_5 = 1,

    # Pillar 2 - Overall Weight
    pillar_2 = 1 / 5,
    # Dimension 2.1: Data releases
    dim_2_1 = 1 / 3,
    # Dimension 2.2: Online access
    dim_2_2 = 1 / 3,
    # Dimension 2.4: Data services
    dim_2_4 = 1 / 3,

    # Pillar 3 - Overall Weight
    pillar_3 = 1 / 5,
    # Dimension 3: SDG goals (16 indicators, equal weight)
    dim_3_1 = 1 / 16,
    dim_3_2 = 1 / 16,
    dim_3_3 = 1 / 16,
    dim_3_4 = 1 / 16,
    dim_3_5 = 1 / 16,
    dim_3_6 = 1 / 16,
    dim_3_7 = 1 / 16,
    dim_3_8 = 1 / 16,
    dim_3_9 = 1 / 16,
    dim_3_10 = 1 / 16,
    dim_3_11 = 1 / 16,
    dim_3_12 = 1 / 16,
    dim_3_13 = 1 / 16,
    dim_3_15 = 1 / 16,
    dim_3_16 = 1 / 16,
    dim_3_17 = 1 / 16,

    # Pillar 4 - Overall Weight
    pillar_4 = 1 / 5,
    # Dimension 4.1: censuses and surveys
    dim_4_1.CEN = 1 / 4,
    dim_4_1.SVY = 1 / 4,
    # Dimension 4.2: administrative data
    dim_4_2 = 1 / 4,
    # Dimension 4.3: geospatial data
    dim_4_3 = 1 / 4,

    # Pillar 5 - Overall Weight
    pillar_5 = 1 / 5,
    # Dimension 5.1: legislation (not in index)
    dim_5_1 = 0,
    # Dimension 5.2: Standards and Methods
    dim_5_2 = 1,
    # Dimension 5.5: finance (not in index)
    dim_5_5 = 0
  )
}

# =============================================================================
# Index construction
# =============================================================================

#' Build the SPI index
#'
#' Mirrors the "data" and "index" chunks. Reads the final SPI data, adds
#' population weights, carries forward missing values, and builds the nested
#' index (dimension -> pillar -> overall).
#'
#' NOTE: the original 02-SPI_index.Rmd reads SPI_data.csv from DISK
#' (line 129). We mirror that CSV round-trip: the staged SPI_data.csv is
#' deduplicated by save_spi() (dplyr::distinct()), so reading the CSV
#' guarantees the same row set the vintage used. The in-memory spi_data
#' target may contain duplicate rows from the append joins.
#'
#' @param spi_data The final SPI data frame (from append_spi()). Retained
#'   only to create the targets dependency; the values come from the
#'   staged CSV.
#' @param params   List of pipeline parameters.
#' @return A tibble with country, iso3c, date, SPI.INDEX.*, SPI.DIM*.*,
#'   the SPI indicators, income, region, weights, population.
#' @export
build_index <- function(spi_data, params) {
  wgt <- params$wgt
  end_date <- params$end_date

  # --- Read the staged SPI_data.csv (CSV round-trip, mirrors the Rmd) -------
  spi_data <- readr::read_csv(file.path(params$staging_dir, "SPI_data.csv"))

  # --- Add population and weights (from the "data" chunk) --------------------
  # NOTE: default join (no `by`) so that the shared `population` column is
  # used as a join key (matching values) instead of creating .x/.y suffixes.
  pop_df <- get_population(params)

  spi_df_final <- spi_data %>%
    dplyr::left_join(pop_df) %>%
    dplyr::group_by(iso3c) %>%
    dplyr::arrange(dplyr::desc(date)) %>%
    tidyr::fill(population, .direction = "downup") %>%
    dplyr::mutate(
      wgt = wgt,
      weights = dplyr::if_else(wgt == 2, population, 1)
    ) %>%
    # Default join (no `by`): spi_data already carries the country metadata
    # columns, so the shared columns (income_level, region, etc.) are used
    # as join keys (matching values) instead of creating .x/.y suffixes.
    dplyr::left_join(params$country_metadata) %>%
    dplyr::mutate(income = income_level) %>%
    dplyr::ungroup()

  # --- Create index dataset (from the "index" chunk) -------------------------
  spi_index_df_temp <- spi_df_final %>%
    dplyr::select(country, iso3c, date, dplyr::starts_with("SPI"), income, region, weights, population) %>%
    dplyr::arrange(-date, country)

  # Drop certain indicators that don't make the cut because of incomplete
  # coverage. Some countries report data at 2nd admin level but not first;
  # give credit if they report at a geographic level lower than 1st admin.
  spi_index_df_temp <- spi_index_df_temp %>%
    dplyr::mutate(
      SPI.D4.3.GEO.first.admin.level = dplyr::if_else(
        SPI.D4.3.GEO.first.admin.level < SPI.D4.3.GEO.second.admin.level,
        SPI.D4.3.GEO.second.admin.level,
        SPI.D4.3.GEO.first.admin.level
      )
    ) %>%
    dplyr::select(-SPI.D4.3.GEO.second.admin.level)

  # --- Nested index ----------------------------------------------------------
  spi_index_df <- spi_index_df_temp %>%
    dplyr::arrange(country, date) %>%
    dplyr::group_by(country) %>%
    dplyr::mutate(dplyr::across(dplyr::starts_with("SPI"), zoo::na.locf, na.rm = FALSE)) %>%
    dplyr::select(country, iso3c, date, dplyr::everything()) %>%
    dplyr::ungroup()

  # Recalculate index based on the weights
  w <- load_index_weights()
  pillar_total <- w$pillar_1 + w$pillar_2 + w$pillar_3 + w$pillar_4 + w$pillar_5
  pillar2_total <- w$dim_2_1 + w$dim_2_2 + w$dim_2_4
  pillar3_total <- w$dim_3_1 + w$dim_3_2 + w$dim_3_3 + w$dim_3_4 + w$dim_3_5 +
    w$dim_3_6 + w$dim_3_7 + w$dim_3_8 + w$dim_3_9 + w$dim_3_10 + w$dim_3_11 +
    w$dim_3_12 + w$dim_3_13 + w$dim_3_15 + w$dim_3_16 + w$dim_3_17
  pillar4_total <- w$dim_4_1.CEN + w$dim_4_1.SVY + w$dim_4_2 + w$dim_4_3
  pillar5_total <- w$dim_5_1 + w$dim_5_2 + w$dim_5_5

  spi_index_df <- spi_index_df %>%
    dplyr::mutate(
      SPI.DIM1.5.INDEX = rowMeans(dplyr::across(dplyr::starts_with("SPI.D1.5")), na.rm = FALSE),
      SPI.DIM2.1.INDEX = rowMeans(dplyr::across(dplyr::starts_with("SPI.D2.1"))),
      SPI.DIM2.2.INDEX = SPI.D2.2.Openness.subscore,
      SPI.DIM2.4.INDEX = SPI.D2.4.NADA,
      SPI.DIM3.1.INDEX = rowMeans(dplyr::across(c(
        "SPI.D3.1.POV", "SPI.D3.2.HNGR", "SPI.D3.3.HLTH", "SPI.D3.4.EDUC",
        "SPI.D3.5.GEND", "SPI.D3.6.WTRS"
      ))),
      SPI.DIM3.2.INDEX = rowMeans(dplyr::across(c(
        "SPI.D3.7.ENRG", "SPI.D3.8.WORK", "SPI.D3.9.INDY", "SPI.D3.10.NEQL",
        "SPI.D3.11.CITY", "SPI.D3.12.CNSP"
      ))),
      SPI.DIM3.3.INDEX = rowMeans(dplyr::across(c(
        "SPI.D3.13.CLMT", "SPI.D3.15.LAND"
      ))),
      SPI.DIM3.4.INDEX = rowMeans(dplyr::across(c(
        "SPI.D3.16.INST", "SPI.D3.17.PTNS"
      ))),
      SPI.DIM4.1.CEN.INDEX = rowMeans(dplyr::across(c(
        "SPI.D4.1.1.POPU", "SPI.D4.1.2.AGRI", "SPI.D4.1.3.BIZZ"
      ))),
      SPI.DIM4.1.SVY.INDEX = rowMeans(dplyr::across(c(
        "SPI.D4.1.4.HOUS", "SPI.D4.1.5.AGSVY", "SPI.D4.1.6.LABR",
        "SPI.D4.1.7.HLTH", "SPI.D4.1.8.BZSVY"
      ))),
      SPI.DIM4.2.INDEX = rowMeans(dplyr::across(dplyr::starts_with("SPI.D4.2"))),
      SPI.DIM4.3.INDEX = rowMeans(dplyr::across(dplyr::starts_with("SPI.D4.3"))),
      SPI.DIM5.1.INDEX = rowMeans(dplyr::across(dplyr::starts_with("SPI.D5.1"))),
      SPI.DIM5.1.INDEX = dplyr::if_else(is.na(SPI.DIM5.1.INDEX), -99, SPI.DIM5.1.INDEX),
      SPI.DIM5.2.INDEX = rowMeans(dplyr::across(dplyr::starts_with("SPI.D5.2"))),
      SPI.DIM5.5.INDEX = rowMeans(dplyr::across(dplyr::starts_with("SPI.D5.5"))),
      SPI.DIM5.5.INDEX = dplyr::if_else(is.na(SPI.DIM5.5.INDEX), -99, SPI.DIM5.5.INDEX)
    ) %>%
    dplyr::mutate(
      SPI.INDEX.PIL1 = SPI.DIM1.5.INDEX,
      SPI.INDEX.PIL2 = (
        (w$dim_2_1 / pillar2_total) * SPI.DIM2.1.INDEX +
          (w$dim_2_2 / pillar2_total) * SPI.DIM2.2.INDEX +
          (w$dim_2_4 / pillar2_total) * SPI.DIM2.4.INDEX
      ),
      SPI.INDEX.PIL3 = (
        (w$dim_3_1 / pillar3_total) * SPI.D3.1.POV +
          (w$dim_3_2 / pillar3_total) * SPI.D3.2.HNGR +
          (w$dim_3_3 / pillar3_total) * SPI.D3.3.HLTH +
          (w$dim_3_4 / pillar3_total) * SPI.D3.4.EDUC +
          (w$dim_3_5 / pillar3_total) * SPI.D3.5.GEND +
          (w$dim_3_6 / pillar3_total) * SPI.D3.6.WTRS +
          (w$dim_3_7 / pillar3_total) * SPI.D3.7.ENRG +
          (w$dim_3_8 / pillar3_total) * SPI.D3.8.WORK +
          (w$dim_3_9 / pillar3_total) * SPI.D3.9.INDY +
          (w$dim_3_10 / pillar3_total) * SPI.D3.10.NEQL +
          (w$dim_3_11 / pillar3_total) * SPI.D3.11.CITY +
          (w$dim_3_12 / pillar3_total) * SPI.D3.12.CNSP +
          (w$dim_3_13 / pillar3_total) * SPI.D3.13.CLMT +
          (w$dim_3_15 / pillar3_total) * SPI.D3.15.LAND +
          (w$dim_3_16 / pillar3_total) * SPI.D3.16.INST +
          (w$dim_3_17 / pillar3_total) * SPI.D3.17.PTNS
      ),
      SPI.INDEX.PIL4 = (
        (w$dim_4_1.CEN / pillar4_total) * SPI.DIM4.1.CEN.INDEX +
          (w$dim_4_1.SVY / pillar4_total) * SPI.DIM4.1.SVY.INDEX +
          (w$dim_4_2 / pillar4_total) * SPI.DIM4.2.INDEX +
          (w$dim_4_3 / pillar4_total) * SPI.DIM4.3.INDEX
      ),
      SPI.INDEX.PIL5 = (
        (w$dim_5_1 / pillar5_total) * SPI.DIM5.1.INDEX +
          (w$dim_5_2 / pillar5_total) * SPI.DIM5.2.INDEX +
          (w$dim_5_5 / pillar5_total) * SPI.DIM5.5.INDEX
      ),
      SPI.INDEX = (w$pillar_1 / pillar_total) * SPI.INDEX.PIL1 +
        (w$pillar_2 / pillar_total) * SPI.INDEX.PIL2 +
        (w$pillar_3 / pillar_total) * SPI.INDEX.PIL3 +
        (w$pillar_4 / pillar_total) * SPI.INDEX.PIL4 +
        (w$pillar_5 / pillar_total) * SPI.INDEX.PIL5
    ) %>%
    dplyr::mutate(dplyr::across(dplyr::starts_with("SPI.INDEX"), ~ 100 * .)) %>%
    dplyr::arrange(-date, -SPI.INDEX) %>%
    dplyr::select(country, iso3c, date, dplyr::starts_with("SPI.INDEX"), dplyr::starts_with("SPI.DIM"), dplyr::everything())

  spi_index_df
}

# =============================================================================
# Save the index
# =============================================================================

#' Save the SPI index to CSV
#'
#' Mirrors the "saver" chunk. Writes SPI_index.csv to the staging directory
#' (constraint C7: never overwrite 03_output_data/).
#'
#' @param spi_index_df The index data frame from build_index().
#' @param params       List of pipeline parameters.
#' @return The path written.
#' @export
save_index <- function(spi_index_df, params) {
  csv_path <- file.path(params$staging_dir, "SPI_index.csv")
  readr::write_csv(spi_index_df, csv_path)
  csv_path
}
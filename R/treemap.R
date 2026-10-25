# =============================================================================
# SPI treemap output
# =============================================================================
# Ported from misc_scripts/SPI_treemap.R.
#
# Produces SPI_treemap.csv -- the dimension scores for the latest year with
# pillar classification, colors, and scaled scores for the treemap chart.
#
# Created: 2026-09-22
# =============================================================================

# The pipe operator (%>%) comes from magrittr (loaded via tidyverse in the
# original Rmds). We import it explicitly so this file is self-contained.
`%>%` <- magrittr::`%>%`

# dplyr functions (if_else, case_when, etc.) are used unqualified throughout
# this file, matching the tidyverse style of the original Rmds.
library(dplyr)

#' Build the treemap dataset
#'
#' Mirrors misc_scripts/SPI_treemap.R. Takes the latest-year dimension
#' scores, joins the card metadata, and computes pillar-scaled scores.
#'
#' NOTE: the original script reads SPI_index.csv from disk
#' (`read_csv(paste0(output_dir,'/SPI_index.csv'))`). We mirror that CSV
#' round-trip by reading the candidate SPI_index.csv, because the round-trip
#' changes binary representations at the 15th significant digit and this
#' flips boundary rounding. Reading the CSV is required for exact
#' replication.
#'
#' @param spi_index The index data frame from build_index(). Retained only
#'   to create the targets dependency (the index target must run first so
#'   candidate SPI_index.csv exists); values come from that written CSV.
#' @param params    List of pipeline parameters.
#' @return A tibble with country, source_id, value, descript,
#'   spi_indicator_description, spi_indicator_scoring, Pillar, color, max,
#'   Score.
#' @export
build_treemap <- function(spi_index, params) {
  # Mirror the original script: read the saved index CSV (CSV round-trip).
  SPI <- readr::read_csv(file.path(params$estimation_write_dir, "SPI_index.csv"), show_col_types = FALSE)

  metadata_card <- readr::read_csv(file.path(params$raw_dir, "metadata", "SPI_card_sources.csv")) %>%
    dplyr::mutate(
      Pillar = dplyr::case_when(
        grepl("Dimension 1", descript) ~ "Pillar 1: Data Use",
        grepl("Dimension 2", descript) ~ "Pillar 2: Data Services",
        grepl("Dimension 3", descript) ~ "Pillar 3: Data Products",
        grepl("Dimension 4", descript) ~ "Pillar 4: Data Sources",
        grepl("Dimension 5", descript) ~ "Pillar 5: Data Infrastructure"
      )
    )

  treemap_df <- SPI %>%
    dplyr::filter(date == max(date)) %>%
    dplyr::select(country, dplyr::starts_with("SPI.DIM")) %>%
    tidyr::pivot_longer(
      cols = dplyr::starts_with("SPI.DIM"),
      names_to = "source_id",
      values_to = "value"
    )

  treemap_df <- treemap_df %>%
    dplyr::mutate(
      value = dplyr::if_else(value == -99, as.numeric(NA), value),
      value = dplyr::case_when(
        source_id == "SPI.DIM5.1.INDEX" ~ as.numeric(NA),
        source_id == "SPI.DIM5.5.INDEX" ~ as.numeric(NA),
        TRUE ~ value
      )
    ) %>%
    dplyr::right_join(metadata_card, by = "source_id") %>%
    dplyr::mutate(
      color = dplyr::case_when(
        value == 0 ~ "#E63946",
        value > 0 & value < 1 ~ "#FDE74C",
        value == 1 ~ "#457B9D",
        TRUE ~ "gray"
      ),
      max = 1
    ) %>%
    dplyr::arrange(descript) %>%
    dplyr::mutate(
      Score = dplyr::case_when(
        Pillar == "Pillar 1: Data Use" ~ 100 * value,
        Pillar == "Pillar 2: Data Services" ~ 100 * value / 3,
        Pillar == "Pillar 3: Data Products" ~ 100 * value / 4,
        Pillar == "Pillar 4: Data Sources" ~ 100 * value / 4,
        Pillar == "Pillar 5: Data Infrastructure" ~ 100 * value
      )
    ) %>%
    dplyr::filter(!is.na(value))

  treemap_df
}

#' Save the treemap output
#'
#' Writes SPI_treemap.csv to the candidate directory before set validation.
#'
#' @param treemap_df The treemap data frame from build_treemap().
#' @param params     List of pipeline parameters.
#' @return The path written.
#' @export
save_treemap <- function(treemap_df, params) {
  path <- file.path(params$estimation_write_dir, "SPI_treemap.csv")
  write_output_csv(treemap_df, path)
  path
}
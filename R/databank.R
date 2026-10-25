# =============================================================================
# SPI databank outputs
# =============================================================================
# Ported from misc_scripts/databank.R.
#
# Produces:
#   1. SPI_databank_country_and_aggregates.csv -- long format with country
#      data and group aggregates.
#   2. SPI_databank_country_and_aggregates_DCS.csv -- DCS format (Time,
#      Country, Series, SCALE, Data).
#   3. SPI_databank_country_and_aggregates_DCS_wide.csv -- DCS wide format.
#   4. SPI_databank_footnotes.csv -- footnotes for each series.
#
# Created: 2026-09-22
# =============================================================================

# The pipe operator (%>%) comes from magrittr (loaded via tidyverse in the
# original Rmds). We import it explicitly so this file is self-contained.
`%>%` <- magrittr::`%>%`

# dplyr functions (if_else, case_when, etc.) are used unqualified throughout
# this file, matching the tidyverse style of the original Rmds.
library(dplyr)

#' Read the World Bank country classifications
#'
#' Reads the CLASS.xlsx "Groups" sheet (country-to-group membership).
#'
#' @param params List of pipeline parameters.
#' @return A tibble with iso3c, country, WB_Group_Code, WB_Group_Name.
#' @export
read_classifications <- function(params) {
  classifications <- readxl::read_excel(
    path = file.path(params$raw_dir, "misc", "CLASS.xlsx"),
    sheet = "Groups"
  ) %>%
    dplyr::rename(
      iso3c = CountryCode,
      country = CountryName,
      WB_Group_Code = GroupCode,
      WB_Group_Name = GroupName
    )
  conflicting <- classifications %>%
    dplyr::group_by(iso3c, WB_Group_Code) %>%
    dplyr::summarise(n_names = dplyr::n_distinct(WB_Group_Name), .groups = "drop") %>%
    dplyr::filter(n_names > 1L)
  if (nrow(conflicting) > 0L) {
    stop(
      "CLASS HAS CONFLICTING GROUP NAMES FOR COUNTRY/GROUP KEYS: ",
      paste(
        paste(conflicting$iso3c, conflicting$WB_Group_Code, sep = "/"),
        collapse = ", "
      ),
      call. = FALSE
    )
  }
  dplyr::distinct(
    classifications,
    iso3c,
    country,
    WB_Group_Code,
    WB_Group_Name
  )
}

#' Group aggregates of the databank series (unweighted means)
#'
#' Members are summed in iso3c order. SPI_index.csv is sorted by the overall
#' score, and a mean that falls on a rounding boundary (for example 0.455)
#' rounds up or down depending on the summation order, so without a fixed
#' order any change that reorders countries (the December ODIN update) would
#' move the aggregates of unrelated series and block the release diff.
#'
#' @param databank_df Long country data (iso3c, date, source_id,
#'   source_name, value).
#' @param class_df World Bank group membership from read_classifications().
#' @return One row per group, year and series with N, N_obs and the mean
#'   rounded to two decimals.
#' @export
aggregate_databank <- function(databank_df, class_df) {
  duplicate_memberships <- class_df %>%
    dplyr::count(iso3c, WB_Group_Code, WB_Group_Name, name = "membership_rows") %>%
    dplyr::filter(membership_rows > 1L)
  if (nrow(duplicate_memberships) > 0L) {
    class_df <- class_df %>%
      dplyr::distinct(iso3c, country, WB_Group_Code, WB_Group_Name)
  }
  conflicting <- class_df %>%
    dplyr::group_by(iso3c, WB_Group_Code) %>%
    dplyr::summarise(n_names = dplyr::n_distinct(WB_Group_Name), .groups = "drop") %>%
    dplyr::filter(n_names > 1L)
  if (nrow(conflicting) > 0L) {
    stop(
      "CLASS HAS CONFLICTING GROUP NAMES FOR COUNTRY/GROUP KEYS: ",
      paste(paste(conflicting$iso3c, conflicting$WB_Group_Code, sep = "/"), collapse = ", "),
      call. = FALSE
    )
  }
  databank_df %>%
    dplyr::left_join(class_df %>% dplyr::select(-country), by = "iso3c", relationship = "many-to-many") %>%
    dplyr::arrange(iso3c) %>%
    dplyr::group_by(WB_Group_Code, WB_Group_Name, date, source_id, source_name) %>%
    dplyr::summarise(
      N = dplyr::n(),
      N_obs = sum(!is.na(value)),
      value = round(mean(value, na.rm = TRUE), 2),
      .groups = "drop"
    ) %>%
    dplyr::ungroup() %>%
    dplyr::filter(!is.na(WB_Group_Name))
}

#' Build the databank dataset
#'
#' Mirrors misc_scripts/databank.R. Reshapes the SPI index to long format,
#' joins series metadata and footnotes, and appends group aggregates.
#'
#' NOTE: the original script reads SPI_index.csv from disk
#' (`read_csv(paste(output_dir, '/SPI_index.csv', sep=""))`). We mirror
#' that CSV round-trip by reading the staged SPI_index.csv, because the
#' round-trip changes binary representations at the 15th significant digit
#' and this flips boundary rounding in the aggregate means. Reading the CSV
#' is required for exact replication.
#'
#' @param spi_index The index data frame from build_index(). Retained only
#'   to create the targets dependency (the index target must run first so
#'   staging/SPI_index.csv exists); the values come from the staged CSV.
#' @param spi_data  The final SPI data frame (for RAW footnotes).
#' @param params    List of pipeline parameters.
#' @return A tibble with iso3c, country, date, source_id, source_name, N,
#'   N_obs, value, footnote.
#' @export
build_databank <- function(spi_index, spi_data, params) {
  # Mirror the original script: read the saved index CSV (CSV round-trip).
  SPI <- readr::read_csv(file.path(params$estimation_write_dir, "SPI_index.csv"), show_col_types = FALSE)

  # --- Series metadata -------------------------------------------------------
  metadata <- readr::read_csv(file.path(params$raw_dir, "metadata", "SPI_dimensions_sources.csv"))
  metadata_full <- readr::read_csv(file.path(params$raw_dir, "metadata", "SPI_index_sources.csv")) %>%
    dplyr::rename(source_name = descript) %>%
    dplyr::bind_rows(metadata)

  # --- Country classifications ----------------------------------------------
  class_df <- read_classifications(params)

  # --- Footnotes from RAW data ----------------------------------------------
  # NOTE: read the staged SPI_data.csv (deduplicated by save_spi) rather
  # than the in-memory spi_data target, which may contain duplicate rows
  # from the append joins. The original script reads SPI_data.csv from
  # disk, so this mirrors the CSV round-trip.
  spi_raw <- readr::read_csv(file.path(params$estimation_write_dir, "SPI_data.csv"), show_col_types = FALSE) %>%
    dplyr::select(country, iso3c, date, dplyr::starts_with("RAW")) %>%
    dplyr::select(-dplyr::ends_with("_text"), -dplyr::ends_with("_nada"))

  spi_footnote <- spi_raw %>%
    dplyr::mutate(dplyr::across(dplyr::starts_with("RAW"), as.character)) %>%
    tidyr::pivot_longer(
      cols = dplyr::matches("RAW"),
      names_to = "source_id",
      values_to = "footnote"
    ) %>%
    dplyr::mutate(source_id = stringr::str_replace(source_id, "RAW", "SPI")) %>%
    dplyr::select(country, iso3c, date, source_id, footnote)

  # --- Reshape to long format ------------------------------------------------
  databank_df <- SPI %>%
    tidyr::pivot_longer(
      cols = dplyr::matches("SPI"),
      names_to = "source_id",
      values_to = "value"
    ) %>%
    dplyr::left_join(metadata_full %>% dplyr::select(source_id, source_name), by = "source_id") %>%
    dplyr::left_join(spi_footnote, by = c("country", "iso3c", "date", "source_id")) %>%
    dplyr::select(country, iso3c, date, source_name, source_id, value, footnote)

  # --- Final touches ---------------------------------------------------------
  databank_df <- databank_df %>%
    dplyr::mutate(
      value = dplyr::if_else(value == -99, as.numeric(NA), value),
      footnote = dplyr::if_else(footnote == "-99", as.character(NA), footnote)
    )

  # --- Produce aggregates (unweighted) ---------------------------------------
  agg_df <- aggregate_databank(databank_df, class_df)

  # --- Append aggregates to country data -------------------------------------
  data_bank_df_w_aggregates <- agg_df %>%
    dplyr::rename(
      iso3c = WB_Group_Code,
      country = WB_Group_Name
    ) %>%
    dplyr::bind_rows(databank_df)

  data_bank_df_w_aggregates
}

#' Save the databank outputs
#'
#' Writes the four databank files to the staging directory (constraint C7).
#'
#' @param databank_df The databank data frame from build_databank().
#' @param params      List of pipeline parameters.
#' @return A list of paths written.
#' @export
save_databank <- function(databank_df, params) {
  # Long format with aggregates
  path1 <- file.path(params$estimation_write_dir, "SPI_databank_country_and_aggregates.csv")
  write_output_csv(databank_df, path1)

  # DCS format
  path2 <- file.path(params$estimation_write_dir, "SPI_databank_country_and_aggregates_DCS.csv")
  databank_df %>%
    dplyr::transmute(
      Time = paste0("YR", date),
      Country = iso3c,
      Series = source_id,
      SCALE = 0,
      Data = value
    ) %>%
    dplyr::mutate(Data = dplyr::if_else(is.na(Data), "", as.character(Data))) %>%
    write_output_csv(path2)

  # DCS wide format
  path3 <- file.path(params$estimation_write_dir, "SPI_databank_country_and_aggregates_DCS_wide.csv")
  databank_df %>%
    dplyr::transmute(
      Time = paste0("YR", date),
      Country = iso3c,
      Series = source_id,
      SCALE = 0,
      Data = value
    ) %>%
    dplyr::mutate(Data = dplyr::if_else(is.na(Data), "", as.character(Data))) %>%
    tidyr::pivot_wider(
      names_from = "Time",
      values_from = "Data",
      names_sort = TRUE
    ) %>%
    write_output_csv(path3)

  # Footnotes
  path4 <- file.path(params$estimation_write_dir, "SPI_databank_footnotes.csv")
  databank_df %>%
    dplyr::transmute(
      Country = iso3c,
      Series = source_id,
      Time = paste0("YR", date),
      FootNote = footnote
    ) %>%
    write_output_csv(path4)

  list(
    aggregates = path1,
    dcs = path2,
    dcs_wide = path3,
    footnotes = path4
  )
}
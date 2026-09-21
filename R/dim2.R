# =============================================================================
# Dimension 2: Data Services
# =============================================================================
# Ported from the "idds", "online_access", and "nada" chunks of
# 01-SPI_data_prep.Rmd.
#
# Three indicators:
#   1. SPI.D2.1.GDDS -- SDDS/e-GDDS data dissemination standard (IMF/WDI)
#   2. SPI.D2.2.*     -- ODIN online access openness scores
#   3. SPI.D2.4.NADA  -- NADA microdata catalog availability
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
# 1. SPI.D2.1.GDDS -- SDDS/e-GDDS data dissemination standard
# =============================================================================
# Source: WDI metadata "IMF data dissemination standard" + archived SCI data.
# Scoring:
#   1 point  -- SDDS+ or SDDS subscription
#   0.5 point -- e-GDDS subscription
#   0 points -- otherwise

#' Score the SDDS/e-GDDS indicator
#'
#' Combines the WDI metadata dissemination standard with the archived SCI
#' data (for earlier years).
#'
#' @param wdi_metadata Tibble from read_wdi_metadata().
#' @param params       List of pipeline parameters.
#' @param grid         The country x year grid.
#' @return A tibble with iso3c, date, RAW.D2.1.GDDS, SPI.D2.1.GDDS.
#' @export
score_sdds <- function(wdi_metadata, params, grid) {
  # --- Archived SCI data (for years 2004-2015) -------------------------------
  # The SCI archived data has SDDS subscription info for earlier years.
  # NOTE: pivot only YR2004:YR2015 -- the SCI file also contains YR2016:YR2020
  # but the original pipeline deliberately stops at 2015 (the WDI metadata
  # covers 2016+). Pivoting the later years would create duplicate rows.
  sci_path <- file.path(params$raw_dir, "2.1_DSDR", "SCI_archived_data.csv")
  D2.1_DSDR_sci <- readr::read_csv(sci_path) %>%
    tidyr::pivot_longer(cols = YR2004:YR2015, names_to = "date", values_to = "value") %>%
    dplyr::filter(`Series Code` == "5.21.01.01.sdds") %>%
    dplyr::transmute(
      iso3c = `Country Code`,
      date = as.numeric(stringr::str_remove_all(date, "YR")),
      SDDS = if_else(is.na(value), 0, as.numeric(value))
    ) %>%
    dplyr::left_join(grid, by = c("iso3c", "date")) %>%
    dplyr::filter(!is.na(income_level)) %>%
    dplyr::select(iso3c, date, SDDS)

  # --- WDI metadata dissemination standard -----------------------------------
  df <- wdi_metadata %>%
    dplyr::filter(!is.na(Income.Group))  # keep just countries (drop aggregations)

  D2.1_DSDR <- df %>%
    dplyr::mutate(
      iso3c = Code,
      country = Table.Name
    ) %>%
    dplyr::select(iso3c, date, IMF.data.dissemination.standard) %>%
    dplyr::mutate(IDDS = IMF.data.dissemination.standard) %>%
    dplyr::mutate(SPI.D2.1.GDDS = dplyr::case_when(
      IDDS == "Special Data Dissemination Standard Plus (SDDS+)" |
        IDDS == "Special Data Dissemination Standard Plus (SDDS Plus)" |
        IDDS == "Special Data Dissemination Standard (SDDS)" ~ 1,
      IDDS == "Enhanced General Data Dissemination System (e-GDDS)" ~ 0.5,
      TRUE ~ 0
    ),
    SDDS = dplyr::case_when(
      IDDS == "Special Data Dissemination Standard (SDDS)" ~ 1,
      TRUE ~ 0
    )
    ) %>%
    dplyr::bind_rows(D2.1_DSDR_sci) %>%
    dplyr::rename(RAW.D2.1.GDDS = IDDS) %>%
    dplyr::select(iso3c, date, RAW.D2.1.GDDS, SPI.D2.1.GDDS) %>%
    dplyr::left_join(params$country_metadata, by = "iso3c")

  D2.1_DSDR
}

# =============================================================================
# 2. SPI.D2.2.* -- ODIN online access openness scores
# =============================================================================
# Source: Open Data Watch ODIN. The Openness subscore (0-100) is divided by
# 100 to get a 0-1 score. Five components: Machine.readable, Non.proprietary,
# Download.options, Metadata.available, Terms.of.use.

#' Read and combine the ODIN openness data
#'
#' Reads ODIN_<year>.csv for 2015:end_date, keeps the "All Categories" rows,
#' and binds them together.
#'
#' @param params List of pipeline parameters.
#' @return A tibble of ODIN openness scores.
#' @export
read_odin_data <- function(params) {
  end_date <- params$end_date
  years <- 2015:end_date

  purrr::map_dfr(years, function(i) {
    file_path <- file.path(params$raw_dir, "2.2_DSOA", sprintf("ODIN_%d.csv", i))
    readr::read_csv(file_path) %>%
      tibble::as_tibble(.name_repair = "universal") %>%
      dplyr::mutate(date = i) %>%
      dplyr::filter(Data.categories %in% c("All Categories", "All categories")) %>%
      # Convert the score columns to numeric
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
}

#' Score the ODIN online access indicator
#'
#' Selects the openness components, joins onto the country grid, fills
#' missing with 0, and produces both RAW (0-100) and SPI (0-1) versions.
#'
#' @param odin_data Tibble from read_odin_data().
#' @param params    List of pipeline parameters.
#' @return A tibble with iso3c, date, RAW.D2.2.* and SPI.D2.2.* columns.
#' @export
score_odin <- function(odin_data, params) {
  openness_df <- odin_data %>%
    dplyr::select(
      Country.Code,
      date,
      Machine.readable,
      Non.proprietary,
      Download.options,
      Metadata.available,
      Terms.of.use,
      Openness.subscore
    ) %>%
    dplyr::rename(iso3c = Country.Code) %>%
    dplyr::group_by(iso3c) %>%
    dplyr::right_join(params$country_metadata, by = "iso3c") %>%
    dplyr::mutate(dplyr::across(
      c(
        "Machine.readable",
        "Non.proprietary",
        "Download.options",
        "Metadata.available",
        "Terms.of.use",
        "Openness.subscore"
      ),
      ~ if_else(is.na(.), 0, .)
    ))

  # RAW versions (0-100 scale)
  openness_df_temp1 <- openness_df %>%
    dplyr::rename_with(
      ~ paste("RAW.D2.2", ., sep = "."),
      .cols = c(
        "Machine.readable",
        "Non.proprietary",
        "Download.options",
        "Metadata.available",
        "Terms.of.use",
        "Openness.subscore"
      )
    )

  # SPI versions (0-1 scale, divide by 100)
  openness_df_temp2 <- openness_df %>%
    dplyr::mutate(dplyr::across(
      c(
        "Machine.readable",
        "Non.proprietary",
        "Download.options",
        "Metadata.available",
        "Terms.of.use",
        "Openness.subscore"
      ),
      ~ ./100
    )) %>%
    dplyr::rename_with(
      ~ paste("SPI.D2.2", ., sep = "."),
      .cols = c(
        "Machine.readable",
        "Non.proprietary",
        "Download.options",
        "Metadata.available",
        "Terms.of.use",
        "Openness.subscore"
      )
    )

  openness_df_temp1 %>%
    dplyr::left_join(openness_df_temp2, by = c("iso3c", "date"))
}

# =============================================================================
# 3. SPI.D2.4.NADA -- NADA microdata catalog availability
# =============================================================================
# Source: NSO websites (manually collected).
# Scoring:
#   1 point  -- NADA catalog available
#   0 points -- otherwise

#' Read and score the NADA indicator
#'
#' Reads the D2.4.NADA csv files for each year and combines them.
#'
#' @param params List of pipeline parameters.
#' @return A tibble with iso3c, date, RAW.D2.4.NADA, RAW.D2.4.NADA_text,
#'   SPI.D2.4.NADA.
#' @export
score_nada <- function(params) {
  # Read each year's NADA file, adding the date
  nada_2020 <- readr::read_csv(file.path(params$raw_dir, "2.4_DSDS", "D2.4.NADA.2020.csv"))
  nada_2022 <- readr::read_csv(file.path(params$raw_dir, "2.4_DSDS", "D2.4.NADA.2022.csv"))
  nada_2023 <- readr::read_csv(file.path(params$raw_dir, "2.4_DSDS", "D2.4.NADA.2023.csv"))
  nada_2024 <- readr::read_csv(file.path(params$raw_dir, "2.4_DSDS", "D2.4.NADA.2024.csv"))

  D2.4_NADA <- readr::read_csv(file.path(params$raw_dir, "2.4_DSDS", "D2.4.NADA.csv")) %>%
    dplyr::bind_rows(nada_2020) %>%
    dplyr::bind_rows(nada_2022 %>% dplyr::mutate(date = 2021)) %>%
    dplyr::bind_rows(nada_2022 %>% dplyr::mutate(date = 2022)) %>%
    dplyr::bind_rows(nada_2023 %>% dplyr::mutate(date = 2023)) %>%
    dplyr::bind_rows(nada_2024 %>% dplyr::mutate(date = 2024)) %>%
    dplyr::mutate(SPI.D2.4.NADA = dplyr::case_when(
      NADA == 1 ~ 1,
      NADA == 0 ~ 0,
      TRUE ~ 0
    )) %>%
    dplyr::rename(
      RAW.D2.4.NADA = NADA,
      RAW.D2.4.NADA_text = NADA_text
    ) %>%
    dplyr::select(iso3c, date, RAW.D2.4.NADA, RAW.D2.4.NADA_text, SPI.D2.4.NADA) %>%
    dplyr::arrange(date, iso3c)

  D2.4_NADA
}

# =============================================================================
# Combine all D2 indicators
# =============================================================================

#' Combine the D2 indicators into one table
#'
#' Joins SDDS, ODIN, and NADA onto the country grid.
#'
#' @param params List of pipeline parameters.
#' @param grid   The country x year grid.
#' @return A tibble with iso3c, date, and the D2 indicator columns.
#' @export
combine_dim2 <- function(params, grid) {
  wdi_metadata <- read_wdi_metadata(params)

  sdds <- score_sdds(wdi_metadata, params, grid)
  odin <- score_odin(read_odin_data(params), params)
  nada <- score_nada(params)

  # Join all onto the grid
  grid %>%
    dplyr::left_join(sdds, by = c("iso3c", "date")) %>%
    dplyr::left_join(odin, by = c("iso3c", "date")) %>%
    dplyr::left_join(nada, by = c("iso3c", "date"))
}
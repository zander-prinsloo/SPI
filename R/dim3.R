# =============================================================================
# Dimension 3: Data Products (UN SDG)
# =============================================================================
# Ported from the "unstats" chunk of 01-SPI_data_prep.Rmd.
#
# The UN SDG indicators are pre-computed in a separate pipeline
# (https://github.com/stacybri/UN_Stats_SDG_Indicators_SPI) and saved as
# SPI_D3_UNSD_data_5yr.csv in 01_raw_data/3_DP/<year>/. This pipeline reads
# those files and renames the goal columns to the SPI naming convention.
#
# 16 indicators (D3.1-D3.17, excluding D3.14 Life Below Water which is not
# relevant for landlocked countries).
#
# Created: 2026-09-21
# =============================================================================

# The pipe operator (%>%) comes from magrittr (loaded via tidyverse in the
# original Rmds). We import it explicitly so this file is self-contained.
`%>%` <- magrittr::`%>%`

# dplyr functions (if_else, case_when, etc.) are used unqualified throughout
# this file, matching the tidyverse style of the original Rmds.
library(dplyr)

#' Read the UN SDG data for one year
#'
#' Reads SPI_D3_UNSD_data_5yr.csv for the given year, renames the goal
#' columns to the SPI naming convention, and drops D3.14 (Life Below Water).
#'
#' @param year   Numeric: the reference year.
#' @param params List of pipeline parameters.
#' @return A tibble with iso3c, date, and the SPI.D3.* columns.
#' @export
un_sdg_data_read <- function(year, params) {
  fl <- file.path(params$raw_dir, "3_DP", year, "SPI_D3_UNSD_data_5yr.csv")

  readr::read_csv(fl) %>%
    dplyr::rename(
      SPI.D3.1.POV = SPI.D3.1,
      SPI.D3.2.HNGR = SPI.D3.2,
      SPI.D3.3.HLTH = SPI.D3.3,
      SPI.D3.4.EDUC = SPI.D3.4,
      SPI.D3.5.GEND = SPI.D3.5,
      SPI.D3.6.WTRS = SPI.D3.6,
      SPI.D3.7.ENRG = SPI.D3.7,
      SPI.D3.8.WORK = SPI.D3.8,
      SPI.D3.9.INDY = SPI.D3.9,
      SPI.D3.10.NEQL = SPI.D3.10,
      SPI.D3.11.CITY = SPI.D3.11,
      SPI.D3.12.CNSP = SPI.D3.12,
      SPI.D3.13.CLMT = SPI.D3.13,
      SPI.D3.14.LFWT = SPI.D3.14,
      SPI.D3.15.LAND = SPI.D3.15,
      SPI.D3.16.INST = SPI.D3.16,
      SPI.D3.17.PTNS = SPI.D3.17
    ) %>%
    dplyr::select(iso3c, date, dplyr::starts_with("SPI")) %>%
    dplyr::select(-SPI.D3.14.LFWT) %>%
    dplyr::filter(date == year)
}

#' Read collection-produced SDG score inputs.
#'
#' Stops when the collection artifact is absent.
#'
#' @param params List of pipeline parameters.
#' @return A tibble with iso3c, date, and the SPI.D3.* columns.
#' @export
read_sdg_collection_scores <- function(params) {
  path <- file.path(
    params$raw_dir,
    "3_DP",
    "collection",
    "SPI_D3_UNSD_data_5yr.csv"
  )
  if (!file.exists(path)) {
    stop(
      "SDG COLLECTION SCORE ARTIFACT NOT FOUND: ", path,
      "\nRun the data collection pipeline before estimation.",
      call. = FALSE
    )
  }

  readr::read_csv(path, show_col_types = FALSE) %>%
    dplyr::filter(date %in% params$span) %>%
    dplyr::select(iso3c, date, dplyr::starts_with("SPI.D3"))
}

#' Combine the legacy per-year SDG data for all years.
#'
#' @param params List of pipeline parameters.
#' @return A tibble with iso3c, date, and the SPI.D3.* columns.
#' @export
combine_dim3 <- function(params) {
  read_sdg_collection_scores(params)
}
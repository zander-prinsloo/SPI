# =============================================================================
# SPL admin data availability output
# =============================================================================
# Ported from the commented-out "aspire" chunk of 01-SPI_data_prep.Rmd
# (eval=FALSE) and the microdata library pull outputs.
#
# Produces SPL_admin_data_availability.csv -- whether beneficiary count or
# expenditure data is available for social protection and labor programs.
#
# Created: 2026-09-22
# =============================================================================

# The pipe operator (%>%) comes from magrittr (loaded via tidyverse in the
# original Rmds). We import it explicitly so this file is self-contained.
`%>%` <- magrittr::`%>%`

# dplyr functions (if_else, case_when, etc.) are used unqualified throughout
# this file, matching the tidyverse style of the original Rmds.
library(dplyr)

#' Build the SPL admin data availability dataset
#'
#' Mirrors the "aspire" chunk. Reads the ASPIRE sources, computes whether
#' beneficiary count or expenditure data is available per country-year, and
#' joins country metadata.
#'
#' @param params List of pipeline parameters.
#' @return A tibble with iso3c, date, ben_count_avail, ben_exp_avail,
#'   country metadata, ben_info_avail.
#' @export
build_spl_admin <- function(params) {
  aspire_df_raw <- readr::read_csv(file.path(params$raw_dir, "4.2_SOAD", "ASPIRE_sources.csv"))

  aspire_df <- aspire_df_raw %>%
    dplyr::mutate(date = as.numeric(year)) %>%
    dplyr::filter(!is.na(date)) %>%
    dplyr::group_by(ccode, date) %>%
    dplyr::summarise(
      ben_count_avail = (!is.na(mean(ben, na.rm = TRUE))),
      ben_exp_avail = (!is.na(mean(exp_b, na.rm = TRUE))),
      .groups = "drop"
    ) %>%
    dplyr::rename(iso3c = ccode) %>%
    dplyr::left_join(params$country_metadata, by = "iso3c") %>%
    dplyr::mutate(
      ben_info_avail = (ben_count_avail == TRUE | ben_exp_avail == TRUE)
    )

  aspire_df
}

#' Save the SPL admin output
#'
#' Writes SPL_admin_data_availability.csv to the staging directory
#' (constraint C7).
#'
#' @param spl_admin_df The SPL admin data frame from build_spl_admin().
#' @param params       List of pipeline parameters.
#' @return The path written.
#' @export
save_spl_admin <- function(spl_admin_df, params) {
  path <- file.path(params$estimation_write_dir, "SPL_admin_data_availability.csv")
  write_output_csv(spl_admin_df, path)
  path
}
# =============================================================================
# JMP washdata download target
# =============================================================================
# Downloads the WHO/UNICEF JMP (Joint Monitoring Programme) country files
# used for SPI.D1.5.SAFE.MAN.WATER (safely managed water).
#
# The JMP provides a per-country CSV download at:
#   https://washdata.org/data/country/<ISO3C>/household/download
#
# The original Rmd (01-SPI_data_prep.Rmd, "safely_managed_scored" chunk)
# loops over all countries and downloads each country file, then combines
# them into Safely_Managed_Water_data.csv. This target replicates that
# download and writes the combined file to 01_raw_data/1.5_DUIO/.
#
# NOTE: this target is OPT-IN. Running tar_make() by default does NOT
# trigger it (it is not in the default target list). The technical lead
# runs it explicitly when updating to a new vintage:
#   targets::tar_make(pull_jmp)
#
# Created: 2026-09-22
# =============================================================================

# The pipe operator (%>%) comes from magrittr (loaded via tidyverse in the
# original Rmds). We import it explicitly so this file is self-contained.
`%>%` <- magrittr::`%>%`

# dplyr functions (if_else, case_when, etc.) are used unqualified throughout
# this file, matching the tidyverse style of the original Rmds.
library(dplyr)

#' Download one country's JMP household data
#'
#' Fetches the JMP country CSV and normalizes it to the columns used by the
#' pipeline (source, type, year, geo, data_available, data_quality,
#' data_value). Mirrors the hyper_read() helper in the original Rmd.
#'
#' @param iso3c Character: the country code.
#' @param timeout Numeric: HTTP timeout in seconds (default 60).
#' @return A tibble with the normalized JMP data.
#' @export
jmp_country_download <- function(iso3c, timeout = 60) {
  url <- sprintf("https://washdata.org/data/country/%s/household/download", iso3c)

  # Kosovo has no JMP page; the original Rmd uses Serbia's data.
  if (iso3c == "XKX") {
    url <- "https://washdata.org/data/country/SRB/household/download"
  }

  # HARD STOP (R8): a failed download must abort the pull, never silently
  # produce an NA row. A missing country file is a data problem that the
  # technical lead must investigate -- the pipeline must not proceed with
  # incomplete JMP data.
  resp <- httr::GET(url, httr::timeout(timeout))
  if (httr::status_code(resp) != 200) {
    stop(
      sprintf("JMP download failed for %s: HTTP %d\n  %s\n", iso3c, httr::status_code(resp), url),
      "\nThe JMP washdata API did not return the expected file.",
      "Investigate before proceeding -- the pipeline must not run with",
      "incomplete JMP data.",
      call. = FALSE
    )
  }
  df <- readr::read_csv(httr::content(resp, as = "text", encoding = "UTF-8"),
    show_col_types = FALSE
  ) %>%
    tibble::as_tibble(.name_repair = "universal")

  # Normalize to the pipeline's expected columns. The JMP CSV has
  # columns like source, type, year, geo, data_available, data_quality,
  # data_value (with possible name variations).
  df %>%
    dplyr::mutate(
      source = as.character(source),
      type = as.character(type),
      year = as.numeric(year),
      geo = as.character(geo),
      data_available = as.numeric(data_available),
      data_quality = as.numeric(data_quality),
      data_value = as.numeric(data_value)
    )
}

#' Download all JMP country files and combine them
#'
#' Loops over the country metadata (excluding aggregates), downloads each
#' country's JMP household data, and combines them into the
#' Safely_Managed_Water_data.csv format used by the pipeline.
#'
#' @param params List of pipeline parameters.
#' @return A tibble of combined JMP data.
#' @export
pull_jmp_water <- function(params) {
  country_metadata <- params$country_metadata %>%
    dplyr::filter(region != "Aggregates")

  # Download all countries (this takes a while -- ~200 HTTP requests).
  message("Downloading JMP water data for ", nrow(country_metadata), " countries...")
  data_list <- purrr::map(country_metadata$iso3c, jmp_country_download)

  combined <- dplyr::bind_rows(data_list) %>%
    dplyr::mutate(type = as.character(type))

  # Write to the raw data folder (this is the file the pipeline reads).
  out_path <- file.path(params$raw_dir, "1.5_DUIO", "Safely_Managed_Water_data.csv")
  readr::write_csv(combined, out_path)

  message(sprintf("JMP water data written to %s (%d rows)", out_path, nrow(combined)))
  combined
}
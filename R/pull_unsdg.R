# =============================================================================
# UN SDG API download target
# =============================================================================
# Downloads UN SDG indicator data from the UN Stats SDG API:
#   https://unstats.un.org/SDGAPI/v1/sdg/Series/Data?seriesCode=<CODE>
#
# Used by the pipeline for:
#   - SPI.D5.1.DILG (statistical legislation, SDG 17.18.2)
#   - SPI.D5.5.DIFI (statistical plan funded, SDG 17.18.3; SG_STT_NSDSFND)
#   - SPI.D4.2.3.CRVS (birth registration, SDG 17.19.2)
#
# The original Rmd defines an un_pull() helper that fetches a series and
# right-joins the UN iso3c codes. This target replicates that helper and
# writes the fetched series to 01_raw_data/.
#
# NOTE: this target is OPT-IN. Running tar_make() by default does NOT
# trigger it. The technical lead runs it explicitly when updating:
#   targets::tar_make(pull_unsdg)
#
# Created: 2026-09-22
# =============================================================================

# The pipe operator (%>%) comes from magrittr (loaded via tidyverse in the
# original Rmds). We import it explicitly so this file is self-contained.
`%>%` <- magrittr::`%>%`

# dplyr functions (if_else, case_when, etc.) are used unqualified throughout
# this file, matching the tidyverse style of the original Rmds.
library(dplyr)

#' Request raw UN SDG JSON bytes for one series.
#'
#' @param series Character series code.
#' @return Raw JSON response bytes.
#' @export
un_sdg_raw_request <- function(series) {
  url <- paste0(
    "https://unstats.un.org/SDGAPI/v1/sdg/Series/Data?seriesCode=",
    series,
    "&pageSize=10000"
  )
  resp <- with_http_retry(function() httr::GET(url, httr::timeout(120)))
  if (httr::status_code(resp) != 200) {
    stop(sprintf("UN SDG API returned HTTP %d for series %s", httr::status_code(resp), series), call. = FALSE)
  }
  content <- httr::content(resp, as = "raw")
  if (length(content) == 0L) {
    stop(sprintf("UN SDG API returned no data for series %s", series), call. = FALSE)
  }
  content
}

#' Parse one raw UN SDG series response.
#'
#' @param payload Raw JSON bytes.
#' @param series Character series code.
#' @param params Pipeline parameters.
#' @return A tibble with iso3c, date, and series values.
#' @export
parse_un_sdg_raw <- function(payload, series, params) {
  data <- jsonlite::fromJSON(
    rawToChar(payload),
    flatten = TRUE
  )$data
  if (is.null(data) || nrow(data) == 0) {
    stop(sprintf("UN SDG API returned no data for series %s", series), call. = FALSE)
  }
  iso3c <- readr::read_csv(file.path(params$raw_dir, "metadata", "iso_codes.csv"), show_col_types = FALSE)
  data |>
    tibble::as_tibble() |>
    dplyr::mutate(date = timePeriodStart) |>
    dplyr::right_join(iso3c, by = "geoAreaCode")
}

#' Pull one UN SDG series from the SDG API
#'
#' Mirrors the un_pull() helper in the original Rmd. Fetches all data for a
#' series code and right-joins the UN iso3c codes so every country appears.
#'
#' @param series Character: the SDG series code (e.g. "SG_STT_FPOS").
#' @param params List of pipeline parameters.
#' @return A tibble with iso3c, date, and the series value columns.
#' @export
un_sdg_pull <- function(series, params) {
  parse_un_sdg_raw(un_sdg_raw_request(series), series, params)
}

#' Download the UN SDG series used by the pipeline
#'
#' Fetches the legislation (SG_STT_FPOS), finance (SG_STT_NSDSFND), and birth
#' registration (SG_REG_BRTH90N) series and writes them to 01_raw_data/.
#'
#' @param params List of pipeline parameters.
#' @return A list of fetched series data frames.
#' @export
download_unsdg_series <- function(params) {
  series_map <- list(
    "SG_STT_FPOS" = file.path(params$raw_dir, "5.1_DILG", "SG_STT_FPOS.csv"),
    "SG_STT_NSDSFND" = file.path(params$raw_dir, "5.5_DIFI", "SG_STT_NSDSFND.csv"),
    "SG_REG_BRTH90N" = file.path(params$raw_dir, "4.2_SOAD", "SG_REG_BRTH90N.csv")
  )

  results <- purrr::imap(series_map, function(out_path, series) {
    message("Pulling UN SDG series ", series, "...")
    record <- collect_cached_raw(
      cache_dir = file.path(params$raw_dir, "_collection", "un_sdg", "raw"),
      source_id = paste0("un_sdg_", series),
      request = list(
        endpoint = "https://unstats.un.org/SDGAPI/v1/sdg/Series/Data",
        series = series
      ),
      vintage = params$end_date,
      collector_version = "un-sdg-json-v1",
      fetch = function() un_sdg_raw_request(series),
      max_age_days = params$collection_age_warning_days
    )
    df <- parse_un_sdg_raw(readBin(record$raw_path, "raw", file.info(record$raw_path)$size), series, params)
    readr::write_csv(df, out_path)
    message(sprintf("  wrote %s (%d rows)", out_path, nrow(df)))
    df
  })

  results
}
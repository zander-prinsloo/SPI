# =============================================================================
# UN SDG series for D4.2, D5.1 and D5.5
# =============================================================================
# Port of 02_programs/misc_scripts/sdg_indicators_for_SPI.R. Each series is
# requested from the UN SDG API DataCSV endpoint (2004 to end_date) through
# the raw collection cache and transformed as the legacy script does:
# date = TimePeriod, Nature = [Nature], geoAreaCode as character, join
# iso_codes.csv (read as character) and the saved country snapshot, keep rows
# with an iso3c. Outputs keep the legacy paths and column layout.
#
#   SG_REG_BRTH90N, SG_REG_DETH75N -> SPI.D4.2.3.CRVS
#   SG_STT_FPOS                    -> SPI.D5.1.DILG
#   SG_STT_NSDSFND                 -> SPI.D5.5.DIFI
#
# The legacy request body has a stray comma (`timePeriodStart=,2004`); the
# port sends the well-formed parameter. The series start in 2015 and 2019 and
# the scorers filter to the SPI span, so outputs are unaffected.
#
# Created: 2026-09-22 (rewritten 2026-10-23 for the 202611 update)
# =============================================================================

# The pipe operator (%>%) comes from magrittr (loaded via tidyverse in the
# original Rmds). We import it explicitly so this file is self-contained.
`%>%` <- magrittr::`%>%`

# dplyr functions (if_else, case_when, etc.) are used unqualified throughout
# the pipeline files, matching the tidyverse style of the original Rmds.
library(dplyr)

.unsdg_endpoint <- "https://unstats.un.org/SDGAPI/v1/sdg/Series/DataCSV"

#' UN SDG series collected for the SPI, with outputs and registry sources.
#'
#' @param raw_dir Root `01_raw_data` directory.
#' @return A data frame with `series`, `source_id` and `path`.
#' @export
unsdg_series_specs <- function(raw_dir) {
  data.frame(
    series = c("SG_REG_BRTH90N", "SG_REG_DETH75N", "SG_STT_FPOS", "SG_STT_NSDSFND"),
    source_id = c("d4_2_crvs", "d4_2_crvs", "d5_1_legislation", "d5_5_finance"),
    path = file.path(raw_dir, c(
      "4.2_SOAD/SG_REG_BRTH90N.csv",
      "4.2_SOAD/SG_REG_DETH75N.csv",
      "5.1_DILG/SG_STT_FPOS.csv",
      "5.5_DIFI/SG_STT_NSDSFND.csv"
    )),
    stringsAsFactors = FALSE
  )
}

#' Read iso_codes.csv as the legacy script does (three character columns).
#'
#' @param raw_dir Root `01_raw_data` directory.
#' @return A tibble with `country`, `geoAreaCode` and `iso3c`.
#' @export
read_unsdg_iso_codes <- function(raw_dir) {
  path <- file.path(raw_dir, "metadata", "iso_codes.csv")
  if (!file.exists(path)) {
    stop("UN SDG ISO CODES NOT FOUND: ", path, call. = FALSE)
  }
  iso_codes <- readr::read_csv(
    path,
    col_types = list(readr::col_character(), readr::col_character(), readr::col_character())
  )
  if (!identical(names(iso_codes), c("country", "geoAreaCode", "iso3c"))) {
    stop("UN SDG ISO CODES MUST HAVE country, geoAreaCode AND iso3c.", call. = FALSE)
  }
  iso_codes
}

#' Transform one DataCSV series as sdg_indicators_for_SPI.R does.
#'
#' The legacy natural joins resolve to `geoAreaCode` (ISO lookup) and `iso3c`
#' (country snapshot) for the DataCSV schema. Any other shared column would
#' silently change those keys, so it stops instead.
#'
#' @param raw_data Data frame read from the DataCSV body.
#' @param series Series code (for messages).
#' @param iso_codes Lookup from [read_unsdg_iso_codes()].
#' @param country_metadata Saved country snapshot.
#' @return A list with the transformed `data` and the `dropped_codes`
#'   (geography codes without an ISO3 code, dropped as in legacy).
#' @export
transform_unsdg_series <- function(raw_data, series, iso_codes, country_metadata) {
  required <- c("TimePeriod", "[Nature]", "GeoAreaCode", "Value")
  missing <- setdiff(required, names(raw_data))
  if (length(missing) > 0L) {
    stop(
      sprintf("UN SDG SERIES SCHEMA MISMATCH for %s: missing %s", series, paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
  if (!"iso3c" %in% names(country_metadata)) {
    stop("UN SDG COUNTRY SNAPSHOT MUST HAVE iso3c.", call. = FALSE)
  }

  data <- raw_data %>%
    dplyr::mutate(
      date = as.numeric(TimePeriod),
      Nature = `[Nature]`,
      geoAreaCode = as.character(GeoAreaCode)
    )

  clash <- unique(c(
    setdiff(intersect(names(data), names(iso_codes)), "geoAreaCode"),
    intersect(setdiff(names(data), "country"), setdiff(names(country_metadata), "iso3c"))
  ))
  if (length(clash) > 0L) {
    stop(
      sprintf("UN SDG SERIES COLUMN CLASH for %s: %s", series, paste(clash, collapse = ", ")),
      call. = FALSE
    )
  }

  joined <- data %>%
    dplyr::left_join(iso_codes, by = "geoAreaCode", relationship = "many-to-one") %>%
    dplyr::select(-country) %>%
    dplyr::left_join(country_metadata, by = "iso3c", relationship = "many-to-one") %>%
    dplyr::select(dplyr::all_of(colnames(country_metadata)), dplyr::everything())

  list(
    data = dplyr::filter(joined, !is.na(iso3c)),
    dropped_codes = sort(unique(joined$geoAreaCode[is.na(joined$iso3c)]))
  )
}

#' Collect the UN SDG series used by D4.2, D5.1 and D5.5.
#'
#' @param params Pipeline parameters (`raw_dir`, `span`, `end_date`,
#'   `collection_age_warning_days`).
#' @param country_metadata Saved country snapshot; defaults to
#'   `params$country_metadata`.
#' @param request_fn Function `(series, start_year, end_year)` returning the
#'   DataCSV body; defaults to [sdg_api_csv_request()].
#' @return A named list (by series) of output records.
#' @export
download_unsdg_series <- function(params, country_metadata = NULL,
                                  request_fn = sdg_api_csv_request) {
  if (is.null(country_metadata)) {
    country_metadata <- params$country_metadata
  }
  if (is.null(country_metadata)) {
    stop("UN SDG COLLECTION REQUIRES THE SAVED COUNTRY SNAPSHOT.", call. = FALSE)
  }
  iso_codes <- read_unsdg_iso_codes(params$raw_dir)
  start_year <- min(params$span)
  end_year <- params$end_date
  max_age_days <- if (is.null(params$collection_age_warning_days)) Inf else params$collection_age_warning_days
  specs <- unsdg_series_specs(params$raw_dir)

  results <- lapply(seq_len(nrow(specs)), function(i) {
    series <- specs$series[[i]]
    record <- collect_cached_raw(
      cache_dir = file.path(params$raw_dir, "_collection", "un_sdg", "raw"),
      source_id = paste0("un_sdg_", series),
      request = list(
        endpoint = .unsdg_endpoint,
        series_code = series,
        start_year = start_year,
        end_year = end_year
      ),
      vintage = params$end_date,
      collector_version = "un-sdg-datacsv-v1",
      fetch = function() request_fn(series, start_year, end_year),
      max_age_days = max_age_days
    )

    raw_data <- readr::read_csv(record$raw_path, show_col_types = FALSE)
    transformed <- transform_unsdg_series(raw_data, series, iso_codes, country_metadata)
    if (length(transformed$dropped_codes) > 0L) {
      warning(
        sprintf(
          "UN SDG GEOAREA CODES DROPPED for %s (no ISO3 code; legacy drops them too): %s",
          series,
          paste(transformed$dropped_codes, collapse = ", ")
        ),
        call. = FALSE
      )
    }

    path <- specs$path[[i]]
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    readr::write_csv(transformed$data, path)
    write_artifact_provenance(
      path,
      source_id = specs$source_id[[i]],
      retrieved_at = record$retrieved_at,
      release_identifier = sprintf("UN SDG API DataCSV retrieved %s", substr(record$retrieved_at, 1, 10)),
      raw_path = record$raw_path,
      extra = list(series_code = series, dropped_geo_area_codes = transformed$dropped_codes)
    )
    message(sprintf("UN SDG %s: wrote %s (%d rows)", series, path, nrow(transformed$data)))
    list(
      path = normalizePath(path, winslash = "/", mustWork = FALSE),
      rows = nrow(transformed$data),
      retrieved_at = record$retrieved_at,
      raw_path = record$raw_path
    )
  })
  stats::setNames(results, specs$series)
}

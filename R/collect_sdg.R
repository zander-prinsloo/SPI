# =============================================================================
# UN SDG collection and normalization
# =============================================================================
# Ported from 02_programs/misc_scripts/un_stats_cleaning.Rmd.
# Created: 2026-10-05
# =============================================================================

#' Read and validate the SDG indicator list used by the collection.
#'
#' @param path Path to SDG_indicator_list.csv.
#' @return A tibble containing the indicator list.
#' @export
read_sdg_indicator_list <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("SDG INDICATOR LIST NOT FOUND: %s", path), call. = FALSE)
  }
  result <- readr::read_csv(path, show_col_types = FALSE)
  required <- c("code1", "Tier_Nov2020")
  missing <- setdiff(required, names(result))
  if (length(missing) > 0L) {
    stop(
      "SDG INDICATOR LIST SCHEMA MISMATCH: missing column(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  result
}

#' Classify an SDG value using the Rmd's Nature rules.
#'
#' @param value Numeric values.
#' @param nature Nature classification values.
#' @return Numeric quality values in the Rmd's 0/1/NA scale.
#' @export
sdg_quality_from_nature <- function(value, nature) {
  available <- !is.na(value)
  result <- rep(0, length(value))
  result[available & (is.na(nature) | nature %in% c("C", "CA", "E", "G"))] <- 1
  result[available & nature == "M"] <- 0
  not_applicable <- !is.na(nature) & nature == "N"
  result[not_applicable] <- NA_real_
  result[!available] <- 0
  result
}

#' Normalize one UN SDG DataCSV response.
#'
#' @param raw_data Data frame parsed from the UN SDG DataCSV response.
#' @param series_code Character series identifier.
#' @param iso_codes Data frame with `geoAreaCode` and `iso3c`.
#' @return A normalized data frame.
#' @export
normalize_sdg_series <- function(raw_data, series_code, iso_codes) {
  required <- c("TimePeriod", "[Nature]", "GeoAreaCode", "Value")
  missing <- setdiff(required, names(raw_data))
  if (length(missing) > 0L) {
    stop(
      "SDG SERIES SCHEMA MISMATCH: missing column(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  if (!all(c("geoAreaCode", "iso3c") %in% names(iso_codes))) {
    stop("SDG ISO LOOKUP MUST HAVE geoAreaCode AND iso3c.", call. = FALSE)
  }

  lookup <- iso_codes |>
    dplyr::transmute(
      geoAreaCode = as.character(geoAreaCode),
      iso3c = as.character(iso3c)
    ) |>
    dplyr::distinct()
  if (anyDuplicated(lookup$geoAreaCode) > 0L) {
    stop("SDG ISO LOOKUP KEY VIOLATION: duplicate geoAreaCode values.", call. = FALSE)
  }

  normalized <- raw_data |>
    tibble::as_tibble(.name_repair = "minimal") |>
    dplyr::transmute(
      series_code = series_code,
      date = as.numeric(TimePeriod),
      Nature = as.character(`[Nature]`),
      geoAreaCode = as.character(GeoAreaCode),
      Value = suppressWarnings(as.numeric(Value))
    ) |>
    dplyr::left_join(lookup, by = "geoAreaCode") |>
    dplyr::mutate(
      available = as.integer(!is.na(Value)),
      quality = sdg_quality_from_nature(Value, Nature)
    )

  unmapped <- normalized |>
    dplyr::filter(!is.na(Value), is.na(iso3c)) |>
    dplyr::distinct(geoAreaCode)
  if (nrow(unmapped) > 0L) {
    warning(
      "SDG GEOAREA CODES NOT IN ISO LOOKUP: ",
      paste(unmapped$geoAreaCode, collapse = ", "),
      call. = FALSE
    )
  }

  normalized
}

#' Request a UN SDG CSV response.
#'
#' @param series_code Character series identifier.
#' @param start_year Numeric lower year.
#' @param end_year Numeric upper year.
#' @return Raw response bytes.
#' @export
sdg_api_csv_request <- function(series_code, start_year, end_year) {
  url <- "https://unstats.un.org/SDGAPI/v1/sdg/Series/DataCSV"
  response <- with_http_retry(function() httr::POST(
    url,
    httr::add_headers(`Content-Type` = "application/x-www-form-urlencoded"),
    httr::accept("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"),
    body = paste0(
      "seriesCodes=", series_code,
      "&timePeriodStart=", start_year,
      "&timePeriodEnd=", end_year
    ),
    httr::timeout(120)
  )
  )
  if (httr::status_code(response) != 200) {
    stop(
      sprintf("UN SDG CSV API returned HTTP %d for series %s", httr::status_code(response), series_code),
      call. = FALSE
    )
  }
  content <- httr::content(response, as = "raw")
  if (length(content) == 0L) {
    stop(sprintf("UN SDG CSV API returned no data for series %s", series_code), call. = FALSE)
  }
  content
}

#' Collect, normalize, and create availability data for SDG series.
#'
#' @param series_codes Character vector of series identifiers.
#' @param start_year Numeric lower year.
#' @param end_year Numeric upper year.
#' @param raw_dir Root `01_raw_data` directory.
#' @param iso_codes Country lookup table.
#' @param country_year_grid Complete country-year grid.
#' @param request_fn Injectable request function for tests.
#' @return A list of per-series collection records.
#' @export
collect_sdg_series <- function(series_codes, start_year, end_year, raw_dir,
                               iso_codes, country_year_grid,
                               request_fn = sdg_api_csv_request,
                               max_age_days = Inf) {
  raw_cache_dir <- file.path(raw_dir, "3_DP", "sdg_data", "raw")
  normalized_dir <- file.path(raw_dir, "3_DP", "sdg_data", "normalized")
  availability_dir <- file.path(raw_dir, "3_DP", "availability")
  dir.create(normalized_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(availability_dir, recursive = TRUE, showWarnings = FALSE)

  lapply(series_codes, function(series_code) {
    record <- collect_cached_raw(
      cache_dir = raw_cache_dir,
      source_id = paste0("sdg_", series_code),
      request = list(
        endpoint = "https://unstats.un.org/SDGAPI/v1/sdg/Series/DataCSV",
        series_code = series_code,
        start_year = start_year,
        end_year = end_year
      ),
      vintage = end_year,
      collector_version = "sdg-csv-v1",
      fetch = function() request_fn(series_code, start_year, end_year),
      max_age_days = max_age_days
    )

    raw_data <- readr::read_csv(record$raw_path, show_col_types = FALSE)
    normalized <- normalize_sdg_series(raw_data, series_code, iso_codes)
    normalized_path <- file.path(normalized_dir, paste0(series_code, ".csv"))
    readr::write_csv(normalized, normalized_path)

    availability <- build_sdg_availability(normalized, country_year_grid)
    availability_path <- file.path(availability_dir, paste0(series_code, ".csv"))
    readr::write_csv(availability, availability_path)

    record$normalized_path <- normalizePath(normalized_path, winslash = "/", mustWork = FALSE)
    record$availability_path <- normalizePath(availability_path, winslash = "/", mustWork = FALSE)
    record$availability <- availability
    record
  })
}

#' Run the SDG collection stage from the reviewed indicator list.
#'
#' @param params Pipeline parameter list.
#' @return A collection result, or NULL when the indicator list is absent.
#' @export
collect_sdg_pipeline <- function(params) {
  indicator_list_path <- params$sdg_indicator_list_file
  if (!file.exists(indicator_list_path)) {
    message(
      "SDG indicator list is missing; collection status will remain blocking: ",
      indicator_list_path
    )
    return(NULL)
  }

  indicator_list <- read_sdg_indicator_list(indicator_list_path)
  if (!"goal" %in% names(indicator_list)) {
    stop("SDG INDICATOR LIST MUST INCLUDE A `goal` COLUMN.", call. = FALSE)
  }
  score_indicator_list <- indicator_list |>
    dplyr::filter(Tier_Nov2020 == 1)
  goal_map <- score_indicator_list |>
    dplyr::transmute(series_code = as.character(code1), goal = as.character(goal)) |>
    dplyr::distinct()
  duplicate_series <- goal_map |>
    dplyr::count(series_code) |>
    dplyr::filter(n > 1)
  if (nrow(duplicate_series) > 0L) {
    stop(
      "SDG INDICATOR LIST MAPS A SERIES TO MULTIPLE GOALS: ",
      paste(duplicate_series$series_code, collapse = ", "),
      call. = FALSE
    )
  }

  iso_codes <- read_iso_codes(params)
  country_year_grid <- build_country_grid(params) |>
    dplyr::select(iso3c, date)
  records <- collect_sdg_series(
    series_codes = unique(indicator_list$code1),
    start_year = min(params$span),
    end_year = max(params$span),
    raw_dir = params$raw_dir,
    iso_codes = iso_codes,
    country_year_grid = country_year_grid,
    max_age_days = params$collection_age_warning_days
  )

  normalized <- purrr::map_dfr(records, function(record) {
    readr::read_csv(record$normalized_path, show_col_types = FALSE)
  }) |>
    dplyr::left_join(
      goal_map,
      by = "series_code"
    ) |>
    dplyr::filter(!is.na(goal))

  scores <- build_sdg_five_year_scores(
    normalized,
    country_year_grid,
    min(params$span),
    max(params$span)
  )
  score_path <- file.path(params$sdg_collection_dir, "SPI_D3_UNSD_data_5yr.csv")
  dir.create(dirname(score_path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(scores, score_path)

  list(records = records, score_path = score_path)
}

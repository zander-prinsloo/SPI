# =============================================================================
# World Bank source collection
# =============================================================================
# Created: 2026-10-05
# =============================================================================

.default_world_bank_population <- function(params) {
  wbstats::wb_data(
    country = "all",
    indicator = "SP.POP.TOTL",
    start_date = 2004,
    end_date = params$end_date
  ) |>
    dplyr::transmute(
      iso3c,
      date = as.numeric(date),
      population = SP.POP.TOTL
    )
}

.default_world_bank_countries <- function(params) {
  wbstats::wb_countries()
}

.default_world_bank_gdp <- function(params) {
  wbstats::wb_data(
    indicator = "NY.GDP.PCAP.PP.KD",
    start_date = 2004,
    end_date = params$end_date
  )
}

.default_world_bank_oecd <- function(params) {
  response <- httr::GET(
    "https://api.worldbank.org/v2/country?region=OED&format=json",
    httr::timeout(60)
  )
  if (httr::status_code(response) != 200) {
    stop(sprintf("WORLD BANK OECD API returned HTTP %d", httr::status_code(response)), call. = FALSE)
  }
  parsed <- jsonlite::fromJSON(
    httr::content(response, as = "text", encoding = "UTF-8"),
    flatten = TRUE
  )
  codes <- parsed[[2]]$id
  if (length(codes) == 0L) {
    stop("WORLD BANK OECD API returned no country codes.", call. = FALSE)
  }
  c(codes, "SGP")
}

validate_world_bank_table <- function(data, key_columns, label) {
  missing <- setdiff(key_columns, names(data))
  if (length(missing) > 0L) {
    stop(label, " MISSING COLUMN(S): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  key <- do.call(interaction, c(data[key_columns], list(drop = TRUE)))
  if (anyDuplicated(key) > 0L) {
    stop(label, " KEY VIOLATION: duplicate rows for ", paste(key_columns, collapse = "/"), call. = FALSE)
  }
  invisible(TRUE)
}

#' Collect World Bank inputs used by estimation.
#'
#' @param params Pipeline parameters.
#' @param fetch_population Optional injected population function.
#' @param fetch_countries Optional injected country metadata function.
#' @param fetch_oecd Optional injected OECD function.
#' @param fetch_gdp Optional injected GDP function.
#' @return Named list of normalized artifact paths.
#' @export
collect_world_bank_inputs <- function(params, fetch_population = NULL,
                                      fetch_countries = NULL, fetch_oecd = NULL,
                                      fetch_gdp = NULL) {
  if (is.null(fetch_population)) fetch_population <- .default_world_bank_population
  if (is.null(fetch_countries)) fetch_countries <- .default_world_bank_countries
  if (is.null(fetch_oecd)) fetch_oecd <- .default_world_bank_oecd
  if (is.null(fetch_gdp)) fetch_gdp <- .default_world_bank_gdp

  cache_dir <- file.path(params$collection_dir, "world_bank", "raw")
  normalized_dir <- file.path(params$collection_dir, "world_bank")
  dir.create(normalized_dir, recursive = TRUE, showWarnings = FALSE)

  collect_one <- function(source_id, request, fetch, file_name) {
    record <- collect_cached_table(
      cache_dir = cache_dir,
      source_id = source_id,
      request = request,
      vintage = params$end_date,
      collector_version = "world-bank-v1",
      fetch = function() fetch(params),
      max_age_days = params$collection_age_warning_days
    )
    normalized_path <- file.path(normalized_dir, file_name)
    if (source_id == "world_bank_population") {
      validate_world_bank_table(record$table, c("iso3c", "date"), "WORLD BANK POPULATION")
    }
    if (source_id == "world_bank_countries") {
      validate_world_bank_table(record$table, c("iso3c"), "WORLD BANK COUNTRIES")
    }
    if (source_id == "world_bank_gdp") {
      validate_world_bank_table(record$table, c("iso3c", "date"), "WORLD BANK GDP")
    }
    saveRDS(record$table, normalized_path)
    normalized_path
  }

  list(
    population = collect_one(
      "world_bank_population",
      list(indicator = "SP.POP.TOTL", start_date = 2004, end_date = params$end_date),
      fetch_population,
      sprintf("population_%d.rds", params$end_date)
    ),
    countries = collect_one(
      "world_bank_countries",
      list(operation = "wb_countries"),
      fetch_countries,
      "country_metadata.rds"
    ),
    oecd = collect_one(
      "world_bank_oecd",
      list(endpoint = "country?region=OED"),
      fetch_oecd,
      "oecd_countries.rds"
    ),
    gdp = collect_one(
      "world_bank_gdp",
      list(indicator = "NY.GDP.PCAP.PP.KD", start_date = 2004, end_date = params$end_date),
      fetch_gdp,
      sprintf("gdp_%d.rds", params$end_date)
    )
  )
}

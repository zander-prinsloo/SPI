# =============================================================================
# UN SDG DataCSV series: parity with sdg_indicators_for_SPI.R
# =============================================================================
# The legacy script runs unmodified in a separate R process with httr::POST
# mocked, here()/wb_countries() shadowed to a temporary project, and its two
# unused, uninstalled packages (flextable, ggpubr) skipped. No network calls.
#
# Created: 2026-10-23
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "collection_provenance.R"))
source(file.path(here::here("R"), "collection_io.R"))
source(file.path(here::here("R"), "collection_cache.R"))
source(file.path(here::here("R"), "collection_attestation.R"))
source(file.path(here::here("R"), "collection_status.R"))
source(file.path(here::here("R"), "collect_sdg.R"))
source(file.path(here::here("R"), "pull_unsdg.R"))

legacy_unsdg_script <- here::here("02_programs", "misc_scripts", "sdg_indicators_for_SPI.R")

unsdg_header <- c(
  "Goal", "Target", "Indicator", "SeriesCode", "SeriesDescription",
  "GeoAreaCode", "GeoAreaName", "TimePeriod", "Value", "Time_Detail",
  "TimeCoverage", "UpperBound", "LowerBound", "BasePeriod", "Source",
  "GeoInfoUrl", "FootNote", "[Nature]", "[Reporting Type]", "[Units]"
)

unsdg_fixture_bytes <- function(series, values) {
  rows <- data.frame(
    code = c("4", "4", "4", "8", "8", "248", "680", "1"),
    name = c("Afghanistan", "Afghanistan", "Afghanistan", "Albania", "Albania", "\u00c5land Islands", "Sark", "World"),
    year = c("2015", "2016", "2025", "2016", "2019", "2020", "2020", "2020"),
    nature = c("C", "E", "M", "N", "", "C", "C", "G"),
    stringsAsFactors = FALSE
  )
  quoted <- function(x) paste0("\"", x, "\"")
  lines <- vapply(seq_len(nrow(rows)), function(i) {
    paste(quoted(c(
      "17", "17.19", "17.19.2", series, "Series description, with comma",
      rows$code[[i]], rows$name[[i]], rows$year[[i]], values[[i]], rows$year[[i]],
      "", "", "", "", "Source text", "", "Footnote \"\"quoted\"\"",
      rows$nature[[i]], "G", "NUMBER"
    )), collapse = ",")
  }, character(1))
  charToRaw(enc2utf8(paste0(paste(c(paste(unsdg_header, collapse = ","), lines), collapse = "\r\n"), "\r\n")))
}

unsdg_fixtures <- function() {
  list(
    SG_REG_BRTH90N = unsdg_fixture_bytes("SG_REG_BRTH90N", c("1", "0", "1", "1", "NaN", "1", "0", "95")),
    SG_REG_DETH75N = unsdg_fixture_bytes("SG_REG_DETH75N", c("0", "1", "1", "0", "1", "0", "1", "80")),
    SG_STT_FPOS = unsdg_fixture_bytes("SG_STT_FPOS", c("1", "1", "1", "0", "1", "1", "1", "120")),
    SG_STT_NSDSFND = unsdg_fixture_bytes("SG_STT_NSDSFND", c("0", "0", "1", "1", "0", "1", "0", "70"))
  )
}

unsdg_metadata <- function() {
  tibble::tibble(
    iso3c = c("AFG", "ALB", "WLD"),
    iso2c = c("AF", "AL", "1W"),
    country = c("Afghanistan", "Albania", "World"),
    capital_city = c("Kabul", "Tirane", NA),
    longitude = c(69.1761, 19.8172, NA),
    latitude = c(34.5228, 41.3317, NA),
    region_iso3c = c("SAS", "ECS", NA),
    region_iso2c = c("8S", "Z7", NA),
    region = c("South Asia", "Europe & Central Asia", "Aggregates"),
    admin_region_iso3c = c("SAS", "ECA", NA),
    admin_region_iso2c = c("8S", "7E", NA),
    admin_region = c("South Asia", "Europe & Central Asia (excluding high income)", NA),
    income_level_iso3c = c("LIC", "UMC", NA),
    income_level_iso2c = c("XM", "XT", NA),
    income_level = c("Low income", "Upper middle income", "Aggregates"),
    lending_type_iso3c = c("IDX", "IBD", NA),
    lending_type_iso2c = c("XI", "XF", NA),
    lending_type = c("IDA", "IBRD", "Aggregates")
  )
}

unsdg_project <- function() {
  project <- withr::local_tempdir(.local_envir = parent.frame())
  for (dir in c("metadata", "4.2_SOAD", "5.1_DILG", "5.5_DIFI")) {
    dir.create(file.path(project, "01_raw_data", dir), recursive = TRUE)
  }
  writeLines(
    enc2utf8(c("country,geoAreaCode,iso3c", "Afghanistan,4,AFG", "Albania,8,ALB", "\u00c5land Islands,248,ALA", "Sark,680,")),
    file.path(project, "01_raw_data", "metadata", "iso_codes.csv"),
    useBytes = TRUE
  )
  project
}

unsdg_output_files <- function(raw_dir) {
  c(
    file.path(raw_dir, "4.2_SOAD", "SG_REG_BRTH90N.csv"),
    file.path(raw_dir, "4.2_SOAD", "SG_REG_DETH75N.csv"),
    file.path(raw_dir, "5.1_DILG", "SG_STT_FPOS.csv"),
    file.path(raw_dir, "5.5_DIFI", "SG_STT_NSDSFND.csv")
  )
}

run_legacy_unsdg <- function(project, fixtures, metadata) {
  callr::r(
    function(script, project, fixtures, metadata) {
      fake_post <- function(url = NULL, config = list(), ..., body = NULL, encode = NULL, handle = NULL) {
        series <- sub("^seriesCodes=([^&]+).*$", "\\1", body)
        target <- NULL
        for (arg in c(list(config), list(...))) {
          if (is.list(arg) && inherits(arg$output, "write_disk")) target <- arg$output$path
        }
        writeBin(fixtures[[series]], target)
        invisible(structure(list(status_code = 200L), class = "response"))
      }
      testthat::local_mocked_bindings(POST = fake_post, .package = "httr")
      env <- new.env(parent = globalenv())
      env$library <- function(package, ...) {
        package <- as.character(substitute(package))
        if (requireNamespace(package, quietly = TRUE)) {
          suppressPackageStartupMessages(base::library(package, character.only = TRUE))
        }
        invisible(NULL)
      }
      env$here <- function(...) file.path(project, ...)
      env$wb_countries <- function(...) metadata
      suppressMessages(sys.source(script, envir = env))
      invisible(TRUE)
    },
    args = list(
      script = legacy_unsdg_script,
      project = project,
      fixtures = fixtures,
      metadata = metadata
    )
  )
}

unsdg_params <- function(project) {
  list(
    raw_dir = file.path(project, "01_raw_data"),
    end_date = 2025,
    span = 2004:2025,
    collection_age_warning_days = 365
  )
}

test_that("the DataCSV port reproduces sdg_indicators_for_SPI.R outputs", {
  fixtures <- unsdg_fixtures()
  metadata <- unsdg_metadata()

  legacy_project <- unsdg_project()
  run_legacy_unsdg(legacy_project, fixtures, metadata)

  port_project <- unsdg_project()
  expect_warning(
    download_unsdg_series(
      unsdg_params(port_project),
      country_metadata = metadata,
      request_fn = function(series, start_year, end_year) fixtures[[series]]
    ),
    "UN SDG GEOAREA CODES DROPPED"
  )

  legacy_files <- unsdg_output_files(file.path(legacy_project, "01_raw_data"))
  port_files <- unsdg_output_files(file.path(port_project, "01_raw_data"))
  expect_true(all(file.exists(legacy_files)))
  expect_true(all(file.exists(port_files)))
  for (i in seq_along(legacy_files)) {
    legacy <- readr::read_csv(legacy_files[[i]], show_col_types = FALSE)
    port <- readr::read_csv(port_files[[i]], show_col_types = FALSE)
    expect_equal(port[, c("iso3c", "date", "Value", "Nature")], legacy[, c("iso3c", "date", "Value", "Nature")])
    expect_identical(readLines(port_files[[i]], encoding = "UTF-8"), readLines(legacy_files[[i]], encoding = "UTF-8"))
  }
})

test_that("DataCSV bodies lose NUL padding and possible truncation stops", {
  body <- charToRaw("a,b\r\n1,2\r\n")
  padded <- c(body, as.raw(rep(0, 1024 - length(body))))
  expect_identical(sdg_clean_csv_body(padded, "S"), body)
  expect_identical(sdg_clean_csv_body(body, "S"), body)

  full_buffer <- as.raw(rep(0x61, 65536))
  full_buffer[[65536]] <- as.raw(0x0a)
  expect_error(sdg_clean_csv_body(full_buffer, "S"), "POSSIBLY TRUNCATED")
  expect_error(sdg_clean_csv_body(charToRaw("a,b\r\n1,"), "S"), "POSSIBLY TRUNCATED")
  expect_error(sdg_clean_csv_body(c(charToRaw("a,b\r\n"), as.raw(0), charToRaw("1,2\r\n")), "S"), "EMBEDDED NUL")
  expect_error(sdg_clean_csv_body(as.raw(rep(0, 512)), "S"), "NO DATA")
})

test_that("a padded response gives the same series as an unpadded one", {
  fixtures <- unsdg_fixtures()
  pad <- function(bytes) c(bytes, as.raw(rep(0, 2^ceiling(log2(length(bytes) + 1)) - length(bytes))))
  clean_project <- unsdg_project()
  padded_project <- unsdg_project()
  suppressWarnings(download_unsdg_series(
    unsdg_params(clean_project), unsdg_metadata(),
    request_fn = function(series, start_year, end_year) sdg_clean_csv_body(fixtures[[series]], series)
  ))
  suppressWarnings(download_unsdg_series(
    unsdg_params(padded_project), unsdg_metadata(),
    request_fn = function(series, start_year, end_year) sdg_clean_csv_body(pad(fixtures[[series]]), series)
  ))
  expect_identical(
    lapply(unsdg_output_files(file.path(padded_project, "01_raw_data")), readLines),
    lapply(unsdg_output_files(file.path(clean_project, "01_raw_data")), readLines)
  )
})

test_that("all four series are written with release provenance that passes the gate", {
  project <- unsdg_project()
  params <- unsdg_params(project)
  fixtures <- unsdg_fixtures()
  result <- suppressWarnings(download_unsdg_series(
    params, unsdg_metadata(),
    request_fn = function(series, start_year, end_year) fixtures[[series]]
  ))

  expect_setequal(names(result), names(fixtures))
  files <- unsdg_output_files(params$raw_dir)
  expect_true(all(file.exists(files)))
  death <- readr::read_csv(files[[2]], show_col_types = FALSE)
  expect_equal(unique(death$SeriesCode), "SG_REG_DETH75N")
  expect_false(any(is.na(death$iso3c)))
  expect_false(any(c("680", "1") %in% death$geoAreaCode))
  for (file in files) {
    expect_match(read_artifact_provenance(file)$release_identifier, "UN SDG")
  }

  registry <- data.frame(
    source_id = "d4_2_crvs", dimension_id = "4.2", source_type = "api",
    normalized_path = "4.2_SOAD/SG_REG_BRTH90N.csv|4.2_SOAD/SG_REG_DETH75N.csv",
    expected_vintage_rule = "release_identifier", age_warning_days = 365,
    status_if_missing = "blocking", analyst_action = "Act", stringsAsFactors = FALSE
  )
  status <- evaluate_collection_status(registry, params$raw_dir, 2025)
  expect_equal(status$status, "informational")
  expect_match(status$observed_vintage, "UN SDG")
})

test_that("an unexpected column clash in the series stops instead of re-keying joins", {
  project <- unsdg_project()
  clash <- sub("GeoAreaName", "iso3c", rawToChar(unsdg_fixtures()$SG_STT_FPOS), fixed = TRUE)
  expect_error(
    download_unsdg_series(
      unsdg_params(project), unsdg_metadata(),
      request_fn = function(series, start_year, end_year) charToRaw(clash)
    ),
    "UN SDG SERIES COLUMN CLASH"
  )
})

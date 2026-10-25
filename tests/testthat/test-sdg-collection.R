# =============================================================================
# Pillar 3 (D3) scorer: parity with un_stats_cleaning.Rmd
# =============================================================================
# The unmodified Rmd is purled and its setup, api_indicators, api_download
# (un_pull), api_download2 (per-series loop), save (OECD blend), shape (grid
# fill) and saver chunks (un_aki_fun and the 5-year loop) run in a separate R
# process on synthetic fixtures, with wbstats::wb_countries() mocked and
# write_excel_csv() accepting the `path` argument that readr 2 removed.
# Download and plotting code is not run. No network.
#
# Created: 2026-10-05 (rewritten 2026-10-23 for the legacy D3 port)
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "collection_provenance.R"))
source(file.path(here::here("R"), "collection_io.R"))
source(file.path(here::here("R"), "collection_cache.R"))
source(file.path(here::here("R"), "collection_attestation.R"))
source(file.path(here::here("R"), "collection_status.R"))
source(file.path(here::here("R"), "pull_unsdg.R"))
source(file.path(here::here("R"), "collect_sdg.R"))

# --- Fixtures -------------------------------------------------------------------

d3_list_fixture <- function() {
  data.frame(
    goal = c(1, 1, 7, 12, 1, 17, 1, 1),
    target = c("1.1", "1.1", "7.b", "12.a", "1.2", "17.18", "1.3", "1.4"),
    code = c("1.1.1", "1.1.1", "7.b.1", "12.a.1", "1.2.1", "17.18.2", "1.3.1", "1.4.1"),
    code1 = c("SI_POV_A", "SI_POV_B", "EG_EGY_X", "EG_EGY_X", "SI_POV_T2", "SG_STT_X", "SI_COV_X", "SI_ACS_X"),
    description1 = c("Poverty A", "Poverty B", "Energy", "Energy", "Tier 2 series", "Statistics", "Coverage", "Access"),
    Tier_Nov2020 = c(1, 1, 1, 1, 2, 1, 1, 1),
    stringsAsFactors = FALSE
  )
}

d3_iso_lines <- c("country,geoAreaCode,iso3c", "World,1,WLD", "A land,4,AAA", "B land,8,BBB", "C land,12,CCC", "D land,16,DDD", "Sark,680,")

d3_snapshot <- function() {
  tibble::tibble(
    iso3c = c("AAA", "BBB", "CCC", "WLD"),
    country = c("A land", "B land", "C land", "World"),
    region = c("Region 1", "Region 2", "Region 3", "Aggregates"),
    income_level = c("Low income", "High income", "Upper middle income", "Aggregates")
  )
}

d3_legacy_country_metadata <- function() {
  tibble::tibble(
    iso3c = c("AAA", "BBB", "CCC"),
    country = c("A land", "B land", "C land"),
    region = c("Region 1", "Region 2", "Region 3"),
    income = c("Low income", "High income", "Upper middle income")
  )
}

d3_raw_bytes <- function(series, rows) {
  header <- c("Goal", "Target", "Indicator", "SeriesCode", "SeriesDescription", "GeoAreaCode",
              "GeoAreaName", "TimePeriod", "Value", "Time_Detail", "TimeCoverage", "UpperBound",
              "LowerBound", "BasePeriod", "Source", "GeoInfoUrl", "FootNote", "[Nature]", "[Sex]",
              "[Reporting Type]", "[Units]")
  q <- function(x) paste0("\"", x, "\"")
  body <- vapply(seq_len(nrow(rows)), function(i) {
    paste(q(c("1", "1.1", "1.1.1", series, "Description", rows$geo[[i]], "Area", rows$year[[i]],
              rows$value[[i]], rows$year[[i]], "", "", "", "", "Source", "", "", rows$nature[[i]],
              rows$sex[[i]], "G", "PERCENT")), collapse = ",")
  }, character(1))
  charToRaw(paste0(paste(c(paste(header, collapse = ","), body), collapse = "\r\n"), "\r\n"))
}

d3_series_rows <- function(...) {
  rows <- data.frame(..., stringsAsFactors = FALSE)
  if (!"sex" %in% names(rows)) rows$sex <- "_T"
  rows
}

d3_raw_fixtures <- function() {
  list(
    SI_POV_A = d3_raw_bytes("SI_POV_A", d3_series_rows(
      geo = c("4", "4", "4", "8", "16", "680", "1"),
      year = c("2016", "2019", "2022", "2020", "2018", "2019", "2019"),
      value = c("10", "11", "12", "20", "30", "40", "50"),
      nature = c("C", "M", "E", "CA", "C", "C", "G")
    )),
    SI_POV_B = d3_raw_bytes("SI_POV_B", d3_series_rows(
      geo = c("4", "4", "8", "12"),
      year = c("2023", "2023", "2017", "2024"),
      value = c("5", "6", "7", "8"),
      nature = c("C", "M", "N", "C"),
      sex = c("F", "M", "_T", "_T")
    )),
    EG_EGY_X = d3_raw_bytes("EG_EGY_X", d3_series_rows(
      geo = c("4", "8", "12"),
      year = c("2021", "2022", "2015"),
      value = c("1", "2", "3"),
      nature = c("C", "C", "M")
    )),
    SI_POV_T2 = d3_raw_bytes("SI_POV_T2", d3_series_rows(
      geo = "4", year = "2020", value = "9", nature = "C"
    )),
    SG_STT_X = d3_raw_bytes("SG_STT_X", d3_series_rows(
      geo = c("4", "8", "12"),
      year = c("2018", "2020", "2024"),
      value = c("1", "1", "NaN"),
      nature = c("C", "C", "C")
    )),
    SI_COV_X = d3_raw_bytes("SI_COV_X", d3_series_rows(
      geo = c("4", "8"), year = c("2022", "2019"), value = c("3", "4"), nature = c("C", "C")
    )),
    SI_ACS_X = d3_raw_bytes("SI_ACS_X", d3_series_rows(
      geo = c("12", "4"), year = c("2023", "2016"), value = c("5", "6"), nature = c("C", "M")
    ))
  )
}

d3_oecd_fixture <- function() {
  data.frame(
    iso3c = c("CCC", "CCC", "BBB", "AAA"),
    date = c(2021, 2019, 2024, 2016),
    goal = c(7, 17, 12, 1),
    code = c("7.b.1", "17.18.2", "12.a.1", "1.1.1"),
    ind_value.oecd = c(5, 1, 1, 1),
    ind_quality.oecd = c(1, 1, 1, 0),
    ind_metadata.oecd = "OECD",
    stringsAsFactors = FALSE
  )
}

d3_project <- function(raw = TRUE) {
  root <- withr::local_tempdir(.local_envir = parent.frame())
  raw_dir <- file.path(root, "01_raw_data")
  for (dir in c("metadata", "oecd_data", "sdg_data/raw")) {
    dir.create(file.path(raw_dir, dir), recursive = TRUE, showWarnings = FALSE)
  }
  dir.create(file.path(root, "03_output_data"), showWarnings = FALSE)
  writeLines(d3_iso_lines, file.path(raw_dir, "iso_codes.csv"))
  writeLines(d3_iso_lines, file.path(raw_dir, "metadata", "iso_codes.csv"))
  readr::write_csv(d3_list_fixture(), file.path(raw_dir, "metadata", "SDG_indicator_list.csv"))
  readr::write_csv(d3_oecd_fixture(), file.path(raw_dir, "oecd_data", "OECD_data_scored.csv"))
  if (raw) {
    fixtures <- d3_raw_fixtures()
    for (series in names(fixtures)) {
      writeBin(fixtures[[series]], file.path(raw_dir, "sdg_data", "raw", paste0(series, "_raw.csv")))
    }
  }
  root
}

d3_params <- function(root, end_date = 2024) {
  list(
    raw_dir = file.path(root, "01_raw_data"),
    end_date = end_date,
    sdg_indicator_list_file = file.path(root, "01_raw_data", "metadata", "SDG_indicator_list.csv"),
    collection_age_warning_days = 365
  )
}

d3_request <- function(calls = NULL) {
  fixtures <- d3_raw_fixtures()
  function(series, start_year, end_year) {
    if (!is.null(calls)) calls$series <- c(calls$series, series)
    fixtures[[series]]
  }
}

# --- Legacy harness -------------------------------------------------------------

legacy_d3_exprs <- function() {
  purled <- tempfile(fileext = ".R")
  on.exit(unlink(purled), add = TRUE)
  knitr::purl(here::here("02_programs", "misc_scripts", "un_stats_cleaning.Rmd"), output = purled, documentation = 1, quiet = TRUE)
  lines <- readLines(purled, warn = FALSE)
  starts <- grep("^## ----", lines)
  labels <- sub("^## ----([^-,]*).*$", "\\1", lines[starts])
  ends <- c(starts[-1] - 1L, length(lines))
  chunk <- function(label) {
    i <- which(labels == label)
    stopifnot(length(i) == 1L)
    parse(text = lines[(starts[[i]] + 1L):ends[[i]]], keep.source = FALSE)
  }
  assigned <- function(e) if (is.call(e) && identical(e[[1]], as.name("<-"))) deparse(e[[2]]) else ""
  setup <- chunk("setup")
  setup <- setup[vapply(setup, assigned, "") %in% c("iso3c", "span", "iso_empty", "upper_year", "lower_year", "window")]
  saver <- chunk("saver")
  aki_def <- saver[vapply(saver, assigned, "") == "un_aki_fun"]
  text <- vapply(saver, function(e) paste(deparse(e), collapse = " "), "")
  five <- which(grepl("i - 4", text, fixed = TRUE) & grepl("un_aki_fun(start, end)", text, fixed = TRUE))[1]
  block <- saver[five:(five + 3L)]
  stopifnot(grepl("SPI_D3_UNSD_data_5yr.csv", paste(deparse(block[[4]]), collapse = " "), fixed = TRUE))
  c(as.list(setup), as.list(chunk("api_indicators")), as.list(chunk("api_download")),
    as.list(chunk("api_download2")), as.list(chunk("save")), as.list(chunk("shape")),
    as.list(aki_def), as.list(block))
}

run_legacy_d3 <- function(root) {
  callr::r(
    function(exprs, raw_dir, output_dir, wb, country_metadata) {
      suppressPackageStartupMessages(library(tidyverse))
      testthat::local_mocked_bindings(wb_countries = function(...) wb, .package = "wbstats")
      env <- new.env(parent = globalenv())
      env$raw_dir <- raw_dir
      env$output_dir <- output_dir
      env$country_metadata <- country_metadata
      # readr 2 removed write_excel_csv()'s `path` argument used by the Rmd.
      env$write_excel_csv <- function(x, file = path, path = NULL, ...) {
        readr::write_excel_csv(x, file = if (is.null(path)) file else path, ...)
      }
      for (e in exprs) suppressWarnings(suppressMessages(eval(e, env)))
      invisible(TRUE)
    },
    args = list(
      exprs = legacy_d3_exprs(),
      raw_dir = file.path(root, "01_raw_data"),
      output_dir = file.path(root, "03_output_data"),
      wb = tibble::tibble(iso3c = d3_snapshot()$iso3c, region = d3_snapshot()$region),
      country_metadata = d3_legacy_country_metadata()
    )
  )
  file.path(root, "03_output_data", "SPI_D3_UNSD_data_5yr.csv")
}

# --- Tests ----------------------------------------------------------------------

test_that("the port reproduces the legacy Rmd scores", {
  legacy_root <- d3_project()
  legacy_path <- run_legacy_d3(legacy_root)
  expect_true(all(file.exists(file.path(legacy_root, "01_raw_data", "sdg_data", paste0(unique(d3_list_fixture()$code1), ".csv")))))
  legacy <- readr::read_csv(legacy_path, show_col_types = FALSE)

  port_root <- d3_project(raw = FALSE)
  result <- collect_d3_scores(d3_params(port_root), d3_snapshot(), request_fn = d3_request(), required_goals = c(1, 7, 12, 17))
  port <- readr::read_csv(result$path, show_col_types = FALSE)

  expect_setequal(names(port), names(legacy))
  expect_equal(nrow(port), nrow(legacy))
  expect_equal(port$iso3c, legacy$iso3c)
  expect_equal(port$date, legacy$date)
  for (column in grep("^SPI\\.D3\\.", names(legacy), value = TRUE)) {
    expect_equal(port[[column]], legacy[[column]], tolerance = 1e-9, label = column)
  }
  expect_equal(port[c("country", "region", "income")], legacy[c("country", "region", "income")])
})

test_that("multi-goal series, Tier-1 filter, OECD blend and missing years follow the legacy rules", {
  root <- d3_project(raw = FALSE)
  calls <- new.env()
  calls$series <- character()
  result <- collect_d3_scores(d3_params(root), d3_snapshot(), request_fn = d3_request(calls), required_goals = c(1, 7, 12, 17))
  scores <- readr::read_csv(result$path, show_col_types = FALSE)
  at <- function(iso, year, column) scores[[column]][scores$iso3c == iso & scores$date == year]

  expect_setequal(calls$series, c("SI_POV_A", "SI_POV_B", "EG_EGY_X", "SG_STT_X", "SI_COV_X", "SI_ACS_X"))
  # Three goal-1 indicators give thirds, which the legacy rounds to 3 places.
  expect_true(any(scores$SPI.D3.1 %in% c(0.333, 0.667)))
  expect_equal(at("AAA", 2021, "SPI.D3.7"), 1)
  expect_equal(at("AAA", 2021, "SPI.D3.12"), 1)
  # OECD raises a UN quality of 0 in a year the series is reported...
  expect_equal(at("CCC", 2021, "SPI.D3.7"), 1)
  expect_equal(at("CCC", 2021, "SPI.D3.12"), 0)
  # ...but not a missing UN quality (no country reported that year).
  expect_equal(at("CCC", 2019, "SPI.D3.17"), 0)
  expect_equal(at("BBB", 2024, "SPI.D3.12"), 1)
  expect_equal(at("CCC", 2024, "SPI.D3.17"), 0)
  expect_setequal(unique(scores$iso3c), c("AAA", "BBB", "CCC"))
  expect_equal(sort(unique(scores$date)), 2004:2024)
})

test_that("only the end_date folder is written, with provenance that passes the gate", {
  root <- d3_project(raw = FALSE)
  result <- collect_d3_scores(d3_params(root, end_date = 2025), d3_snapshot(), request_fn = d3_request(), required_goals = c(1, 7, 12, 17))
  expect_equal(list.files(file.path(root, "01_raw_data", "3_DP")), c("2025", "sdg_data"))
  cached <- list.files(file.path(root, "01_raw_data", "3_DP", "sdg_data", "raw"), pattern = "\\.raw$", full.names = TRUE)
  expect_true(all(vapply(cached, function(f) identical(readBin(f, "raw", 2), as.raw(c(0x1f, 0x8b))), logical(1))))
  scores <- readr::read_csv(result$path, show_col_types = FALSE)
  expect_equal(max(scores$date), 2025)
  expect_equal(names(scores)[1:5], c("iso3c", "date", "country", "region", "income"))
  expect_equal(names(scores)[-(1:5)], paste0("SPI.D3.", c(1, 7, 12, 17)))

  registry <- data.frame(
    source_id = "d3_1_sdg", dimension_id = "3.1", source_type = "api",
    normalized_path = "3_DP/<END_DATE>/SPI_D3_UNSD_data_5yr.csv",
    expected_vintage_rule = "release_identifier", age_warning_days = 365,
    status_if_missing = "blocking", analyst_action = "Act", stringsAsFactors = FALSE
  )
  status <- evaluate_collection_status(registry, file.path(root, "01_raw_data"), 2025)
  expect_equal(status$status, "informational")
  expect_match(status$observed_vintage, "6 Tier-1 series")
})

test_that("missing inputs and unscored goals stop", {
  root <- d3_project(raw = FALSE)
  unlink(file.path(root, "01_raw_data", "oecd_data", "OECD_data_scored.csv"))
  expect_error(collect_d3_scores(d3_params(root), d3_snapshot(), request_fn = d3_request(), required_goals = 1), "OECD SCORES NOT FOUND")

  root <- d3_project(raw = FALSE)
  expect_error(collect_d3_scores(d3_params(root), d3_snapshot(), request_fn = d3_request()), "D3 SCORES MISSING GOAL COLUMNS")

  root <- d3_project(raw = FALSE)
  expect_error(
    collect_d3_scores(d3_params(root), d3_snapshot(), request_fn = function(series, start_year, end_year) stop("API down"), required_goals = 1),
    "API down"
  )
})

test_that("unknown SDG geography codes stop instead of becoming zeros", {
  raw <- data.frame(
    TimePeriod = 2020,
    `[Nature]` = "C",
    GeoAreaCode = "9999",
    Value = "1",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  iso <- tibble::tibble(geoAreaCode = "4", iso3c = "AAA")
  expect_error(
    d3_series_quality(raw, iso, 2020, series = "TEST"),
    "UNKNOWN GEOGRAPHY CODE.*9999"
  )
})

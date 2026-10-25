# =============================================================================
# JMP safely managed water collection: parity with the original hyper_read()
# =============================================================================
# The unmodified hyper_read() and its year template are taken from the
# `safely_managed` chunk of 02_programs/01-SPI_data_prep.Rmd and run in a
# separate R process with download.file() shadowed to copy a synthetic
# workbook (tests/fixtures/jmp/, built by make_jmp_fixtures.R). No network.
#
# Created: 2026-10-23
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "collection_provenance.R"))
source(file.path(here::here("R"), "collection_io.R"))
source(file.path(here::here("R"), "collection_cache.R"))
source(file.path(here::here("R"), "collection_attestation.R"))
source(file.path(here::here("R"), "collection_status.R"))
source(file.path(here::here("R"), "pull_jmp.R"))
source(file.path(here::here("R"), "dim1_5.R"))

jmp_fixture <- function(iso3c) here::here("tests", "fixtures", "jmp", paste0(iso3c, ".xlsx"))

legacy_jmp_definitions <- function() {
  lines <- readLines(here::here("02_programs", "01-SPI_data_prep.Rmd"), warn = FALSE)
  start <- grep("^```\\{r safely_managed,", lines)
  stopifnot(length(start) == 1L)
  end <- start + which(grepl("^```\\s*$", lines[(start + 1):length(lines)]))[1]
  exprs <- parse(text = lines[(start + 1):(end - 1)], keep.source = FALSE)
  wanted <- c("span", "smw_template_df", "smw_empty_df", "hyper_read")
  keep <- vapply(exprs, function(e) {
    is.call(e) && identical(e[[1]], as.name("<-")) && as.character(e[[2]]) %in% wanted
  }, logical(1))
  stopifnot(sum(keep) == length(wanted))
  exprs[keep]
}

run_legacy_hyper_read <- function(workbook, end_date) {
  callr::r(
    function(exprs, workbook, end_date) {
      suppressPackageStartupMessages({
        library(dplyr)
        library(tidyr)
        library(readxl)
      })
      env <- new.env(parent = globalenv())
      env$end_date <- end_date
      env$download.file <- function(url, destfile, ...) file.copy(workbook, destfile, overwrite = TRUE)
      for (e in exprs) eval(e, env)
      out <- suppressWarnings(suppressMessages(env$hyper_read("https://washdata.org/data/country/XXX/household/download")))
      as.data.frame(dplyr::mutate(out, source = as.character(source), type = as.character(type)))
    },
    args = list(exprs = legacy_jmp_definitions(), workbook = workbook, end_date = end_date)
  )
}

jmp_metadata <- function() {
  tibble::tibble(
    iso3c = c("AAA", "BBB", "CCC", "WLD"),
    iso2c = c("AA", "BB", "CC", "1W"),
    country = c("A land", "B land", "C land", "World"),
    region = c("Region 1", "Region 2", "Region 3", "Aggregates"),
    income_level = c("Low income", "High income", "Upper middle income", "Aggregates")
  )
}

fixture_fetcher <- function(counter = NULL) {
  function(iso3c) {
    if (!is.null(counter)) counter$n <- counter$n + 1L
    jmp_fetch_data_summary(iso3c, download_fn = function(url, destfile) {
      file.copy(jmp_fixture(iso3c), destfile, overwrite = TRUE)
      list(effective_url = paste0("https://washdata.org/media/", iso3c, "/download"))
    })
  }
}

test_that("the port reproduces the original hyper_read() on every fixture", {
  for (iso3c in c("AAA", "BBB", "CCC")) {
    for (end_date in c(2024, 2025)) {
      legacy <- run_legacy_hyper_read(jmp_fixture(iso3c), end_date)
      expect_gt(nrow(legacy), 3)
      port <- as.data.frame(parse_jmp_data_summary(jmp_read_sheet_text(jmp_fixture(iso3c)), iso3c, end_date))
      # 202611 correction: the legacy method treats empty -99 template rows
      # as qualifying data. The port intentionally assigns those rows zero
      # quality, while preserving all other legacy values.
      legacy$data_quality[is.na(legacy$data_quality) | legacy$max_value == -99] <- 0
      expect_equal(port, legacy[, names(port)], label = paste(iso3c, end_date))
    }
  }
})

test_that("the cached sheet text gives the same result as the workbook", {
  sheet <- jmp_read_sheet_text(jmp_fixture("AAA"))
  path <- withr::local_tempfile(fileext = ".csv")
  writeBin(jmp_sheet_csv(sheet), path)
  cached <- jmp_read_cached_sheet(path)
  expect_identical(unname(lapply(cached, as.character)), unname(lapply(sheet, as.character)))
  expect_identical(
    parse_jmp_data_summary(cached, "AAA", 2025),
    parse_jmp_data_summary(sheet, "AAA", 2025)
  )
})

test_that("the documented behaviours of the original method are kept", {
  aaa <- parse_jmp_data_summary(jmp_read_sheet_text(jmp_fixture("AAA")), "AAA", 2025)
  expect_false(any(aaa$source %in% "AAA_1997_MICS"))
  expect_true(all(is.na(aaa$source[aaa$geo == "National"])))
  expect_true(all(aaa$data_quality[aaa$geo == "National"] == 0))
  dhs <- aaa[aaa$source %in% "AAA_2008_DHS" & aaa$geo == "Urban", ]
  expect_equal(dhs$data_available, 1)
  expect_equal(dhs$data_quality, 0)

  bbb <- parse_jmp_data_summary(jmp_read_sheet_text(jmp_fixture("BBB")), "BBB", 2025)
  expect_true(all(bbb$data_quality[bbb$geo == "Urban"] == 1))
  expect_true(any(!is.na(bbb$source[bbb$geo == "National"])))

  ccc <- parse_jmp_data_summary(jmp_read_sheet_text(jmp_fixture("CCC")), "CCC", 2025)
  expect_equal(nrow(ccc), 3 * length(2000:2025))
  expect_true(all(ccc$data_quality == 0))
  expect_true(all(ccc$max_value == -99))
})

test_that("layout drift stops instead of producing silent zeros", {
  expect_error(jmp_read_sheet_text(jmp_fixture("AAA"), "Nope"), "NO 'Nope' SHEET")
  sheet <- jmp_read_sheet_text(jmp_fixture("AAA"))

  no_header <- sheet
  no_header[5, 1] <- "Source"
  expect_error(parse_jmp_data_summary(no_header, "AAA", 2025), "HEADER ROW NOT FOUND")

  no_rural <- sheet
  no_rural[5, ] <- as.list(sub("_r$", "_x", unlist(no_rural[5, ])))
  expect_error(parse_jmp_data_summary(no_rural, "AAA", 2025), "NO URBAN AND RURAL WATER COLUMNS")

  odd_year <- sheet
  odd_year[7, 3] <- "2003-04"
  expect_error(parse_jmp_data_summary(odd_year, "AAA", 2025), "NON-NUMERIC YEARS")
})

test_that("collection caches only the Data Summary sheet with workbook identity", {
  root <- withr::local_tempdir()
  params <- list(raw_dir = root, end_date = 2025, collection_age_warning_days = 365, collection_dir = file.path(root, "_collection"))
  counter <- new.env()
  counter$n <- 0L

  result <- pull_jmp_water(params, jmp_metadata(), fetch_fn = fixture_fetcher(counter))
  expect_equal(counter$n, 3L)
  expect_equal(result$countries, 3L)

  cache <- file.path(root, "1.5_DUIO", "raw", "jmp")
  expect_length(list.files(cache, pattern = "\\.raw$"), 3L)
  expect_length(list.files(cache, pattern = "\\.xlsx$"), 0L)
  provenance <- jsonlite::read_json(list.files(cache, pattern = "^jmp_AAA-.*\\.json$", full.names = TRUE), simplifyVector = TRUE)
  expect_equal(provenance$workbook_sha256, digest::digest(jmp_fixture("AAA"), algo = "sha256", file = TRUE))
  expect_equal(provenance$workbook_url, "https://washdata.org/data/country/AAA/household/download")
  expect_equal(provenance$workbook_effective_url, "https://washdata.org/media/AAA/download")
  expect_equal(provenance$jmp_release, "Updated August 2025")
  expect_equal(provenance$sheet, "Data Summary")

  pull_jmp_water(params, jmp_metadata(), fetch_fn = fixture_fetcher(counter))
  expect_equal(counter$n, 3L)

  output <- result$path
  expect_identical(readBin(output, "raw", 3), as.raw(c(0xef, 0xbb, 0xbf)))
  data <- readr::read_csv(output, show_col_types = FALSE)
  expect_equal(
    names(data),
    c(names(jmp_metadata()), "hyperlink", "source", "type", "year", "geo",
      "data_available", "data_quality", "data_value", "max_value")
  )
  expect_setequal(unique(data$iso3c), c("AAA", "BBB", "CCC"))
  expect_match(read_artifact_provenance(output)$release_identifier, "Updated August 2025")

  registry <- data.frame(
    source_id = "d1_5_jmp", dimension_id = "1.5", source_type = "api",
    normalized_path = "1.5_DUIO/Safely_Managed_Water_data.csv",
    expected_vintage_rule = "release_identifier", age_warning_days = 365,
    status_if_missing = "blocking", analyst_action = "Act", stringsAsFactors = FALSE
  )
  expect_equal(evaluate_collection_status(registry, root, 2025)$status, "informational")

  scores <- score_safely_managed_water(data, list(end_date = 2025))
  expect_setequal(unique(scores$iso3c), c("AAA", "BBB", "CCC"))
  expect_true(all(scores$SPI.D1.5.SAFE.MAN.WATER %in% c(0, 0.5, 1)))
})

test_that("Kosovo uses the Serbia country file", {
  expect_equal(jmp_country_url("XKX"), "https://washdata.org/data/country/SRB/household/download")
})

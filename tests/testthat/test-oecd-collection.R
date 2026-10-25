# =============================================================================
# OECD SDG collection: parity with oecd_bulk_download.R
# =============================================================================
# The unmodified script runs in a separate R process with download.file()
# shadowed to copy a fixture and here() pointing at a temporary project. The
# fixture is 226 rows of the public OECD SDG bulk CSV (dataflow
# OECD.WISE.RSB:DSD_SDG@DF_SDG(1.0), downloaded 2026-10-23) for AUS, AUT and
# CHL, 2019-2023: seven indicator codes including two multi-code ones and two
# complete groups with several sources; two OBS_VALUE cells were blanked to
# exercise the quality rule. No network.
#
# Created: 2026-10-23
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "collection_provenance.R"))
source(file.path(here::here("R"), "collection_io.R"))
source(file.path(here::here("R"), "collection_cache.R"))
source(file.path(here::here("R"), "collection_attestation.R"))
source(file.path(here::here("R"), "collection_status.R"))
source(file.path(here::here("R"), "collection_registry.R"))
source(file.path(here::here("R"), "collect_oecd.R"))

oecd_fixture <- here::here("tests", "fixtures", "oecd", "oecd_sdg_sample.csv")

copy_download <- function(source) {
  function(url, destfile) {
    file.copy(source, destfile, overwrite = TRUE)
    list(effective_url = url)
  }
}

run_legacy_oecd <- function(root, fixture) {
  dir.create(file.path(root, "01_raw_data", "oecd_data"), recursive = TRUE, showWarnings = FALSE)
  callr::r(
    function(script, root, fixture) {
      env <- new.env(parent = globalenv())
      env$here <- function(...) file.path(root, ...)
      env$download.file <- function(url, destfile, ...) file.copy(fixture, destfile, overwrite = TRUE)
      suppressPackageStartupMessages(suppressMessages(sys.source(script, envir = env)))
      invisible(TRUE)
    },
    args = list(
      script = here::here("02_programs", "misc_scripts", "oecd_bulk_download.R"),
      root = root,
      fixture = fixture
    )
  )
  file.path(root, "01_raw_data", "oecd_data", "OECD_data_scored.csv")
}

oecd_params <- function(root) {
  list(raw_dir = file.path(root, "01_raw_data"), end_date = 2025, collection_age_warning_days = 365)
}

test_that("the port reproduces oecd_bulk_download.R", {
  legacy <- run_legacy_oecd(withr::local_tempdir(), oecd_fixture)
  root <- withr::local_tempdir()
  result <- collect_oecd_sdg(oecd_params(root), fetch_fn = function() oecd_fetch_sdg(copy_download(oecd_fixture)))

  expect_true(file.exists(legacy))
  expect_identical(readLines(result$path), readLines(legacy))
  expect_gt(result$rows, 0)
})

test_that("multi-code indicators are split and missing values lower quality", {
  scored <- transform_oecd_sdg(readr::read_csv(oecd_fixture, show_col_types = FALSE))
  split <- scored[scored$iso3c == "AUS" & scored$goal == "1", ]
  expect_true(all(c("1.5.1", "11.5.1", "13.1.1") %in% split$code))
  expect_false(any(grepl("/", scored$code)))
  expect_true(all(scored$ind_quality.oecd %in% c(0, 1)))
  expect_true(all(scored$goal %in% as.character(1:17)))
})

test_that("the full download is cached compressed with its identity", {
  root <- withr::local_tempdir()
  calls <- 0L
  fetch <- function() {
    calls <<- calls + 1L
    oecd_fetch_sdg(copy_download(oecd_fixture))
  }
  result <- collect_oecd_sdg(oecd_params(root), fetch_fn = fetch)
  collect_oecd_sdg(oecd_params(root), fetch_fn = fetch)
  expect_equal(calls, 1L)

  cache <- file.path(root, "01_raw_data", "oecd_data", "raw")
  raw <- list.files(cache, pattern = "\\.raw$", full.names = TRUE)
  expect_length(raw, 1L)
  expect_identical(readLines(gzfile(raw)), readLines(oecd_fixture))
  provenance <- jsonlite::read_json(paste0(raw, ".json"), simplifyVector = TRUE)
  expect_equal(provenance$download_sha256, digest::digest(oecd_fixture, algo = "sha256", file = TRUE))
  expect_equal(provenance$compression, "gzip")

  expect_match(read_artifact_provenance(result$path)$release_identifier, "DSD_SDG@DF_SDG\\(1.0\\)")
  registry <- load_source_registry(here::here("config", "source_registry.R"))
  source <- registry[registry$source_id == "d3_oecd_sdg", , drop = FALSE]
  expect_equal(nrow(source), 1L)
  expect_equal(source$expected_vintage_rule, "release_identifier")
  status <- evaluate_collection_status(source, file.path(root, "01_raw_data"), 2025)
  expect_equal(status$status, "informational")
})

test_that("an empty download or a header-only file stops", {
  empty <- withr::local_tempfile(fileext = ".csv")
  file.create(empty)
  expect_error(oecd_fetch_sdg(copy_download(empty)), "OECD SDG DOWNLOAD IS EMPTY")

  header_only <- withr::local_tempfile(fileext = ".csv")
  writeLines(readLines(oecd_fixture, n = 1L), header_only)
  expect_error(
    collect_oecd_sdg(oecd_params(withr::local_tempdir()), fetch_fn = function() oecd_fetch_sdg(copy_download(header_only))),
    "OECD SDG DATA HAS NO ROWS"
  )
})

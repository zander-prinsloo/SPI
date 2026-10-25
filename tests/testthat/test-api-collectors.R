# =============================================================================
# API-backed collector tests
# =============================================================================
# Created: 2026-10-05
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "collection_provenance.R"))
source(file.path(here::here("R"), "collection_io.R"))
source(file.path(here::here("R"), "collection_cache.R"))
source(file.path(here::here("R"), "collection_attestation.R"))
source(file.path(here::here("R"), "collect_pip.R"))
source(file.path(here::here("R"), "collect_world_bank.R"))

test_that("PIP collector writes the normalized comparability artifact", {
  root <- tempfile("pip-collector-")
  fetch <- function() {
    data.frame(
      survey_acronym = "HBS",
      country_code = "AAA",
      year = 2020,
      survey_comparability = 1,
      survey_coverage = "national",
      reporting_level = "national",
      welfare_type = "consumption",
      stringsAsFactors = FALSE
    )
  }

  result <- collect_pip_comparability(
    raw_dir = root,
    fetch_fn = fetch,
    vintage = 2024,
    release = "test-release"
  )

  expect_true(file.exists(result$normalized_path))
  expect_true(file.exists(result$provenance_path))
  expect_equal(readr::read_csv(result$normalized_path, show_col_types = FALSE)$country_code, "AAA")
})

test_that("World Bank collectors write cached source artifacts", {
  root <- tempfile("world-bank-collector-")
  params <- list(
    raw_dir = root,
    collection_dir = file.path(root, "_collection"),
    end_date = 2024,
    span = 2004:2024
  )
  result <- collect_world_bank_inputs(
    params,
    fetch_population = function(params) data.frame(iso3c = "AAA", date = 2024, population = 10),
    fetch_countries = function(params) data.frame(iso3c = "AAA", country = "A", region = "R"),
    fetch_oecd = function(params) c("AAA"),
    fetch_gdp = function(params) data.frame(iso3c = "AAA", date = 2024, gdp = 100)
  )

  expect_true(all(file.exists(unlist(result))))
  expect_equal(readRDS(result$population)$population, 10)
  expect_equal(readRDS(result$oecd), "AAA")
})

test_that("PIP collector rejects duplicate survey keys", {
  expect_error(
    collect_pip_comparability(
      raw_dir = tempfile("pip-duplicate-"),
      fetch_fn = function() data.frame(
        survey_acronym = c("HBS", "HBS"),
        country_code = c("AAA", "AAA"),
        year = c(2020, 2020),
        survey_comparability = c(1, 1),
        survey_coverage = c("national", "national"),
        reporting_level = c("national", "national"),
        welfare_type = c("consumption", "consumption")
      ),
      vintage = 2024,
      release = "test-release"
    ),
    "KEY VIOLATION"
  )
})

test_that("World Bank collectors reject duplicate country-year rows", {
  expect_error(
    collect_world_bank_inputs(
      list(
        raw_dir = tempfile("world-bank-duplicate-"),
        collection_dir = tempfile("world-bank-cache-"),
        end_date = 2024,
        collection_age_warning_days = 365
      ),
      fetch_population = function(params) data.frame(
        iso3c = c("AAA", "AAA"), date = c(2024, 2024), population = c(1, 2)
      ),
      fetch_countries = function(params) data.frame(iso3c = "AAA"),
      fetch_oecd = function(params) "AAA",
      fetch_gdp = function(params) data.frame(iso3c = "AAA", date = 2024, gdp = 1)
    ),
    "KEY VIOLATION"
  )
})

# --- 202611 readiness plan, Step 7: PIP most recent public release ----------

pip_versions_fixture <- function() {
  data.frame(
    version = c(
      "20260324_2021_01_02_PROD", "20260922_2017_01_02_PROD",
      "20260922_2021_01_02_PROD", "20261015_2021_01_02_INT",
      "20250930_2021_01_02_PROD"
    ),
    release_version = c("20260324", "20260922", "20260922", "20261015", "20250930"),
    ppp_version = c("2021", "2017", "2021", "2021", "2021"),
    identity = c("PROD", "PROD", "PROD", "INT", "PROD"),
    stringsAsFactors = FALSE
  )
}

pip_fixture <- function(n_levels = 1) {
  levels <- c("national", "urban", "rural")[seq_len(n_levels)]
  data.frame(
    survey_acronym = "HBS",
    country_code = "AAA",
    year = 2020,
    survey_comparability = 1,
    survey_coverage = "national",
    reporting_level = levels,
    welfare_type = "consumption",
    stringsAsFactors = FALSE
  )
}

test_that("the newest PROD PIP release for the PPP version is resolved", {
  expect_equal(
    resolve_pip_release(versions_fn = pip_versions_fixture, ppp_version = 2021),
    "20260922_2021_01_02_PROD"
  )
  expect_equal(
    resolve_pip_release(versions_fn = pip_versions_fixture, ppp_version = 2017),
    "20260922_2017_01_02_PROD"
  )
  expect_error(
    resolve_pip_release(versions_fn = pip_versions_fixture, ppp_version = 2011),
    "NO PIP PROD RELEASE"
  )
})

test_that("a locked PIP release overrides resolution without querying versions", {
  offline <- function() stop("network unavailable")
  expect_equal(
    resolve_pip_release(versions_fn = offline, ppp_version = 2021, lock = "20260324_2021_01_02_PROD"),
    "20260324_2021_01_02_PROD"
  )
  expect_error(
    resolve_pip_release(versions_fn = offline, ppp_version = 2021),
    "network unavailable"
  )
})

test_that("PIP rows are unique on the full survey identity", {
  result <- collect_pip_comparability(
    raw_dir = withr::local_tempdir(),
    fetch_fn = function() pip_fixture(n_levels = 3),
    vintage = 2025,
    release = "r1"
  )
  expect_equal(nrow(readr::read_csv(result$normalized_path, show_col_types = FALSE)), 3)

  missing_level <- pip_fixture()
  missing_level$reporting_level <- NULL
  expect_error(
    collect_pip_comparability(withr::local_tempdir(), function() missing_level, 2025, release = "r1"),
    "PIP OUTPUT SCHEMA MISMATCH"
  )
})

test_that("a new PIP release forces a fresh fetch and is recorded in provenance", {
  root <- withr::local_tempdir()
  calls <- character()
  fetch_for <- function(release) function() { calls <<- c(calls, release); pip_fixture() }

  first <- collect_pip_comparability(root, fetch_for("r1"), 2025, release = "r1")
  collect_pip_comparability(root, fetch_for("r1"), 2025, release = "r1")
  expect_equal(calls, "r1")
  expect_equal(first$release_identifier, "r1")
  expect_equal(read_artifact_provenance(first$normalized_path)$release_identifier, "r1")

  second <- collect_pip_comparability(root, fetch_for("r2"), 2025, release = "r2")
  expect_equal(calls, c("r1", "r2"))
  expect_equal(read_artifact_provenance(second$normalized_path)$release_identifier, "r2")
})

test_that("the PIP collector resolves the release before fetching", {
  root <- withr::local_tempdir()
  seen <- NULL
  result <- collect_pip_comparability(
    root,
    fetch_fn = NULL,
    vintage = 2025,
    versions_fn = pip_versions_fixture,
    stats_fn = function(version) { seen <<- version; pip_fixture() }
  )
  expect_equal(seen, "20260922_2021_01_02_PROD")
  expect_equal(result$release_identifier, "20260922_2021_01_02_PROD")
})

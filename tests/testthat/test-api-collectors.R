# =============================================================================
# API-backed collector tests
# =============================================================================
# Created: 2026-10-05
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "collection_provenance.R"))
source(file.path(here::here("R"), "collection_io.R"))
source(file.path(here::here("R"), "collection_cache.R"))
source(file.path(here::here("R"), "collect_pip.R"))
source(file.path(here::here("R"), "collect_world_bank.R"))
source(file.path(here::here("R"), "pull_jmp.R"))

test_that("PIP collector writes the normalized comparability artifact", {
  root <- tempfile("pip-collector-")
  fetch <- function() {
    data.frame(
      survey_acronym = "HBS",
      country_code = "AAA",
      year = 2020,
      survey_comparability = 1,
      survey_coverage = "national",
      stringsAsFactors = FALSE
    )
  }

  result <- collect_pip_comparability(
    raw_dir = root,
    fetch_fn = fetch,
    vintage = 2024
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
        survey_coverage = c("national", "national")
      ),
      vintage = 2024
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

test_that("JMP normalization attaches the requested country code", {
  result <- normalize_jmp_data(
    data.frame(
      source = "AAA_2020_CEN",
      type = "Census",
      year = 2020,
      geo = "National",
      data_available = 1,
      data_quality = 1,
      data_value = 10
    ),
    iso3c = "AAA"
  )
  expect_equal(result$iso3c, "AAA")
  expect_true(all(c("geo", "year", "data_quality") %in% names(result)))
})

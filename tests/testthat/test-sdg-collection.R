# =============================================================================
# UN SDG collection and availability tests
# =============================================================================
# Created: 2026-10-05
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "collection_provenance.R"))
source(file.path(here::here("R"), "collection_io.R"))
source(file.path(here::here("R"), "collection_cache.R"))
source(file.path(here::here("R"), "collect_sdg.R"))
source(file.path(here::here("R"), "availability.R"))

sdg_raw_fixture <- function() {
  data.frame(
    TimePeriod = c(2020, 2020, 2020, 2020),
    `[Nature]` = c("C", "M", NA, "N"),
    GeoAreaCode = c("1", "1", "2", "2"),
    Value = c(10, 20, NA, 30),
    SeriesCode = rep("S1", 4),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

test_that("SDG normalization preserves Rmd fields and country joins", {
  iso_codes <- data.frame(
    geoAreaCode = c("1", "2"),
    iso3c = c("AAA", "BBB"),
    country = c("A", "B"),
    stringsAsFactors = FALSE
  )

  normalized <- normalize_sdg_series(sdg_raw_fixture(), "S1", iso_codes)

  expect_true(all(c("series_code", "date", "Nature", "geoAreaCode", "iso3c", "Value") %in% names(normalized)))
  expect_equal(unique(normalized$date), 2020)
  expect_setequal(normalized$iso3c, c("AAA", "BBB"))
})

test_that("SDG availability is binary and follows source nature rules", {
  iso_codes <- data.frame(
    geoAreaCode = c("1", "2"),
    iso3c = c("AAA", "BBB"),
    country = c("A", "B"),
    stringsAsFactors = FALSE
  )
  normalized <- normalize_sdg_series(sdg_raw_fixture(), "S1", iso_codes)
  grid <- expand.grid(
    iso3c = c("AAA", "BBB"),
    date = 2020,
    stringsAsFactors = FALSE
  )

  availability <- build_sdg_availability(normalized, grid)

  expect_true(all(availability$available %in% c(0L, 1L)))
  expect_equal(availability$available[availability$iso3c == "AAA"], 1L)
  # Nature = N is not applicable for scoring, but the raw value is present,
  # so availability remains 1 just as in the Rmd.
  expect_equal(availability$available[availability$iso3c == "BBB"], 1L)
  expect_equal(normalized$quality[!is.na(normalized$Nature) & normalized$Nature == "M"], 0)
  expect_true(is.na(normalized$quality[!is.na(normalized$Nature) & normalized$Nature == "N"]))
})

test_that("SDG collection caches raw response and writes normalized output", {
  root <- tempfile("sdg-collection-")
  iso_codes <- data.frame(
    geoAreaCode = c("1"),
    iso3c = c("AAA"),
    country = c("A"),
    stringsAsFactors = FALSE
  )
  grid <- expand.grid(iso3c = "AAA", date = 2020, stringsAsFactors = FALSE)
  raw_csv <- paste(
    "TimePeriod,[Nature],GeoAreaCode,Value,SeriesCode",
    "2020,C,1,10,S1",
    sep = "\n"
  )
  calls <- 0L
  request <- function(series_code, start_year, end_year) {
    calls <<- calls + 1L
    charToRaw(raw_csv)
  }

  first <- collect_sdg_series(
    series_codes = "S1",
    start_year = 2020,
    end_year = 2020,
    raw_dir = root,
    iso_codes = iso_codes,
    country_year_grid = grid,
    request_fn = request
  )
  second <- collect_sdg_series(
    series_codes = "S1",
    start_year = 2020,
    end_year = 2020,
    raw_dir = root,
    iso_codes = iso_codes,
    country_year_grid = grid,
    request_fn = request
  )

  expect_false(first[[1]]$cached)
  expect_true(second[[1]]$cached)
  expect_equal(calls, 1L)
  expect_true(file.exists(first[[1]]$normalized_path))
  expect_equal(first[[1]]$availability$available, 1L)
})

test_that("SDG five-year scores reproduce the Rmd aggregation", {
  normalized <- data.frame(
    series_code = c("S1", "S1", "S2"),
    iso3c = c("AAA", "AAA", "AAA"),
    date = c(2019, 2020, 2020),
    goal = c("1", "1", "1"),
    quality = c(0, 1, 1),
    stringsAsFactors = FALSE
  )
  grid <- expand.grid(iso3c = "AAA", date = 2020, stringsAsFactors = FALSE)

  result <- build_sdg_five_year_scores(normalized, grid, 2020, 2020)

  # S1 maxes to 1 over the window and S2 is 1, so the goal average is 1.
  expect_equal(result$SPI.D3.1, 1)
})

test_that("SDG quality completion retains missing countries and global gaps", {
  normalized <- data.frame(
    series_code = "S1",
    iso3c = "AAA",
    date = 2020,
    available = 1L,
    quality = 1,
    stringsAsFactors = FALSE
  )
  grid <- expand.grid(
    iso3c = c("AAA", "BBB"),
    date = c(2020, 2021),
    stringsAsFactors = FALSE
  )

  completed <- complete_sdg_quality(normalized, grid)

  expect_equal(completed$quality[completed$iso3c == "BBB" & completed$date == 2020], 0)
  expect_true(is.na(completed$quality[completed$iso3c == "AAA" & completed$date == 2021]))
})

test_that("missing SDG indicator list does not fabricate collection success", {
  result <- collect_sdg_pipeline(list(
    sdg_indicator_list_file = file.path(tempdir(), "missing-sdg-list.csv")
  ))

  expect_null(result)
})

test_that("SDG collection rejects ambiguous series-to-goal mappings", {
  indicator_path <- file.path(tempdir(), "SDG_indicator_list.csv")
  readr::write_csv(
    data.frame(code1 = c("S1", "S1"), Tier_Nov2020 = c(1, 1), goal = c(1, 2)),
    indicator_path
  )

  expect_error(
    collect_sdg_pipeline(list(sdg_indicator_list_file = indicator_path)),
    "MULTIPLE GOALS"
  )
})

test_that("SDG normalization reports unmapped country codes", {
  raw <- sdg_raw_fixture()
  raw$GeoAreaCode[1] <- "999"
  expect_warning(
    normalize_sdg_series(
      raw,
      "S1",
      data.frame(geoAreaCode = c("1", "2"), iso3c = c("AAA", "BBB"))
    ),
    "NOT IN ISO LOOKUP"
  )
})

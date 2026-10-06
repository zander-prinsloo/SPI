# =============================================================================
# Collection cache and provenance tests
# =============================================================================
# Created: 2026-10-05
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "collection_provenance.R"))
source(file.path(here::here("R"), "collection_io.R"))
source(file.path(here::here("R"), "collection_cache.R"))

test_that("cache keys are deterministic and query-sensitive", {
  key_a <- collection_cache_key(
    source_id = "example",
    request = list(endpoint = "https://example.test", series = "A"),
    vintage = 2024,
    collector_version = "1"
  )
  key_b <- collection_cache_key(
    source_id = "example",
    request = list(endpoint = "https://example.test", series = "A"),
    vintage = 2024,
    collector_version = "1"
  )
  key_query <- collection_cache_key(
    source_id = "example",
    request = list(endpoint = "https://example.test", series = "B"),
    vintage = 2024,
    collector_version = "1"
  )

  expect_identical(key_a, key_b)
  expect_false(identical(key_a, key_query))
})

test_that("raw capture preserves bytes and writes provenance", {
  root <- tempfile("collection-raw-")
  raw_path <- file.path(root, "example", "response.bin")
  payload <- as.raw(c(0, 1, 2, 255))

  record <- write_raw_capture(
    raw_path,
    payload,
    metadata = list(source_id = "example", retrieved_at = "2026-10-05T00:00:00Z")
  )

  expect_true(file.exists(raw_path))
  expect_identical(readBin(raw_path, "raw", n = file.info(raw_path)$size), payload)
  expect_true(file.exists(record$provenance_path))
  expect_match(record$sha256, "^[0-9a-f]{64}$")
})

test_that("cached collection skips a second request", {
  root <- tempfile("collection-cache-")
  calls <- 0L
  fetch <- function() {
    calls <<- calls + 1L
    charToRaw("payload")
  }

  first <- collect_cached_raw(
    cache_dir = root,
    source_id = "example",
    request = list(endpoint = "https://example.test", series = "A"),
    vintage = 2024,
    collector_version = "1",
    fetch = fetch
  )
  second <- collect_cached_raw(
    cache_dir = root,
    source_id = "example",
    request = list(endpoint = "https://example.test", series = "A"),
    vintage = 2024,
    collector_version = "1",
    fetch = fetch
  )

  expect_false(first$cached)
  expect_true(second$cached)
  expect_equal(calls, 1L)

  changed <- collect_cached_raw(
    cache_dir = root,
    source_id = "example",
    request = list(endpoint = "https://example.test", series = "B"),
    vintage = 2024,
    collector_version = "1",
    fetch = fetch
  )
  expect_false(changed$cached)
  expect_equal(calls, 2L)
})

test_that("cache hits reject corrupted raw bytes", {
  root <- tempfile("collection-cache-corrupt-")
  fetch <- function() charToRaw("original")
  first <- collect_cached_raw(
    cache_dir = root,
    source_id = "example",
    request = list(endpoint = "https://example.test"),
    vintage = 2024,
    collector_version = "1",
    fetch = fetch
  )
  writeBin(charToRaw("changed"), first$raw_path)

  expect_error(
    collect_cached_raw(
      cache_dir = root,
      source_id = "example",
      request = list(endpoint = "https://example.test"),
      vintage = 2024,
      collector_version = "1",
      fetch = fetch
    ),
    "CHECKSUM MISMATCH"
  )
})

test_that("old cache entries are refreshed after the age threshold", {
  root <- tempfile("collection-cache-age-")
  calls <- 0L
  fetch <- function() {
    calls <<- calls + 1L
    charToRaw(paste0("payload-", calls))
  }
  first <- collect_cached_raw(
    cache_dir = root,
    source_id = "example",
    request = list(endpoint = "https://example.test"),
    vintage = 2024,
    collector_version = "1",
    fetch = fetch,
    max_age_days = 365
  )
  Sys.setFileTime(first$raw_path, Sys.time() - 400 * 86400)
  second <- collect_cached_raw(
    cache_dir = root,
    source_id = "example",
    request = list(endpoint = "https://example.test"),
    vintage = 2024,
    collector_version = "1",
    fetch = fetch,
    max_age_days = 365
  )

  expect_false(second$cached)
  expect_equal(calls, 2L)
})

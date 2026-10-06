# =============================================================================
# Source registry tests
# =============================================================================
# Created: 2026-10-05
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "collection_registry.R"))

registry_path <- here::here("config", "source_registry.R")

expected_dimensions <- c(
  "1.1", "1.2", "1.3", "1.4", "1.5",
  "2.1", "2.2", "2.3", "2.4",
  "3.1", "3.2", "3.3", "3.4",
  "4.1", "4.2", "4.3", "4.4",
  "5.1", "5.2", "5.3", "5.4", "5.5"
)

test_that("source registry is machine-readable and unique", {
  registry <- load_source_registry(registry_path)

  expect_true(is.data.frame(registry))
  expect_true(all(c(
    "source_id", "dimension_id", "source_type", "status_if_missing",
    "expected_vintage_rule", "age_warning_days"
  ) %in% names(registry)))
  expect_true(all(!is.na(registry$source_id)))
  expect_true(all(!duplicated(registry$source_id)))
  expect_true(all(registry$source_type %in% c("api", "manual", "external", "unavailable")))
})

test_that("source registry covers all SPI dimensions", {
  registry <- load_source_registry(registry_path)
  expect_setequal(unique(registry$dimension_id), expected_dimensions)
})

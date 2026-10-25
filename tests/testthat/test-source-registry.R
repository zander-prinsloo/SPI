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

# --- 202611 readiness plan, Steps 5-6 ----------------------------------------

test_that("the registry uses only supported vintage rules", {
  registry <- load_source_registry(registry_path)
  expect_true(all(registry$expected_vintage_rule %in% c(
    "not_measured", "end_date", "end_date_plus_one",
    "manual_attestation", "release_identifier"
  )))

  retired <- registry[1, , drop = FALSE]
  retired$expected_vintage_rule <- "latest_release"
  expect_error(validate_source_registry(retired), "UNSUPPORTED EXPECTED VINTAGE RULE")
})

test_that("configured source files are referenced through parameter placeholders", {
  registry <- load_source_registry(registry_path)
  path_of <- function(id) registry$normalized_path[registry$source_id == id]
  expect_equal(path_of("d1_5_ilo"), "1.5_DUIO/<ILO_MODELLED_FILE>|1.5_DUIO/<ILO_SURVEY_FILE>")
  expect_equal(path_of("d1_5_igme"), "1.5_DUIO/<UNIGME_FILE>")
  expect_equal(path_of("d5_2_imf_workbook"), "5.2_DISM/<IMF_FILE>")
  expect_equal(path_of("d5_2_imf_workbook_2024"), "5.2_DISM/<IMF_FILE_2024>")
})

test_that("the CRVS source covers the birth and death registration series", {
  registry <- load_source_registry(registry_path)
  expect_equal(
    registry$normalized_path[registry$source_id == "d4_2_crvs"],
    "4.2_SOAD/SG_REG_BRTH90N.csv|4.2_SOAD/SG_REG_DETH75N.csv"
  )
})

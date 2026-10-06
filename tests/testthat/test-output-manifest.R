# =============================================================================
# Final output manifest tests
# =============================================================================
# Created: 2026-10-05
# =============================================================================

library(testthat)
source(file.path(here::here("R"), "output_manifest.R"))

test_that("output manifest fails clearly when final artifacts are missing", {
  expect_error(
    validate_output_manifest(tempdir()),
    "FINAL OUTPUT SET INCOMPLETE"
  )
})

test_that("output manifest passes when every expected artifact exists", {
  root <- tempfile("output-manifest-")
  dir.create(root, recursive = TRUE)
  file.create(file.path(root, expected_estimation_outputs(2024)))

  result <- validate_output_manifest(root, 2024)

  expect_true(all(result$present))
  expect_equal(nrow(result), length(expected_estimation_outputs(2024)))
  expect_true(file.exists(file.path(root, "_estimation_manifest.json")))
})

test_that("validated candidate outputs are promoted as a complete set", {
  candidate <- tempfile("spi-candidate-")
  output <- tempfile("spi-final-")
  dir.create(candidate, recursive = TRUE)
  dir.create(output, recursive = TRUE)
  file.create(file.path(candidate, expected_estimation_outputs(2024)))
  validate_output_manifest(candidate, 2024)

  promote_output_set(candidate, output, 2024)

  expect_true(all(file.exists(file.path(output, expected_estimation_outputs(2024)))))
  expect_true(file.exists(file.path(output, "_estimation_manifest.json")))
})

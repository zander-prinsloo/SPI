# =============================================================================
# Collection and estimation pipeline contract tests
# =============================================================================
# Created: 2026-10-05
# =============================================================================

library(testthat)

project_root <- here::here()

# The collection script must expose a separate target list and the estimation
# script must validate the collection manifest before producing final outputs.
test_that("collection pipeline exposes a separate target graph", {
  expect_true(file.exists(file.path(project_root, "_targets_data.R")))

  collection_env <- new.env(parent = globalenv())
  sys.source(file.path(project_root, "_targets_data.R"), envir = collection_env)

  expect_true(exists("collection_targets", envir = collection_env, inherits = FALSE))
  expect_type(collection_env$collection_targets(), "list")
})

test_that("estimation pipeline exposes a collection status gate", {
  expect_true(file.exists(file.path(project_root, "R", "collection_status.R")))

  source(file.path(project_root, "R", "collection_status.R"))

  expect_true(exists("validate_collection_status", mode = "function"))
  expect_error(
    validate_collection_status(file.path(tempdir(), "missing-collection-status.csv")),
    "COLLECTION STATUS FILE NOT FOUND"
  )
})

# =============================================================================
# Tests for the vintage fixtures and hash manifest
# =============================================================================
# These tests verify:
#   1. The fixture files exist and match the manifest hashes (V4).
#   2. The historical output files in 03_output_data/ are NEVER modified
#      (constraint C7) -- their hashes must match the manifest.
#
# Created: 2026-09-21
# =============================================================================

library(testthat)

# --- Helper: compute SHA-256 of a file ---------------------------------------

sha256_file <- function(path) {
  h <- digest::digest(file = path, algo = "sha256")
  h
}

# --- Load the manifest -------------------------------------------------------

manifest_path <- file.path(here::here("tests", "fixtures"), "manifest.json")
manifest <- jsonlite::fromJSON(manifest_path)

# --- Test: fixtures exist and match manifest hashes --------------------------

test_that("fixture files exist and match the manifest", {
  for (fname in names(manifest$files)) {
    fixture_path <- file.path(here::here("tests", "fixtures"), fname)
    expect_true(
      file.exists(fixture_path),
      info = sprintf("fixture missing: %s", fname)
    )
    actual_hash <- sha256_file(fixture_path)
    expect_equal(
      actual_hash,
      manifest$files[[fname]]$sha256,
      info = sprintf("fixture hash mismatch: %s", fname)
    )
  }
})

# --- Test: historical outputs are never modified (constraint C7) -------------

test_that("historical output files are never modified (C7)", {
  for (fname in names(manifest$files)) {
    source_path <- file.path(here::here("03_output_data"), fname)
    # Fail loudly if a historical output is missing (deletion is a C7
    # violation just like modification).
    expect_true(
      file.exists(source_path),
      info = sprintf(
        "HISTORICAL OUTPUT MISSING: %s -- the pipeline must never delete 03_output_data/ files",
        fname
      )
    )
    actual_hash <- sha256_file(source_path)
    expect_equal(
      actual_hash,
      manifest$files[[fname]]$sha256,
      info = sprintf(
        "HISTORICAL OUTPUT MODIFIED: %s -- the pipeline must never overwrite 03_output_data/",
        fname
      )
    )
  }
})
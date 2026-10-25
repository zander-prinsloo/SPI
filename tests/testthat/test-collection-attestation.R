# =============================================================================
# Source attestation and artifact provenance tests
# =============================================================================
# Created: 2026-10-23
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "collection_status.R"))
source(file.path(here::here("R"), "collection_attestation.R"))

attestation_registry <- function() {
  data.frame(
    source_id = c("a", "b"), dimension_id = "1.5", source_type = "manual",
    normalized_path = c("a.csv", "1.5_DUIO/<UNIGME_FILE>"),
    expected_vintage_rule = "manual_attestation", age_warning_days = 365,
    status_if_missing = "blocking", analyst_action = "Act",
    stringsAsFactors = FALSE
  )
}

test_that("attestation records hash every artifact of the selected sources", {
  root <- withr::local_tempdir()
  dir.create(file.path(root, "1.5_DUIO"))
  writeLines("a", file.path(root, "a.csv"))
  writeLines("igme", file.path(root, "1.5_DUIO", "igme.csv"))
  params <- list(raw_dir = root, collection_dir = file.path(root, "_collection"), end_date = 2025, unigme_file = "igme.csv")

  path <- attest_collection_sources(c("a", "b"), attested_by = "lead", release_label = "202611", params = params, registry = attestation_registry())
  record <- read_collection_attestations(path)

  expect_equal(nrow(record), 2)
  expect_setequal(record$source_id, c("a", "b"))
  expect_equal(record$sha256[record$source_id == "a"], digest::digest(file.path(root, "a.csv"), algo = "sha256", file = TRUE))
  expect_true(all(record$attested_by == "lead"))
})

test_that("re-attesting a source replaces its previous rows", {
  root <- withr::local_tempdir()
  writeLines("a", file.path(root, "a.csv"))
  params <- list(raw_dir = root, collection_dir = root, end_date = 2025)
  registry <- attestation_registry()[1, ]

  attest_collection_sources("a", attested_by = "lead", params = params, registry = registry)
  writeLines("a2", file.path(root, "a.csv"))
  path <- attest_collection_sources("a", attested_by = "lead", params = params, registry = registry)

  record <- read_collection_attestations(path)
  expect_equal(nrow(record), 1)
  expect_equal(record$sha256, digest::digest(file.path(root, "a.csv"), algo = "sha256", file = TRUE))
})

test_that("attesting a missing artifact or an unknown source fails loudly", {
  root <- withr::local_tempdir()
  params <- list(raw_dir = root, collection_dir = root, end_date = 2025)
  expect_error(
    attest_collection_sources("a", attested_by = "lead", params = params, registry = attestation_registry()[1, ]),
    "ATTESTATION ARTIFACT NOT FOUND"
  )
  expect_error(
    attest_collection_sources("zzz", attested_by = "lead", params = params, registry = attestation_registry()),
    "UNKNOWN SOURCE"
  )
})

test_that("artifact provenance records the artifact hash and release", {
  root <- withr::local_tempdir()
  artifact <- file.path(root, "x.csv")
  writeLines("x", artifact)
  write_artifact_provenance(artifact, "src", retrieved_at = "2026-10-23 10:00:00 UTC", release_identifier = "r1", raw_path = "raw.bin")
  record <- read_artifact_provenance(artifact)
  expect_equal(record$release_identifier, "r1")
  expect_equal(record$sha256, digest::digest(artifact, algo = "sha256", file = TRUE))
  expect_null(read_artifact_provenance(file.path(root, "missing.csv")))
})

# =============================================================================
# Collection status and report tests
# =============================================================================
# Created: 2026-10-05
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "collection_status.R"))
source(file.path(here::here("R"), "collection_report.R"))
source(file.path(here::here("R"), "collection_attestation.R"))

status_registry <- function() {
  data.frame(
    source_id = c("present", "missing", "unavailable"),
    dimension_id = c("1.5", "2.2", "1.1"),
    source_type = c("manual", "api", "unavailable"),
    normalized_path = c("present.csv", "missing.csv", NA),
    expected_vintage_rule = c("end_date", "end_date", "not_measured"),
    age_warning_days = c(365, 365, 365),
    status_if_missing = c("blocking", "blocking", "informational"),
    analyst_action = c("Review present", "Download missing", "No action"),
    stringsAsFactors = FALSE
  )
}

test_that("collection status classifies present, missing, and unavailable sources", {
  root <- tempfile("collection-status-")
  dir.create(root, recursive = TRUE)
  file.create(file.path(root, "present.csv"))

  status <- evaluate_collection_status(
    registry = status_registry(),
    collection_root = root,
    end_date = 2024,
    now = as.POSIXct("2026-10-05", tz = "UTC")
  )

  expect_equal(status$status[status$source_id == "present"], "informational")
  expect_equal(status$status[status$source_id == "missing"], "blocking")
  expect_equal(status$status[status$source_id == "unavailable"], "informational")
})

test_that("collection status checks every composite artifact path", {
  root <- tempfile("composite-status-")
  dir.create(root, recursive = TRUE)
  file.create(file.path(root, "first.csv"))
  file.create(file.path(root, "second.csv"))
  registry <- status_registry()[1, , drop = FALSE]
  registry$normalized_path <- "first.csv|second.csv"

  status <- evaluate_collection_status(registry, root, end_date = 2024)
  expect_equal(status$status, "informational")

  unlink(file.path(root, "second.csv"))
  status <- evaluate_collection_status(registry, root, end_date = 2024)
  expect_equal(status$status, "blocking")
})

test_that("collection status report writes machine and human outputs", {
  root <- tempfile("collection-report-")
  dir.create(root, recursive = TRUE)
  file.create(file.path(root, "present.csv"))
  status <- evaluate_collection_status(status_registry(), root, end_date = 2024)

  csv_path <- file.path(root, "collection_status.csv")
  md_path <- file.path(root, "collection_status.md")
  warnings <- data.frame(
    source_id = "d2_4_nada_url_evidence",
    message = "Auto-zeroed NADA for: AAA",
    stringsAsFactors = FALSE
  )
  write_collection_status_report(status, csv_path, md_path, warnings = warnings)

  expect_true(file.exists(csv_path))
  expect_true(file.exists(md_path))
  expect_equal(nrow(readr::read_csv(csv_path, show_col_types = FALSE)), 3)
  expect_match(paste(readLines(md_path), collapse = "\n"), "Collection Status Report")
  expect_match(paste(readLines(md_path), collapse = "\n"), "blocking")
  expect_match(paste(readLines(md_path), collapse = "\n"), "Collection warnings")
  expect_match(paste(readLines(md_path), collapse = "\n"), "Auto-zeroed NADA")
})

test_that("status gate requires a complete current run and registry coverage", {
  root <- tempfile("collection-gate-")
  dir.create(root, recursive = TRUE)
  status_path <- file.path(root, "status.csv")
  run_path <- file.path(root, "run.json")
  status <- data.frame(
    source_id = "present",
    status = "informational",
    checked_at = "2026-10-06 UTC",
    collection_run_id = "run-1",
    parameters_hash = "hash-1",
    stringsAsFactors = FALSE
  )
  readr::write_csv(status, status_path)
  status_hash <- digest::digest(status_path, algo = "sha256", file = TRUE)
  run <- list(
    collection_state = "complete",
    run_id = "run-1",
    parameters_hash = "hash-1",
    status_sha256 = status_hash
  )
  run$run_sha256 <- .collection_run_digest(run)
  jsonlite::write_json(run, run_path, auto_unbox = TRUE)

  expect_true(validate_collection_status(
    status_path,
    expected_source_ids = "present",
    run_path = run_path,
    parameters_hash = "hash-1"
  ))
  expect_error(
    validate_collection_status(
      status_path,
      expected_source_ids = c("present", "missing"),
      run_path = run_path,
      parameters_hash = "hash-1"
    ),
    "DOES NOT MATCH"
  )
  jsonlite::write_json(
    list(collection_state = "started", run_id = "run-1"),
    run_path,
    auto_unbox = TRUE
  )
  expect_error(
    validate_collection_status(status_path, "present", run_path, "hash-1"),
    "NOT COMPLETE"
  )
  run$status_sha256 <- "bad"
  run$run_sha256 <- .collection_run_digest(run)
  jsonlite::write_json(run, run_path, auto_unbox = TRUE)
  expect_error(
    validate_collection_status(status_path, "present", run_path, "hash-1"),
    "STATUS HASH"
  )

  run$status_sha256 <- status_hash
  run$run_sha256 <- "tampered"
  jsonlite::write_json(run, run_path, auto_unbox = TRUE)
  expect_error(
    validate_collection_status(status_path, "present", run_path, "hash-1"),
    "SELF-HASH"
  )
})

# --- 202611 readiness plan, Steps 5-6 ----------------------------------------


one_source <- function(rule, path = "artifact.csv", status_if_missing = "blocking", age = 365) {
  data.frame(
    source_id = "src", dimension_id = "1.5", source_type = "manual",
    normalized_path = path, expected_vintage_rule = rule,
    age_warning_days = age, status_if_missing = status_if_missing,
    analyst_action = "Act", stringsAsFactors = FALSE
  )
}

test_that("registry placeholders resolve to configured filenames", {
  root <- withr::local_tempdir()
  dir.create(file.path(root, "1.5_DUIO"))
  file.create(file.path(root, "1.5_DUIO", c("modelled.xlsx", "survey.xlsx")))
  registry <- one_source("end_date", "1.5_DUIO/<ILO_MODELLED_FILE>|1.5_DUIO/<ILO_SURVEY_FILE>")
  substitutions <- list(ILO_MODELLED_FILE = "modelled.xlsx", ILO_SURVEY_FILE = "survey.xlsx")

  status <- evaluate_collection_status(registry, root, 2025, substitutions = substitutions)
  expect_equal(status$status, "informational")
  expect_match(status$artifact_path, "modelled.xlsx")
  expect_match(status$artifact_path, "survey.xlsx")

  expect_error(
    evaluate_collection_status(registry, root, 2025),
    "UNRESOLVED PLACEHOLDER"
  )
})

test_that("manual sources pass only with a hash-matching attestation", {
  root <- withr::local_tempdir()
  writeLines("v1", file.path(root, "artifact.csv"))
  registry <- one_source("manual_attestation")
  params <- list(raw_dir = root, collection_dir = file.path(root, "_collection"), end_date = 2025)

  status <- evaluate_collection_status(registry, root, 2025, attestations = read_collection_attestations(collection_attestation_path(params)))
  expect_equal(status$status, "blocking")
  expect_equal(status$reason, "attestation_missing")

  attest_collection_sources("src", attested_by = "tester", release_label = "2025 release", params = params, registry = registry)
  attestations <- read_collection_attestations(collection_attestation_path(params))
  status <- evaluate_collection_status(registry, root, 2025, attestations = attestations)
  expect_equal(status$status, "informational")
  expect_equal(status$reason, "attested")
  expect_equal(status$observed_vintage, "2025 release")

  Sys.setFileTime(file.path(root, "artifact.csv"), as.POSIXct("2020-01-01", tz = "UTC"))
  expect_equal(evaluate_collection_status(registry, root, 2025, attestations = attestations)$status, "informational")

  writeLines("v2", file.path(root, "artifact.csv"))
  status <- evaluate_collection_status(registry, root, 2025, attestations = attestations)
  expect_equal(status$status, "blocking")
  expect_equal(status$reason, "attestation_hash_mismatch")
})

test_that("attestation records reject ambiguity and malformed approvals", {
  root <- withr::local_tempdir()
  artifact <- file.path(root, "artifact.csv")
  writeLines("data", artifact)
  path <- file.path(root, "attestations.csv")
  valid <- data.frame(
    source_id = "src",
    artifact_path = .collection_relative_path(artifact),
    sha256 = digest::digest(artifact, algo = "sha256", file = TRUE),
    release_label = "release",
    attested_by = "tester",
    attested_at = "2026-10-25 12:00:00 UTC",
    notes = "",
    stringsAsFactors = FALSE
  )
  readr::write_csv(valid, path)
  expect_no_error(read_collection_attestations(path))

  readr::write_csv(rbind(valid, valid), path)
  expect_error(read_collection_attestations(path), "DUPLICATE")

  invalid <- valid
  invalid$sha256 <- "not-a-hash"
  readr::write_csv(invalid, path)
  expect_error(read_collection_attestations(path), "INVALID SHA-256")

  invalid <- valid
  invalid$attested_at <- "not-a-time"
  readr::write_csv(invalid, path)
  expect_error(read_collection_attestations(path), "INVALID attested_at")
})

test_that("collected sources pass only with matching provenance and a release identifier", {
  root <- withr::local_tempdir()
  artifact <- file.path(root, "artifact.csv")
  writeLines("data", artifact)
  registry <- one_source("release_identifier")

  status <- evaluate_collection_status(registry, root, 2025)
  expect_equal(status$reason, "provenance_missing")
  expect_equal(status$status, "blocking")

  write_artifact_provenance(artifact, "src", retrieved_at = format(Sys.time(), tz = "UTC", usetz = TRUE), release_identifier = "20260922_2021_01_02_PROD")
  status <- evaluate_collection_status(registry, root, 2025)
  expect_equal(status$status, "informational")
  expect_equal(status$observed_vintage, "20260922_2021_01_02_PROD")

  write_artifact_provenance(artifact, "src", retrieved_at = format(Sys.time(), tz = "UTC", usetz = TRUE), release_identifier = NA_character_)
  expect_equal(evaluate_collection_status(registry, root, 2025)$reason, "release_identifier_missing")

  write_artifact_provenance(artifact, "src", retrieved_at = "2020-01-01 00:00:00 UTC", release_identifier = "old")
  expect_equal(evaluate_collection_status(registry, root, 2025)$reason, "artifact_age_exceeds_warning_threshold")

  write_artifact_provenance(artifact, "src", retrieved_at = format(Sys.time(), tz = "UTC", usetz = TRUE), release_identifier = "r1")
  writeLines("edited by hand", artifact)
  status <- evaluate_collection_status(registry, root, 2025)
  expect_equal(status$status, "blocking")
  expect_equal(status$reason, "artifact_modified_after_collection")
})

test_that("file modification time never makes an artifact stale", {
  root <- withr::local_tempdir()
  writeLines("data", file.path(root, "artifact.csv"))
  Sys.setFileTime(file.path(root, "artifact.csv"), as.POSIXct("2019-01-01", tz = "UTC"))
  status <- evaluate_collection_status(one_source("end_date"), root, 2025)
  expect_equal(status$status, "informational")
  expect_equal(status$reason, "artifact_present")
})

test_that("the collection parameter hash covers the attestation record", {
  root <- withr::local_tempdir()
  params <- list(
    raw_dir = root, collection_dir = root, end_date = 2025, span = 2004:2025,
    source_registry_file = NA_character_
  )
  before <- collection_parameters_hash(params)
  writeLines("source_id,artifact_path,sha256", collection_attestation_path(params))
  expect_false(identical(before, collection_parameters_hash(params)))
})

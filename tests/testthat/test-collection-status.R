# =============================================================================
# Collection status and report tests
# =============================================================================
# Created: 2026-10-05
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "collection_status.R"))
source(file.path(here::here("R"), "collection_report.R"))

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
  jsonlite::write_json(
    list(collection_state = "complete", run_id = "run-1"),
    run_path,
    auto_unbox = TRUE
  )

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
})

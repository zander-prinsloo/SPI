# =============================================================================
# Release lock (202611 readiness plan, Step 24)
# =============================================================================
# Created: 2026-10-24
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "collection_cache.R"))
source(file.path(here::here("R"), "collection_attestation.R"))
source(file.path(here::here("R"), "collection_status.R"))
source(file.path(here::here("R"), "output_manifest.R"))
source(file.path(here::here("R"), "release_lock.R"))

make_lock_fixture <- function() {
  root <- withr::local_tempdir(.local_envir = parent.frame())
  raw <- file.path(root, "01_raw_data")
  dir.create(file.path(raw, "a"), recursive = TRUE)
  dir.create(file.path(raw, "b"))
  dir.create(file.path(raw, "2.2_DSOA"))
  dir.create(file.path(raw, "1.5_DUIO"))
  dir.create(file.path(raw, "_collection", "world_bank", "raw"), recursive = TRUE)
  writeLines(c("iso3c,value", "AAA,1"), file.path(raw, "a", "source_a.csv"))
  jsonlite::write_json(
    list(files = list(list(path = "x.csv", sha256 = "abc", modified_at = "2026-10-01T00:00:00Z")),
         checked_at = "2026-10-01T00:00:00Z"),
    file.path(raw, "b", "manifest.json"),
    auto_unbox = TRUE
  )
  writeLines(c("Country Code,Year", "AAA,2025"), file.path(raw, "2.2_DSOA", "ODIN_2025.csv"))
  pip <- file.path(raw, "1.5_DUIO", "PIP_comparability_latest.csv")
  writeLines(c("country_code,year", "AAA,2020"), pip)
  write_artifact_provenance(pip, source_id = "d1_5_pip", retrieved_at = Sys.time(),
                            release_identifier = "20260922_2021_01_02_PROD")
  saveRDS(data.frame(iso3c = "AAA"), file.path(raw, "_collection", "world_bank", "country_metadata.rds"))
  saveRDS(data.frame(x = 1), file.path(raw, "_collection", "world_bank", "raw", "cache.rds"))
  writeLines(
    "source_id,artifact_path,sha256,release_label,attested_by,attested_at,notes",
    collection_attestation_path(list(collection_dir = file.path(raw, "_collection"), end_date = 2025))
  )
  jsonlite::write_json(
    list(collection_state = "complete", status_sha256 = "fixture"),
    file.path(raw, "_collection", "collection_run.json"),
    auto_unbox = TRUE
  )
  writeLines("source_id,status,reason,observed,age_days", 
             file.path(raw, "_collection", "collection_status.csv"))

  output <- file.path(root, "03_output_data")
  dir.create(output)
  file.create(file.path(output, expected_estimation_outputs(2025)))
  writeLines("data", file.path(output, "SPI_data.csv"))
  jsonlite::write_json(
    list(end_date = 2025, files = expected_estimation_outputs(2025), odin_status = "provisional"),
    file.path(output, "_estimation_manifest.json"),
    auto_unbox = TRUE
  )
  writeLines("provisional", file.path(output, "PROVISIONAL_ODIN.md"))

  registry <- data.frame(
    source_id = c("src_a", "src_b", "d1_5_pip", "d2_2_odin", "src_gone"),
    source_type = c("manual", "manual", "api", "manual", "unavailable"),
    normalized_path = c("a/source_a.csv", "b/manifest.json", "1.5_DUIO/PIP_comparability_latest.csv",
                        "2.2_DSOA/ODIN_<END_DATE>.csv", NA),
    input_path = NA_character_,
    stringsAsFactors = FALSE
  )
  params <- list(
    raw_dir = raw,
    collection_dir = file.path(raw, "_collection"),
    output_dir = output,
    end_date = 2025
  )
  list(params = params, registry = registry, raw = raw, output = output)
}

lock_it <- function(fixture, ...) {
  write_release_lock(
    fixture$params,
    approved_by = "Technical lead",
    registry = fixture$registry,
    substitutions = list(),
    ...
  )
}

verify_it <- function(fixture) {
  verify_release_lock(fixture$params, registry = fixture$registry, substitutions = list())
}

test_that("the lock records non-ODIN artifacts, the PIP release and archived outputs", {
  fixture <- make_lock_fixture()
  path <- lock_it(fixture)
  expect_identical(basename(path), "release_lock_2025.json")
  lock <- jsonlite::read_json(path)
  locked <- vapply(lock$artifacts, `[[`, character(1), "path")
  expect_setequal(locked, c(
    "a/source_a.csv", "b/manifest.json", "1.5_DUIO/PIP_comparability_latest.csv",
    "1.5_DUIO/PIP_comparability_latest.csv.provenance.json",
    "_collection/world_bank/country_metadata.rds"
  ))
  expect_identical(lock$pip_release, "20260922_2021_01_02_PROD")
  expect_identical(lock$odin_status, "provisional")
  expect_setequal(unlist(lock$excluded_sources), c("d2_2_odin", "d4_3_odin"))
  archive <- file.path(fixture$output, "releases", "202611-provisional")
  expect_identical(lock$archive, "03_output_data/releases/202611-provisional")
  expect_true(all(file.exists(file.path(archive, c(expected_estimation_outputs(2025), "_estimation_manifest.json", "PROVISIONAL_ODIN.md")))))
  outputs <- lock$outputs
  spi <- outputs[[which(vapply(outputs, `[[`, character(1), "file") == "SPI_data.csv")]]
  expect_identical(spi$sha256, digest::digest(file.path(archive, "SPI_data.csv"), algo = "sha256", file = TRUE))
})

test_that("an unchanged repository passes verification", {
  fixture <- make_lock_fixture()
  lock_it(fixture)
  expect_no_error(verify_it(fixture))
  expect_null(verify_release_lock(
    utils::modifyList(fixture$params, list(collection_dir = tempfile())),
    registry = fixture$registry,
    substitutions = list()
  ))
})

test_that("a tampered lock allow-list or hash is rejected", {
  fixture <- make_lock_fixture()
  path <- lock_it(fixture)
  lock <- jsonlite::read_json(path, simplifyVector = FALSE)
  lock$artifacts[[1]]$sha256 <- strrep("0", 64)
  jsonlite::write_json(lock, path, auto_unbox = TRUE, pretty = TRUE)
  expect_error(verify_it(fixture), "RELEASE LOCK SELF-HASH MISMATCH")
})

test_that("the detached lock integrity record is enforced", {
  fixture <- make_lock_fixture()
  lock_it(fixture)
  writeLines(strrep("0", 64), release_lock_integrity_path(fixture$params))
  expect_error(verify_it(fixture), "RELEASE LOCK INTEGRITY SIDECAR MISMATCH")
})

test_that("a tampered provenance sidecar blocks verification", {
  fixture <- make_lock_fixture()
  lock_it(fixture)
  sidecar <- file.path(fixture$raw, "1.5_DUIO", "PIP_comparability_latest.csv.provenance.json")
  record <- jsonlite::read_json(sidecar, simplifyVector = TRUE)
  record$release_identifier <- "different-release"
  jsonlite::write_json(record, sidecar, auto_unbox = TRUE, pretty = TRUE)
  expect_error(verify_it(fixture), "RELEASE LOCK MISMATCH.*provenance")
})

test_that("a tampered non-ODIN artifact blocks", {
  fixture <- make_lock_fixture()
  lock_it(fixture)
  writeLines(c("iso3c,value", "AAA,2"), file.path(fixture$raw, "a", "source_a.csv"))
  expect_error(verify_it(fixture), "RELEASE LOCK MISMATCH.*a/source_a.csv")
  fixture2 <- make_lock_fixture()
  lock_it(fixture2)
  saveRDS(data.frame(iso3c = "BBB"), file.path(fixture2$raw, "_collection", "world_bank", "country_metadata.rds"))
  expect_error(verify_it(fixture2), "RELEASE LOCK MISMATCH.*country_metadata.rds")
})

test_that("ODIN files may change after the lock", {
  fixture <- make_lock_fixture()
  lock_it(fixture)
  writeLines(c("Country Code,Year", "AAA,2025", "BBB,2025"), file.path(fixture$raw, "2.2_DSOA", "ODIN_2025.csv"))
  expect_no_error(verify_it(fixture))
})

test_that("JSON manifests are compared without their timestamps", {
  fixture <- make_lock_fixture()
  lock_it(fixture)
  path <- file.path(fixture$raw, "b", "manifest.json")
  jsonlite::write_json(
    list(files = list(list(path = "x.csv", sha256 = "abc", modified_at = "2026-12-07T09:00:00Z")),
         checked_at = "2026-12-07T09:00:00Z"),
    path,
    auto_unbox = TRUE,
    pretty = TRUE
  )
  expect_no_error(verify_it(fixture))
  jsonlite::write_json(
    list(files = list(list(path = "x.csv", sha256 = "abd", modified_at = "2026-12-07T09:00:00Z"))),
    path,
    auto_unbox = TRUE
  )
  expect_error(verify_it(fixture), "RELEASE LOCK MISMATCH.*b/manifest.json")
})

test_that("a missing locked artifact or a new non-ODIN artifact blocks", {
  fixture <- make_lock_fixture()
  lock_it(fixture)
  unlink(file.path(fixture$raw, "a", "source_a.csv"))
  expect_error(verify_it(fixture), "RELEASE LOCK MISMATCH.*a/source_a.csv")
  fixture2 <- make_lock_fixture()
  lock_it(fixture2)
  saveRDS(data.frame(y = 1), file.path(fixture2$raw, "_collection", "world_bank", "gdp_2025.rds"))
  expect_error(verify_it(fixture2), "RELEASE LOCK MISMATCH.*gdp_2025.rds")
})

test_that("the locked PIP release is used instead of a newer one", {
  fixture <- make_lock_fixture()
  lock_it(fixture)
  expect_identical(pip_locked_release(fixture$params), "20260922_2021_01_02_PROD")
  source(file.path(here::here("R"), "collect_pip.R"))
  expect_identical(
    resolve_pip_release(
      versions_fn = function() stop("the API must not be queried under a lock"),
      lock = pip_locked_release(fixture$params)
    ),
    "20260922_2021_01_02_PROD"
  )
  expect_null(pip_locked_release(utils::modifyList(fixture$params, list(collection_dir = tempfile()))))
})

test_that("a lock and an archive are never overwritten", {
  fixture <- make_lock_fixture()
  lock_it(fixture)
  expect_error(lock_it(fixture), "RELEASE LOCK ALREADY EXISTS")
  unlink(release_lock_path(fixture$params))
  expect_error(lock_it(fixture), "RELEASE ARCHIVE ALREADY EXISTS")
})

test_that("locking requires a complete promoted output set", {
  fixture <- make_lock_fixture()
  unlink(file.path(fixture$output, "SPI_index.csv"))
  expect_error(lock_it(fixture), "RELEASE LOCK REQUIRES THE PROMOTED OUTPUTS.*SPI_index.csv")
  expect_false(file.exists(release_lock_path(fixture$params)))
})

test_that("directory artifacts are locked file by file, ignoring hidden and Excel lock files", {
  fixture <- make_lock_fixture()
  dir.create(file.path(fixture$raw, "d", "input"), recursive = TRUE)
  writeLines("one", file.path(fixture$raw, "d", "one.csv"))
  writeLines("two", file.path(fixture$raw, "d", "input", "two.xlsx"))
  writeLines("finder", file.path(fixture$raw, "d", ".DS_Store"))
  fixture$registry <- rbind(fixture$registry, data.frame(
    source_id = "src_dir", source_type = "manual", normalized_path = "d/",
    input_path = NA_character_, stringsAsFactors = FALSE
  ))
  lock_it(fixture)
  locked <- vapply(jsonlite::read_json(release_lock_path(fixture$params))$artifacts, `[[`, character(1), "path")
  expect_true(all(c("d/one.csv", "d/input/two.xlsx") %in% locked))
  expect_false(any(grepl("DS_Store", locked)))

  writeLines("other finder state", file.path(fixture$raw, "d", ".DS_Store"))
  writeLines("excel lock", file.path(fixture$raw, "d", "~$two.xlsx"))
  expect_no_error(verify_it(fixture))
  writeLines("two changed", file.path(fixture$raw, "d", "input", "two.xlsx"))
  expect_error(verify_it(fixture), "RELEASE LOCK MISMATCH.*d/input/two.xlsx")
})

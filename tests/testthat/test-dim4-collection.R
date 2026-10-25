# =============================================================================
# Dimension 4.1 collection contract tests
# =============================================================================
# Created: 2026-10-20
# =============================================================================

library(testthat)

collection_function_path <- file.path(here::here("R"), "collect_dim4_1.R")
if (file.exists(collection_function_path)) {
  source(collection_function_path)
}

expected_input_files <- c(
  "D2.1.CEN.POPU.xlsx",
  "D2.2.CEN.AGRI.xlsx",
  "D2.3.CEN.BIZZ.xlsx",
  "D2.4.SVY.HOUS.xlsx",
  "D2.5.SVY.AGRI.xlsx",
  "D2.6.SVY.LABR.xlsx",
  "D2.7.SVY.HLTH.xlsx",
  "D2.8.SVY.BIZZ.xlsx"
)

review_path <- file.path(
  here::here("01_raw_data", "4.1_SOCS", "raw"),
  "D4.1.Manual.Review.2024.xlsx"
)

input_dir <- here::here("01_raw_data", "4.1_SOCS", "raw", "input")
class_path <- here::here("01_raw_data", "misc", "CLASS.xlsx")

# Fixture raw root for vintage 2024: real workbooks, review and derived CSVs,
# CLASS.xlsx, and the real catalogue companions restricted to rows dated up
# to 2024 (the current LABR companion already lists 2025 surveys). The
# companions are normalized unless `normalize = FALSE`.
make_dim4_1_fixture_root <- function(normalize = TRUE) {
  root <- tempfile("d41-fixture-")
  raw_root <- file.path(root, "01_raw_data")
  input_fixture <- file.path(raw_root, "4.1_SOCS", "raw", "input")
  raw_fixture <- file.path(raw_root, "4.1_SOCS", "raw")
  companion_fixture <- file.path(raw_root, "4.1_SOCS")
  dir.create(input_fixture, recursive = TRUE, showWarnings = FALSE)
  dir.create(companion_fixture, recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(raw_root, "misc"), recursive = TRUE, showWarnings = FALSE)
  file.copy(class_path, file.path(raw_root, "misc"), overwrite = TRUE)

  file.copy(
    file.path(input_dir, expected_input_files),
    input_fixture,
    overwrite = TRUE
  )
  file.copy(
    review_path,
    raw_fixture,
    overwrite = TRUE
  )

  source_paths <- dim4_1_artifact_paths(
    here::here("01_raw_data"),
    end_date = 2024
  )
  fixture_paths <- dim4_1_artifact_paths(raw_root, end_date = 2024)
  dir.create(raw_fixture, recursive = TRUE, showWarnings = FALSE)
  file.copy(
    unname(source_paths$derived_files),
    raw_fixture,
    overwrite = TRUE
  )
  for (path in unname(source_paths$companion_files)) {
    companion <- readr::read_csv(
      path,
      col_types = readr::cols(.default = readr::col_character())
    )
    companion <- companion[as.numeric(companion$indicator_date) <= 2024, , drop = FALSE]
    destination <- fixture_paths$companion_files[[basename(path) |>
      sub("_NADA[.]csv$", "", x = _)]]
    readr::write_csv(companion, destination, na = "")
  }
  if (normalize) {
    normalize_dim4_1_companions(raw_root, end_date = 2024)
  }
  root
}

# Replace one raw catalogue companion in a fixture root.
write_raw_companion <- function(raw_root, stem, country, indicator_date,
                                nada_title = "Catalogue study") {
  path <- file.path(raw_root, "4.1_SOCS", paste0(stem, "_NADA.csv"))
  readr::write_csv(
    tibble::tibble(
      country = country,
      indicator_date = indicator_date,
      nada_dates = as.character(indicator_date),
      nada_title = nada_title
    ),
    path,
    na = ""
  )
  path
}

exclusion_names <- function(records) {
  vapply(records, `[[`, character(1), "catalogue_name")
}

# The first contract test intentionally fails until the collection validator
# exists. It prevents implementation from drifting away from the workbook
# structure established by the current manual process.
test_that("D4.1 collection exposes the workbook validator", {
  expect_true(
    exists("validate_dim4_1_workbooks", mode = "function"),
    info = "Create the D4.1 collection validator before wiring targets."
  )
})

test_that("D4.1 input inventory contains all eight workbooks", {
  expect_true(all(file.exists(file.path(input_dir, expected_input_files))))
  expect_true(file.exists(review_path))
})

test_that("D4.1 workbook validator accepts the current 2024 inputs", {
  skip_if_not(exists("validate_dim4_1_workbooks", mode = "function"))
  result <- validate_dim4_1_workbooks(
    raw_dir = here::here("01_raw_data"),
    end_date = 2024
  )
  expect_true(isTRUE(result$valid))
  expect_setequal(result$input_files, file.path(input_dir, expected_input_files))
  expect_equal(result$review_file, review_path)
})

test_that("D4.1 workbook validation fails on a missing input", {
  skip_if_not(exists("validate_dim4_1_workbooks", mode = "function"))
  expect_error(
    validate_dim4_1_workbooks(
      raw_dir = tempdir(),
      end_date = 2024
    ),
    "D4.1.*FILE NOT FOUND"
  )
})

test_that("D4.1 review validation rejects duplicate country keys", {
  skip_if_not(exists("validate_dim4_1_review", mode = "function"))
  review <- data.frame(
    iso3c = c("AAA", "AAA"),
    country = c("A", "A"),
    POP.CENSUS = NA_real_,
    AGRI.CENSUS = NA_real_,
    BIZZ.CENSUS = NA_character_,
    HOUS.SURVEYS = NA_real_,
    AGRI.SURVEYS = NA_real_,
    LABR.SURVEYS = NA_character_,
    HLTH.SURVEYS = NA_character_,
    BIZZ.SURVEYS = NA_real_,
    Evidence = NA_character_
  )
  expect_error(
    validate_dim4_1_review(review),
    "duplicate",
    ignore.case = TRUE
  )
})

test_that("D4.1 review validation rejects malformed non-empty values", {
  skip_if_not(exists("validate_dim4_1_review", mode = "function"))
  review <- data.frame(
    iso3c = "AAA",
    country = "A",
    POP.CENSUS = "pending",
    AGRI.CENSUS = NA_character_,
    BIZZ.CENSUS = NA_character_,
    HOUS.SURVEYS = NA_character_,
    AGRI.SURVEYS = NA_character_,
    LABR.SURVEYS = NA_character_,
    HLTH.SURVEYS = NA_character_,
    BIZZ.SURVEYS = NA_character_,
    Evidence = "review",
    stringsAsFactors = FALSE
  )
  expect_error(validate_dim4_1_review(review), "INVALID VALUE")
})

test_that("D4.1 review validation rejects year substrings and missing evidence", {
  review <- data.frame(
    iso3c = "AAA",
    country = "A",
    POP.CENSUS = "pending 2025",
    AGRI.CENSUS = NA_character_,
    BIZZ.CENSUS = NA_character_,
    HOUS.SURVEYS = NA_character_,
    AGRI.SURVEYS = NA_character_,
    LABR.SURVEYS = NA_character_,
    HLTH.SURVEYS = NA_character_,
    BIZZ.SURVEYS = NA_character_,
    Evidence = "review",
    stringsAsFactors = FALSE
  )
  expect_error(validate_dim4_1_review(review), "INVALID VALUE")
  review$POP.CENSUS <- "2025"
  review$Evidence <- NA_character_
  expect_error(validate_dim4_1_review(review), "REQUIRE EVIDENCE")
})

test_that("D4.1 review metadata records a hash and override counts", {
  skip_if_not(exists("dim4_1_review_metadata", mode = "function"))
  metadata <- dim4_1_review_metadata(
    review_path,
    end_date = 2024
  )
  expect_equal(metadata$end_date, 2024)
  expect_match(metadata$sha256, "^[0-9a-f]{64}$")
  expect_equal(metadata$rows, 217)
  expect_gt(metadata$override_count, 0)
})

test_that("D4.1 review values merge source and reviewed evidence", {
  skip_if_not(exists("dim4_1_merge_review_values", mode = "function"))
  result <- dim4_1_merge_review_values(
    base_values = c("2010", NA_character_),
    review_values = c("2015", "Register based census"),
    register_based = TRUE
  )
  expect_match(result[[1]], "2010")
  expect_match(result[[1]], "2015")
  expect_match(result[[2]], "Register based census")
})

test_that("D4.1 manifest hashes all validated artifact classes", {
  skip_if_not(exists("dim4_1_build_manifest", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root()
  manifest <- dim4_1_build_manifest(
    raw_dir = file.path(fixture_root, "01_raw_data"),
    end_date = 2024
  )
  expect_equal(manifest$schema_version, "spi-d4.1-collection-v2")
  expect_equal(manifest$end_date, 2024)
  expect_length(manifest$inputs, 8)
  expect_length(manifest$derived, 8)
  expect_length(manifest$catalogue_raw, 8)
  expect_length(manifest$companions, 8)
  expect_match(manifest$review$sha256, "^[0-9a-f]{64}$")
  expect_true(all(vapply(manifest$derived, function(item) {
    grepl("^[0-9a-f]{64}$", item$sha256)
  }, logical(1))))
})

test_that("D4.1 manifest records the naming authority, exclusions and normalized companions", {
  skip_if_not(exists("dim4_1_build_manifest", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root()
  manifest <- dim4_1_build_manifest(
    raw_dir = file.path(fixture_root, "01_raw_data"),
    end_date = 2024
  )
  expect_setequal(names(manifest$naming), c("class_file", "crosswalk_file", "exclusions_file"))
  expect_true(all(vapply(manifest$naming, function(item) {
    grepl("^[0-9a-f]{64}$", item$sha256)
  }, logical(1))))
  companion_paths <- vapply(manifest$companions, `[[`, character(1), "path")
  expect_true(all(grepl("4[.]1_SOCS/collection/D4[.]1[.].*_NADA[.]iso3c[.]csv$", companion_paths)))
  expect_true(all(vapply(manifest$companions, function(item) {
    all(c("raw_rows", "rows", "duplicate_keys") %in% names(item))
  }, logical(1))))
  # The labour companion has catalogue rows without a country (2019-2023).
  labour <- manifest$exclusions[["D4.1.6.SVY.LABR"]]
  expect_true("<blank>" %in% exclusion_names(labour))
  expect_true(all(vapply(labour, function(item) item$rows > 0, logical(1))))
})

test_that("D4.1 companion files validate as a separate catalogue artifact class", {
  skip_if_not(exists("validate_dim4_1_companions", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root()
  companions <- validate_dim4_1_companions(
    file.path(fixture_root, "01_raw_data"),
    end_date = 2024
  )
  expect_length(companions$files, 8)
  expect_true(all(vapply(companions$files, function(item) item$rows > 0, logical(1))))
})

test_that("D4.1 companion validation rejects unknown country names", {
  skip_if_not(exists("validate_dim4_1_companions", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root()
  raw_root <- file.path(fixture_root, "01_raw_data")
  path <- file.path(raw_root, "4.1_SOCS", "D4.1.1.CEN.POPU_NADA.csv")
  data <- readr::read_csv(path, col_types = readr::cols(.default = "c"))
  data$country[[1]] <- "Unknownland"
  readr::write_csv(data, path, na = "")
  expect_error(
    validate_dim4_1_companions(raw_root, end_date = 2024),
    "UNKNOWN COUNTRY NAME.*Unknownland"
  )
})

test_that("D4.1 companion validation records duplicate catalogue rows", {
  skip_if_not(exists("validate_dim4_1_companions", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root(normalize = FALSE)
  raw_root <- file.path(fixture_root, "01_raw_data")
  before <- normalize_dim4_1_companions(raw_root, end_date = 2024)
  path <- file.path(raw_root, "4.1_SOCS", "D4.1.5.SVY.AGRI_NADA.csv")
  data <- readr::read_csv(path, col_types = readr::cols(.default = "c"))
  readr::write_csv(dplyr::bind_rows(data, data[1, ]), path, na = "")
  normalize_dim4_1_companions(raw_root, end_date = 2024)
  companions <- validate_dim4_1_companions(raw_root, end_date = 2024)
  expect_identical(
    companions$files[["D4.1.5.SVY.AGRI"]]$duplicate_keys,
    before$files[["D4.1.5.SVY.AGRI"]]$duplicate_keys + 1L
  )
})

test_that("D4.1 catalogue collection validates external companions without downloads", {
  skip_if_not(exists("collect_dim4_1_catalogue", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root(normalize = FALSE)
  raw_root <- file.path(fixture_root, "01_raw_data")
  result <- collect_dim4_1_catalogue(list(
    raw_dir = raw_root,
    end_date = 2024,
    run_downloads = FALSE
  ))
  expect_identical(result$status, "validated_external_artifacts")
  expect_false(result$refreshed)
  expect_length(result$companion_files, 8)
  expect_true(all(file.exists(result$companion_files)))
  expect_true(all(grepl("_NADA[.]iso3c[.]csv$", result$companion_files)))
})

# =============================================================================
# Staged catalogue refresh (202611 plan, Step 17)
# =============================================================================

refresh_params <- function(raw_root, budget_minutes = 5) {
  list(
    raw_dir = raw_root,
    end_date = 2024,
    run_downloads = FALSE,
    d41_catalogue_budget_minutes = budget_minutes
  )
}

# Simulate a fresh pull: copy the fixture's raw companions into staging,
# replacing any companion given in `override`.
stage_current_companions <- function(raw_root, staging_dir, override = list()) {
  file.copy(
    unname(dim4_1_artifact_paths(raw_root, 2024)$companion_files),
    staging_dir,
    overwrite = TRUE
  )
  for (stem in names(override)) {
    readr::write_csv(
      override[[stem]],
      file.path(staging_dir, paste0(stem, "_NADA.csv")),
      na = ""
    )
  }
  invisible(staging_dir)
}

companion_hashes <- function(raw_root) {
  paths <- dim4_1_artifact_paths(raw_root, 2024)
  files <- c(unname(paths$companion_files), unname(paths$normalized_companion_files))
  vapply(files, digest::digest, character(1), algo = "sha256", file = TRUE)
}

staging_leftovers <- function(raw_root) {
  list.files(file.path(raw_root, "4.1_SOCS", "collection"), pattern = "^staging")
}

test_that("D4.1 catalogue collection records an injected refresh", {
  skip_if_not(exists("collect_dim4_1_catalogue", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root()
  raw_root <- file.path(fixture_root, "01_raw_data")
  called <- FALSE
  result <- collect_dim4_1_catalogue(
    refresh_params(raw_root),
    refresh_fn = function(params, staging_dir) {
      called <<- TRUE
      stage_current_companions(raw_root, staging_dir)
    }
  )
  expect_true(called)
  expect_identical(result$status, "refreshed")
})

test_that("a failing catalogue adapter leaves the previous companion set intact", {
  skip_if_not(exists("collect_dim4_1_catalogue", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root()
  raw_root <- file.path(fixture_root, "01_raw_data")
  before <- companion_hashes(raw_root)
  expect_error(
    collect_dim4_1_catalogue(
      refresh_params(raw_root),
      refresh_fn = function(params, staging_dir) {
        stage_current_companions(raw_root, staging_dir)
        stop("catalogue API unavailable")
      }
    ),
    "D4.1 CATALOGUE REFRESH FAILED.*catalogue API unavailable"
  )
  expect_identical(companion_hashes(raw_root), before)
  expect_length(staging_leftovers(raw_root), 0)
})

test_that("a failed companion promotion restores the complete previous set", {
  fixture_root <- make_dim4_1_fixture_root()
  target_dir <- file.path(fixture_root, "01_raw_data", "4.1_SOCS")
  stage_dir <- file.path(fixture_root, "stage")
  dir.create(stage_dir, recursive = TRUE)
  staged <- file.path(stage_dir, c("first.csv", "second.csv"))
  targets <- file.path(target_dir, basename(staged))
  writeLines("old-first", targets[[1]])
  writeLines("old-second", targets[[2]])
  writeLines("new-first", staged[[1]])
  writeLines("new-second", staged[[2]])
  before <- vapply(targets, digest::digest, character(1), algo = "sha256", file = TRUE)
  expect_error(
    dim4_1_promote_staged_files(
      staged,
      target_dir,
      backup_dir = file.path(stage_dir, "previous"),
      fail_after = 2L
    ),
    "D4.1 CATALOGUE PROMOTION FAILED and was rolled back"
  )
  expect_identical(
    vapply(targets, digest::digest, character(1), algo = "sha256", file = TRUE),
    before
  )
  expect_false(file.exists(dim4_1_promotion_marker_path(target_dir)))
})

test_that("an invalid staged companion blocks promotion", {
  skip_if_not(exists("collect_dim4_1_catalogue", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root()
  raw_root <- file.path(fixture_root, "01_raw_data")
  before <- companion_hashes(raw_root)
  invalid <- tibble::tibble(
    country = "Atlantis",
    indicator_date = 2015,
    nada_dates = "2015",
    nada_title = "Business census"
  )
  expect_error(
    collect_dim4_1_catalogue(
      refresh_params(raw_root),
      refresh_fn = function(params, staging_dir) {
        stage_current_companions(raw_root, staging_dir, list(D4.1.3.CEN.BIZZ = invalid))
      }
    ),
    "D4.1 STAGED CATALOGUE REJECTED.*UNKNOWN COUNTRY NAME.*Atlantis"
  )
  expect_identical(companion_hashes(raw_root), before)
  expect_length(staging_leftovers(raw_root), 0)
})

test_that("an incomplete staged catalogue blocks promotion", {
  skip_if_not(exists("collect_dim4_1_catalogue", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root()
  raw_root <- file.path(fixture_root, "01_raw_data")
  before <- companion_hashes(raw_root)
  expect_error(
    collect_dim4_1_catalogue(
      refresh_params(raw_root),
      refresh_fn = function(params, staging_dir) {
        stage_current_companions(raw_root, staging_dir)
        unlink(file.path(staging_dir, "D4.1.6.SVY.LABR_NADA.csv"))
      }
    ),
    "D4.1 STAGED CATALOGUE INCOMPLETE.*D4.1.6.SVY.LABR"
  )
  expect_identical(companion_hashes(raw_root), before)
})

test_that("a successful refresh promotes all eight companions and records them", {
  skip_if_not(exists("collect_dim4_1_catalogue", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root()
  raw_root <- file.path(fixture_root, "01_raw_data")
  health <- tibble::tibble(
    country = c("Nauru", "Republic of Cabo Verde"),
    indicator_date = c(2015, 2019),
    nada_dates = c("2015", "2019"),
    nada_title = "Health survey"
  )
  result <- collect_dim4_1_catalogue(
    refresh_params(raw_root),
    refresh_fn = function(params, staging_dir) {
      stage_current_companions(raw_root, staging_dir, list(D4.1.7.SVY.HLTH = health))
      readr::write_csv(
        tibble::tibble(id = 1),
        file.path(staging_dir, "microdata_library_public_studies.csv")
      )
    }
  )
  expect_identical(result$status, "refreshed")
  paths <- dim4_1_artifact_paths(raw_root, 2024)

  promoted <- readr::read_csv(paths$companion_files[["D4.1.7.SVY.HLTH"]], col_types = readr::cols(.default = "c"))
  expect_identical(promoted$country, health$country)
  normalized <- readr::read_csv(
    paths$normalized_companion_files[["D4.1.7.SVY.HLTH"]],
    col_types = readr::cols(.default = "c")
  )
  expect_identical(normalized$iso3c, c("NRU", "CPV"))
  expect_true(file.exists(file.path(raw_root, "4.1_SOCS", "microdata_library_public_studies.csv")))

  record <- result$refresh
  expect_identical(record$adapter, "injected")
  expect_true(all(c("started_at", "finished_at", "elapsed_seconds", "budget_seconds") %in% names(record)))
  expect_setequal(names(record$companions), names(paths$companion_files))
  expect_identical(record$companions[["D4.1.7.SVY.HLTH"]]$rows, 2L)
  expect_identical(
    record$companions[["D4.1.7.SVY.HLTH"]]$sha256,
    digest::digest(paths$companion_files[["D4.1.7.SVY.HLTH"]], algo = "sha256", file = TRUE)
  )
  expect_true("microdata_library_public_studies.csv" %in% record$promoted_files)
  expect_length(staging_leftovers(raw_root), 0)

  # The promoted set passes the manifest checks.
  expect_no_error(dim4_1_build_manifest(raw_root, end_date = 2024))
})

test_that("the refresh record persists for later runs without a refresh", {
  fixture_root <- make_dim4_1_fixture_root()
  raw_root <- file.path(fixture_root, "01_raw_data")
  refreshed <- collect_dim4_1_catalogue(
    refresh_params(raw_root),
    refresh_fn = function(params, staging_dir) {
      stage_current_companions(raw_root, staging_dir)
      list(prefetch = list(requests = 7L, failed = 0L))
    }
  )
  expect_identical(refreshed$refresh$fetch$prefetch$requests, 7L)
  record_path <- dim4_1_catalogue_refresh_record_path(raw_root)
  expect_true(file.exists(record_path))

  later <- collect_dim4_1_catalogue(refresh_params(raw_root))
  expect_null(later$refresh)
  expect_identical(later$last_refresh$adapter, "injected")
  expect_identical(later$last_refresh$fetch$prefetch$requests, 7L)
  expect_true(later$last_refresh$matches_current_companions)

  # A companion changed after the refresh no longer matches the record.
  companion <- dim4_1_artifact_paths(raw_root, 2024)$companion_files[["D4.1.7.SVY.HLTH"]]
  lines <- readLines(companion)
  writeLines(c(lines, lines[length(lines)]), companion)
  expect_error(
    collect_dim4_1_catalogue(refresh_params(raw_root)),
    "D4.1 CATALOGUE REFRESH RECORD DOES NOT MATCH CURRENT COMPANION: D4.1.7.SVY.HLTH"
  )
})

test_that("without a recorded refresh the catalogue result says so", {
  fixture_root <- make_dim4_1_fixture_root()
  raw_root <- file.path(fixture_root, "01_raw_data")
  result <- collect_dim4_1_catalogue(refresh_params(raw_root))
  expect_null(result$last_refresh)
})

test_that("a companion the refresh does not produce is carried forward and recorded", {
  fixture_root <- make_dim4_1_fixture_root()
  raw_root <- file.path(fixture_root, "01_raw_data")
  stems <- names(dim4_1_workbook_specs())
  produced <- setdiff(stems, "D4.1.2.CEN.AGRI")
  carried_path <- dim4_1_artifact_paths(raw_root, 2024)$companion_files[["D4.1.2.CEN.AGRI"]]
  before <- digest::digest(carried_path, algo = "sha256", file = TRUE)
  record <- dim4_1_refresh_catalogue(
    refresh_params(raw_root),
    refresh_fn = function(params, staging_dir) {
      stage_current_companions(raw_root, staging_dir)
      unlink(file.path(staging_dir, "D4.1.2.CEN.AGRI_NADA.csv"))
    },
    companions = produced
  )
  expect_identical(record$carried_forward, "D4.1.2.CEN.AGRI")
  expect_identical(digest::digest(carried_path, algo = "sha256", file = TRUE), before)
  expect_false(record$companions[["D4.1.2.CEN.AGRI"]]$refreshed)
  expect_true(record$companions[["D4.1.6.SVY.LABR"]]$refreshed)
  expect_false("D4.1.2.CEN.AGRI_NADA.csv" %in% record$promoted_files)
  expect_length(staging_leftovers(raw_root), 0)
})

test_that("the legacy catalogue script writes seven of the eight companions", {
  code <- dim4_1_legacy_catalogue_code(dim4_1_catalogue_script_path())
  expect_setequal(
    dim4_1_catalogue_written_companions(code),
    setdiff(names(dim4_1_workbook_specs()), "D4.1.2.CEN.AGRI")
  )
})

test_that("the catalogue refresh enforces its run-time budget", {
  skip_if_not(exists("collect_dim4_1_catalogue", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root()
  raw_root <- file.path(fixture_root, "01_raw_data")
  before <- companion_hashes(raw_root)
  expect_error(
    collect_dim4_1_catalogue(
      refresh_params(raw_root, budget_minutes = 1 / 60),
      refresh_fn = function(params, staging_dir) {
        Sys.sleep(5)
        stage_current_companions(raw_root, staging_dir)
      }
    ),
    "D4.1 CATALOGUE REFRESH EXCEEDED ITS BUDGET"
  )
  expect_identical(companion_hashes(raw_root), before)
  expect_error(
    collect_dim4_1_catalogue(
      list(raw_dir = raw_root, end_date = 2024, run_downloads = FALSE),
      refresh_fn = function(params, staging_dir) invisible(NULL)
    ),
    "d41_catalogue_budget_minutes"
  )
})

test_that("the legacy catalogue adapter redirects the script output to staging", {
  skip_if_not(exists("dim4_1_legacy_catalogue_code", mode = "function"))
  code <- dim4_1_legacy_catalogue_code(
    here::here("02_programs", "misc_scripts", "microdata_library_pull.Rmd")
  )
  expect_true(any(grepl("^dir <- here[(][)]", code)))
  expect_true(any(grepl("output_dir <- paste[(]dir,", code)))
  expect_false(any(grepl("^library[(](skimr|kableExtra|Hmisc|gt|tidytext|rsdmx|ggthemes)[)]", code)))
  expect_false(any(grepl("path[[:space:]]*=", code)))
  urls <- dim4_1_catalogue_request_urls(code)
  expect_true(any(grepl("microdata.worldbank.org", urls, fixed = TRUE)))
  expect_true(any(grepl("api.worldbank.org/pip", urls, fixed = TRUE)))
})

test_that("D4.1 catalogue collection requires the reference year", {
  skip_if_not(exists("collect_dim4_1_catalogue", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root(normalize = FALSE)
  expect_error(
    collect_dim4_1_catalogue(list(
      raw_dir = file.path(fixture_root, "01_raw_data"),
      run_downloads = FALSE
    )),
    "REQUIRES end_date"
  )
})

test_that("D4.1 manifest validation rejects vintage and hash mismatches", {
  skip_if_not(exists("validate_dim4_1_manifest", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root()
  raw_root <- file.path(fixture_root, "01_raw_data")
  manifest <- dim4_1_build_manifest(raw_root, end_date = 2024)
  manifest_path <- file.path(tempdir(), "d41-manifest-test.json")
  write_dim4_1_manifest(manifest, manifest_path)

  expect_no_error(validate_dim4_1_manifest(manifest_path, raw_root, 2024))
  expect_error(
    validate_dim4_1_manifest(manifest_path, raw_root, 2025),
    "VINTAGE MISMATCH"
  )

  tampered <- manifest$derived[[1]]$path
  readr::write_lines("tampered", dim4_1_resolve_manifest_path(tampered))
  expect_error(
    validate_dim4_1_manifest(manifest_path, raw_root, 2024),
    "HASH MISMATCH"
  )
})

test_that("D4.1 manifest validation covers normalized companions and the naming authority", {
  skip_if_not(exists("validate_dim4_1_manifest", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root()
  raw_root <- file.path(fixture_root, "01_raw_data")
  manifest <- dim4_1_build_manifest(raw_root, end_date = 2024)
  manifest_path <- tempfile("d41-manifest-", fileext = ".json")
  write_dim4_1_manifest(manifest, manifest_path)
  expect_no_error(validate_dim4_1_manifest(manifest_path, raw_root, 2024))

  normalized <- dim4_1_artifact_paths(raw_root, 2024)$normalized_companion_files[[1]]
  original <- readLines(normalized)
  writeLines(original[-length(original)], normalized)
  expect_error(
    validate_dim4_1_manifest(manifest_path, raw_root, 2024),
    "HASH MISMATCH.*d41_catalogue_companion"
  )
  writeLines(original, normalized)

  writeLines("tampered", file.path(raw_root, "misc", "CLASS.xlsx"))
  expect_error(
    validate_dim4_1_manifest(manifest_path, raw_root, 2024),
    "HASH MISMATCH.*naming_authority"
  )

  outdated <- manifest
  outdated$schema_version <- "spi-d4.1-collection-v1"
  outdated$naming <- NULL
  write_dim4_1_manifest(outdated, manifest_path)
  expect_error(
    validate_dim4_1_manifest(manifest_path, raw_root, 2024),
    "MANIFEST SCHEMA"
  )
})

test_that("D4.1 companion validation fails on a missing file", {
  skip_if_not(exists("validate_dim4_1_companions", mode = "function"))
  expect_error(
    validate_dim4_1_companions(tempdir()),
    "D4.1 CATALOGUE COMPANION NOT FOUND"
  )
})

test_that("D4.1 artifact paths follow the configured reference year", {
  paths <- dim4_1_artifact_paths(here::here("01_raw_data"), 2025)

  expect_length(paths$input_files, 8)
  expect_length(paths$derived_files, 8)
  expect_true(all(grepl("[.]2025[.]csv$", paths$derived_files)))
  expect_match(paths$review_file, "D4[.]1[.]Manual[.]Review[.]2025[.]xlsx$")
  expect_length(paths$normalized_companion_files, 8)
  expect_true(all(grepl(
    "4[.]1_SOCS/collection/D4[.]1[.].*_NADA[.]iso3c[.]csv$",
    paths$normalized_companion_files
  )))
  expect_identical(names(paths$normalized_companion_files), names(paths$companion_files))
  expect_match(paths$naming_files$class_file, "01_raw_data/misc/CLASS[.]xlsx$")
})

# =============================================================================
# CLASS-name normalization of catalogue companions (202611 plan, Step 16)
# =============================================================================

test_that("D4.1 country lookup maps CLASS names and crosswalk variants to ISO3", {
  skip_if_not(exists("dim4_1_country_lookup", mode = "function"))
  lookup <- dim4_1_country_lookup(dim4_1_naming_files(here::here("01_raw_data")))
  iso3 <- function(name) lookup$iso3c[match(name, lookup$catalogue_name)]
  class_name <- function(name) lookup$country[match(name, lookup$catalogue_name)]

  expect_identical(
    iso3(c("Republic of Cabo Verde", "United Republic of Tanzania", "Yemen", "Korea, Dem. Rep.")),
    c("CPV", "TZA", "YEM", "PRK")
  )
  # CLASS economy names match directly.
  expect_identical(iso3(c("Czech Republic", "Nauru")), c("CZE", "NRU"))
  expect_identical(class_name("United Republic of Tanzania"), "Tanzania")
  expect_identical(class_name("Nauru"), "Nauru")
  expect_identical(iso3("Côte d'Ivoire"), "CIV")
  # Aggregates in the CLASS sheet are not economies.
  expect_true(is.na(iso3("World")))
  expect_false(anyDuplicated(lookup$catalogue_name) > 0L)
})

test_that("D4.1 crosswalk rows must point to CLASS economies without conflicts", {
  skip_if_not(exists("dim4_1_country_lookup", mode = "function"))
  naming <- dim4_1_naming_files(here::here("01_raw_data"))
  bad_code <- tempfile(fileext = ".csv")
  readr::write_csv(
    tibble::tibble(catalogue_name = "Atlantis", iso3c = "ATL", note = "test"),
    bad_code
  )
  expect_error(
    dim4_1_country_lookup(utils::modifyList(naming, list(crosswalk_file = bad_code))),
    "CROSSWALK CODE NOT IN CLASS.*ATL"
  )

  conflict <- tempfile(fileext = ".csv")
  readr::write_csv(
    tibble::tibble(catalogue_name = "Nauru", iso3c = "TUV", note = "test"),
    conflict
  )
  expect_error(
    dim4_1_country_lookup(utils::modifyList(naming, list(crosswalk_file = conflict))),
    "CROSSWALK CONFLICTS WITH CLASS.*Nauru"
  )
})

test_that("D4.1 normalization writes ISO3 companions and records exclusions", {
  skip_if_not(exists("normalize_dim4_1_companions", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root(normalize = FALSE)
  raw_root <- file.path(fixture_root, "01_raw_data")
  raw_path <- write_raw_companion(
    raw_root,
    "D4.1.7.SVY.HLTH",
    country = c("Republic of Cabo Verde", "Anguilla", "Nauru", "Nauru"),
    indicator_date = c(2018, 2019, 2010, 2010)
  )

  result <- normalize_dim4_1_companions(raw_root, end_date = 2024)
  hlth <- readr::read_csv(
    result$files[["D4.1.7.SVY.HLTH"]]$path,
    col_types = readr::cols(.default = "c")
  )
  expect_named(hlth, c("iso3c", "country", "indicator_date", "nada_dates", "nada_title"))
  expect_identical(hlth$iso3c, c("CPV", "NRU", "NRU"))
  expect_identical(hlth$country, c("Cabo Verde", "Nauru", "Nauru"))
  expect_identical(result$files[["D4.1.7.SVY.HLTH"]]$raw_rows, 4L)
  expect_identical(result$files[["D4.1.7.SVY.HLTH"]]$rows, 3L)
  expect_identical(result$files[["D4.1.7.SVY.HLTH"]]$duplicate_keys, 1L)
  expect_identical(
    result$files[["D4.1.7.SVY.HLTH"]]$crosswalked,
    list(`Republic of Cabo Verde` = 1L)
  )

  excluded <- result$exclusions[["D4.1.7.SVY.HLTH"]]
  expect_identical(exclusion_names(excluded), "Anguilla")
  expect_identical(excluded[[1]]$category, "non_economy")
  expect_identical(excluded[[1]]$rows, 1L)
  expect_equal(excluded[[1]]$dates, 2019)

  # The raw catalogue output is preserved unchanged.
  raw <- readr::read_csv(raw_path, col_types = readr::cols(.default = "c"))
  expect_identical(nrow(raw), 4L)
  expect_identical(raw$country[[2]], "Anguilla")
})

test_that("D4.1 normalization stops on an unknown country name", {
  skip_if_not(exists("normalize_dim4_1_companions", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root(normalize = FALSE)
  raw_root <- file.path(fixture_root, "01_raw_data")
  write_raw_companion(raw_root, "D4.1.1.CEN.POPU", "Unknownland", 2010)
  expect_error(
    normalize_dim4_1_companions(raw_root, end_date = 2024),
    "UNKNOWN COUNTRY NAME.*D4.1.1.CEN.POPU.*Unknownland"
  )
})

test_that("D4.1 blank-country rows are excluded only where recorded", {
  skip_if_not(exists("normalize_dim4_1_companions", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root(normalize = FALSE)
  raw_root <- file.path(fixture_root, "01_raw_data")
  write_raw_companion(raw_root, "D4.1.4.SVY.HOUS", c(NA, "Nauru"), c(2016, 2012))
  result <- normalize_dim4_1_companions(raw_root, end_date = 2024)
  hous <- result$exclusions[["D4.1.4.SVY.HOUS"]]
  expect_identical(exclusion_names(hous), "<blank>")
  expect_identical(hous[[1]]$category, "blank_country")
  expect_identical(result$files[["D4.1.4.SVY.HOUS"]]$rows, 1L)

  write_raw_companion(raw_root, "D4.1.1.CEN.POPU", c(NA, "Nauru"), c(2011, 2011))
  expect_error(
    normalize_dim4_1_companions(raw_root, end_date = 2024),
    "UNKNOWN COUNTRY NAME.*D4.1.1.CEN.POPU.*<blank>"
  )
})

test_that("D4.1 normalization keeps and counts catalogue studies dated after the reference year", {
  # A catalogue refreshed after the reference year lists studies that started
  # later; the scoring ignores them for earlier reference years, as in the
  # legacy pipeline. Years beyond a plausible refresh horizon still stop.
  skip_if_not(exists("normalize_dim4_1_companions", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root(normalize = FALSE)
  raw_root <- file.path(fixture_root, "01_raw_data")
  write_raw_companion(raw_root, "D4.1.5.SVY.AGRI", "Nauru", c(2023, 2025))
  result <- normalize_dim4_1_companions(raw_root, end_date = 2024)
  expect_identical(result$files[["D4.1.5.SVY.AGRI"]]$after_end_date, 1L)
  normalized <- readr::read_csv(
    dim4_1_artifact_paths(raw_root, 2024)$normalized_companion_files[["D4.1.5.SVY.AGRI"]],
    col_types = readr::cols(.default = readr::col_character())
  )
  expect_identical(normalized$indicator_date, c("2023", "2025"))

  write_raw_companion(raw_root, "D4.1.5.SVY.AGRI", "Nauru", 2027)
  expect_error(
    normalize_dim4_1_companions(raw_root, end_date = 2024),
    "MORE THAN 2 YEARS AFTER END_DATE.*D4.1.5.SVY.AGRI"
  )
})

test_that("D4.1 manifest build stops when a normalized companion is stale", {
  skip_if_not(exists("dim4_1_build_manifest", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root()
  raw_root <- file.path(fixture_root, "01_raw_data")
  write_raw_companion(raw_root, "D4.1.3.CEN.BIZZ", "Nauru", 2010)
  expect_error(
    dim4_1_build_manifest(raw_root, end_date = 2024),
    "NORMALIZED COMPANION IS STALE.*D4.1.3.CEN.BIZZ"
  )
  unlink(dim4_1_artifact_paths(raw_root, 2024)$normalized_companion_files[["D4.1.3.CEN.BIZZ"]])
  expect_error(
    dim4_1_build_manifest(raw_root, end_date = 2024),
    "NORMALIZED COMPANION NOT FOUND"
  )
})

test_that("D4.1 current catalogue companions normalize with the recorded exclusions", {
  skip_if_not(exists("normalize_dim4_1_companions", mode = "function"))
  output_dir <- tempfile("d41-normalized-")
  result <- normalize_dim4_1_companions(
    here::here("01_raw_data"),
    end_date = 2025,
    output_dir = output_dir
  )
  expect_length(result$files, 8)
  expect_true(all(file.exists(vapply(result$files, `[[`, character(1), "path"))))
  expect_true(all(startsWith(
    vapply(result$files, `[[`, character(1), "path"),
    output_dir
  )))

  categories <- unlist(lapply(result$exclusions, function(records) {
    vapply(records, `[[`, character(1), "category")
  }))
  expect_setequal(
    unique(categories),
    c("non_economy", "multi_country_study", "blank_country", "outside_country_universe")
  )
  expect_true("<blank>" %in% exclusion_names(result$exclusions[["D4.1.4.SVY.HOUS"]]))
  expect_true("<blank>" %in% exclusion_names(result$exclusions[["D4.1.6.SVY.LABR"]]))
  # Companions of the 24 October 2026 catalogue refresh: the health
  # catalogue now spells "Cook Island" and lists "Serbia and Montenegro"
  # (both recorded in config/d41_companion_exclusions.csv during the refresh,
  # pending the technical lead's review).
  expect_setequal(
    exclusion_names(result$exclusions[["D4.1.7.SVY.HLTH"]]),
    c("Anguilla", "Cook Island", "Montserrat", "Niue", "Serbia and Montenegro")
  )
  expect_true("Taiwan, China" %in% exclusion_names(result$exclusions[["D4.1.8.SVY.BIZZ"]]))

  # Economies whose catalogue names did not match World Bank API names.
  read_iso3 <- function(stem) {
    readr::read_csv(result$files[[stem]]$path, col_types = readr::cols(.default = "c"))$iso3c
  }
  expect_true(all(c("CPV", "PRK", "CZE") %in% read_iso3("D4.1.7.SVY.HLTH")))
  expect_true("NRU" %in% read_iso3("D4.1.4.SVY.HOUS"))
  expect_true("TZA" %in% read_iso3("D4.1.2.CEN.AGRI"))
  expect_true(all(c("TZA", "YEM") %in% read_iso3("D4.1.5.SVY.AGRI")))
  expect_false(anyNA(unlist(lapply(names(result$files), read_iso3))))
})

# =============================================================================
# Workbook coverage and strict year parsing (202611 plan, Step 16)
# =============================================================================

test_that("D4.1 year parsing accepts only four-digit years and register-based census", {
  skip_if_not(exists("dim4_1_check_year_values", mode = "function"))
  expect_invisible(dim4_1_check_year_values(
    c("2011, 2021", NA, "", "Register based census, 2011", "register-based census"),
    "D2.1.CEN.POPU.xlsx",
    allow_register = TRUE
  ))
  expect_error(
    dim4_1_check_year_values(c("2011", "c. 2015"), "D2.4.SVY.HOUS.xlsx", allow_register = FALSE),
    "INVALID YEAR TEXT in 'D2.4.SVY.HOUS.xlsx'.*c. 2015"
  )
  expect_error(
    dim4_1_check_year_values("201", "D2.4.SVY.HOUS.xlsx", allow_register = FALSE),
    "INVALID YEAR TEXT"
  )
  expect_error(
    dim4_1_check_year_values("Register based census", "D2.4.SVY.HOUS.xlsx", allow_register = FALSE),
    "INVALID YEAR TEXT"
  )
})

# Minimal population-census workbook (sheet "Data", no preamble rows).
write_popu_workbook <- function(raw_root, codes, years) {
  writexl::write_xlsx(
    list(Data = data.frame(Code = codes, Country = codes, Years = years)),
    file.path(raw_root, "4.1_SOCS", "raw", "input", "D2.1.CEN.POPU.xlsx")
  )
}

popu_metadata <- data.frame(
  iso3c = c("AFG", "ALB"),
  country = c("Afghanistan", "Albania"),
  stringsAsFactors = FALSE
)

test_that("D4.1 preprocessing stops when a workbook loses countries", {
  skip_if_not(exists("preprocess_dim4_1", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root(normalize = FALSE)
  raw_root <- file.path(fixture_root, "01_raw_data")
  write_popu_workbook(raw_root, c("AFG", "ALB"), c("1979", "2011"))
  readr::write_csv(
    data.frame(iso3c = c("AFG", "ALB", "ZZZ"), date = 2023, POP.CENSUS = NA),
    file.path(raw_root, "4.1_SOCS", "raw", "D4.1.1.CEN.POPU.2023.csv")
  )
  expect_error(
    preprocess_dim4_1(raw_root, 2024, popu_metadata, output_dir = tempfile("d41-out-")),
    "COVERAGE LOSS in 'D2.1.CEN.POPU.xlsx'.*ZZZ"
  )

  unlink(file.path(raw_root, "4.1_SOCS", "raw", "D4.1.1.CEN.POPU.2023.csv"))
  expect_error(
    preprocess_dim4_1(raw_root, 2024, popu_metadata, output_dir = tempfile("d41-out-")),
    "PREVIOUS DERIVED FILE NOT FOUND"
  )
})

test_that("D4.1 preprocessing stops on invalid year text", {
  skip_if_not(exists("preprocess_dim4_1", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root(normalize = FALSE)
  raw_root <- file.path(fixture_root, "01_raw_data")
  write_popu_workbook(raw_root, c("AFG", "ALB"), c("1979", "around 2011"))
  readr::write_csv(
    data.frame(iso3c = c("AFG", "ALB"), date = 2023, POP.CENSUS = NA),
    file.path(raw_root, "4.1_SOCS", "raw", "D4.1.1.CEN.POPU.2023.csv")
  )
  expect_error(
    preprocess_dim4_1(raw_root, 2024, popu_metadata, output_dir = tempfile("d41-out-")),
    "INVALID YEAR TEXT in 'D2.1.CEN.POPU.xlsx'.*around 2011"
  )
})

test_that("D4.1 preprocessing writes all current-vintage artifacts", {
  if (!exists("preprocess_dim4_1", mode = "function")) {
    fail("Create preprocess_dim4_1() before wiring the collection target.")
    return(invisible(NULL))
  }
  metadata <- readr::read_csv(
    here::here("01_raw_data", "metadata", "iso_codes.csv"),
    show_col_types = FALSE
  )
  metadata <- dplyr::bind_rows(
    metadata,
    tibble::tibble(
      country = "Kosovo",
      geoAreaCode = NA_real_,
      iso3c = "XKX"
    )
  )
  output_dir <- tempfile("d41-preprocess-")
  dir.create(output_dir, recursive = TRUE)

  result <- preprocess_dim4_1(
    raw_dir = here::here("01_raw_data"),
    end_date = 2024,
    country_metadata = metadata,
    output_dir = output_dir
  )

  expect_length(result, 8)
  expect_true(all(file.exists(unname(result))))
  for (path in result) {
    data <- readr::read_csv(path, show_col_types = FALSE)
    expect_true(all(data$date == 2024))
  }
})

test_that("D4.1 preprocessing rejects missing country metadata", {
  skip_if_not(exists("dim4_1_join_country_metadata", mode = "function"))
  expect_error(
    dim4_1_join_country_metadata(
      data.frame(iso3c = "XKX", stringsAsFactors = FALSE),
      data.frame(iso3c = "AAA", country = "A", stringsAsFactors = FALSE),
      "fixture.csv"
    ),
    "COUNTRY METADATA MISSING"
  )
})

test_that("D4.1 derived validation rejects duplicate country-year keys", {
  skip_if_not(exists("validate_dim4_1_derived", mode = "function"))
  output_dir <- tempfile("d41-derived-")
  dir.create(output_dir, recursive = TRUE)
  source_paths <- dim4_1_artifact_paths(
    here::here("01_raw_data"),
    end_date = 2024
  )$derived_files
  file.copy(unname(source_paths), output_dir, overwrite = TRUE)
  path <- file.path(output_dir, basename(source_paths[[1]]))
  data <- readr::read_csv(path, show_col_types = FALSE)
  readr::write_csv(dplyr::bind_rows(data, data[1, ]), path)

  expect_error(
    validate_dim4_1_derived(
      raw_dir = here::here("01_raw_data"),
      end_date = 2024,
      output_dir = output_dir
    ),
    "DUPLICATE COUNTRY/YEAR"
  )
})

# =============================================================================
# Review vintages collapse per country (202611 readiness plan, Step 2)
# =============================================================================

source(file.path(here::here("R"), "dim4.R"))

review_row <- function(iso3c, pop = NA_character_, hous = NA_character_, evidence = NA_character_) {
  if (is.na(evidence) && any(nzchar(c(pop, hous)), na.rm = TRUE)) {
    evidence <- "test evidence"
  }
  tibble::tibble(
    iso3c = iso3c,
    country = iso3c,
    POP.CENSUS = pop,
    AGRI.CENSUS = NA_character_,
    BIZZ.CENSUS = NA_character_,
    HOUS.SURVEYS = hous,
    AGRI.SURVEYS = NA_character_,
    LABR.SURVEYS = NA_character_,
    HLTH.SURVEYS = NA_character_,
    BIZZ.SURVEYS = NA_character_,
    Evidence = evidence
  )
}

make_review_vintages <- function(reviews) {
  raw <- withr::local_tempdir(.local_envir = parent.frame())
  raw_sub <- file.path(raw, "4.1_SOCS", "raw")
  dir.create(raw_sub, recursive = TRUE)
  for (year in names(reviews)) {
    writexl::write_xlsx(
      reviews[[year]],
      file.path(raw_sub, sprintf("D4.1.Manual.Review.%s.xlsx", year))
    )
  }
  list(raw_dir = raw, end_date = max(as.integer(names(reviews))))
}

write_normalized_companion <- function(raw_dir, stem, rows) {
  directory <- file.path(raw_dir, "4.1_SOCS", "collection")
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(rows, file.path(directory, paste0(stem, "_NADA.iso3c.csv")), na = "")
}

test_that("D4.1 review vintages collapse to one additive row per country", {
  params <- make_review_vintages(list(
    "2024" = dplyr::bind_rows(review_row("AFG", pop = "2016", evidence = "NSO site"), review_row("BEN")),
    "2025" = dplyr::bind_rows(review_row("AFG", pop = "2023", evidence = "Census report"), review_row("BEN", pop = "2024"))
  ))
  out <- .read_manual_review(params)

  expect_equal(nrow(out), 2)
  expect_false(anyDuplicated(out$iso3c) > 0)
  afg <- out[out$iso3c == "AFG", ]
  expect_match(afg$POP.CENSUS, "2016")
  expect_match(afg$POP.CENSUS, "2023")
  expect_match(afg$Evidence, "NSO site")
  expect_match(afg$Evidence, "Census report")
  expect_match(out$POP.CENSUS[out$iso3c == "BEN"], "2024")
})

test_that("an empty current review leaves the previous review unchanged", {
  only_2024 <- make_review_vintages(list("2024" = review_row("AFG", pop = "2016")))
  with_empty_2025 <- make_review_vintages(list(
    "2024" = review_row("AFG", pop = "2016"),
    "2025" = review_row("AFG")
  ))
  expect_equal(
    .read_manual_review(with_empty_2025)$POP.CENSUS,
    .read_manual_review(only_2024)$POP.CENSUS
  )
})

test_that("register-based census evidence survives the collapse", {
  params <- make_review_vintages(list(
    "2024" = review_row("DNK", pop = "Register based census"),
    "2025" = review_row("DNK", pop = "2021")
  ))
  out <- .read_manual_review(params)
  expect_match(out$POP.CENSUS, "Register based census")
  expect_match(out$POP.CENSUS, "2021")
})

test_that("duplicate countries within one review vintage fail loudly", {
  params <- make_review_vintages(list(
    "2025" = dplyr::bind_rows(review_row("AFG", pop = "2016"), review_row("AFG", pop = "2020"))
  ))
  expect_error(.read_manual_review(params), "DUPLICATE COUNTRY KEYS")
})

test_that("census scoring runs with two review vintages present", {
  params <- make_review_vintages(list(
    "2024" = review_row("AFG", pop = "2016"),
    "2025" = review_row("AFG", pop = "2023")
  ))
  readr::write_csv(
    tibble::tibble(iso3c = "AFG", date = 2025, POP.CENSUS = "2015"),
    file.path(params$raw_dir, "4.1_SOCS", "raw", "D4.1.1.CEN.POPU.2025.csv")
  )
  write_normalized_companion(
    params$raw_dir,
    "D4.1.1.CEN.POPU",
    tibble::tibble(iso3c = "AFG", country = "Afghanistan", indicator_date = 2015, nada_dates = "2015", nada_title = "Census")
  )
  params$span <- 2004:2025
  params$country_metadata <- tibble::tibble(iso3c = "AFG", country = "Afghanistan")

  result <- suppressMessages(suppressWarnings(census_fun("D4.1.1.CEN.POPU", "POP.CENSUS", params)))
  latest <- result$input_var[result$date == 2025]
  expect_length(latest, 1)
  expect_match(latest, "2016")
  expect_match(latest, "2023")
})

test_that("survey scoring joins catalogue companions by ISO3, not by API country names", {
  params <- make_review_vintages(list("2025" = review_row("NRU")))
  readr::write_csv(
    tibble::tibble(iso3c = "NRU", date = 2025, HOUS.SURVEYS = NA_character_),
    file.path(params$raw_dir, "4.1_SOCS", "raw", "D4.1.4.SVY.HOUS.2025.csv")
  )
  write_normalized_companion(
    params$raw_dir,
    "D4.1.4.SVY.HOUS",
    tibble::tibble(
      iso3c = "NRU",
      country = "Nauru",
      indicator_date = c(2015, 2018, 2021),
      nada_dates = "2015, 2018, 2021",
      nada_title = "Household survey"
    )
  )
  # The World Bank API renamed NRU to "Naoero"; the join must not depend on it.
  params$country_metadata <- tibble::tibble(iso3c = "NRU", country = "Naoero")

  result <- suppressMessages(survey_fun("D4.1.4.SVY.HOUS", "HOUS.SURVEYS", params))
  latest <- result[result$iso3c == "NRU" & result$date == 2025, ]
  expect_identical(nrow(latest), 1L)
  expect_equal(latest$indicator, 1)
  expect_identical(latest$nada_dates, "2015, 2018, 2021")
})

test_that("survey scoring stops when the normalized companion is missing", {
  params <- make_review_vintages(list("2025" = review_row("NRU")))
  readr::write_csv(
    tibble::tibble(iso3c = "NRU", date = 2025, HOUS.SURVEYS = "2019"),
    file.path(params$raw_dir, "4.1_SOCS", "raw", "D4.1.4.SVY.HOUS.2025.csv")
  )
  expect_error(
    suppressMessages(survey_fun("D4.1.4.SVY.HOUS", "HOUS.SURVEYS", params)),
    "NORMALIZED COMPANION NOT FOUND"
  )
})

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

make_dim4_1_fixture_root <- function() {
  root <- tempfile("d41-fixture-")
  raw_root <- file.path(root, "01_raw_data")
  input_fixture <- file.path(raw_root, "4.1_SOCS", "raw", "input")
  raw_fixture <- file.path(raw_root, "4.1_SOCS", "raw")
  companion_fixture <- file.path(raw_root, "4.1_SOCS")
  dir.create(input_fixture, recursive = TRUE, showWarnings = FALSE)
  dir.create(companion_fixture, recursive = TRUE, showWarnings = FALSE)

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
    companion <- readr::read_csv(path, show_col_types = FALSE)
    companion$country[is.na(companion$country)] <- "Kosovo"
    companion <- companion |>
      dplyr::filter(indicator_date <= 2024) |>
      dplyr::mutate(.canonical_country = dim4_1_canonical_country(country)) |>
      dplyr::distinct(.canonical_country, indicator_date, .keep_all = TRUE) |>
      dplyr::select(-.canonical_country)
    destination <- fixture_paths$companion_files[[basename(path) |>
      sub("_NADA[.]csv$", "", x = _)]]
    readr::write_csv(companion, destination)
  }
  root
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
  expect_equal(manifest$schema_version, "spi-d4.1-collection-v1")
  expect_equal(manifest$end_date, 2024)
  expect_length(manifest$inputs, 8)
  expect_length(manifest$derived, 8)
  expect_length(manifest$companions, 8)
  expect_match(manifest$review$sha256, "^[0-9a-f]{64}$")
  expect_true(all(vapply(manifest$derived, function(item) {
    grepl("^[0-9a-f]{64}$", item$sha256)
  }, logical(1))))
})

test_that("D4.1 companion files validate as a separate catalogue artifact class", {
  skip_if_not(exists("validate_dim4_1_companions", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root()
  companions <- validate_dim4_1_companions(file.path(fixture_root, "01_raw_data"))
  expect_length(companions$files, 8)
  expect_true(all(vapply(companions$files, function(item) item$rows > 0, logical(1))))
})

test_that("D4.1 companion validation rejects unknown country names", {
  skip_if_not(exists("validate_dim4_1_companions", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root()
  path <- file.path(
    fixture_root,
    "01_raw_data",
    "4.1_SOCS",
    "D4.1.1.CEN.POPU_NADA.csv"
  )
  data <- readr::read_csv(path, show_col_types = FALSE)
  data$country[[1]] <- "Unknownland"
  readr::write_csv(data, path)
  allowed <- data.frame(
    country = setdiff(unique(data$country), "Unknownland"),
    stringsAsFactors = FALSE
  )
  expect_error(
    validate_dim4_1_companions(
      file.path(fixture_root, "01_raw_data"),
      country_metadata = allowed
    ),
    "UNKNOWN COUNTRY NAME"
  )
})

test_that("D4.1 companion validation blocks unresolved labour rows", {
  skip_if_not(exists("validate_dim4_1_companions", mode = "function"))
  expect_error(
    validate_dim4_1_companions(here::here("01_raw_data"), end_date = 2024),
    "MISSING COUNTRY"
  )
})

test_that("D4.1 companion validation records duplicate catalogue rows", {
  skip_if_not(exists("validate_dim4_1_companions", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root()
  path <- file.path(
    fixture_root,
    "01_raw_data",
    "4.1_SOCS",
    "D4.1.5.SVY.AGRI_NADA.csv"
  )
  data <- readr::read_csv(path, show_col_types = FALSE)
  readr::write_csv(dplyr::bind_rows(data, data[1, ]), path)
  companions <- validate_dim4_1_companions(
    file.path(fixture_root, "01_raw_data"),
    end_date = 2024
  )
  expect_gt(companions$files[["D4.1.5.SVY.AGRI"]]$duplicate_keys, 0)
})

test_that("D4.1 catalogue collection validates external companions without downloads", {
  skip_if_not(exists("collect_dim4_1_catalogue", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root()
  result <- collect_dim4_1_catalogue(list(
    raw_dir = file.path(fixture_root, "01_raw_data"),
    run_downloads = FALSE
  ))
  expect_identical(result$status, "validated_external_artifacts")
  expect_false(result$refreshed)
  expect_length(result$companion_files, 8)
})

test_that("D4.1 catalogue collection records an injected refresh", {
  skip_if_not(exists("collect_dim4_1_catalogue", mode = "function"))
  fixture_root <- make_dim4_1_fixture_root()
  called <- FALSE
  result <- collect_dim4_1_catalogue(
    list(
      raw_dir = file.path(fixture_root, "01_raw_data"),
      run_downloads = FALSE
    ),
    refresh_fn = function(params) {
      called <<- TRUE
      invisible(params)
    }
  )
  expect_true(called)
  expect_identical(result$status, "refreshed")
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

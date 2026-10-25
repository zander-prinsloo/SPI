# =============================================================================
# Final output manifest tests
# =============================================================================
# Created: 2026-10-05
# =============================================================================

library(testthat)
source(file.path(here::here("R"), "output_manifest.R"))

write_nonempty_outputs <- function(directory, end_date) {
  files <- expected_estimation_outputs(end_date)
  paths <- file.path(directory, files)
  for (index in seq_along(files)) {
    file <- files[[index]]
    path <- paths[[index]]
    if (identical(tools::file_ext(file), "md")) {
      writeLines("fixture", path)
      next
    }
    keys <- output_artifact_key_columns(file)
    row <- stats::setNames(as.list(rep("AAA", length(keys))), keys)
    if ("date" %in% keys) {
      row$date <- as.character(end_date)
    }
    if ("Time" %in% keys) {
      row$Time <- as.character(end_date)
    }
    if ("year" %in% keys) {
      row$year <- as.character(end_date)
    }
    if ("source_id" %in% keys) {
      row$source_id <- "SPI.D2.2.Machine.readable"
    }
    if ("Series" %in% keys) {
      row$Series <- "SPI.D2.2.Machine.readable"
    }
    if ("measure" %in% keys) {
      row$measure <- "SPI.INDEX.PIL2"
    }
    if ("indicator" %in% keys) {
      row$indicator <- "SPI.D2.2.Machine.readable"
    }
    if ("dimension" %in% keys) {
      row$dimension <- "D2.2"
    }
    data <- as.data.frame(row, stringsAsFactors = FALSE)
    data$value <- "1"
    if (identical(tools::file_ext(file), "dta")) {
      names(data) <- gsub(".", "_", names(data), fixed = TRUE)
      haven::write_dta(data, path)
    } else {
      readr::write_csv(data, path, na = "")
    }
  }
  paths
}

test_that("output manifest fails clearly when final artifacts are missing", {
  expect_error(
    validate_output_manifest(tempdir()),
    "FINAL OUTPUT SET INCOMPLETE"
  )
})

test_that("output manifest passes when every expected artifact exists", {
  root <- tempfile("output-manifest-")
  dir.create(root, recursive = TRUE)
  write_nonempty_outputs(root, 2024)

  result <- validate_output_manifest(root, 2024)

  expect_true(all(result$present))
  expect_equal(nrow(result), length(expected_estimation_outputs(2024)))
  expect_true(file.exists(file.path(root, "_estimation_manifest.json")))
})

test_that("output manifest rejects empty artifacts", {
  root <- tempfile("output-manifest-empty-")
  dir.create(root, recursive = TRUE)
  write_nonempty_outputs(root, 2024)
  file.create(file.path(root, "SPI_data.csv"))
  expect_error(
    validate_output_manifest(root, 2024),
    "CONTAINS EMPTY FILE"
  )
})

test_that("validated candidate outputs are promoted as a complete set", {
  candidate <- tempfile("spi-candidate-")
  output <- tempfile("spi-final-")
  dir.create(candidate, recursive = TRUE)
  dir.create(output, recursive = TRUE)
  write_nonempty_outputs(candidate, 2024)
  validate_output_manifest(candidate, 2024)

  promote_output_set(candidate, output, 2024)

  expect_true(all(file.exists(file.path(output, expected_estimation_outputs(2024)))))
  expect_true(file.exists(file.path(output, "_estimation_manifest.json")))
})

# --- 202611 readiness plan, Step 4: incremental output writing ---------------

test_that("the output candidate folder is created but never wiped", {
  candidate <- file.path(withr::local_tempdir(), ".candidate")
  expect_identical(ensure_output_candidate(candidate), candidate)
  expect_true(dir.exists(candidate))

  writeLines("kept", file.path(candidate, "SPI_data.csv"))
  ensure_output_candidate(candidate)
  expect_equal(readLines(file.path(candidate, "SPI_data.csv")), "kept")
})

test_that("promotion returns the promoted paths and ignores unexpected files", {
  candidate <- withr::local_tempdir()
  output <- withr::local_tempdir()
  write_nonempty_outputs(candidate, 2025)
  file.create(file.path(candidate, "stray_from_old_run.csv"))
  validate_output_manifest(candidate, 2025)

  promoted <- promote_output_set(candidate, output, 2025)

  expect_type(promoted, "character")
  expect_setequal(
    basename(promoted),
    c(expected_estimation_outputs(2025), "_estimation_manifest.json")
  )
  expect_true(all(file.exists(promoted)))
  expect_false(file.exists(file.path(output, "stray_from_old_run.csv")))
})

# --- ODIN provisional marker (202611 plan, Step 20) ---------------------------

make_odin_candidate <- function(end_date = 2025) {
  candidate <- tempfile("spi-candidate-")
  dir.create(candidate, recursive = TRUE)
  write_nonempty_outputs(candidate, end_date)
  writeLines(
    c(
      "iso3c,date,SPI.D1.5.POV,SPI.D2.2.Machine.readable,RAW.D2.2.Openness.subscore,SPI.D4.3.GEO.first.admin.level,SPI.D5.1.DILG",
      "AAA,2025,1,1,1,1,1"
    ),
    file.path(candidate, "SPI_data.csv")
  )
  writeLines(
    c(
      "country,iso3c,date,SPI.INDEX.PIL1,SPI.INDEX.PIL2,SPI.INDEX.PIL4,SPI.INDEX,SPI.DIM2.2.INDEX,SPI.DIM4.3.INDEX,SPI.DIM5.1.INDEX",
      "AAA,AAA,2025,1,1,1,1,1,1,1"
    ),
    file.path(candidate, "SPI_index.csv")
  )
  odin_dir <- tempfile("odin-")
  dir.create(odin_dir)
  odin_files <- file.path(odin_dir, sprintf("ODIN_%d.csv", c(end_date - 1L, end_date)))
  writeLines(c("a", "1"), odin_files[[1]])
  writeLines(c("a", "2"), odin_files[[2]])
  list(
    candidate = candidate,
    odin_files = odin_files,
    end_date = end_date,
    odin_release_record = list(
      schema_version = "spi-odin-release-v1",
      source_url = "https://odin.opendatawatch.com",
      release_label = "ODIN official fixture",
      released_at = "2026-12-07T00:00:00Z",
      approved_by = "fixture",
      files = lapply(odin_files, function(path) list(
        file = basename(path),
        sha256 = digest::digest(path, algo = "sha256", file = TRUE),
        provisional_sha256 = strrep("0", 64)
      ))
    )
  )
}

test_that("a provisional ODIN run records its status and writes the marker", {
  setup <- make_odin_candidate()
  validate_output_manifest(
    setup$candidate,
    setup$end_date,
    odin = list(status = "provisional", files = setup$odin_files)
  )
  manifest <- jsonlite::read_json(file.path(setup$candidate, "_estimation_manifest.json"))
  expect_identical(manifest$odin_status, "provisional")
  expect_setequal(vapply(manifest$odin_files, `[[`, character(1), "file"), basename(setup$odin_files))
  expect_identical(
    manifest$odin_files[[2]]$sha256,
    digest::digest(setup$odin_files[[2]], algo = "sha256", file = TRUE)
  )
  dependent <- unlist(manifest$odin_dependent_columns)
  expect_setequal(dependent, c(
    "SPI.D2.2.Machine.readable", "RAW.D2.2.Openness.subscore", "SPI.D4.3.GEO.first.admin.level",
    "SPI.INDEX.PIL2", "SPI.INDEX.PIL4", "SPI.INDEX", "SPI.DIM2.2.INDEX", "SPI.DIM4.3.INDEX"
  ))
  expect_true(file.exists(file.path(setup$candidate, "PROVISIONAL_ODIN.md")))
  expect_match(
    paste(readLines(file.path(setup$candidate, "PROVISIONAL_ODIN.md")), collapse = "\n"),
    "ODIN_2025.csv"
  )

  output <- tempfile("spi-final-")
  promoted <- promote_output_set(setup$candidate, output, setup$end_date)
  expect_true(file.exists(file.path(output, "PROVISIONAL_ODIN.md")))
  expect_true(file.path(output, "PROVISIONAL_ODIN.md") %in% promoted)
})

test_that("an official ODIN run removes the provisional marker", {
  setup <- make_odin_candidate()
  output <- tempfile("spi-final-")
  dir.create(output)
  writeLines("stale", file.path(output, "PROVISIONAL_ODIN.md"))
  writeLines("stale", file.path(setup$candidate, "PROVISIONAL_ODIN.md"))
  validate_output_manifest(
    setup$candidate,
    setup$end_date,
    odin = list(status = "official", files = setup$odin_files),
    odin_release_record = setup$odin_release_record
  )
  expect_false(file.exists(file.path(setup$candidate, "PROVISIONAL_ODIN.md")))
  promote_output_set(setup$candidate, output, setup$end_date)
  expect_false(file.exists(file.path(output, "PROVISIONAL_ODIN.md")))
  manifest <- jsonlite::read_json(file.path(output, "_estimation_manifest.json"))
  expect_identical(manifest$odin_status, "official")
})

test_that("official ODIN outputs require a release record that replaces provisional hashes", {
  setup <- make_odin_candidate()
  expect_error(
    validate_output_manifest(
      setup$candidate,
      setup$end_date,
      odin = list(status = "official", files = setup$odin_files)
    ),
    "REQUIRE A VALIDATED RELEASE RECORD"
  )
  unchanged <- setup$odin_release_record
  unchanged$files[[1]]$provisional_sha256 <- unchanged$files[[1]]$sha256
  record_path <- tempfile(fileext = ".json")
  jsonlite::write_json(unchanged, record_path, auto_unbox = TRUE)
  expect_error(
    read_odin_release_record(record_path, setup$odin_files),
    "DOES NOT REPLACE THE PROVISIONAL HASH"
  )
})

test_that("an unknown ODIN status stops", {
  setup <- make_odin_candidate()
  expect_error(
    validate_output_manifest(
      setup$candidate,
      setup$end_date,
      odin = list(status = "draft", files = setup$odin_files)
    ),
    "ODIN STATUS MUST BE 'provisional' OR 'official'"
  )
})

test_that("a release-diff report in the candidate is promoted with the outputs", {
  candidate <- tempfile("spi-candidate-")
  output <- tempfile("spi-final-")
  dir.create(candidate)
  write_nonempty_outputs(candidate, 2025)
  validate_output_manifest(candidate, 2025)
  for (file in c("release_diff_2025.csv", "release_diff_2025.md")) writeLines("report", file.path(candidate, file))
  promoted <- promote_output_set(candidate, output, 2025)
  expect_true(all(file.exists(file.path(output, c("release_diff_2025.csv", "release_diff_2025.md")))))
})

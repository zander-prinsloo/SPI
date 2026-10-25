# =============================================================================
# Provisional-to-final release diff (202611 readiness plan, Step 25)
# =============================================================================
# Created: 2026-10-24
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "collection_attestation.R"))
source(file.path(here::here("R"), "collection_cache.R"))
source(file.path(here::here("R"), "collection_status.R"))
source(file.path(here::here("R"), "output_manifest.R"))
source(file.path(here::here("R"), "release_lock.R"))
source(file.path(here::here("R"), "release_diff.R"))

write_pair <- function(file, archive_rows, candidate_rows) {
  root <- withr::local_tempdir(.local_envir = parent.frame())
  archive <- file.path(root, "archive")
  candidate <- file.path(root, "candidate")
  dir.create(archive)
  dir.create(candidate)
  write_dta_fixture <- function(data, path) {
    names(data) <- gsub(".", "_", names(data), fixed = TRUE)
    haven::write_dta(data, path)
  }
  if (identical(tools::file_ext(file), "dta")) {
    write_dta_fixture(archive_rows, file.path(archive, file))
    write_dta_fixture(candidate_rows, file.path(candidate, file))
  } else {
    readr::write_csv(archive_rows, file.path(archive, file), na = "")
    readr::write_csv(candidate_rows, file.path(candidate, file), na = "")
  }
  list(archive = archive, candidate = candidate)
}

spi_data <- data.frame(
  iso3c = c("AAA", "BBB"), date = 2025,
  SPI.D1.5.POV = c(1, 0.5),
  SPI.D2.2.Machine.readable = c(0.4, 0.6),
  RAW.D4.3.GEO.first.admin.level = c(40, 60)
)

test_that("only ODIN-dependent columns changing passes", {
  changed <- spi_data
  changed$SPI.D2.2.Machine.readable <- c(0.5, 0.7)
  changed$RAW.D4.3.GEO.first.admin.level <- c(41, 60)
  dirs <- write_pair("SPI_data.csv", spi_data, changed)
  report <- build_release_diff(dirs$archive, dirs$candidate, 2025, files = "SPI_data.csv")
  expect_identical(nrow(report), 3L)
  expect_true(all(report$allowed))
  expect_silent(enforce_release_diff(report, "report.md"))
})

test_that("the Stata output uses the same ODIN allowlist as CSV output", {
  changed <- spi_data
  changed$SPI.D2.2.Machine.readable <- c(0.5, 0.7)
  dirs <- write_pair("SPI_data.dta", spi_data, changed)
  report <- build_release_diff(dirs$archive, dirs$candidate, 2025, files = "SPI_data.dta")
  expect_true(all(report$allowed))

  changed <- spi_data
  changed$SPI.D1.5.POV[[2]] <- 1
  dirs <- write_pair("SPI_data.dta", spi_data, changed)
  report <- build_release_diff(dirs$archive, dirs$candidate, 2025, files = "SPI_data.dta")
  expect_identical(report$column, "SPI.D1.5.POV")
  expect_false(report$allowed)
})

test_that("any other change fails", {
  changed <- spi_data
  changed$SPI.D1.5.POV[[2]] <- 1
  dirs <- write_pair("SPI_data.csv", spi_data, changed)
  report <- build_release_diff(dirs$archive, dirs$candidate, 2025, files = "SPI_data.csv")
  expect_identical(report$column, "SPI.D1.5.POV")
  expect_false(report$allowed)
  expect_error(enforce_release_diff(report, "report.md"), "RELEASE DIFF BLOCKS PROMOTION: 1 change")
})

test_that("pillar, overall and quintile columns may change; other pillars may not", {
  base <- data.frame(
    iso3c = "AAA", date = 2025, SPI.INDEX.PIL1 = 50, SPI.INDEX.PIL2 = 60,
    SPI.INDEX = 55, SPI.INDEX.quintile = 3, SPI.INDEX.PIL2.quintile = 4, SPI.INDEX.PIL1.quintile = 2
  )
  changed <- base
  changed$SPI.INDEX.PIL2 <- 62
  changed$SPI.INDEX <- 55.4
  changed$SPI.INDEX.quintile <- 4
  changed$SPI.INDEX.PIL2.quintile <- 5
  dirs <- write_pair("SPI_quantiles.csv", base, changed)
  report <- build_release_diff(dirs$archive, dirs$candidate, 2025, files = "SPI_quantiles.csv")
  expect_true(all(report$allowed))
  changed$SPI.INDEX.PIL1.quintile <- 3
  dirs <- write_pair("SPI_quantiles.csv", base, changed)
  report <- build_release_diff(dirs$archive, dirs$candidate, 2025, files = "SPI_quantiles.csv")
  expect_identical(report$column[!report$allowed], "SPI.INDEX.PIL1.quintile")
})

test_that("the latest-year plotting jitter may move with the index order", {
  # build_quantiles_2024() assigns the jitter by row position in index order,
  # so an ODIN change that reorders countries moves the jitter between rows.
  base <- data.frame(
    iso3c = c("AAA", "BBB"), date = 2025, SPI.INDEX = c(60, 55),
    NY.GDP.PCAP.PP.KD = c(1000, 2000), jitter_y = c(0.1, -0.2), jitter_x = c(0.05, 0.3)
  )
  changed <- base
  changed$SPI.INDEX <- c(54, 55)
  changed$jitter_y <- rev(base$jitter_y)
  changed$jitter_x <- rev(base$jitter_x)
  dirs <- write_pair("SPI_quantiles_2025.csv", base, changed)
  report <- build_release_diff(dirs$archive, dirs$candidate, 2025, files = "SPI_quantiles_2025.csv")
  expect_identical(sort(unique(report$column)), c("jitter_x", "jitter_y", "SPI.INDEX"))
  expect_true(all(report$allowed))
  changed$NY.GDP.PCAP.PP.KD[[1]] <- 1100
  dirs <- write_pair("SPI_quantiles_2025.csv", base, changed)
  report <- build_release_diff(dirs$archive, dirs$candidate, 2025, files = "SPI_quantiles_2025.csv")
  expect_identical(report$column[!report$allowed], "NY.GDP.PCAP.PP.KD")
})

test_that("long-format rows may change only for ODIN-dependent series", {
  base <- data.frame(
    country = c("A", "A"), source_id = c("SPI.DIM2.2.INDEX", "SPI.DIM1.5.INDEX"),
    value = c(0.4, 0.5), Score = c(10, 12)
  )
  changed <- base
  changed$value[[1]] <- 0.45
  changed$Score[[1]] <- 11
  dirs <- write_pair("SPI_treemap.csv", base, changed)
  report <- build_release_diff(dirs$archive, dirs$candidate, 2025, files = "SPI_treemap.csv")
  expect_true(all(report$allowed))
  changed$value[[2]] <- 0.6
  dirs <- write_pair("SPI_treemap.csv", base, changed)
  report <- build_release_diff(dirs$archive, dirs$candidate, 2025, files = "SPI_treemap.csv")
  expect_identical(report$key[!report$allowed], "country=A;source_id=SPI.DIM1.5.INDEX")
})

test_that("added or removed rows and columns fail", {
  dirs <- write_pair("SPI_data.csv", spi_data, rbind(spi_data, transform(spi_data[1, ], iso3c = "CCC")))
  report <- build_release_diff(dirs$archive, dirs$candidate, 2025, files = "SPI_data.csv")
  expect_true(any(report$column == "<row added>" & !report$allowed))
  dirs <- write_pair("SPI_data.csv", spi_data, spi_data[, -3])
  report <- build_release_diff(dirs$archive, dirs$candidate, 2025, files = "SPI_data.csv")
  expect_true(any(report$column == "<column removed>" & report$key == "SPI.D1.5.POV" & !report$allowed))
})

test_that("the December run compares candidate outputs with the locked archive", {
  root <- withr::local_tempdir()
  output <- file.path(root, "03_output_data")
  candidate <- file.path(output, ".candidate")
  archive <- file.path(output, "releases", "202611-provisional")
  dir.create(candidate, recursive = TRUE)
  dir.create(archive, recursive = TRUE)
  dir.create(file.path(root, "01_raw_data", "_collection"), recursive = TRUE)
  specs <- release_diff_specs(2025)
  fixture_for <- function(file, value) {
    spec <- specs[[file]]
    if (identical(spec$reader, "dta")) {
      out <- spi_data
      out$SPI.D2.2.Machine.readable <- value
      return(out)
    }
    if (identical(spec$reader, "json")) {
      return(list(
        end_date = 2025,
        checked_at = paste0("2025-", value),
        files = expected_estimation_outputs(2025),
        odin_status = "provisional",
        odin_files = list(list(file = "ODIN_2025.csv", sha256 = as.character(value))),
        odin_dependent_columns = "SPI.D2.2.Machine.readable"
      ))
    }
    if (identical(spec$reader, "text")) {
      return(paste("ODIN evidence", value))
    }
    if (is.null(spec$series)) {
      out <- spi_data
      out$SPI.D2.2.Machine.readable <- value
      return(out)
    }
    out <- as.data.frame(stats::setNames(as.list(rep("x", length(spec$keys))), spec$keys))
    out[[spec$series]] <- if (grepl("revision_index", file, fixed = TRUE)) {
      "SPI.INDEX.PIL2"
    } else {
      "SPI.D2.2.Machine.readable"
    }
    out$value <- value
    out
  }
  for (file in release_diff_files(2025)) {
    archive_value <- fixture_for(file, 0.4)
    candidate_value <- fixture_for(file, 1)
    if (identical(specs[[file]]$reader, "dta")) {
      names(archive_value) <- gsub(".", "_", names(archive_value), fixed = TRUE)
      names(candidate_value) <- gsub(".", "_", names(candidate_value), fixed = TRUE)
      haven::write_dta(archive_value, file.path(archive, file))
      haven::write_dta(candidate_value, file.path(candidate, file))
    } else if (identical(specs[[file]]$reader, "json")) {
      jsonlite::write_json(archive_value, file.path(archive, file), auto_unbox = TRUE)
      jsonlite::write_json(candidate_value, file.path(candidate, file), auto_unbox = TRUE)
    } else if (identical(specs[[file]]$reader, "text")) {
      writeLines(archive_value, file.path(archive, file))
      writeLines(candidate_value, file.path(candidate, file))
    } else {
      readr::write_csv(archive_value, file.path(archive, file), na = "")
      readr::write_csv(candidate_value, file.path(candidate, file), na = "")
    }
  }
  params <- list(
    raw_dir = file.path(root, "01_raw_data"), collection_dir = file.path(root, "01_raw_data", "_collection"),
    output_dir = output, estimation_write_dir = candidate, end_date = 2025
  )
  expect_null(write_release_diff(params))

  outputs <- lapply(release_diff_files(2025), function(file) {
    list(file = file, sha256 = digest::digest(file.path(archive, file), algo = "sha256", file = TRUE))
  })
  lock <- list(
    schema_version = "spi-release-lock-v2",
    end_date = 2025,
    approved_by = "fixture",
    approved_at = "2026-10-24T00:00:00Z",
    odin_status = "provisional",
    pip_release = "fixture",
    excluded_sources = c("d2_2_odin", "d4_3_odin"),
    artifacts = list(),
    controls = list(),
    archive = "03_output_data/releases/202611-provisional",
    outputs = outputs
  )
  lock$lock_sha256 <- .release_lock_digest(lock)
  jsonlite::write_json(lock, release_lock_path(params), auto_unbox = TRUE)
  writeLines(lock$lock_sha256, release_lock_integrity_path(params))
  paths <- write_release_diff(params)
  expect_identical(basename(paths), c("release_diff_2025.csv", "release_diff_2025.md"))
  expect_true(all(readr::read_csv(paths[[1]], show_col_types = FALSE)$allowed))
  expect_match(paste(readLines(paths[[2]]), collapse = "\n"), "0 outside the ODIN-dependent outputs")

  writeLines("tampered", file.path(archive, "SPI_index.csv"))
  expect_error(write_release_diff(params), "RELEASE ARCHIVE CHANGED SINCE THE LOCK.*SPI_index.csv")
})

test_that("the ODIN rehearsal perturbs every all-category row", {
  script <- readLines(
    here::here("tests", "replication", "rehearse_odin_swap.R"),
    warn = FALSE
  )
  expect_false(any(grepl("[1:10]", script, fixed = TRUE)))
  expect_true(any(grepl("which(odin[[\"Data categories\"]]", script, fixed = TRUE)))
})

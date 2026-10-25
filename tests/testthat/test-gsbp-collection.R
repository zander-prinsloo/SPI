# =============================================================================
# GSBP (5.2.10) vintage builder
# =============================================================================
# Steps 5-6 of .cg-docs/plans/2026-10-21-nada-gsbp-collection-pipeline.md.
# tests/fixtures/gsbp/D1.12.MSC.2024.csv is the desk review frozen at commit
# 95b3959 (the input of the 2024 file; the live file is edited in place).
#
# Created: 2026-10-23
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "collection_provenance.R"))
source(file.path(here::here("R"), "collection_io.R"))
source(file.path(here::here("R"), "collection_cache.R"))
source(file.path(here::here("R"), "collection_attestation.R"))
source(file.path(here::here("R"), "collect_manual_review.R"))
source(file.path(here::here("R"), "collect_d5_2.R"))
source(file.path(here::here("R"), "collect_gsbp.R"))
source(file.path(here::here("R"), "dim5.R"))

repo_raw <- here::here("01_raw_data")

gsbp_metadata <- function() {
  tibble::tibble(iso3c = c("AAA", "BBB", "CCC", "DDD"), country = c("A land", "B land", "C land", "D land"),
                 region = c("R1", "R1", "R2", "R2"), income_level = "Low income")
}
gsbp_previous <- function() {
  data.frame(iso3c = c("AAA", "BBB", "CCC"), country = c("A land", "B land", "C land"), date = 2024, GSBP = c("Yes", NA, NA))
}
gsbp_desk <- function(values = c(NA, "yes", NA)) {
  data.frame(`#` = 1:3, Code = c("AAA", "BBB", "CCC"), Country = c("A land", "B land", "C land"),
             `Business Process (GSBPM)` = values, check.names = FALSE)
}
gsbp_review <- function(iso3c = c("AAA", "BBB", "CCC"), values = NA_character_, evidence = NA_character_) {
  data.frame(iso3c = iso3c, country = paste(iso3c, "land"), GSBP = values, Evidence = evidence, stringsAsFactors = FALSE)
}

test_that("GSBP is Yes when the previous vintage or the desk review says Yes", {
  result <- build_gsbp_vintage(gsbp_previous(), gsbp_desk(), gsbp_review(), gsbp_metadata(), 2025)
  expect_equal(result$data$GSBP, c("Yes", "Yes", NA))
  expect_equal(names(result$data), c(names(gsbp_metadata()), "date", "GSBP"))
  expect_true(all(result$data$date == 2025))
})

test_that("a review No removes a Yes and a review Yes needs evidence", {
  review <- gsbp_review(values = c("No", NA, "yes"), evidence = c("NSO confirms GSBPM was dropped", NA, "GSBPM in quality framework"))
  result <- build_gsbp_vintage(gsbp_previous(), gsbp_desk(), review, gsbp_metadata(), 2025)
  expect_equal(result$data$GSBP, c(NA, "Yes", "Yes"))
  expect_equal(sort(result$overrides$iso3c), c("AAA", "CCC"))
  expect_error(
    build_gsbp_vintage(gsbp_previous(), gsbp_desk(), gsbp_review(values = c("No", NA, NA)), gsbp_metadata(), 2025),
    "REQUIRES EVIDENCE"
  )
})

test_that("invalid desk values and scope mismatches stop", {
  expect_error(
    build_gsbp_vintage(gsbp_previous(), gsbp_desk(c(NA, "Maybe", NA)), gsbp_review(), gsbp_metadata(), 2025),
    "GSBP DESK REVIEW HAS INVALID VALUES"
  )
  extra <- rbind(gsbp_desk(), data.frame(`#` = 4, Code = "DDD", Country = "D land", `Business Process (GSBPM)` = "Yes", check.names = FALSE))
  expect_error(build_gsbp_vintage(gsbp_previous(), extra, gsbp_review(), gsbp_metadata(), 2025), "GSBP COUNTRY SCOPE MISMATCH")
  with_row <- build_gsbp_vintage(gsbp_previous(), extra, gsbp_review(c("AAA", "BBB", "CCC", "DDD")), gsbp_metadata(), 2025)
  expect_equal(with_row$data$iso3c, c("AAA", "BBB", "CCC", "DDD"))
  expect_error(
    build_gsbp_vintage(gsbp_previous(), gsbp_desk(), gsbp_review(), gsbp_metadata()[1:2, ], 2025),
    "MISSING FROM COUNTRY METADATA"
  )
})

test_that("an unchanged desk review warns and countries without evidence are candidates", {
  result <- build_gsbp_vintage(
    gsbp_previous(), gsbp_desk(), gsbp_review(), gsbp_metadata(), 2025,
    previous_desk_sha256 = "abc", desk_sha256 = "abc"
  )
  expect_match(result$warnings$message, "unchanged since the 2024 vintage")
  candidates <- gsbp_candidates(result$data)
  expect_equal(candidates$iso3c, "CCC")
  expect_equal(names(candidates), c("source_id", "iso3c", "country", "current_value", "reason", "evidence_hint"))
})

test_that("the collector refuses historical writes and needs the review file", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "5.2_DISM", "raw"), recursive = TRUE)
  readr::write_csv(gsbp_previous(), file.path(dir, "5.2_DISM", "D5.2.10.GSBP.2024.csv"), na = "NA")
  readr::write_csv(gsbp_desk(), file.path(dir, "5.2_DISM", "raw", "D1.12.MSC.csv"), na = "")
  params <- list(raw_dir = dir, end_date = 2025, first_collected_vintage = 2025)
  expect_error(collect_gsbp_vintage(params, gsbp_metadata()), "GSBP MANUAL REVIEW FILE NOT FOUND")

  writexl::write_xlsx(gsbp_review(), file.path(dir, "5.2_DISM", "D5.2.10.GSBP.Manual.Review.2025.xlsx"))
  result <- collect_gsbp_vintage(params, gsbp_metadata())
  expect_true(file.exists(result$output))
  expect_true(file.exists(result$manifest))
  expect_equal(readr::read_csv(result$output, show_col_types = FALSE)$GSBP, c("Yes", "Yes", NA))
  expect_equal(jsonlite::read_json(result$manifest)$desk_review$sha256, digest::digest(file.path(dir, "5.2_DISM", "raw", "D1.12.MSC.csv"), algo = "sha256", file = TRUE))

  expect_error(collect_gsbp_vintage(list(raw_dir = dir, end_date = 2024, first_collected_vintage = 2025), gsbp_metadata()), "REFUSING TO WRITE HISTORICAL GSBP VINTAGE")
})

test_that("the 2024 GSBP file is rebuilt from 2023 and the frozen desk review", {
  skip_if_not(file.exists(file.path(repo_raw, "5.2_DISM", "D5.2.10.GSBP.2023.csv")))
  previous <- readr::read_csv(file.path(repo_raw, "5.2_DISM", "D5.2.10.GSBP.2023.csv"), show_col_types = FALSE)
  published <- readr::read_csv(file.path(repo_raw, "5.2_DISM", "D5.2.10.GSBP.2024.csv"), show_col_types = FALSE)
  desk <- read_gsbp_desk_review(here::here("tests", "fixtures", "gsbp", "D1.12.MSC.2024.csv"))
  metadata <- published[, setdiff(names(published), c("date", "GSBP"))]
  rebuilt <- build_gsbp_vintage(previous, desk, gsbp_review(previous$iso3c), metadata, 2024)$data
  expect_equal(rebuilt$iso3c, published$iso3c)
  expect_equal(rebuilt$GSBP, published$GSBP)

  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "5.2_DISM"))
  file.copy(Sys.glob(file.path(repo_raw, "5.2_DISM", "D5.2.10.GSBP*.csv")), file.path(dir, "5.2_DISM"))
  original <- score_gsbp(list(raw_dir = repo_raw, end_date = 2024))
  readr::write_csv(rebuilt, file.path(dir, "5.2_DISM", "D5.2.10.GSBP.2024.csv"), na = "NA")
  again <- score_gsbp(list(raw_dir = dir, end_date = 2024))
  expect_equal(again[again$date == 2024, c("iso3c", "SPI.D5.2.10.GSBP")], original[original$date == 2024, c("iso3c", "SPI.D5.2.10.GSBP")])
})

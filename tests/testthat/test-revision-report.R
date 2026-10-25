# =============================================================================
# Revision report (202611 Working Group evidence)
# =============================================================================
# Created: 2026-10-24
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "output_manifest.R"))
report_path <- file.path(here::here("R"), "revision_report.R")
if (file.exists(report_path)) {
  source(report_path)
}

diff_rows <- function(indicator, policy, iso3c, date, previous, current, status) {
  data.frame(
    indicator = indicator,
    dimension = sub("^SPI[.](D[0-9]+[.][0-9]+).*$", "\\1", indicator),
    policy = policy, iso3c = iso3c, date = date,
    previous = previous, current = current, status = status,
    approval_reason = NA_character_, approved_by = NA_character_,
    stringsAsFactors = FALSE
  )
}

example_diff <- function() {
  rbind(
    diff_rows("SPI.D1.5.POV", "refresh", c("AAA", "BBB", "CCC"), c(2019L, 2020L, 2021L),
              c("0", "1", NA), c("1", "0", "1"), "reported"),
    diff_rows("SPI.D5.5.DIFI", "frozen", "COL", 2024L, "0", "1", "blocking"),
    diff_rows("SPI.D2.2.Openness.subscore", "frozen", "DDD", 2023L, "0.5", NA, "approved"),
    data.frame(indicator = "<duplicate key>", dimension = NA_character_, policy = "integrity", iso3c = "EEE",
               date = 2022L, previous = NA_character_, current = NA_character_, status = "blocking",
               approval_reason = NA_character_, approved_by = NA_character_, stringsAsFactors = FALSE)
  )
}

test_that("indicator revisions are summarised per indicator with direction and status", {
  summary <- revision_indicator_summary(example_diff())
  expect_identical(summary$indicator, c("SPI.D1.5.POV", "SPI.D2.2.Openness.subscore", "SPI.D5.5.DIFI"))
  pov <- summary[summary$indicator == "SPI.D1.5.POV", ]
  expect_identical(pov$cells, 3L)
  expect_identical(pov$countries, 3L)
  expect_identical(pov$increased, 1L)
  expect_identical(pov$decreased, 1L)
  expect_identical(pov$added, 1L)
  expect_identical(pov$removed, 0L)
  expect_identical(c(pov$first_year, pov$last_year), c(2019L, 2021L))
  expect_identical(pov$country_codes, "AAA BBB CCC")
  difi <- summary[summary$indicator == "SPI.D5.5.DIFI", ]
  expect_identical(c(difi$policy, difi$blocking, difi$increased), c("frozen", "1", "1"))
  odin <- summary[summary$indicator == "SPI.D2.2.Openness.subscore", ]
  expect_identical(c(odin$removed, odin$approved), c(1L, 1L))
})

index_frame <- function(iso3c, date, overall, pil2 = overall) {
  data.frame(country = paste(iso3c, "land"), iso3c = iso3c, date = date,
             SPI.INDEX.PIL1 = overall, SPI.INDEX.PIL2 = pil2, SPI.INDEX.PIL3 = overall,
             SPI.INDEX.PIL4 = overall, SPI.INDEX.PIL5 = overall, SPI.INDEX = overall,
             stringsAsFactors = FALSE)
}

test_that("index revisions report score, rank and quintile changes", {
  previous <- index_frame(c("AAA", "BBB", "CCC", "DDD", "EEE"), 2024L, c(90, 80, 70, 60, 50))
  current <- index_frame(c("AAA", "BBB", "CCC", "DDD", "FFF"), 2024L, c(90, 65, 70, 60, 40))
  changes <- revision_index_changes(previous, current, years = 2024L)
  overall <- changes[changes$measure == "SPI.INDEX", ]
  bbb <- overall[overall$iso3c == "BBB", ]
  expect_equal(bbb$change, -15)
  expect_identical(c(bbb$previous_rank, bbb$current_rank), c(2L, 3L))
  expect_identical(bbb$current_quintile, "3rd Quintile")
  expect_identical(overall$status[overall$iso3c == "EEE"], "dropped")
  expect_identical(overall$status[overall$iso3c == "FFF"], "added")
  expect_identical(overall$status[overall$iso3c == "AAA"], "unchanged")
  expect_setequal(unique(changes$measure), c("SPI.INDEX", paste0("SPI.INDEX.PIL", 1:5)))
})

test_that("years without index values in either vintage are skipped", {
  previous <- rbind(index_frame(c("AAA", "BBB"), 2015L, NA_real_), index_frame(c("AAA", "BBB"), 2024L, c(80, 70)))
  current <- rbind(index_frame(c("AAA", "BBB"), 2015L, NA_real_), index_frame(c("AAA", "BBB"), 2024L, c(80, 65)))
  changes <- revision_index_changes(previous, current, years = c(2015L, 2024L))
  expect_identical(unique(changes$year), 2024L)
})

test_that("the reference year reports coverage and values identical to the previous year", {
  data <- data.frame(
    iso3c = rep(c("AAA", "BBB", "CCC"), each = 2), date = rep(c(2024L, 2025L), 3),
    SPI.D5.2.3.CNIN = c(1, 1, 0.5, 0.5, 0, 0),
    SPI.D1.5.POV = c(1, 0, NA, 1, 0.5, NA),
    SPI.D2.2.Openness.subscore = c(0.4, 0.4, 0.6, 0.6, NA, NA),
    stringsAsFactors = FALSE
  )
  status <- revision_new_year_summary(data, 2025L, provisional_columns = "SPI.D2.2.Openness.subscore")
  cnin <- status[status$indicator == "SPI.D5.2.3.CNIN", ]
  expect_identical(c(cnin$countries, cnin$same_as_previous_year, cnin$changed), c(3L, 3L, 0L))
  expect_identical(cnin$status, "identical to 2024 for every country")
  pov <- status[status$indicator == "SPI.D1.5.POV", ]
  expect_identical(c(pov$countries, pov$changed, pov$new_values, pov$dropped_values), c(2L, 1L, 1L, 1L))
  expect_identical(pov$status, "updated")
  expect_identical(status$status[status$indicator == "SPI.D2.2.Openness.subscore"], "provisional (ODIN)")
})

write_report_inputs <- function(end_date = 2025L, previous_rows = TRUE) {
  dir <- withr::local_tempdir(.local_envir = parent.frame())
  candidate <- file.path(dir, "candidate")
  previous <- file.path(dir, "previous")
  dir.create(candidate)
  dir.create(previous)
  readr::write_csv(data.frame(
    iso3c = rep(c("AAA", "BBB"), each = 2), date = rep(c(2024L, 2025L), 2),
    SPI.D1.5.POV = c(1, 1, 0, 1), SPI.D5.5.DIFI = c(0, 0, 1, 1)
  ), file.path(candidate, "SPI_data.csv"))
  readr::write_csv(index_frame(c("AAA", "BBB"), 2024L, c(80, 70)), file.path(candidate, "SPI_index.csv"))
  readr::write_csv(example_diff(), file.path(candidate, sprintf("vintage_diff_%d.csv", end_date)), na = "")
  previous_index <- index_frame(c("AAA", "BBB"), 2024L, c(80, 75))
  if (!previous_rows) previous_index <- previous_index[0, ]
  readr::write_csv(previous_index, file.path(previous, "SPI_index_2024.csv"))
  list(candidate = candidate, previous_index = file.path(previous, "SPI_index_2024.csv"))
}

test_that("the revision report writes its evidence tables and summary", {
  inputs <- write_report_inputs()
  paths <- write_revision_report(inputs$candidate, inputs$previous_index, 2025L,
                                 odin_status = "provisional", provisional_columns = character())
  expect_identical(unname(basename(paths)), unname(revision_report_files(2025L)))
  expect_true(all(file.exists(paths)))
  summary <- readLines(paths[["summary"]])
  expect_true(any(grepl("^# SPI revision evidence: 2025 outputs", summary)))
  expect_true(any(grepl("SPI.D5.5.DIFI.*frozen.*blocking", summary)))
  expect_true(any(grepl("BBB land.*75.*70.*-5", summary)))
  index <- readr::read_csv(paths[["index"]], show_col_types = FALSE)
  expect_equal(index$change[index$iso3c == "BBB" & index$measure == "SPI.INDEX"], -5)
})

test_that("a previous index without rows for the previous year is reported, not hidden", {
  inputs <- write_report_inputs(previous_rows = FALSE)
  paths <- write_revision_report(inputs$candidate, inputs$previous_index, 2025L,
                                 odin_status = "provisional", provisional_columns = character())
  expect_true(any(grepl("Index revisions are not available", readLines(paths[["summary"]]))))
})

test_that("a missing previous index stops the report", {
  params <- list(raw_dir = withr::local_tempdir(), end_date = 2025L)
  expect_error(revision_previous_index_path(params), "PREVIOUS VINTAGE INDEX NOT FOUND.*SPI_index_2024.csv")
})

test_that("the revision report is part of the complete output set", {
  expect_true(all(revision_report_files(2025L) %in% expected_estimation_outputs(2025L)))
})

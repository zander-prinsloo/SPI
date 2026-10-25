# =============================================================================
# Vintage-diff policy report (202611 readiness plan, Step 21)
# =============================================================================
# Created: 2026-10-24
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "vintage_diff.R"))

vintage_frame <- function(rows) {
  base <- expand.grid(iso3c = c("AAA", "BBB"), date = 2019:2025, stringsAsFactors = FALSE)
  base$SPI.D1.5.POV <- 0.5
  base$SPI.D2.4.NADA <- 1
  base$SPI.D3.1.POV <- 0.25
  base$SPI.D4.1.1.POPU <- 1
  base$SPI.D4.3.GEO.first.admin.level <- 0.4
  base$SPI.D5.1.DILG <- 1
  base$RAW.D5.1.DILG <- "text"
  for (change in rows) {
    hit <- base$iso3c == change$iso3c & base$date == change$date
    base[[change$column]][hit] <- change$value
  }
  base
}

write_vintages <- function(candidate_changes = list(), approvals = NULL, end_date = 2025) {
  root <- withr::local_tempdir(.local_envir = parent.frame())
  candidate_dir <- file.path(root, "candidate")
  dir.create(candidate_dir)
  dir.create(file.path(root, "previous_vintages"))
  readr::write_csv(vintage_frame(list()), file.path(root, "previous_vintages", sprintf("SPI_data_%d.csv", end_date - 1L)))
  readr::write_csv(vintage_frame(candidate_changes), file.path(candidate_dir, "SPI_data.csv"))
  approvals_path <- file.path(root, sprintf("vintage_diff_approvals_%d.csv", end_date))
  if (!is.null(approvals)) readr::write_csv(approvals, approvals_path, na = "")
  list(
    candidate_dir = candidate_dir,
    previous = file.path(root, "previous_vintages", sprintf("SPI_data_%d.csv", end_date - 1L)),
    approvals = approvals_path,
    end_date = end_date
  )
}

run_diff <- function(setup) {
  build_vintage_diff(
    candidate = file.path(setup$candidate_dir, "SPI_data.csv"),
    previous = setup$previous,
    approvals_path = setup$approvals,
    end_date = setup$end_date
  )
}

change <- function(column, iso3c, date, value) {
  list(column = column, iso3c = iso3c, date = date, value = value)
}

test_that("indicator columns are classified by the revision policy", {
  expect_identical(
    vintage_diff_policy(c("SPI.D1.5.POV", "SPI.D4.1.1.POPU", "SPI.D4.2.3.CRVS")),
    rep("refresh", 3)
  )
  expect_identical(
    vintage_diff_policy(c("SPI.D2.4.NADA", "SPI.D3.1.POV", "SPI.D3.NA", "SPI.D4.3.GEO.first.admin.level", "SPI.D5.1.DILG")),
    rep("frozen", 5)
  )
  expect_error(vintage_diff_policy("SPI.D6.1.NEW"), "UNCLASSIFIED INDICATOR.*SPI.D6.1.NEW")
})

test_that("an unapproved frozen change blocks promotion", {
  setup <- write_vintages(list(change("SPI.D5.1.DILG", "AAA", 2020, 0)))
  report <- run_diff(setup)
  expect_identical(nrow(report), 1L)
  expect_identical(report$status, "blocking")
  expect_identical(report$policy, "frozen")
  expect_equal(c(report$previous, report$current), c("1", "0"))
  expect_error(enforce_vintage_diff(report, "report.md"), "VINTAGE DIFF BLOCKS PROMOTION: 1 frozen")
})

test_that("an approved frozen change passes", {
  approvals <- data.frame(
    indicator = "SPI.D5.1.DILG", iso3c = "AAA", date = "2020",
    reason = "Legislation database revised", approved_by = "Technical lead"
  )
  setup <- write_vintages(list(change("SPI.D5.1.DILG", "AAA", 2020, 0)), approvals)
  report <- run_diff(setup)
  expect_identical(report$status, "approved")
  expect_identical(report$approval_reason, "Legislation database revised")
  expect_silent(enforce_vintage_diff(report, "report.md"))
})

test_that("wildcard approvals cover an indicator across countries and years", {
  approvals <- data.frame(
    indicator = "SPI.D3.1.POV", iso3c = "*", date = "*",
    reason = "UN SDG revision accepted", approved_by = "Technical lead"
  )
  setup <- write_vintages(
    list(change("SPI.D3.1.POV", "AAA", 2019, 0.5), change("SPI.D3.1.POV", "BBB", 2023, 0)),
    approvals
  )
  report <- run_diff(setup)
  expect_identical(report$status, c("approved", "approved"))
})

test_that("refresh-dimension changes are reported only", {
  setup <- write_vintages(list(
    change("SPI.D1.5.POV", "AAA", 2021, 1),
    change("SPI.D4.1.1.POPU", "BBB", 2019, 0.5)
  ))
  report <- run_diff(setup)
  expect_identical(sort(report$status), c("reported", "reported"))
  expect_silent(enforce_vintage_diff(report, "report.md"))
})

test_that("reference-year values, RAW columns and unchanged cells are not compared", {
  setup <- write_vintages(list(
    change("SPI.D5.1.DILG", "AAA", 2025, 0),
    change("RAW.D5.1.DILG", "AAA", 2020, "other text")
  ))
  expect_identical(nrow(run_diff(setup)), 0L)
})

test_that("a value appearing or disappearing in history counts as a change", {
  setup <- write_vintages(list(change("SPI.D2.4.NADA", "BBB", 2022, NA)))
  report <- run_diff(setup)
  expect_identical(report$status, "blocking")
  expect_true(is.na(report$current))
})

test_that("duplicate country-year keys block promotion and cannot be approved", {
  setup <- write_vintages()
  candidate <- readr::read_csv(file.path(setup$candidate_dir, "SPI_data.csv"), show_col_types = FALSE)
  readr::write_csv(rbind(candidate, candidate[candidate$date == 2025, ]), file.path(setup$candidate_dir, "SPI_data.csv"))
  readr::write_csv(
    data.frame(indicator = "*", iso3c = "*", date = "*", reason = "all", approved_by = "x"),
    setup$approvals
  )
  report <- run_diff(setup)
  expect_true(all(report$status[report$indicator == "<duplicate key>"] == "blocking"))
  expect_identical(sum(report$indicator == "<duplicate key>"), 2L)
  expect_error(enforce_vintage_diff(report, "report.md"), "duplicate")
})

test_that("approvals need a reason and an approver and must name known indicators", {
  bad <- data.frame(indicator = "SPI.D5.1.DILG", iso3c = "AAA", date = "2020", reason = "", approved_by = "x")
  setup <- write_vintages(list(change("SPI.D5.1.DILG", "AAA", 2020, 0)), bad)
  expect_error(run_diff(setup), "VINTAGE DIFF APPROVALS.*reason")
  typo <- data.frame(indicator = "SPI.D5.1.DLIG", iso3c = "AAA", date = "2020", reason = "r", approved_by = "x")
  setup <- write_vintages(list(change("SPI.D5.1.DILG", "AAA", 2020, 0)), typo)
  expect_error(run_diff(setup), "UNKNOWN INDICATOR.*SPI.D5.1.DLIG")
})

test_that("the approvals template is created once and never overwritten", {
  path <- file.path(withr::local_tempdir(), "vintage_diff_approvals_2025.csv")
  ensure_vintage_diff_approvals(path)
  expect_identical(readLines(path), "indicator,iso3c,date,reason,approved_by")
  writeLines(c("indicator,iso3c,date,reason,approved_by", "SPI.D5.1.DILG,AAA,2020,r,x"), path)
  ensure_vintage_diff_approvals(path)
  expect_length(readLines(path), 2L)
})

test_that("the report is written as CSV and Markdown next to the outputs", {
  setup <- write_vintages(list(
    change("SPI.D5.1.DILG", "AAA", 2020, 0),
    change("SPI.D1.5.POV", "AAA", 2021, 1)
  ))
  paths <- write_vintage_diff(
    candidate_dir = setup$candidate_dir,
    previous = setup$previous,
    approvals_path = setup$approvals,
    end_date = setup$end_date,
    enforce = FALSE
  )
  expect_identical(basename(paths), c("vintage_diff_2025.csv", "vintage_diff_2025.md"))
  csv <- readr::read_csv(paths[[1]], show_col_types = FALSE)
  expect_setequal(csv$status, c("blocking", "reported"))
  md <- paste(readLines(paths[[2]]), collapse = "\n")
  expect_match(md, "1 blocking")
  expect_match(md, "| SPI.D5.1.DILG | frozen | 1 | 1 | 2020 | blocking |", fixed = TRUE)
  expect_error(
    write_vintage_diff(setup$candidate_dir, setup$previous, setup$approvals, setup$end_date),
    "VINTAGE DIFF BLOCKS PROMOTION"
  )
  expect_true(file.exists(paths[[2]]))
})

# =============================================================================
# Replication command result policy
# =============================================================================

library(testthat)

local({
  old_wd <- setwd(here::here())
  on.exit(setwd(old_wd), add = TRUE)
  sys.source(file.path("tests", "replication", "replicate_vintage.R"), envir = .GlobalEnv)
})

replication_tests <- function(failed = 0L, skipped = 0L, error = 0L) {
  data.frame(
    nb = 3L,
    failed = failed,
    skipped = skipped,
    error = error
  )
}

test_that("replication failures and errors return non-zero", {
  expect_identical(replication_result_status(replication_tests(failed = 1L))$status, 1L)
  expect_identical(replication_result_status(replication_tests(error = 1L))$status, 1L)
})

test_that("skips require explicit exception-mode acceptance", {
  tests <- replication_tests(skipped = 1L)
  expect_identical(replication_result_status(tests)$status, 1L)
  result <- replication_result_status(tests, allow_skips = TRUE)
  expect_identical(result$status, 0L)
  expect_true(result$skips_accepted)
})

test_that("output comparison differences fail the replication command", {
  comparison <- data.frame(
    file = "SPI_data.csv",
    column = "SPI.D1.5.POV",
    differing_cells = 2L
  )
  expect_identical(
    replication_result_status(replication_tests(), comparison)$status,
    1L
  )
})

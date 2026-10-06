# =============================================================================
# HTTP retry tests
# =============================================================================
# Created: 2026-10-06
# =============================================================================

library(testthat)
source(file.path(here::here("R"), "collection_http.R"))

test_that("HTTP retry stops after bounded request failures", {
  calls <- 0L
  expect_error(
    with_http_retry(
      request_fn = function() {
        calls <<- calls + 1L
        stop("transient failure")
      },
      attempts = 3,
      delay_fn = function(seconds) invisible(NULL)
    ),
    "transient failure"
  )
  expect_equal(calls, 3L)
})

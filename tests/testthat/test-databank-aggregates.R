# =============================================================================
# Databank aggregates
# =============================================================================
# The group aggregates of the databank are rounded means. A mean that falls
# on a rounding boundary (for example 0.455) is computed just below or just
# above it depending on the order in which the members are summed, and
# SPI_index.csv is sorted by the overall score. Any change that reorders
# countries (the December ODIN update, a correction) must not move the
# aggregates of unrelated series, or the release diff blocks promotion.
#
# Created: 2026-10-24
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "databank.R"))

test_that("databank aggregates do not depend on the row order of the index", {
  values <- c(AAA = 0.3, BBB = 0.1, CCC = 0.75, DDD = 0.67)
  class_df <- tibble::tibble(
    iso3c = names(values),
    country = names(values),
    WB_Group_Code = "GRP",
    WB_Group_Name = "Group"
  )
  long <- function(codes) {
    tibble::tibble(
      country = codes, iso3c = codes, date = 2025, source_name = "Series",
      source_id = "SPI.TEST", value = unname(values[codes]), footnote = NA_character_
    )
  }
  # In floating point the mean of these values is 0.45499... summed in this
  # order and 0.45500... summed in the second.
  ranked_one_way <- aggregate_databank(long(c("AAA", "BBB", "CCC", "DDD")), class_df)
  ranked_other_way <- aggregate_databank(long(c("DDD", "CCC", "AAA", "BBB")), class_df)
  expect_identical(ranked_one_way$value, ranked_other_way$value)
  expect_identical(ranked_one_way$N_obs, 4L)
  expect_identical(ranked_one_way$N, 4L)
})

test_that("databank aggregates keep N, N_obs and the rounded mean of the members", {
  class_df <- tibble::tibble(
    iso3c = c("AAA", "BBB", "CCC", "AAA"),
    country = c("A", "B", "C", "A"),
    WB_Group_Code = c("G1", "G1", "G1", "G2"),
    WB_Group_Name = c("One", "One", "One", "Two")
  )
  data <- tibble::tibble(
    country = c("A", "B", "C"), iso3c = c("AAA", "BBB", "CCC"), date = 2025,
    source_name = "Series", source_id = "SPI.TEST", value = c(1, NA, 0.5), footnote = NA_character_
  )
  out <- aggregate_databank(data, class_df)
  expect_identical(out$WB_Group_Code, c("G1", "G2"))
  expect_identical(out$N, c(3L, 1L))
  expect_identical(out$N_obs, c(2L, 1L))
  expect_equal(out$value, c(0.75, 1))
})

test_that("duplicate exact CLASS memberships count each economy once", {
  class_df <- tibble::tibble(
    iso3c = c("AAA", "AAA", "BBB"),
    country = c("A", "A", "B"),
    WB_Group_Code = c("G1", "G1", "G1"),
    WB_Group_Name = c("One", "One", "One")
  )
  data <- tibble::tibble(
    country = c("A", "B"),
    iso3c = c("AAA", "BBB"),
    date = 2025,
    source_name = "Series",
    source_id = "SPI.TEST",
    value = c(1, 0),
    footnote = NA_character_
  )
  out <- aggregate_databank(data, class_df)
  expect_identical(out$N, 2L)
  expect_identical(out$N_obs, 2L)
  expect_equal(out$value, 0.5)
})

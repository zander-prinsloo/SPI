# =============================================================================
# Shared manual-review contract tests
# Created: 2026-10-21
# =============================================================================

library(testthat)

manual_review_path <- file.path(here::here("R"), "collect_manual_review.R")
if (file.exists(manual_review_path)) {
  source(manual_review_path)
}

review_spec <- function() {
  manual_review_spec(
    indicator = "NADA",
    value_columns = c("NADA", "NADA_text"),
    validators = list(
      NADA = function(values) values %in% c("0", "1"),
      NADA_text = function(values) grepl("^https?://", values)
    )
  )
}

write_review <- function(data) {
  path <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(data, path)
  path
}

test_that("manual review spec records the review contract", {
  spec <- review_spec()

  expect_equal(spec$indicator, "NADA")
  expect_equal(spec$value_columns, c("NADA", "NADA_text"))
  expect_equal(spec$evidence_column, "Evidence")
  expect_named(spec$validators, c("NADA", "NADA_text"))
})

test_that("valid reviews are read and overrides are applied", {
  spec <- review_spec()
  review <- data.frame(
    iso3c = "TJK",
    country = "Tajikistan",
    NADA = 1,
    NADA_text = "https://example.test/nada",
    Evidence = "Reviewed source",
    stringsAsFactors = FALSE
  )
  path <- write_review(review)
  on.exit(unlink(path), add = TRUE)

  parsed <- read_manual_review(path, spec, valid_iso3c = c("TJK", "FJI"))
  expect_equal(parsed$iso3c, "TJK")

  base <- data.frame(
    iso3c = c("TJK", "FJI"),
    country = c("Tajikistan", "Fiji"),
    NADA = c(0, 1),
    NADA_text = c("https://old.test/tjk", "https://old.test/fji"),
    stringsAsFactors = FALSE
  )
  applied <- apply_manual_review(base, parsed, spec)

  expect_equal(applied$data$NADA, c(1, 1))
  expect_equal(applied$data$NADA_text,
               c("https://example.test/nada", "https://old.test/fji"))
  expect_equal(applied$overrides$iso3c, c("TJK", "TJK"))
  expect_equal(applied$overrides$column,
               c("NADA", "NADA_text"))
})

test_that("blank review values do not require evidence or change the base", {
  spec <- review_spec()
  review <- data.frame(
    iso3c = "FJI",
    country = "Fiji",
    NADA = NA,
    NADA_text = NA,
    Evidence = NA,
    stringsAsFactors = FALSE
  )
  path <- write_review(review)
  on.exit(unlink(path), add = TRUE)

  parsed <- read_manual_review(path, spec, valid_iso3c = "FJI")
  applied <- apply_manual_review(
    data.frame(
      iso3c = "FJI",
      country = "Fiji",
      NADA = 1,
      NADA_text = "https://old.test/fji",
      stringsAsFactors = FALSE
    ),
    parsed,
    spec
  )

  expect_equal(applied$data$NADA, 1)
  expect_equal(nrow(applied$overrides), 0)
})

test_that("header-only reviews are valid", {
  spec <- review_spec()
  review <- data.frame(
    iso3c = character(),
    country = character(),
    NADA = character(),
    NADA_text = character(),
    Evidence = character(),
    stringsAsFactors = FALSE
  )
  path <- write_review(review)
  on.exit(unlink(path), add = TRUE)

  parsed <- read_manual_review(path, spec)
  expect_equal(nrow(parsed), 0)
})

test_that("invalid manual reviews fail loudly", {
  spec <- review_spec()

  duplicate_headers <- data.frame(
    iso3c = "TJK",
    country = "Tajikistan",
    NADA = 1,
    NADA_text = "https://example.test/nada",
    Evidence = "Reviewed source",
    stringsAsFactors = FALSE
  )
  names(duplicate_headers)[[4]] <- "NADA"
  expect_error(
    validate_manual_review(duplicate_headers, spec),
    "NADA MANUAL REVIEW HAS DUPLICATE COLUMN NAMES"
  )

  missing_path <- tempfile(fileext = ".xlsx")
  expect_error(
    read_manual_review(missing_path, spec),
    "NADA MANUAL REVIEW FILE NOT FOUND"
  )

  invalid <- data.frame(
    iso3c = "TJK",
    country = "Tajikistan",
    NADA = 2,
    NADA_text = "https://example.test/nada",
    Evidence = "Reviewed source",
    stringsAsFactors = FALSE
  )
  invalid_path <- write_review(invalid)
  on.exit(unlink(invalid_path), add = TRUE)
  expect_error(
    read_manual_review(invalid_path, spec),
    "NADA MANUAL REVIEW HAS INVALID VALUE"
  )

  duplicate <- rbind(invalid[1, ], invalid[1, ])
  duplicate$NADA <- 1
  duplicate_path <- write_review(duplicate)
  on.exit(unlink(duplicate_path), add = TRUE)
  expect_error(
    read_manual_review(duplicate_path, spec),
    "NADA MANUAL REVIEW HAS DUPLICATE COUNTRY KEYS"
  )

  unknown <- invalid[1, ]
  unknown$NADA <- 1
  unknown_path <- write_review(unknown)
  on.exit(unlink(unknown_path), add = TRUE)
  expect_error(
    read_manual_review(unknown_path, spec, valid_iso3c = "FJI"),
    "NADA MANUAL REVIEW HAS UNKNOWN COUNTRY KEYS"
  )

  no_evidence <- invalid[1, ]
  no_evidence$NADA <- 1
  no_evidence$Evidence <- ""
  no_evidence_path <- write_review(no_evidence)
  on.exit(unlink(no_evidence_path), add = TRUE)
  expect_error(
    read_manual_review(no_evidence_path, spec),
    "NADA MANUAL REVIEW OVERRIDE REQUIRES EVIDENCE"
  )

  unmatched <- data.frame(
    iso3c = "ZZZ",
    country = "Unknown",
    NADA = "1",
    NADA_text = "https://example.test/nada",
    Evidence = "Reviewed source",
    stringsAsFactors = FALSE
  )
  expect_error(
    apply_manual_review(
      data.frame(
        iso3c = "TJK",
        NADA = 0,
        NADA_text = NA_character_,
        stringsAsFactors = FALSE
      ),
      unmatched,
      spec
    ),
    "NADA MANUAL REVIEW HAS UNMATCHED COUNTRY KEYS"
  )
})

test_that("manual review metadata records provenance", {
  spec <- review_spec()
  review <- data.frame(
    iso3c = "TJK",
    country = "Tajikistan",
    NADA = 1,
    NADA_text = "https://example.test/nada",
    Evidence = "Reviewed source",
    stringsAsFactors = FALSE
  )
  path <- write_review(review)
  on.exit(unlink(path), add = TRUE)
  parsed <- read_manual_review(path, spec)
  applied <- apply_manual_review(
    data.frame(
      iso3c = "TJK",
      country = "Tajikistan",
      NADA = 0,
      NADA_text = "https://old.test/tjk",
      stringsAsFactors = FALSE
    ),
    parsed,
    spec
  )

  metadata <- manual_review_metadata(path, parsed, applied$overrides)
  expect_equal(metadata$rows, 1)
  expect_equal(metadata$override_count, 2)
  expect_length(metadata$sha256, 1)
})

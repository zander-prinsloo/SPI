# =============================================================================
# NADA collection contract tests
# Created: 2026-10-21
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "collect_manual_review.R"))
source(file.path(here::here("R"), "collection_http.R"))
nada_collection_path <- file.path(here::here("R"), "collect_nada.R")
if (file.exists(nada_collection_path)) {
  source(nada_collection_path)
}

make_nada_review <- function(rows = data.frame()) {
  if (nrow(rows) == 0L) {
    return(data.frame(
      iso3c = character(),
      country = character(),
      NADA = character(),
      NADA_text = character(),
      Evidence = character(),
      stringsAsFactors = FALSE
    ))
  }
  rows
}

write_nada_review <- function(root, rows = data.frame()) {
  path <- file.path(root, "2.4_DSDS", "D2.4.NADA.Manual.Review.2025.xlsx")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writexl::write_xlsx(make_nada_review(rows), path)
  path
}

fake_response <- function(status) {
  structure(list(status_code = as.integer(status)), class = "response")
}

test_that("NADA artifact paths are end-date driven", {
  paths <- nada_artifact_paths("/tmp/raw", 2025)

  expect_equal(
    unname(unlist(paths[c("previous", "review", "evidence", "output")])),
    c(
      "/tmp/raw/2.4_DSDS/D2.4.NADA.2024.csv",
      "/tmp/raw/2.4_DSDS/D2.4.NADA.Manual.Review.2025.xlsx",
      "/tmp/raw/2.4_DSDS/collection/D2.4.NADA.url_evidence.2025.csv",
      "/tmp/raw/2.4_DSDS/D2.4.NADA.2025.csv"
    )
  )
  expect_match(paths$manifest, "D2.4.NADA_manifest_2025\\.json$")
})

test_that("NADA URL checks record status, errors, and retries", {
  attempts <- integer()
  request_fn <- function(url) {
    attempts <<- c(attempts, length(attempts) + 1L)
    if (grepl("retry", url) && length(attempts) == 1L) {
      stop("temporary failure")
    }
    if (grepl("missing", url)) {
      return(fake_response(404))
    }
    fake_response(200)
  }
  sites <- data.frame(
    iso3c = c("AAA", "BBB", "CCC"),
    NADA_text = c(
      "https://retry.example/nada",
      "https://missing.example/nada",
      NA_character_
    ),
    stringsAsFactors = FALSE
  )

  evidence <- check_nada_urls(
    sites,
    request_fn = request_fn,
    delay_fn = function(...) NULL,
    attempts = 3,
    delay_seconds = 0
  )

  expect_equal(evidence$NADA_working, c(TRUE, FALSE, NA))
  expect_equal(evidence$status_code, c(200L, 404L, NA))
  expect_equal(evidence$attempts, c(2L, 1L, 0L))
  expect_equal(evidence$error_message, c(NA, NA, "NADA URL MISSING"))
})

test_that("NADA URL evidence is reused while fresh", {
  root <- tempfile("nada-cache-")
  dir.create(file.path(root, "2.4_DSDS"), recursive = TRUE)
  previous <- data.frame(
    iso3c = c("AAA", "BBB"),
    country = c("A", "B"),
    NADA = c(1, 0),
    NADA_text = c("https://a.example/nada", "https://b.example/nada"),
    date = 2024,
    stringsAsFactors = FALSE
  )
  readr::write_csv(previous, file.path(root, "2.4_DSDS", "D2.4.NADA.2024.csv"))
  review_path <- write_nada_review(root)
  params <- list(
    raw_dir = root,
    end_date = 2025,
    refresh_nada_urls = FALSE,
    nada_url_max_age_days = 30,
    nada_url_delay_seconds = 0
  )
  calls <- 0L
  request_fn <- function(url) {
    calls <<- calls + 1L
    fake_response(200)
  }

  evidence_path <- collect_nada_url_evidence(
    params,
    request_fn = request_fn,
    delay_fn = function(...) NULL
  )
  expect_true(file.exists(evidence_path))
  expect_equal(calls, 2L)

  collect_nada_url_evidence(
    params,
    request_fn = function(...) stop("cache was not reused"),
    delay_fn = function(...) NULL
  )
  expect_equal(readr::read_csv(evidence_path, show_col_types = FALSE)$NADA_working,
               c(TRUE, TRUE))
  expect_true(file.exists(review_path))
})

test_that("malformed fresh NADA evidence is rejected", {
  root <- tempfile("nada-bad-cache-")
  dir.create(file.path(root, "2.4_DSDS", "collection"), recursive = TRUE)
  previous <- data.frame(
    iso3c = c("AAA", "BBB"),
    country = c("A", "B"),
    NADA = c(1, 0),
    NADA_text = c("https://a.example/nada", "https://b.example/nada"),
    date = 2024,
    stringsAsFactors = FALSE
  )
  readr::write_csv(previous, file.path(root, "2.4_DSDS", "D2.4.NADA.2024.csv"))
  write_nada_review(root)
  evidence_path <- nada_artifact_paths(root, 2025)$evidence
  readr::write_csv(
    data.frame(
      iso3c = previous$iso3c,
      url = previous$NADA_text,
      stringsAsFactors = FALSE
    ),
    evidence_path
  )
  params <- list(
    raw_dir = root,
    end_date = 2025,
    refresh_nada_urls = FALSE,
    nada_url_max_age_days = 30,
    nada_url_delay_seconds = 0
  )

  expect_error(
    collect_nada_url_evidence(
      params,
      request_fn = function(...) stop("malformed cache should not be accepted"),
      delay_fn = function(...) NULL
    ),
    "NADA EVIDENCE SCHEMA MISMATCH"
  )
})

test_that("NADA evidence stops on a network-wide failure", {
  root <- tempfile("nada-errors-")
  dir.create(file.path(root, "2.4_DSDS"), recursive = TRUE)
  previous <- data.frame(
    iso3c = c("AAA", "BBB", "CCC"),
    country = c("A", "B", "C"),
    NADA = 1,
    NADA_text = paste0("https://", c("a", "b", "c"), ".example/nada"),
    date = 2024,
    stringsAsFactors = FALSE
  )
  readr::write_csv(previous, file.path(root, "2.4_DSDS", "D2.4.NADA.2024.csv"))
  write_nada_review(root)
  params <- list(
    raw_dir = root,
    end_date = 2025,
    refresh_nada_urls = TRUE,
    nada_url_max_age_days = 30,
    nada_url_delay_seconds = 0
  )

  expect_error(
    collect_nada_url_evidence(
      params,
      request_fn = function(...) stop("network unavailable"),
      delay_fn = function(...) NULL
    ),
    "NADA URL CHECK FAILED FOR MOST SITES"
  )
})

test_that("NADA vintage applies review and auto-zero rules", {
  previous <- data.frame(
    iso3c = c("AAA", "BBB", "CCC"),
    country = c("A", "B", "C"),
    NADA = c(1, 1, 0),
    NADA_text = paste0("https://", c("a", "b", "c"), ".example/nada"),
    date = 2024,
    stringsAsFactors = FALSE
  )
  evidence <- data.frame(
    iso3c = c("AAA", "BBB", "CCC"),
    url = previous$NADA_text,
    status_code = c(404L, 404L, 200L),
    NADA_working = c(FALSE, FALSE, TRUE),
    error_message = c(NA_character_, NA_character_, NA_character_),
    checked_at = rep("2026-10-21 UTC", 3),
    attempts = c(1L, 1L, 1L),
    stringsAsFactors = FALSE
  )
  review <- make_nada_review(data.frame(
    iso3c = "BBB",
    country = "B",
    NADA = "1",
    NADA_text = NA_character_,
    Evidence = "Confirmed by technical lead",
    stringsAsFactors = FALSE
  ))

  expect_error(
    build_nada_vintage(
      previous,
      evidence,
      review,
      end_date = 2025,
      first_collected_vintage = 2025
    ),
    "NADA REVIEW REQUIRED FOR UNRESOLVED POSITIVE VALUES"
  )

  resolved_review <- make_nada_review(rbind(
    data.frame(
      iso3c = "AAA",
      country = "A",
      NADA = "0",
      NADA_text = NA_character_,
      Evidence = "Technical failure reviewed",
      stringsAsFactors = FALSE
    ),
    review
  ))
  result <- build_nada_vintage(
    previous,
    evidence,
    resolved_review,
    end_date = 2025,
    first_collected_vintage = 2025
  )

  expect_equal(result$data$NADA, c(0, 1, 0))
  expect_equal(nrow(result$auto_zero), 0)
  expect_equal(result$overrides$iso3c, c("AAA", "BBB"))

  historical <- build_nada_vintage(
    previous,
    evidence,
    make_nada_review(),
    end_date = 2024,
    first_collected_vintage = 2025
  )
  expect_equal(historical$data$NADA, c(1, 1, 0))
  expect_equal(nrow(historical$auto_zero), 0)
})

test_that("reviewed new NADA countries require complete values", {
  previous <- data.frame(
    iso3c = "AAA",
    country = "A",
    NADA = 0,
    NADA_text = "https://a.example/nada",
    date = 2024,
    stringsAsFactors = FALSE
  )
  evidence <- data.frame(
    iso3c = "AAA",
    url = previous$NADA_text,
    status_code = 200L,
    NADA_working = TRUE,
    error_message = NA_character_,
    checked_at = "2026-10-21 UTC",
    attempts = 1L,
    stringsAsFactors = FALSE
  )
  incomplete <- make_nada_review(data.frame(
    iso3c = "BBB",
    country = "B",
    NADA = 1,
    NADA_text = NA_character_,
    Evidence = "Reviewed",
    stringsAsFactors = FALSE
  ))
  expect_error(
    build_nada_vintage(previous, evidence, incomplete, 2025, 2025),
    "NEW COUNTRY REVIEW MUST PROVIDE NADA AND NADA_text"
  )

  complete <- incomplete
  complete$NADA_text <- "https://b.example/nada"
  evidence <- rbind(
    evidence,
    data.frame(
      iso3c = "BBB",
      url = complete$NADA_text,
      status_code = 200L,
      NADA_working = TRUE,
      error_message = NA_character_,
      checked_at = "2026-10-21 UTC",
      attempts = 1L,
      stringsAsFactors = FALSE
    )
  )
  result <- build_nada_vintage(previous, evidence, complete, 2025, 2025)
  expect_true("BBB" %in% result$data$iso3c)
})

test_that("historical NADA writes are guarded", {
  paths <- nada_artifact_paths(tempdir(), 2024)
  result <- list(
    data = data.frame(
      iso3c = "AAA",
      NADA = 0,
      NADA_text = NA_character_,
      stringsAsFactors = FALSE
    ),
    overrides = data.frame(),
    auto_zero = data.frame()
  )

  expect_error(
    write_nada_vintage(result, paths, 2024, first_collected_vintage = 2025),
    "REFUSING TO WRITE HISTORICAL NADA VINTAGE"
  )
})

test_that("NADA manifest hashes validate and detect tampering", {
  root <- tempfile("nada-manifest-")
  dir.create(file.path(root, "2.4_DSDS"), recursive = TRUE)
  previous <- data.frame(
    iso3c = "AAA",
    country = "A",
    NADA = 0,
    NADA_text = "https://a.example/nada",
    date = 2024,
    stringsAsFactors = FALSE
  )
  previous_path <- file.path(root, "2.4_DSDS", "D2.4.NADA.2024.csv")
  readr::write_csv(previous, previous_path)
  review_path <- write_nada_review(root)
  paths <- nada_artifact_paths(root, 2025)
  evidence <- data.frame(
    iso3c = "AAA",
    url = previous$NADA_text,
    status_code = 200L,
    NADA_working = TRUE,
    error_message = NA_character_,
    checked_at = "2026-10-21 UTC",
    attempts = 1L,
    stringsAsFactors = FALSE
  )
  dir.create(dirname(paths$evidence), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(evidence, paths$evidence)
  result <- build_nada_vintage(previous, evidence, read_manual_review(
    review_path,
    nada_review_spec(),
    valid_iso3c = "AAA"
  ), 2025, 2025, valid_iso3c = "AAA")
  write_nada_vintage(result, paths, 2025, 2025)

  expect_true(validate_nada_collection_artifact(
    list(raw_dir = root, end_date = 2025),
    valid_iso3c = "AAA"
  ))
  writeLines("tampered", paths$output)
  expect_error(
    validate_nada_collection_artifact(
      list(raw_dir = root, end_date = 2025),
      valid_iso3c = "AAA"
    ),
    "NADA MANIFEST HASH MISMATCH"
  )
})

test_that("the 2024 NADA rebuild matches indicator columns and scores", {
  raw_dir <- here::here("01_raw_data")
  previous <- readr::read_csv(
    file.path(raw_dir, "2.4_DSDS", "D2.4.NADA.2023.csv"),
    show_col_types = FALSE
  )
  expected <- readr::read_csv(
    file.path(raw_dir, "2.4_DSDS", "D2.4.NADA.2024.csv"),
    show_col_types = FALSE
  )
  evidence_source <- readr::read_csv(
    file.path(raw_dir, "2.4_DSDS", "Nada2024.csv"),
    show_col_types = FALSE
  )
  changed <- dplyr::left_join(
    previous[, c("iso3c", "country", "NADA", "NADA_text")],
    expected[, c("iso3c", "NADA", "NADA_text")],
    by = "iso3c",
    suffix = c("_old", "_new")
  )
  review <- make_nada_review(rbind(
    data.frame(
      iso3c = "TJK",
      country = "Tajikistan",
      NADA = "1",
      NADA_text = "http://nada.stat.tj/index.php/home",
      Evidence = "2024 source review",
      stringsAsFactors = FALSE
    ),
    data.frame(
      iso3c = "FJI",
      country = "Fiji",
      NADA = "1",
      NADA_text = "https://www.statsfiji.gov.fj/census-surveys/household-income-and-expenditure-survey/",
      Evidence = "2024 source review",
      stringsAsFactors = FALSE
    )
  ))
  evidence <- evidence_source[, c("iso3c", "NADA_working")]
  evidence$url <- previous$NADA_text[match(evidence$iso3c, previous$iso3c)]
  review_urls <- setNames(review$NADA_text, review$iso3c)
  reviewed <- evidence$iso3c %in% names(review_urls) &
    !is.na(review_urls[evidence$iso3c])
  evidence$url[reviewed] <- unname(review_urls[evidence$iso3c[reviewed]])
  evidence$status_code <- ifelse(evidence$NADA_working, 200L, 404L)
  evidence$error_message <- NA_character_
  evidence$checked_at <- "2026-10-21 UTC"
  evidence$attempts <- 1L

  result <- build_nada_vintage(previous, evidence, review, 2024, 2025)
  rebuilt <- result$data[, c("iso3c", "NADA", "NADA_text")]
  expected_indicator <- expected[, c("iso3c", "NADA", "NADA_text")]
  expect_equal(
    rebuilt[order(rebuilt$iso3c), ],
    expected_indicator[order(expected_indicator$iso3c), ],
    ignore_attr = TRUE
  )

  source(file.path(here::here("R"), "dim2.R"))
  fixture_root <- tempfile("nada-score-")
  fixture_dir <- file.path(fixture_root, "2.4_DSDS")
  dir.create(fixture_dir, recursive = TRUE)
  file.copy(
    list.files(
      file.path(raw_dir, "2.4_DSDS"),
      pattern = "^D2\\.4\\.NADA(\\.2020|\\.2022|\\.2023)?\\.csv$",
      full.names = TRUE
    ),
    fixture_dir
  )
  readr::write_csv(result$data, file.path(fixture_dir, "D2.4.NADA.2024.csv"))
  scored <- score_nada(list(raw_dir = fixture_root, end_date = 2024))
  expected_scores <- expected_indicator %>%
    dplyr::transmute(
      iso3c,
      SPI.D2.4.NADA = dplyr::if_else(NADA == 1, 1, 0)
    )
  actual_scores <- scored %>%
    dplyr::filter(date == 2024) %>%
    dplyr::select(iso3c, SPI.D2.4.NADA)
  expect_equal(
    actual_scores[order(actual_scores$iso3c), ],
    expected_scores[order(expected_scores$iso3c), ],
    ignore_attr = TRUE
  )
})

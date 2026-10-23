# =============================================================================
# NADA collection and vintage construction
# Created: 2026-10-21
# =============================================================================

nada_artifact_paths <- function(raw_dir, end_date) {
  nada_dir <- file.path(raw_dir, "2.4_DSDS")
  collection_dir <- file.path(nada_dir, "collection")
  list(
    previous = file.path(nada_dir, sprintf("D2.4.NADA.%d.csv", end_date - 1L)),
    review = file.path(
      nada_dir,
      sprintf("D2.4.NADA.Manual.Review.%d.xlsx", end_date)
    ),
    evidence = file.path(
      collection_dir,
      sprintf("D2.4.NADA.url_evidence.%d.csv", end_date)
    ),
    output = file.path(nada_dir, sprintf("D2.4.NADA.%d.csv", end_date)),
    manifest = file.path(
      collection_dir,
      sprintf("D2.4.NADA_manifest_%d.json", end_date)
    )
  )
}

nada_review_spec <- function() {
  manual_review_spec(
    indicator = "NADA",
    value_columns = c("NADA", "NADA_text"),
    validators = list(
      NADA = function(values) values %in% c("0", "1"),
      NADA_text = function(values) grepl("^https?://", values)
    )
  )
}

.read_nada_file <- function(path, label = "NADA") {
  if (!file.exists(path)) {
    stop(sprintf("%s FILE NOT FOUND: %s", label, path), call. = FALSE)
  }
  data <- readr::read_csv(path, show_col_types = FALSE)
  required <- c("iso3c", "NADA", "NADA_text")
  missing <- setdiff(required, names(data))
  if (length(missing) > 0L) {
    stop(
      sprintf(
        "%s FILE SCHEMA MISMATCH: missing column(s): %s",
        label,
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (anyNA(data$iso3c) || anyDuplicated(data$iso3c) > 0L) {
    stop(sprintf("%s FILE MUST HAVE UNIQUE iso3c KEYS.", label), call. = FALSE)
  }
  data
}

.nada_review_sites <- function(previous, review) {
  sites <- data.frame(
    iso3c = as.character(previous$iso3c),
    NADA_text = as.character(previous$NADA_text),
    stringsAsFactors = FALSE
  )
  if (nrow(review) == 0L) return(sites)

  review_keys <- as.character(review$iso3c)
  for (index in seq_len(nrow(review))) {
    match_index <- match(review_keys[[index]], sites$iso3c)
    replacement <- review$NADA_text[[index]]
    if (!is.na(replacement) && nzchar(replacement)) {
      if (is.na(match_index)) {
        sites <- rbind(
          sites,
          data.frame(
            iso3c = review_keys[[index]],
            NADA_text = replacement,
            stringsAsFactors = FALSE
          )
        )
      } else {
        sites$NADA_text[[match_index]] <- replacement
      }
    }
  }
  sites
}

#' Check NADA catalogue URLs and record the observed response.
#'
#' @param sites Data frame with `iso3c` and `NADA_text`.
#' @param request_fn Function accepting a URL and returning an httr response.
#' @param delay_fn Function accepting seconds between requests.
#' @param attempts Maximum attempts for transient failures.
#' @param delay_seconds Delay between country requests.
#' @return A data frame of URL evidence.
#' @export
check_nada_urls <- function(sites, request_fn = httr::GET,
                            delay_fn = function(seconds) Sys.sleep(seconds),
                            attempts = 3L, delay_seconds = 5) {
  required <- c("iso3c", "NADA_text")
  missing <- setdiff(required, names(sites))
  if (length(missing) > 0L) {
    stop(
      "NADA URL CHECK INPUT MISSING COLUMN(S): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  if (nrow(sites) == 0L) {
    return(data.frame(
      iso3c = character(),
      url = character(),
      status_code = integer(),
      NADA_working = logical(),
      error_message = character(),
      checked_at = character(),
      attempts = integer(),
      stringsAsFactors = FALSE
    ))
  }

  rows <- lapply(seq_len(nrow(sites)), function(index) {
    iso3c <- as.character(sites$iso3c[[index]])
    raw_url <- sites$NADA_text[[index]]
    url <- if (is.na(raw_url)) NA_character_ else trimws(as.character(raw_url))
    attempt_count <- 0L
    error_message <- NA_character_
    if (is.na(url) || !nzchar(url)) {
      return(data.frame(
        iso3c = iso3c,
        url = NA_character_,
        status_code = NA_integer_,
        NADA_working = NA,
        error_message = "NADA URL MISSING",
        checked_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
        attempts = 0L,
        stringsAsFactors = FALSE
      ))
    }
    response <- tryCatch(
      with_http_retry(
        request_fn = function() {
          attempt_count <<- attempt_count + 1L
          request_fn(url)
        },
        attempts = attempts,
        delay_fn = delay_fn
      ),
      error = function(error) {
        error_message <<- conditionMessage(error)
        NULL
      }
    )
    status_code <- if (is.null(response)) {
      NA_integer_
    } else {
      as.integer(httr::status_code(response))
    }
    nada_working <- if (is.na(status_code)) NA else status_code == 200L
    if (index < nrow(sites) && delay_seconds > 0) {
      delay_fn(delay_seconds)
    }

    data.frame(
      iso3c = iso3c,
      url = url,
      status_code = status_code,
      NADA_working = nada_working,
      error_message = error_message,
      checked_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
      attempts = attempt_count,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

.nada_evidence_matches_sites <- function(evidence, sites) {
  if (!all(c("iso3c", "url") %in% names(evidence))) return(FALSE)
  expected <- paste(
    sites$iso3c,
    ifelse(is.na(sites$NADA_text), "<NA>", sites$NADA_text),
    sep = "\r"
  )
  observed <- paste(
    evidence$iso3c,
    ifelse(is.na(evidence$url), "<NA>", evidence$url),
    sep = "\r"
  )
  identical(sort(expected), sort(observed))
}

.validate_nada_evidence <- function(evidence, sites) {
  required <- c(
    "iso3c", "url", "status_code", "NADA_working", "error_message",
    "checked_at", "attempts"
  )
  missing <- setdiff(required, names(evidence))
  if (length(missing) > 0L) {
    stop(
      "NADA EVIDENCE SCHEMA MISMATCH: missing column(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  if (anyNA(evidence$iso3c) || anyDuplicated(evidence$iso3c) > 0L) {
    stop("NADA EVIDENCE MUST HAVE UNIQUE iso3c KEYS.", call. = FALSE)
  }
  if (!.nada_evidence_matches_sites(evidence, sites) ||
      nrow(evidence) != nrow(sites)) {
    stop(
      "NADA EVIDENCE MUST COVER EACH EXPECTED COUNTRY AND URL EXACTLY ONCE.",
      call. = FALSE
    )
  }
  expected_working <- ifelse(
    is.na(evidence$status_code),
    NA,
    evidence$status_code == 200L
  )
  inconsistent <- !is.na(expected_working) &
    (is.na(evidence$NADA_working) | evidence$NADA_working != expected_working)
  if (any(inconsistent)) {
    stop(
      "NADA EVIDENCE HAS INCONSISTENT STATUS AND NADA_working VALUES.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Collect or reuse cached NADA URL evidence.
#'
#' @param params Collection parameters.
#' @param request_fn Optional injected URL request function.
#' @param delay_fn Optional injected delay function.
#' @return Path to the evidence CSV.
#' @export
collect_nada_url_evidence <- function(params, request_fn = NULL, delay_fn = NULL,
                                      valid_iso3c = NULL) {
  paths <- nada_artifact_paths(params$raw_dir, params$end_date)
  previous <- .read_nada_file(paths$previous, "NADA PREVIOUS VINTAGE")
  review <- read_manual_review(
    paths$review,
    nada_review_spec(),
    valid_iso3c = valid_iso3c
  )
  sites <- .nada_review_sites(previous, review)

  max_age <- if (is.null(params$nada_url_max_age_days)) Inf else params$nada_url_max_age_days
  refresh <- isTRUE(params$refresh_nada_urls)
  cache_is_fresh <- file.exists(paths$evidence) &&
    as.numeric(difftime(Sys.time(), file.info(paths$evidence)$mtime, units = "days")) <= max_age
  if (!refresh && cache_is_fresh) {
    cached <- readr::read_csv(paths$evidence, show_col_types = FALSE)
    if (.nada_evidence_matches_sites(cached, sites)) {
      .validate_nada_evidence(cached, sites)
      return(paths$evidence)
    }
  }

  if (is.null(request_fn)) {
    request_fn <- function(url) httr::GET(url, httr::timeout(60))
  }
  if (is.null(delay_fn)) delay_fn <- function(seconds) Sys.sleep(seconds)
  evidence <- check_nada_urls(
    sites,
    request_fn = request_fn,
    delay_fn = delay_fn,
    attempts = 3L,
    delay_seconds = if (is.null(params$nada_url_delay_seconds)) 5 else params$nada_url_delay_seconds
  )
  .validate_nada_evidence(evidence, sites)
  network_failure <- is.na(evidence$status_code) |
    evidence$status_code %in% c(408L, 429L, 500L, 502L, 503L, 504L)
  error_rate <- if (nrow(evidence) == 0L) 0 else mean(network_failure)
  if (error_rate > 0.5) {
    stop(
      "NADA URL CHECK FAILED FOR MOST SITES; check network access before auto-zeroing.",
      call. = FALSE
    )
  }

  dir.create(dirname(paths$evidence), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(evidence, paths$evidence)
  paths$evidence
}

.nada_new_rows <- function(previous, review, new_keys) {
  rows <- previous[rep(1L, length(new_keys)), , drop = FALSE]
  for (column in names(rows)) {
    rows[[column]] <- previous[[column]][rep(NA_integer_, length(new_keys))]
  }
  review_index <- match(new_keys, review$iso3c)
  rows$iso3c <- new_keys
  if ("country" %in% names(rows)) rows$country <- review$country[review_index]
  rows$NADA <- as.numeric(review$NADA[review_index])
  rows$NADA_text <- review$NADA_text[review_index]
  rows
}

#' Build a NADA vintage from prior values, URL evidence, and review overrides.
#'
#' @param previous Previous vintage data frame.
#' @param evidence URL evidence data frame.
#' @param review Validated review data frame.
#' @param end_date Current reference year.
#' @param first_collected_vintage First vintage using auto-zero collection logic.
#' @return A list with `data`, `overrides`, `auto_zero`, and `warnings`.
#' @export
build_nada_vintage <- function(previous, evidence, review, end_date,
                               first_collected_vintage = 2025,
                               valid_iso3c = NULL) {
  required_previous <- c("iso3c", "NADA", "NADA_text")
  missing_previous <- setdiff(required_previous, names(previous))
  if (length(missing_previous) > 0L) {
    stop(
      "NADA PREVIOUS VINTAGE MISSING COLUMN(S): ",
      paste(missing_previous, collapse = ", "),
      call. = FALSE
    )
  }
  required_evidence <- c("iso3c", "NADA_working")
  missing_evidence <- setdiff(required_evidence, names(evidence))
  if (length(missing_evidence) > 0L) {
    stop(
      "NADA EVIDENCE MISSING COLUMN(S): ",
      paste(missing_evidence, collapse = ", "),
      call. = FALSE
    )
  }

  spec <- nada_review_spec()
  validate_manual_review(review, spec, valid_iso3c = valid_iso3c)
  previous$iso3c <- as.character(previous$iso3c)
  review$iso3c <- as.character(review$iso3c)
  evidence$iso3c <- as.character(evidence$iso3c)
  sites <- .nada_review_sites(previous, review)
  .validate_nada_evidence(evidence, sites)
  new_keys <- setdiff(review$iso3c, previous$iso3c)
  if (length(new_keys) > 0L) {
    new_review <- review[match(new_keys, review$iso3c), , drop = FALSE]
    complete <- !is.na(new_review$NADA) & !is.na(new_review$NADA_text)
    if (any(!complete)) {
      stop(
        "NEW COUNTRY REVIEW MUST PROVIDE NADA AND NADA_text",
        call. = FALSE
      )
    }
    previous <- rbind(previous, .nada_new_rows(previous, review, new_keys))
  }

  applied <- apply_manual_review(previous, review, spec)
  data <- applied$data
  if ("date" %in% names(data)) data$date <- end_date
  evidence_index <- match(data$iso3c, evidence$iso3c)
  data$NADA_working <- evidence$NADA_working[evidence_index]
  evidence_errors <- if ("error_message" %in% names(evidence)) {
    evidence$error_message[evidence_index]
  } else {
    rep(NA_character_, nrow(data))
  }
  review_override <- match(data$iso3c, review$iso3c)
  has_nada_override <- !is.na(review_override) &
    !is.na(review$NADA[review_override])
  unresolved <- end_date >= first_collected_vintage &
    !is.na(data$NADA) & data$NADA == 1 &
    (is.na(data$NADA_working) | !data$NADA_working) &
    !has_nada_override
  if (any(unresolved)) {
    stop(
      paste0(
        "NADA REVIEW REQUIRED FOR UNRESOLVED POSITIVE VALUES: ",
        paste(data$iso3c[unresolved], collapse = ", "),
        ". Add an evidenced NADA value to the current manual review workbook."
      ),
      call. = FALSE
    )
  }

  auto_zero <- data.frame(
    iso3c = character(),
    old = numeric(),
    new = numeric(),
    reason = character(),
    stringsAsFactors = FALSE
  )
  warnings <- data.frame(
    source_id = character(),
    message = character(),
    stringsAsFactors = FALSE
  )

  list(
    data = data,
    overrides = applied$overrides,
    auto_zero = auto_zero,
    warnings = warnings
  )
}

.nada_project_relative_path <- function(path) {
  root <- normalizePath(here::here(), winslash = "/", mustWork = FALSE)
  normalized <- normalizePath(path, winslash = "/", mustWork = FALSE)
  prefix <- paste0(root, "/")
  if (startsWith(normalized, prefix)) {
    substring(normalized, nchar(prefix) + 1L)
  } else {
    normalized
  }
}

.nada_file_record <- function(path, role) {
  list(
    path = .nada_project_relative_path(path),
    role = role,
    sha256 = if (file.exists(path)) digest::digest(path, algo = "sha256", file = TRUE) else NA_character_
  )
}

.validate_nada_output <- function(data) {
  required <- c("iso3c", "NADA", "NADA_text")
  missing <- setdiff(required, names(data))
  if (length(missing) > 0L) {
    stop(
      "NADA OUTPUT MISSING COLUMN(S): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  if (anyNA(data$iso3c) || anyDuplicated(data$iso3c) > 0L) {
    stop("NADA OUTPUT MUST HAVE UNIQUE iso3c KEYS.", call. = FALSE)
  }
  if (any(!is.na(data$NADA) & !data$NADA %in% c(0, 1))) {
    stop("NADA OUTPUT CONTAINS VALUES OUTSIDE {0, 1}.", call. = FALSE)
  }
  invisible(TRUE)
}

.nada_manifest_path <- function(path) {
  if (grepl("^/", path)) path else here::here(path)
}

#' Validate the current NADA output, evidence, and manifest hashes.
#'
#' @param params Collection parameters.
#' @param valid_iso3c Optional canonical country-key vector.
#' @return Invisibly returns TRUE.
#' @export
validate_nada_collection_artifact <- function(params, valid_iso3c = NULL) {
  paths <- nada_artifact_paths(params$raw_dir, params$end_date)
  if (!file.exists(paths$manifest)) {
    stop("NADA MANIFEST FILE NOT FOUND: ", paths$manifest, call. = FALSE)
  }
  manifest <- jsonlite::read_json(paths$manifest, simplifyVector = FALSE)
  if (!identical(as.integer(manifest$end_date), as.integer(params$end_date))) {
    stop("NADA MANIFEST VINTAGE DOES NOT MATCH CURRENT PARAMETERS.", call. = FALSE)
  }
  records <- c("output", "evidence", "previous", "review")
  for (record_name in records) {
    record <- manifest[[record_name]]
    if (is.null(record$path) || is.null(record$sha256)) {
      stop("NADA MANIFEST IS MISSING RECORD: ", record_name, call. = FALSE)
    }
    record_path <- .nada_manifest_path(record$path)
    if (!file.exists(record_path)) {
      stop("NADA MANIFEST ARTIFACT NOT FOUND: ", record_path, call. = FALSE)
    }
    actual_hash <- digest::digest(record_path, algo = "sha256", file = TRUE)
    if (!identical(as.character(record$sha256), actual_hash)) {
      stop("NADA MANIFEST HASH MISMATCH: ", record_name, call. = FALSE)
    }
  }

  previous <- .read_nada_file(paths$previous, "NADA PREVIOUS VINTAGE")
  review <- read_manual_review(
    paths$review,
    nada_review_spec(),
    valid_iso3c = valid_iso3c
  )
  sites <- .nada_review_sites(previous, review)
  evidence <- readr::read_csv(paths$evidence, show_col_types = FALSE)
  .validate_nada_evidence(evidence, sites)
  .validate_nada_output(readr::read_csv(paths$output, show_col_types = FALSE))
  invisible(TRUE)
}

#' Read warnings recorded in a NADA manifest.
#'
#' @param manifest_path Path to a NADA manifest.
#' @return A two-column warning data frame.
#' @export
read_nada_manifest_warnings <- function(manifest_path) {
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
  warnings <- manifest$warnings
  if (is.null(warnings) || length(warnings) == 0L) {
    return(data.frame(
      source_id = character(),
      message = character(),
      stringsAsFactors = FALSE
    ))
  }
  as.data.frame(warnings, stringsAsFactors = FALSE)
}

#' Write a NADA vintage and its provenance manifest.
#'
#' @param result Output from [build_nada_vintage()].
#' @param paths Output from [nada_artifact_paths()].
#' @param end_date Current reference year.
#' @param first_collected_vintage First permitted project vintage.
#' @param allow_historical Allow historical writes only in isolated tests.
#' @return A list with output, manifest, warnings, and auto-zero records.
#' @export
write_nada_vintage <- function(result, paths, end_date,
                               first_collected_vintage = 2025,
                               allow_historical = FALSE) {
  if (end_date < first_collected_vintage && !allow_historical) {
    stop(
      "REFUSING TO WRITE HISTORICAL NADA VINTAGE: use the current end_date.",
      call. = FALSE
    )
  }
  .validate_nada_output(result$data)
  dir.create(dirname(paths$output), recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(paths$manifest), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(result$data, paths$output)
  manifest <- list(
    indicator = "SPI.D2.4.NADA",
    end_date = end_date,
    created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    output = .nada_file_record(paths$output, "normalized_vintage"),
    evidence = if (file.exists(paths$evidence)) {
      .nada_file_record(paths$evidence, "url_evidence")
    } else {
      NULL
    },
    previous = if (file.exists(paths$previous)) {
      .nada_file_record(paths$previous, "previous_vintage")
    } else {
      NULL
    },
    review = if (file.exists(paths$review)) {
      manual_review_metadata(
        paths$review,
        read_manual_review(paths$review, nada_review_spec()),
        result$overrides
      )
    } else {
      NULL
    },
    rows = nrow(result$data),
    auto_zero = result$auto_zero,
    overrides = result$overrides,
    warnings = result$warnings
  )
  jsonlite::write_json(manifest, paths$manifest, auto_unbox = TRUE, pretty = TRUE, na = "null")
  .validate_nada_output(readr::read_csv(paths$output, show_col_types = FALSE))

  list(
    output = paths$output,
    manifest = paths$manifest,
    warnings = result$warnings,
    auto_zero = result$auto_zero
  )
}

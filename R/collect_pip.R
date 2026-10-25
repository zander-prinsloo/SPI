# =============================================================================
# PIP comparability collection
# =============================================================================
# Created: 2026-10-05
# =============================================================================

.pip_key_columns <- c(
  "country_code", "year", "survey_acronym", "reporting_level", "welfare_type"
)

validate_pip_output <- function(data) {
  required <- unique(c(
    "survey_acronym", "country_code", "year",
    "survey_comparability", "survey_coverage", .pip_key_columns
  ))
  missing <- setdiff(required, names(data))
  if (length(missing) > 0L) {
    stop("PIP OUTPUT SCHEMA MISMATCH: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  if (!is.numeric(data$year) && !is.integer(data$year)) {
    stop("PIP OUTPUT TYPE MISMATCH: year must be numeric.", call. = FALSE)
  }
  if (anyDuplicated(as.data.frame(data)[, .pip_key_columns, drop = FALSE]) > 0L) {
    stop(
      "PIP OUTPUT KEY VIOLATION: duplicate ",
      paste(.pip_key_columns, collapse = "/"),
      " rows.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

.require_pipr <- function() {
  if (!requireNamespace("pipr", quietly = TRUE)) {
    stop(
      "PIP COLLECTOR UNAVAILABLE: install or restore the locked `pipr` package.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Resolve the PIP release to collect.
#'
#' Returns the newest `PROD` release for the PPP version, unless a release
#' lock is supplied, in which case the locked release is returned without
#' querying the API (the locked response is served from the raw cache).
#'
#' @param versions_fn Zero-argument function returning the PIP versions table
#'   (`version`, `release_version`, `ppp_version`, `identity`); defaults to
#'   `pipr::get_versions`.
#' @param ppp_version PPP base year (for example 2021).
#' @param lock Optional approved release identifier from the release lock.
#' @return A PIP version identifier such as `20260922_2021_01_02_PROD`.
#' @export
resolve_pip_release <- function(versions_fn = NULL, ppp_version = 2021, lock = NULL) {
  if (!is.null(lock) && length(lock) == 1L && !is.na(lock) && nzchar(lock)) {
    return(lock)
  }
  if (is.null(versions_fn)) {
    .require_pipr()
    versions_fn <- function() pipr::get_versions()
  }
  versions <- as.data.frame(versions_fn(), stringsAsFactors = FALSE)
  required <- c("version", "release_version", "ppp_version", "identity")
  missing <- setdiff(required, names(versions))
  if (length(missing) > 0L) {
    stop("PIP VERSIONS SCHEMA MISMATCH: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  prod <- versions[
    versions$identity == "PROD" &
      as.character(versions$ppp_version) == as.character(ppp_version),
    ,
    drop = FALSE
  ]
  if (nrow(prod) == 0L) {
    stop(sprintf("NO PIP PROD RELEASE for PPP version %s.", ppp_version), call. = FALSE)
  }
  prod <- prod[order(prod$release_version, prod$version, decreasing = TRUE), , drop = FALSE]
  prod$version[[1]]
}

#' Collect PIP comparability data through pipr.
#'
#' The release is part of the cache request, so a new PIP release forces a
#' fresh fetch, and it is recorded in the artifact provenance sidecar.
#'
#' @param raw_dir Root `01_raw_data` directory.
#' @param fetch_fn Optional injected function returning a PIP data frame.
#' @param vintage Reference vintage used in the cache identity.
#' @param max_age_days Maximum cache age in days.
#' @param release Optional pre-resolved PIP release identifier.
#' @param ppp_version PPP base year used to resolve the release.
#' @param versions_fn Optional injected versions function (see
#'   [resolve_pip_release()]).
#' @param stats_fn Optional injected function taking a release identifier and
#'   returning PIP statistics; defaults to `pipr::get_stats(version = )`.
#' @param release_lock Optional approved release identifier.
#' @return Provenance record with normalized artifact path and release.
#' @export
collect_pip_comparability <- function(raw_dir, fetch_fn = NULL, vintage,
                                      max_age_days = Inf, release = NULL,
                                      ppp_version = 2021, versions_fn = NULL,
                                      stats_fn = NULL, release_lock = NULL) {
  if (is.null(release)) {
    release <- resolve_pip_release(
      versions_fn = versions_fn,
      ppp_version = ppp_version,
      lock = release_lock
    )
  }
  if (is.null(fetch_fn)) {
    if (is.null(stats_fn)) {
      .require_pipr()
      stats_fn <- function(version) pipr::get_stats(version = version)
    }
    fetch_fn <- function() stats_fn(release)
  }

  record <- collect_cached_table(
    cache_dir = file.path(raw_dir, "1.5_DUIO", "raw", "pip"),
    source_id = "pip_comparability",
    request = list(source = "pipr::get_stats", version = release),
    vintage = vintage,
    collector_version = "pipr-v2",
    fetch = fetch_fn,
    max_age_days = max_age_days
  )
  validate_pip_output(record$table)

  normalized_path <- file.path(raw_dir, "1.5_DUIO", "PIP_comparability_latest.csv")
  dir.create(dirname(normalized_path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(record$table, normalized_path)
  write_artifact_provenance(
    normalized_path,
    source_id = "d1_5_pip",
    retrieved_at = record$retrieved_at,
    release_identifier = release,
    raw_path = record$raw_path
  )
  record$normalized_path <- normalizePath(normalized_path, winslash = "/", mustWork = FALSE)
  record$release_identifier <- release
  record
}

# =============================================================================
# PIP comparability collection
# =============================================================================
# Created: 2026-10-05
# =============================================================================

validate_pip_output <- function(data) {
  required <- c(
    "survey_acronym", "country_code", "year",
    "survey_comparability", "survey_coverage"
  )
  missing <- setdiff(required, names(data))
  if (length(missing) > 0L) {
    stop("PIP OUTPUT SCHEMA MISMATCH: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  if (!is.numeric(data$year) && !is.integer(data$year)) {
    stop("PIP OUTPUT TYPE MISMATCH: year must be numeric.", call. = FALSE)
  }
  key <- interaction(data$country_code, data$year, data$survey_acronym, drop = TRUE)
  if (anyDuplicated(key) > 0L) {
    stop("PIP OUTPUT KEY VIOLATION: duplicate country/year/survey rows.", call. = FALSE)
  }
  invisible(TRUE)
}

#' Collect PIP comparability data through pipr.
#'
#' @param raw_dir Root `01_raw_data` directory.
#' @param fetch_fn Optional injected function returning a PIP data frame.
#' @param vintage Reference vintage used in the cache identity.
#' @return Provenance record with normalized artifact path.
#' @export
collect_pip_comparability <- function(raw_dir, fetch_fn = NULL, vintage,
                                      max_age_days = Inf) {
  if (is.null(fetch_fn)) {
    if (!requireNamespace("pipr", quietly = TRUE)) {
      stop(
        "PIP COLLECTOR UNAVAILABLE: install or restore the locked `pipr` package.",
        call. = FALSE
      )
    }
    fetch_fn <- function() pipr::get_stats()
  }

  record <- collect_cached_table(
    cache_dir = file.path(raw_dir, "1.5_DUIO", "raw", "pip"),
    source_id = "pip_comparability",
    request = list(source = "pipr::get_stats"),
    vintage = vintage,
    collector_version = "pipr-v1",
    fetch = fetch_fn,
    max_age_days = max_age_days
  )
  validate_pip_output(record$table)

  normalized_path <- file.path(raw_dir, "1.5_DUIO", "PIP_comparability_latest.csv")
  dir.create(dirname(normalized_path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(record$table, normalized_path)
  record$normalized_path <- normalizePath(normalized_path, winslash = "/", mustWork = FALSE)
  record
}

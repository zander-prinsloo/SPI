# =============================================================================
# Source registry loading and validation
# =============================================================================
# Created: 2026-10-05
# =============================================================================

#' Validate the source registry contract.
#'
#' @param registry A data frame loaded from config/source_registry.R.
#' @return TRUE when the registry is valid.
#' @export
validate_source_registry <- function(registry) {
  required <- c(
    "source_id", "dimension_id", "source_type", "indicator_ids",
    "source_url", "input_path", "raw_path", "normalized_path",
    "availability_path", "expected_vintage_rule", "age_warning_days",
    "status_if_missing", "analyst_action"
  )
  missing <- setdiff(required, names(registry))
  if (length(missing) > 0) {
    stop(
      "SOURCE REGISTRY SCHEMA MISMATCH: missing column(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  if (anyNA(registry$source_id) || anyDuplicated(registry$source_id) > 0) {
    stop("SOURCE REGISTRY contains missing or duplicate source_id values.", call. = FALSE)
  }

  valid_types <- c("api", "manual", "external", "unavailable")
  invalid_types <- setdiff(unique(registry$source_type), valid_types)
  if (length(invalid_types) > 0) {
    stop(
      "SOURCE REGISTRY contains invalid source_type values: ",
      paste(invalid_types, collapse = ", "),
      call. = FALSE
    )
  }

  valid_statuses <- c("blocking", "warning", "informational")
  invalid_statuses <- setdiff(unique(registry$status_if_missing), valid_statuses)
  if (length(invalid_statuses) > 0) {
    stop(
      "SOURCE REGISTRY contains invalid status_if_missing values: ",
      paste(invalid_statuses, collapse = ", "),
      call. = FALSE
    )
  }

  valid_rules <- c(
    "not_measured", "end_date", "end_date_plus_one",
    "manual_attestation", "release_identifier"
  )
  invalid_rules <- setdiff(unique(registry$expected_vintage_rule), valid_rules)
  if (length(invalid_rules) > 0) {
    stop(
      "SOURCE REGISTRY contains UNSUPPORTED EXPECTED VINTAGE RULE value(s): ",
      paste(invalid_rules, collapse = ", "),
      call. = FALSE
    )
  }

  if (any(is.na(registry$age_warning_days) | registry$age_warning_days < 0)) {
    stop("SOURCE REGISTRY age_warning_days must be non-negative.", call. = FALSE)
  }

  invisible(TRUE)
}

#' Load and validate the machine-readable source registry.
#'
#' @param registry_path Character path to the registry R file.
#' @return A validated data frame.
#' @export
load_source_registry <- function(registry_path) {
  if (!file.exists(registry_path)) {
    stop(sprintf("SOURCE REGISTRY FILE NOT FOUND: %s", registry_path), call. = FALSE)
  }

  registry_env <- new.env(parent = baseenv())
  sys.source(registry_path, envir = registry_env)
  if (!exists("source_registry", envir = registry_env, inherits = FALSE)) {
    stop("SOURCE REGISTRY FILE MUST DEFINE `source_registry`.", call. = FALSE)
  }

  registry <- registry_env$source_registry
  if (!is.data.frame(registry)) {
    stop("SOURCE REGISTRY `source_registry` must be a data frame.", call. = FALSE)
  }

  validate_source_registry(registry)
  registry
}

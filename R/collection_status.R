# =============================================================================
# Collection status validation
# =============================================================================
# Created: 2026-10-05
# =============================================================================

#' Hash the collection-relevant parameter identity.
#'
#' @param params Pipeline parameter list.
#' @return SHA-256 parameter identity.
#' @export
collection_parameters_hash <- function(params) {
  identity <- list(
    end_date = params$end_date,
    span = params$span,
    imf_file = params$imf_file,
    ilo_modelled_file = params$ilo_modelled_file,
    ilo_survey_file = params$ilo_survey_file,
    registry = params$source_registry_file
  )
  digest::digest(
    jsonlite::toJSON(identity, auto_unbox = TRUE, null = "null"),
    algo = "sha256",
    serialize = FALSE
  )
}

#' Mark the beginning of a collection run.
#'
#' @param params Pipeline parameter list.
#' @return Run metadata.
#' @export
start_collection_run <- function(params) {
  dir.create(dirname(params$collection_run_file), recursive = TRUE, showWarnings = FALSE)
  run <- list(
    run_id = paste0(format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"), "-", substr(collection_parameters_hash(params), 1, 12)),
    collection_state = "started",
    started_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    parameters_hash = collection_parameters_hash(params)
  )
  jsonlite::write_json(run, params$collection_run_file, auto_unbox = TRUE, pretty = TRUE)
  run
}

#' Mark a collection run complete after writing its report.
#'
#' @param params Pipeline parameter list.
#' @param run Run metadata from start_collection_run().
#' @return Invisibly returns the run metadata.
#' @export
complete_collection_run <- function(params, run) {
  run$collection_state <- "complete"
  run$completed_at <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  jsonlite::write_json(run, params$collection_run_file, auto_unbox = TRUE, pretty = TRUE)
  invisible(run)
}

#' Resolve a registry artifact path against a collection root.
#'
#' @param relative_path Registry path, possibly containing `<YEAR>` or a
#'   glob pattern.
#' @param collection_root Root directory for source artifacts.
#' @param end_date Current reference year.
#' @return A matching path or NA when no path is configured.
#' @export
resolve_collection_artifact_path <- function(relative_path, collection_root, end_date) {
  if (length(relative_path) == 0L || is.na(relative_path) || !nzchar(relative_path)) {
    return(NA_character_)
  }

  relative_path <- gsub("<YEAR>", as.character(end_date), relative_path, fixed = TRUE)
  relative_path <- gsub("<END_DATE>", as.character(end_date), relative_path, fixed = TRUE)
  relative_path <- gsub("<END_DATE_PLUS_ONE>", as.character(end_date + 1), relative_path, fixed = TRUE)
  candidate <- file.path(collection_root, relative_path)
  matches <- Sys.glob(candidate)
  if (length(matches) > 0L) matches[[1]] else candidate
}

#' Evaluate registry sources and classify collection status.
#'
#' @param registry Validated source registry data frame.
#' @param collection_root Root directory containing source artifacts.
#' @param end_date Current reference year.
#' @param now Current time used for age calculations.
#' @return A status data frame.
#' @export
evaluate_collection_status <- function(registry, collection_root, end_date,
                                       now = Sys.time(), run_id = NA_character_,
                                       parameters_hash = NA_character_) {
  required <- c(
    "source_id", "dimension_id", "source_type", "normalized_path",
    "expected_vintage_rule", "age_warning_days", "status_if_missing",
    "analyst_action"
  )
  missing <- setdiff(required, names(registry))
  if (length(missing) > 0L) {
    stop(
      "COLLECTION STATUS REGISTRY MISMATCH: missing column(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  checked_at <- format(as.POSIXct(now, tz = "UTC"), tz = "UTC", usetz = TRUE)
  rows <- lapply(seq_len(nrow(registry)), function(i) {
    source <- registry[i, , drop = FALSE]
    relative_path <- source$normalized_path[[1]]
    if (is.na(relative_path) || !nzchar(relative_path)) {
      relative_path <- if ("input_path" %in% names(source)) {
        source$input_path[[1]]
      } else {
        NA_character_
      }
    }
    artifact_path <- resolve_collection_artifact_path(relative_path, collection_root, end_date)
    expected_rule <- source$expected_vintage_rule[[1]]
    observed_vintage <- switch(
      expected_rule,
      end_date = as.character(end_date),
      end_date_plus_one = as.character(end_date + 1),
      not_measured = NA_character_,
      latest_release = "unverified",
      "unverified"
    )

    if (source$source_type[[1]] == "unavailable") {
      status <- "informational"
      reason <- "source_unavailable_by_design"
      age_days <- NA_real_
    } else if (is.na(artifact_path) || !file.exists(artifact_path)) {
      status <- source$status_if_missing[[1]]
      reason <- "artifact_missing"
      age_days <- NA_real_
    } else if (identical(observed_vintage, "unverified")) {
      status <- source$status_if_missing[[1]]
      reason <- "source_vintage_unverified"
      age_days <- as.numeric(difftime(now, file.info(artifact_path)$mtime, units = "days"))
    } else {
      modified <- file.info(artifact_path)$mtime
      age_days <- as.numeric(difftime(now, modified, units = "days"))
      if (!is.na(age_days) && age_days > source$age_warning_days[[1]]) {
        status <- if (source$status_if_missing[[1]] == "blocking") "blocking" else "warning"
        reason <- "artifact_age_exceeds_warning_threshold"
      } else {
        status <- "informational"
        reason <- "artifact_present"
      }
    }

    data.frame(
      source_id = source$source_id[[1]],
      dimension_id = source$dimension_id[[1]],
      source_type = source$source_type[[1]],
      status = status,
      reason = reason,
      artifact_path = artifact_path,
      expected_vintage_rule = expected_rule,
      observed_vintage = observed_vintage,
      age_days = age_days,
      age_warning_days = source$age_warning_days[[1]],
      analyst_action = source$analyst_action[[1]],
      collection_run_id = run_id,
      parameters_hash = parameters_hash,
      checked_at = checked_at,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

#' Validate the collection status manifest before estimation.
#'
#' @param status_path Character path to the collection status CSV.
#' @return TRUE when the manifest exists and has no blocking records.
#' @export
validate_collection_status <- function(status_path, expected_source_ids = NULL,
                                       run_path = NULL, parameters_hash = NULL) {
  if (!file.exists(status_path)) {
    stop(
      sprintf("COLLECTION STATUS FILE NOT FOUND: %s", status_path),
      "Run the data collection pipeline before estimation.",
      call. = FALSE
    )
  }

  status <- readr::read_csv(status_path, show_col_types = FALSE)
  required <- c("source_id", "status", "checked_at", "collection_run_id", "parameters_hash")
  missing <- setdiff(required, names(status))
  if (length(missing) > 0) {
    stop(
      "COLLECTION STATUS SCHEMA MISMATCH: missing column(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  if (nrow(status) == 0L || anyDuplicated(status$source_id) > 0L) {
    stop("COLLECTION STATUS MANIFEST MUST CONTAIN UNIQUE SOURCE ROWS.", call. = FALSE)
  }
  if (!all(status$status %in% c("blocking", "warning", "informational"))) {
    stop("COLLECTION STATUS MANIFEST CONTAINS AN INVALID STATUS.", call. = FALSE)
  }
  if (!is.null(expected_source_ids) && !setequal(status$source_id, expected_source_ids)) {
    stop("COLLECTION STATUS MANIFEST DOES NOT MATCH THE CURRENT SOURCE REGISTRY.", call. = FALSE)
  }
  if (!is.null(run_path)) {
    if (!file.exists(run_path)) stop("COLLECTION RUN MARKER NOT FOUND.", call. = FALSE)
    run <- jsonlite::read_json(run_path, simplifyVector = TRUE)
    if (!identical(run$collection_state, "complete")) {
      stop("COLLECTION RUN IS NOT COMPLETE.", call. = FALSE)
    }
    if (!all(status$collection_run_id == run$run_id)) {
      stop("COLLECTION STATUS DOES NOT MATCH THE COMPLETED RUN.", call. = FALSE)
    }
  }
  if (!is.null(parameters_hash) && !all(status$parameters_hash == parameters_hash)) {
    stop("COLLECTION STATUS DOES NOT MATCH CURRENT PARAMETERS.", call. = FALSE)
  }

  blocking <- status[status$status == "blocking", , drop = FALSE]
  if (nrow(blocking) > 0) {
    stop(
      "COLLECTION BLOCKED: ", nrow(blocking),
      " source issue(s) require analyst action before estimation.",
      call. = FALSE
    )
  }

  TRUE
}

# =============================================================================
# Collection status validation
# =============================================================================
# Created: 2026-10-05
# =============================================================================

.collection_hash_or_na <- function(path) {
  if (is.null(path) || length(path) == 0L || !file.exists(path)) {
    return(NA_character_)
  }
  digest::digest(path, algo = "sha256", file = TRUE)
}

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
    imf_file_2024 = params$imf_file_2024,
    ilo_modelled_file = params$ilo_modelled_file,
    ilo_survey_file = params$ilo_survey_file,
    first_collected_vintage = params$first_collected_vintage,
    pip_ppp_version = params$pip_ppp_version,
    nada_url_max_age_days = params$nada_url_max_age_days,
    refresh_nada_urls = params$refresh_nada_urls,
    nada_url_delay_seconds = params$nada_url_delay_seconds,
    registry_path = params$source_registry_file,
    registry_hash = .collection_hash_or_na(params$source_registry_file),
    odin_country_exclusions_hash = .collection_hash_or_na(
      params$odin_country_exclusions_file
    ),
    odin_country_crosswalk_hash = .collection_hash_or_na(
      params$odin_country_crosswalk_file
    ),
    nada_previous_hash = .collection_hash_or_na(file.path(
      params$raw_dir,
      "2.4_DSDS",
      sprintf("D2.4.NADA.%d.csv", params$end_date - 1L)
    )),
    nada_review_hash = .collection_hash_or_na(file.path(
      params$raw_dir,
      "2.4_DSDS",
      sprintf("D2.4.NADA.Manual.Review.%d.xlsx", params$end_date)
    )),
    gsbp_desk_review_hash = .collection_hash_or_na(file.path(
      params$raw_dir,
      "5.2_DISM",
      "raw",
      "D1.12.MSC.csv"
    )),
    attestation_hash = if (is.null(params$collection_dir)) {
      NA_character_
    } else {
      .collection_hash_or_na(collection_attestation_path(params))
    }
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
  if (!file.exists(params$collection_status_file)) {
    stop(
      "COLLECTION STATUS FILE NOT FOUND BEFORE RUN COMPLETION: ",
      params$collection_status_file,
      call. = FALSE
    )
  }
  run$status_sha256 <- digest::digest(
    params$collection_status_file,
    algo = "sha256",
    file = TRUE
  )
  jsonlite::write_json(run, params$collection_run_file, auto_unbox = TRUE, pretty = TRUE)
  invisible(run)
}

#' Placeholder values that bind registry paths to configured source files.
#'
#' @param params Pipeline parameters.
#' @return Named list of placeholder values (unset parameters are omitted).
#' @export
collection_artifact_substitutions <- function(params) {
  values <- list(
    ILO_MODELLED_FILE = params$ilo_modelled_file,
    ILO_SURVEY_FILE = params$ilo_survey_file,
    IMF_FILE = params$imf_file,
    IMF_FILE_2024 = params$imf_file_2024,
    UNIGME_FILE = params$unigme_file
  )
  values[!vapply(values, is.null, logical(1))]
}

#' Resolve a registry artifact path against a collection root.
#'
#' @param relative_path Registry path, possibly containing `<YEAR>`,
#'   configured-file placeholders such as `<IMF_FILE>`, or a glob pattern.
#' @param collection_root Root directory for source artifacts.
#' @param end_date Current reference year.
#' @param substitutions Named list from [collection_artifact_substitutions()].
#' @return Resolved paths; stops on any unresolved placeholder.
#' @export
resolve_collection_artifact_paths <- function(relative_path, collection_root, end_date,
                                              substitutions = list()) {
  if (length(relative_path) == 0L || is.na(relative_path) || !nzchar(relative_path)) {
    return(character())
  }

  paths <- strsplit(relative_path, "|", fixed = TRUE)[[1]]
  unname(unlist(lapply(paths, function(path) {
    for (name in names(substitutions)) {
      path <- gsub(sprintf("<%s>", name), as.character(substitutions[[name]]), path, fixed = TRUE)
    }
    path <- gsub("<YEAR>", as.character(end_date), path, fixed = TRUE)
    path <- gsub("<END_DATE>", as.character(end_date), path, fixed = TRUE)
    path <- gsub("<END_DATE_PLUS_ONE>", as.character(end_date + 1), path, fixed = TRUE)
    path <- gsub("<timestamp>", "*", path, fixed = TRUE)
    unresolved <- regmatches(path, gregexpr("<[A-Za-z0-9_]+>", path))[[1]]
    if (length(unresolved) > 0L) {
      stop(
        "COLLECTION ARTIFACT PATH HAS UNRESOLVED PLACEHOLDER(S): ",
        paste(unique(unresolved), collapse = ", "), " in '", relative_path, "'",
        call. = FALSE
      )
    }
    candidate <- file.path(collection_root, path)
    matches <- Sys.glob(candidate)
    if (length(matches) > 0L) matches[[1]] else candidate
  })))
}

resolve_collection_artifact_path <- function(relative_path, collection_root, end_date,
                                             substitutions = list()) {
  paths <- resolve_collection_artifact_paths(relative_path, collection_root, end_date, substitutions)
  if (length(paths) == 0L) NA_character_ else paste(paths, collapse = "|")
}

.age_status <- function(age_days, threshold, status_if_missing, ok_reason) {
  if (!is.na(age_days) && age_days > threshold) {
    list(
      status = if (status_if_missing == "blocking") "blocking" else "warning",
      reason = "artifact_age_exceeds_warning_threshold"
    )
  } else {
    list(status = "informational", reason = ok_reason)
  }
}

.evaluate_attested_source <- function(source, artifact_paths, attestations, now) {
  rows <- attestations[attestations$source_id == source$source_id[[1]], , drop = FALSE]
  if (nrow(rows) == 0L) {
    return(list(status = source$status_if_missing[[1]], reason = "attestation_missing",
                observed = NA_character_, age = NA_real_))
  }
  attested_paths <- .collection_absolute_path(rows$artifact_path)
  for (path in artifact_paths) {
    hit <- which(attested_paths == normalizePath(path, winslash = "/", mustWork = FALSE))
    if (length(hit) == 0L) {
      return(list(status = source$status_if_missing[[1]], reason = "attestation_missing",
                  observed = NA_character_, age = NA_real_))
    }
    if (!identical(rows$sha256[[hit[[1]]]], .collection_sha256(path))) {
      return(list(status = "blocking", reason = "attestation_hash_mismatch",
                  observed = NA_character_, age = NA_real_))
    }
  }
  attested_at <- .parse_utc_time(rows$attested_at[[1]])
  age <- as.numeric(difftime(now, attested_at, units = "days"))
  labels <- unique(rows$release_label[!is.na(rows$release_label) & nzchar(rows$release_label)])
  outcome <- .age_status(age, source$age_warning_days[[1]], source$status_if_missing[[1]], "attested")
  c(outcome, list(observed = if (length(labels)) paste(labels, collapse = "; ") else "attested", age = age))
}

.evaluate_collected_source <- function(source, artifact_paths, now, require_release) {
  ages <- numeric()
  releases <- character()
  for (path in artifact_paths) {
    provenance <- read_artifact_provenance(path)
    if (is.null(provenance)) {
      if (require_release) {
        return(list(status = source$status_if_missing[[1]], reason = "provenance_missing",
                    observed = NA_character_, age = NA_real_))
      }
      next
    }
    if (!identical(as.character(provenance$sha256), .collection_sha256(path))) {
      return(list(status = "blocking", reason = "artifact_modified_after_collection",
                  observed = NA_character_, age = NA_real_))
    }
    release <- provenance$release_identifier
    if (require_release && (is.null(release) || is.na(release) || !nzchar(release))) {
      return(list(status = source$status_if_missing[[1]], reason = "release_identifier_missing",
                  observed = NA_character_, age = NA_real_))
    }
    if (!is.null(release) && !is.na(release)) releases <- c(releases, release)
    ages <- c(ages, as.numeric(difftime(now, .parse_utc_time(provenance$retrieved_at), units = "days")))
  }
  age <- if (length(ages)) max(ages) else NA_real_
  ok_reason <- if (require_release) "release_recorded" else "artifact_present"
  outcome <- .age_status(age, source$age_warning_days[[1]], source$status_if_missing[[1]], ok_reason)
  c(outcome, list(observed = if (length(releases)) paste(unique(releases), collapse = "; ") else NA_character_, age = age))
}

#' Evaluate registry sources and classify collection status.
#'
#' Rules: `manual_attestation` requires a hash-matching attestation record;
#' `release_identifier` requires a provenance sidecar with a release
#' identifier and an unchanged artifact hash; `end_date`/`end_date_plus_one`
#' require presence (and an unchanged hash when a sidecar exists). Ages come
#' from provenance or attestation records, never from file modification time.
#'
#' @param registry Validated source registry data frame.
#' @param collection_root Root directory containing source artifacts.
#' @param end_date Current reference year.
#' @param now Current time used for age calculations.
#' @param substitutions Named list from [collection_artifact_substitutions()].
#' @param attestations Data frame from [read_collection_attestations()].
#' @return A status data frame.
#' @export
evaluate_collection_status <- function(registry, collection_root, end_date,
                                       now = Sys.time(), run_id = NA_character_,
                                       parameters_hash = NA_character_,
                                       substitutions = list(),
                                       attestations = NULL) {
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
  if (is.null(attestations)) {
    attestations <- read_collection_attestations(NULL)
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
    expected_rule <- source$expected_vintage_rule[[1]]
    artifact_paths <- if (source$source_type[[1]] == "unavailable") {
      character()
    } else {
      resolve_collection_artifact_paths(relative_path, collection_root, end_date, substitutions)
    }
    artifact_path <- if (length(artifact_paths) == 0L) NA_character_ else paste(artifact_paths, collapse = "|")

    outcome <- if (source$source_type[[1]] == "unavailable") {
      list(status = "informational", reason = "source_unavailable_by_design",
           observed = NA_character_, age = NA_real_)
    } else if (length(artifact_paths) == 0L || !all(file.exists(artifact_paths))) {
      list(status = source$status_if_missing[[1]], reason = "artifact_missing",
           observed = NA_character_, age = NA_real_)
    } else if (identical(expected_rule, "manual_attestation")) {
      .evaluate_attested_source(source, artifact_paths, attestations, now)
    } else if (identical(expected_rule, "release_identifier")) {
      .evaluate_collected_source(source, artifact_paths, now, require_release = TRUE)
    } else {
      collected <- .evaluate_collected_source(source, artifact_paths, now, require_release = FALSE)
      collected$observed <- switch(
        expected_rule,
        end_date = as.character(end_date),
        end_date_plus_one = as.character(end_date + 1),
        collected$observed
      )
      collected
    }

    data.frame(
      source_id = source$source_id[[1]],
      dimension_id = source$dimension_id[[1]],
      source_type = source$source_type[[1]],
      status = outcome$status,
      reason = outcome$reason,
      artifact_path = artifact_path,
      expected_vintage_rule = expected_rule,
      observed_vintage = outcome$observed,
      age_days = outcome$age,
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
    if (is.null(run$status_sha256) || length(run$status_sha256) != 1L ||
        is.na(run$status_sha256) || !nzchar(run$status_sha256)) {
      stop("COLLECTION RUN MARKER HAS NO STATUS HASH.", call. = FALSE)
    }
    status_hash <- digest::digest(status_path, algo = "sha256", file = TRUE)
    if (!identical(status_hash, run$status_sha256)) {
      stop("COLLECTION STATUS HASH DOES NOT MATCH THE COMPLETED RUN.", call. = FALSE)
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

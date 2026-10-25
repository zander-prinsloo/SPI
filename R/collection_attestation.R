# =============================================================================
# Source attestation and artifact provenance
# =============================================================================
# Manual sources are accepted by the collection gate only when the technical
# lead has attested the exact file contents (hash-bound). Collected sources
# carry a provenance sidecar (`<artifact>.provenance.json`) recording the
# retrieval time, release identifier, and the artifact hash. Freshness always
# comes from these records, never from file modification times.
#
# Created: 2026-10-23
# =============================================================================

.attestation_columns <- c(
  "source_id", "artifact_path", "sha256", "release_label",
  "attested_by", "attested_at", "notes"
)

#' Path of the attestation record for the current vintage.
#'
#' @param params Pipeline parameters (uses `collection_dir`, `end_date`).
#' @return Character path.
#' @export
collection_attestation_path <- function(params) {
  file.path(
    params$collection_dir,
    sprintf("source_attestations_%d.csv", as.integer(params$end_date))
  )
}

#' Read the attestation record (empty when absent).
#'
#' @param path Attestation CSV path.
#' @return A data frame with the attestation columns.
#' @export
read_collection_attestations <- function(path) {
  empty <- as.data.frame(
    stats::setNames(replicate(length(.attestation_columns), character(), simplify = FALSE), .attestation_columns),
    stringsAsFactors = FALSE
  )
  if (is.null(path) || length(path) == 0L || !file.exists(path)) {
    return(empty)
  }
  record <- utils::read.csv(path, stringsAsFactors = FALSE, colClasses = "character")
  missing <- setdiff(.attestation_columns, names(record))
  if (length(missing) > 0L) {
    stop(
      "SOURCE ATTESTATION FILE SCHEMA MISMATCH: missing column(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  record <- record[, .attestation_columns, drop = FALSE]
  .validate_collection_attestations(record, path)
  record
}

.validate_collection_attestations <- function(record, path = "<in-memory>") {
  if (nrow(record) == 0L) {
    return(invisible(TRUE))
  }
  required <- c("source_id", "artifact_path", "sha256", "attested_by", "attested_at")
  blank <- vapply(record[required], function(column) {
    is.na(column) | !nzchar(trimws(as.character(column)))
  }, logical(nrow(record)))
  if (any(blank)) {
    bad <- unique(unlist(lapply(required, function(column) {
      which(blank[, column])
    }), use.names = FALSE))
    stop(
      "SOURCE ATTESTATION RECORD HAS BLANK REQUIRED FIELD(S) in ", path,
      " at row(s): ", paste(bad, collapse = ", "),
      call. = FALSE
    )
  }
  sha256 <- trimws(as.character(record$sha256))
  if (any(!grepl("^[0-9a-fA-F]{64}$", sha256))) {
    stop("SOURCE ATTESTATION RECORD HAS INVALID SHA-256 in ", path, call. = FALSE)
  }
  parsed <- vapply(record$attested_at, function(value) {
    !is.na(.parse_utc_time(value))
  }, logical(1))
  if (any(!parsed)) {
    stop("SOURCE ATTESTATION RECORD HAS INVALID attested_at in ", path, call. = FALSE)
  }
  keys <- paste(
    trimws(as.character(record$source_id)),
    .collection_absolute_path(trimws(as.character(record$artifact_path))),
    sep = "\r"
  )
  if (anyDuplicated(keys) > 0L) {
    stop(
      "SOURCE ATTESTATION RECORD HAS DUPLICATE source_id/artifact_path ROWS in ",
      path,
      call. = FALSE
    )
  }
  invisible(TRUE)
}

.collection_relative_path <- function(path) {
  root <- normalizePath(here::here(), winslash = "/", mustWork = FALSE)
  absolute <- normalizePath(path, winslash = "/", mustWork = FALSE)
  prefix <- paste0(root, "/")
  ifelse(startsWith(absolute, prefix), substring(absolute, nchar(prefix) + 1L), absolute)
}

.collection_absolute_path <- function(path) {
  absolute <- ifelse(
    grepl("^(/|[A-Za-z]:[/\\\\])", path),
    path,
    file.path(here::here(), path)
  )
  normalizePath(absolute, winslash = "/", mustWork = FALSE)
}

.collection_sha256 <- function(path) {
  vapply(path, function(p) digest::digest(p, algo = "sha256", file = TRUE), character(1), USE.NAMES = FALSE)
}

#' Attest the current contents of manual source artifacts.
#'
#' Records one row per artifact with its SHA-256 hash. Re-attesting a source
#' replaces its previous rows. Run after confirming the release is correct.
#'
#' @param source_ids Registry source IDs to attest.
#' @param attested_by Name of the person attesting.
#' @param release_label Optional release label (for example "UN IGME 2025").
#' @param notes Optional free-text note.
#' @param params Pipeline parameters.
#' @param registry Optional registry data frame (defaults to the configured one).
#' @return Invisibly returns the attestation file path.
#' @export
attest_collection_sources <- function(source_ids, attested_by,
                                      release_label = NA_character_,
                                      notes = NA_character_, params,
                                      registry = NULL) {
  if (missing(attested_by) || length(attested_by) != 1L || is.na(attested_by) || !nzchar(attested_by)) {
    stop("ATTESTATION REQUIRES A NON-BLANK attested_by.", call. = FALSE)
  }
  if (length(source_ids) == 0L || anyNA(source_ids) || anyDuplicated(source_ids) > 0L) {
    stop("ATTESTATION REQUIRES UNIQUE SOURCE IDS.", call. = FALSE)
  }
  if (is.null(registry)) {
    registry <- load_source_registry(params$source_registry_file)
  }
  unknown <- setdiff(source_ids, registry$source_id)
  if (length(unknown) > 0L) {
    stop("ATTESTATION FOR UNKNOWN SOURCE(S): ", paste(unknown, collapse = ", "), call. = FALSE)
  }

  substitutions <- collection_artifact_substitutions(params)
  attested_at <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  rows <- lapply(source_ids, function(source_id) {
    source <- registry[registry$source_id == source_id, , drop = FALSE]
    relative <- source$normalized_path[[1]]
    if (is.na(relative) || !nzchar(relative)) relative <- source$input_path[[1]]
    paths <- resolve_collection_artifact_paths(relative, params$raw_dir, params$end_date, substitutions)
    missing <- paths[!file.exists(paths)]
    if (length(paths) == 0L || length(missing) > 0L) {
      stop(
        sprintf("ATTESTATION ARTIFACT NOT FOUND for '%s': %s", source_id, paste(missing, collapse = ", ")),
        call. = FALSE
      )
    }
    data.frame(
      source_id = source_id,
      artifact_path = .collection_relative_path(paths),
      sha256 = .collection_sha256(paths),
      release_label = as.character(release_label),
      attested_by = attested_by,
      attested_at = attested_at,
      notes = as.character(notes),
      stringsAsFactors = FALSE
    )
  })

  path <- collection_attestation_path(params)
  existing <- read_collection_attestations(path)
  combined <- rbind(existing[!existing$source_id %in% source_ids, , drop = FALSE], do.call(rbind, rows))
  .validate_collection_attestations(combined, path)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(combined, path, row.names = FALSE, na = "")
  invisible(path)
}

#' Path of an artifact's provenance sidecar.
#'
#' @param path Artifact path.
#' @return Character path of `<artifact>.provenance.json`.
#' @export
artifact_provenance_path <- function(path) {
  paste0(path, ".provenance.json")
}

#' Write a provenance sidecar for a collected artifact.
#'
#' @param path Normalized artifact path (must exist).
#' @param source_id Registry source ID.
#' @param retrieved_at Retrieval timestamp of the underlying source data.
#' @param release_identifier Source release identifier, when known.
#' @param raw_path Path of the cached raw response, when any.
#' @param extra Optional named list of additional fields.
#' @return Invisibly returns the sidecar path.
#' @export
write_artifact_provenance <- function(path, source_id, retrieved_at,
                                      release_identifier = NA_character_,
                                      raw_path = NA_character_, extra = list()) {
  if (!file.exists(path)) {
    stop("PROVENANCE TARGET NOT FOUND: ", path, call. = FALSE)
  }
  record <- c(
    list(
      source_id = source_id,
      artifact_path = .collection_relative_path(path),
      sha256 = .collection_sha256(path),
      retrieved_at = as.character(retrieved_at),
      release_identifier = as.character(release_identifier),
      raw_path = if (is.na(raw_path)) NA_character_ else .collection_relative_path(raw_path)
    ),
    extra
  )
  sidecar <- artifact_provenance_path(path)
  jsonlite::write_json(record, sidecar, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null")
  invisible(sidecar)
}

#' Read an artifact's provenance sidecar.
#'
#' @param path Artifact path.
#' @return The provenance list, or NULL when no sidecar exists.
#' @export
read_artifact_provenance <- function(path) {
  sidecar <- artifact_provenance_path(path)
  if (!file.exists(sidecar)) {
    return(NULL)
  }
  jsonlite::read_json(sidecar, simplifyVector = TRUE)
}

.parse_utc_time <- function(value) {
  if (is.null(value) || length(value) == 0L || is.na(value) || !nzchar(value)) {
    return(as.POSIXct(NA))
  }
  as.POSIXct(sub(" UTC$", "", value), tz = "UTC", format = "%Y-%m-%d %H:%M:%S")
}

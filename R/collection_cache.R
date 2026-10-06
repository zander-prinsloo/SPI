# =============================================================================
# Collection cache helpers
# =============================================================================
# Created: 2026-10-05
# =============================================================================

validate_cached_hash <- function(raw_path, record) {
  if (is.null(record$sha256) || !file.exists(raw_path)) {
    stop("COLLECTION CACHE PROVENANCE INCOMPLETE: missing hash or raw artifact.", call. = FALSE)
  }
  raw_bytes <- readBin(raw_path, what = "raw", n = file.info(raw_path)$size)
  actual <- digest::digest(raw_bytes, algo = "sha256", serialize = FALSE)
  if (!identical(as.character(record$sha256), actual)) {
    stop("COLLECTION CACHE CHECKSUM MISMATCH: ", raw_path, call. = FALSE)
  }
  invisible(TRUE)
}

#' Build a deterministic cache key for a source request.
#'
#' @param source_id Character source identifier.
#' @param request Named list describing endpoint and query parameters.
#' @param vintage Source vintage or requested year range.
#' @param collector_version Collector implementation/schema version.
#' @return A SHA-256 cache key.
#' @export
collection_cache_key <- function(source_id, request, vintage, collector_version) {
  identity <- list(
    source_id = source_id,
    request = request,
    vintage = vintage,
    collector_version = collector_version
  )
  digest::digest(
    jsonlite::toJSON(identity, auto_unbox = TRUE, null = "null"),
    algo = "sha256",
    serialize = FALSE
  )
}

#' Collect a raw response with a deterministic on-disk cache.
#'
#' @param cache_dir Root cache directory.
#' @param source_id Character source identifier.
#' @param request Named list describing endpoint and query parameters.
#' @param vintage Source vintage or requested year range.
#' @param collector_version Collector implementation/schema version.
#' @param fetch Zero-argument function returning raw bytes or text.
#' @return Provenance record with `cached` flag.
#' @export
collect_cached_raw <- function(cache_dir, source_id, request, vintage,
                               collector_version, fetch, max_age_days = Inf) {
  key <- collection_cache_key(source_id, request, vintage, collector_version)
  safe_source_id <- gsub("[^A-Za-z0-9_.-]", "_", source_id)
  raw_path <- file.path(cache_dir, paste0(safe_source_id, "-", key, ".raw"))
  provenance_path <- paste0(raw_path, ".json")

  cache_age <- if (file.exists(raw_path)) {
    as.numeric(difftime(Sys.time(), file.info(raw_path)$mtime, units = "days"))
  } else {
    Inf
  }
  if (file.exists(raw_path) && file.exists(provenance_path) && cache_age <= max_age_days) {
    record <- jsonlite::read_json(provenance_path, simplifyVector = TRUE)
    validate_cached_hash(raw_path, record)
    record$cached <- TRUE
    return(record)
  }

  payload <- fetch()
  record <- write_raw_capture(
    raw_path,
    payload,
    metadata = list(
      source_id = source_id,
      request = request,
      vintage = vintage,
      collector_version = collector_version,
      payload_type = "serialized_structured_response",
      retrieved_at = format(Sys.time(), tz = "UTC", usetz = TRUE)
    )
  )
  record$cached <- FALSE
  record
}

#' Collect a serializable table or vector with the shared raw cache contract.
#'
#' @param cache_dir Root cache directory.
#' @param source_id Character source identifier.
#' @param request Named request identity.
#' @param vintage Source vintage.
#' @param collector_version Collector implementation version.
#' @param fetch Zero-argument function returning a serializable object.
#' @return Provenance record with the object in `table`.
#' @export
collect_cached_table <- function(cache_dir, source_id, request, vintage,
                                 collector_version, fetch, max_age_days = Inf) {
  key <- collection_cache_key(source_id, request, vintage, collector_version)
  safe_source_id <- gsub("[^A-Za-z0-9_.-]", "_", source_id)
  raw_path <- file.path(cache_dir, paste0(safe_source_id, "-", key, ".rds"))
  provenance_path <- paste0(raw_path, ".json")

  cache_age <- if (file.exists(raw_path)) {
    as.numeric(difftime(Sys.time(), file.info(raw_path)$mtime, units = "days"))
  } else {
    Inf
  }
  if (file.exists(raw_path) && file.exists(provenance_path) && cache_age <= max_age_days) {
    record <- jsonlite::read_json(provenance_path, simplifyVector = TRUE)
    validate_cached_hash(raw_path, record)
    record$table <- readRDS(raw_path)
    record$cached <- TRUE
    return(record)
  }

  table <- fetch()
  raw_bytes <- serialize(table, NULL, version = 3)
  record <- write_raw_capture(
    raw_path,
    raw_bytes,
    metadata = list(
      source_id = source_id,
      request = request,
      vintage = vintage,
      collector_version = collector_version,
      retrieved_at = format(Sys.time(), tz = "UTC", usetz = TRUE)
    )
  )
  record$table <- table
  record$cached <- FALSE
  record
}

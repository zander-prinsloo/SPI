# =============================================================================
# Collection raw artifact I/O
# =============================================================================
# Created: 2026-10-05
# =============================================================================

#' Coerce a response payload to raw bytes.
#'
#' @param payload Raw bytes or character response content.
#' @return A raw vector.
#' @export
as_raw_payload <- function(payload) {
  if (is.raw(payload)) {
    return(payload)
  }
  if (is.character(payload) && length(payload) == 1L) {
    return(charToRaw(payload))
  }
  stop("COLLECTION PAYLOAD MUST BE RAW OR A SINGLE CHARACTER STRING.", call. = FALSE)
}

#' Preserve raw response bytes and write their provenance record.
#'
#' @param raw_path Character destination for the raw payload.
#' @param payload Raw bytes or character response content.
#' @param metadata Named list of source metadata.
#' @return A provenance record with artifact paths and hash.
#' @export
write_raw_capture <- function(raw_path, payload, metadata = list()) {
  raw_bytes <- as_raw_payload(payload)
  dir.create(dirname(raw_path), recursive = TRUE, showWarnings = FALSE)

  temporary_path <- tempfile(pattern = ".collection-raw-", tmpdir = dirname(raw_path))
  on.exit(unlink(temporary_path), add = TRUE)
  writeBin(raw_bytes, temporary_path)
  if (file.exists(raw_path)) {
    unlink(raw_path)
  }
  if (!file.rename(temporary_path, raw_path)) {
    stop(sprintf("COLLECTION RAW WRITE FAILED: %s", raw_path), call. = FALSE)
  }

  record <- c(
    metadata,
    list(
      raw_path = normalizePath(raw_path, winslash = "/", mustWork = FALSE),
      bytes = length(raw_bytes),
      sha256 = digest::digest(raw_bytes, algo = "sha256", serialize = FALSE)
    )
  )
  provenance_path <- paste0(raw_path, ".json")
  record$provenance_path <- normalizePath(provenance_path, winslash = "/", mustWork = FALSE)
  write_provenance_record(record, provenance_path)
  record
}

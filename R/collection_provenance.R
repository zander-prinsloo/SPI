# =============================================================================
# Collection provenance helpers
# =============================================================================
# Created: 2026-10-05
# =============================================================================

#' Write a JSON provenance record.
#'
#' @param record Named list of provenance fields.
#' @param path Character destination path.
#' @return Invisibly returns the path.
#' @export
write_provenance_record <- function(record, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(record, path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  invisible(path)
}

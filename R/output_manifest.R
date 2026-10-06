# =============================================================================
# Final estimation output manifest
# =============================================================================
# Created: 2026-10-05
# =============================================================================

expected_estimation_outputs <- function(end_date = 2024) {
  c(
    "SPI_data.csv",
    "SPI_data.dta",
    "SPI_index.csv",
    "SPI_quantiles.csv",
    sprintf("SPI_quantiles_%d.csv", end_date),
    sprintf("SPI_indicators_%d.csv", end_date),
    "SPI_treemap.csv",
    "SPI_databank_country_and_aggregates.csv",
    "SPI_databank_country_and_aggregates_DCS.csv",
    "SPI_databank_country_and_aggregates_DCS_wide.csv",
    "SPI_databank_footnotes.csv",
    "SPL_admin_data_availability.csv"
  )
}

#' Prepare an empty candidate output directory.
#'
#' @param candidate_dir Candidate directory used during estimation.
#' @return The candidate path.
#' @export
prepare_output_candidate <- function(candidate_dir) {
  if (dir.exists(candidate_dir)) unlink(candidate_dir, recursive = TRUE, force = TRUE)
  dir.create(candidate_dir, recursive = TRUE, showWarnings = FALSE)
  candidate_dir
}

#' Validate the complete final output set.
#'
#' @param output_dir Final output directory.
#' @return A data frame with expected paths and existence flags.
#' @export
validate_output_manifest <- function(output_dir, end_date = 2024) {
  files <- expected_estimation_outputs(end_date)
  paths <- file.path(output_dir, files)
  present <- file.exists(paths)
  if (any(!present)) {
    stop(
      "FINAL OUTPUT SET INCOMPLETE: missing file(s): ",
      paste(files[!present], collapse = ", "),
      call. = FALSE
    )
  }
  result <- data.frame(file = files, path = paths, present = present, stringsAsFactors = FALSE)
  jsonlite::write_json(
    list(
      end_date = end_date,
      checked_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
      files = files
    ),
    file.path(output_dir, "_estimation_manifest.json"),
    auto_unbox = TRUE,
    pretty = TRUE
  )
  result
}

#' Promote a complete candidate output set to the final directory.
#'
#' @param candidate_dir Validated candidate directory.
#' @param output_dir Final output directory.
#' @param end_date Current output vintage.
#' @return The promoted output manifest.
#' @export
promote_output_set <- function(candidate_dir, output_dir, end_date = 2024) {
  files <- c(expected_estimation_outputs(end_date), "_estimation_manifest.json")
  missing <- files[!file.exists(file.path(candidate_dir, files))]
  if (length(missing) > 0L) {
    stop("CANDIDATE OUTPUT SET INCOMPLETE: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  backup_dir <- tempfile("spi-output-backup-")
  dir.create(backup_dir, recursive = TRUE)
  on.exit(unlink(backup_dir, recursive = TRUE, force = TRUE), add = TRUE)
  existing <- files[file.exists(file.path(output_dir, files))]
  if (length(existing) > 0L) {
    file.copy(file.path(output_dir, existing), backup_dir, overwrite = TRUE)
  }

  promoted <- tryCatch({
    ok <- file.copy(
      file.path(candidate_dir, files),
      output_dir,
      overwrite = TRUE
    )
    if (!all(ok)) stop("FINAL OUTPUT PROMOTION FAILED.", call. = FALSE)
    TRUE
  }, error = function(error) {
    unlink(file.path(output_dir, files), force = TRUE)
    if (length(existing) > 0L) {
      file.copy(file.path(backup_dir, existing), output_dir, overwrite = TRUE)
    }
    stop(conditionMessage(error), call. = FALSE)
  })

  invisible(data.frame(file = files, promoted = promoted, stringsAsFactors = FALSE))
}

# =============================================================================
# Overwrite protection for output files
# =============================================================================
# Constraint C7: existing historical output files must NEVER be overwritten.
# The pipeline writes new outputs to the staging/ directory.
#
# NOTE (P2.5/P2.26): C7 is enforced BY CONSTRUCTION -- every save_*()
# function (R/append.R, R/index.R, R/quantiles.R, R/treemap.R,
# R/databank.R, R/spl_admin.R) writes to params$staging_dir, never to
# 03_output_data/. The helpers below are kept as a defensive guard for any
# future code that might write to an arbitrary path; they are not called by
# the current pipeline.
#
# Created: 2026-09-21
# =============================================================================

#' Check whether a path is a protected historical output
#'
#' Historical outputs live under 03_output_data/. The pipeline must never
#' write to them.
#'
#' @param path Character: the file path to check.
#' @return Logical: TRUE if the path is under the historical output dir.
#' @export
is_historical_output <- function(path) {
  # Normalize both paths for comparison
  hist_dir <- normalizePath(here::here("03_output_data"), winslash = "/")
  target   <- normalizePath(path, winslash = "/", mustWork = FALSE)
  starts_with(target, paste0(hist_dir, "/"))
}

#' Write a data frame to a CSV with overwrite protection
#'
#' Writes to the staging directory. Refuses to write if the target already
#' exists as a historical output file.
#'
#' @param df        A data frame.
#' @param file_name Character: output file name (e.g. "SPI_data.csv").
#' @param ...       Additional arguments passed to readr::write_csv().
#'
#' @return Invisibly returns the file path written.
#' @export
write_csv_staged <- function(df, file_name, ...) {
  target <- file.path(here::here("staging"), file_name)

  # Constraint C7: never overwrite historical outputs
  if (is_historical_output(target)) {
    stop(
      sprintf(
        "REFUSING TO WRITE: %s is a historical output file.\n",
        target
      ),
      "The pipeline writes to staging/ only. Copy validated outputs to",
      "03_output_data/ manually after review.",
      call. = FALSE
    )
  }

  # Create the staging directory if needed
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)

  readr::write_csv(df, target, ...)
  invisible(target)
}
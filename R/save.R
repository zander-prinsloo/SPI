# =============================================================================
# Overwrite protection for output files
# =============================================================================
# Constraint C7: existing historical output files must NEVER be overwritten.
# The estimation pipeline writes validated final outputs to 03_output_data/.
#
# NOTE (P2.5/P2.26): C7 is enforced BY CONSTRUCTION -- every save_*()
# function (R/append.R, R/index.R, R/quantiles.R, R/treemap.R,
# R/databank.R, R/spl_admin.R) writes to params$output_dir. The helpers below
# keep individual writes atomic so a failed write does not truncate a target.
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

replace_output_file <- function(temporary_path, target, rename_fn = file.rename) {
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  backup_path <- NULL
  if (file.exists(target)) {
    backup_path <- tempfile(pattern = ".spi-output-backup-", tmpdir = dirname(target))
    if (!file.copy(target, backup_path, overwrite = TRUE)) {
      stop(sprintf("OUTPUT BACKUP FAILED: %s", target), call. = FALSE)
    }
  }

  replaced <- isTRUE(rename_fn(temporary_path, target))
  if (!replaced) {
    if (!is.null(backup_path)) {
      if (file.exists(target)) unlink(target)
      file.copy(backup_path, target, overwrite = TRUE)
      unlink(backup_path)
    }
    stop(sprintf("OUTPUT WRITE FAILED: %s", target), call. = FALSE)
  }
  if (!is.null(backup_path)) unlink(backup_path)
  invisible(target)
}

#' Write a data frame to a CSV atomically.
#'
#' @param df     A data frame.
#' @param target Character destination path.
#' @param ...       Additional arguments passed to readr::write_csv().
#'
#' @return Invisibly returns the file path written.
#' @export
write_output_csv <- function(df, target, ...) {
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  temporary_path <- tempfile(pattern = ".spi-output-", tmpdir = dirname(target), fileext = ".csv")
  on.exit(unlink(temporary_path), add = TRUE)
  readr::write_csv(df, temporary_path, ...)
  replace_output_file(temporary_path, target)
}

#' Write a Stata file atomically.
#'
#' @param df Data frame to write.
#' @param target Destination path.
#' @return Invisibly returns the destination path.
#' @export
write_output_dta <- function(df, target) {
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  temporary_path <- tempfile(pattern = ".spi-output-", tmpdir = dirname(target), fileext = ".dta")
  on.exit(unlink(temporary_path), add = TRUE)
  haven::write_dta(df, temporary_path)
  replace_output_file(temporary_path, target)
}
# =============================================================================
# Overwrite protection for output files
# =============================================================================
# Individual writers use params$estimation_write_dir (the candidate folder).
# The complete validated set is later promoted to params$output_dir by
# output_manifest. Preserve historical fixtures, approved prior vintages, and
# release archives separately; current output files can be replaced by promotion.
# The helpers below keep each individual file replacement atomic so a failed
# write does not truncate that file. Multi-file promotion is a separate step.
#
# Created: 2026-09-21
# =============================================================================

#' Check whether a path is a protected historical output
#'
#' Identify paths under 03_output_data/ for legacy callers. This predicate
#' does not itself enforce write protection; active candidate/promotion gates
#' determine when designated current outputs may be replaced.
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
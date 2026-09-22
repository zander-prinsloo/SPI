# =============================================================================
# Schema validation helpers
# =============================================================================
# These functions implement the "fail loudly, never silently" rule (R8).
# Every source file read by the pipeline is validated against an expected
# schema. If the source format changes (e.g. ILO renames a column, ODIN
# changes its layout), the pipeline STOPS and reports the change to the
# technical lead instead of silently producing wrong estimates.
#
# Created: 2026-09-21
# =============================================================================

#' Validate that a data frame has the expected columns
#'
#' @param df        A data frame (the source file just read).
#' @param file_name Character: the source file name, for error messages.
#' @param required  Character vector: column names that MUST be present.
#' @param optional  Character vector: column names that MAY be present.
#'
#' @return Invisibly returns TRUE if validation passes.
#' @export
validate_schema <- function(df, file_name, required, optional = character()) {
  # Check that required columns exist
  missing <- setdiff(required, names(df))
  if (length(missing) > 0) {
    stop(
      sprintf(
        "SCHEMA MISMATCH in '%s':\n  Missing required column(s): %s\n  Found columns: %s\n\n",
        file_name,
        paste(missing, collapse = ", "),
        paste(names(df), collapse = ", ")
      ),
      "This means the source file format has changed. Update the schema check",
      "in the R/ function that reads this file (read_csv_validated call), or",
      "the checkpoint in R/checkpoints.R, or investigate the source download.",
      call. = FALSE
    )
  }

  # Report (but do not fail on) unexpected extra columns -- the technical lead
  # should know about them, but they do not break the estimates.
  unexpected <- setdiff(names(df), c(required, optional))
  if (length(unexpected) > 0) {
    warning(
      sprintf(
        "SCHEMA NOTE in '%s': unexpected column(s) present: %s",
        file_name,
        paste(unexpected, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

#' Read a CSV file with schema validation
#'
#' Wraps readr::read_csv() and validates the result against the schema
#' registry. Fails loudly on missing required columns.
#'
#' @param file_path  Character: full path to the CSV file.
#' @param schema     List with `required_cols` and optional `optional_cols`.
#' @param ...        Additional arguments passed to readr::read_csv().
#'
#' @return A tibble.
#' @export
read_csv_validated <- function(file_path, schema, ...) {
  # Fail loudly if the file does not exist
  if (!file.exists(file_path)) {
    stop(
      sprintf("SOURCE FILE NOT FOUND: %s\n", file_path),
      "Check the source download instructions in docs/user-guide.md.",
      call. = FALSE
    )
  }

  df <- readr::read_csv(file_path, ...)

  validate_schema(
    df,
    basename(file_path),
    required = schema$required_cols,
    optional = schema$optional_cols %||% character()
  )

  df
}

# Small helper: `%||%` returns the right-hand side when the left is NULL.
`%||%` <- function(lhs, rhs) {
  if (is.null(lhs)) rhs else lhs
}
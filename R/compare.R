# =============================================================================
# Tolerance-based comparison utilities
# =============================================================================
# These functions compare the new pipeline's outputs against the 202511
# vintage fixtures. They implement the replication gate (R1): outputs must
# match within a 1e-9 relative tolerance, and any real difference must fail
# loudly with a precise report.
#
# Design notes:
#   - Relative tolerance (1e-9) allows floating-point noise from different
#     arithmetic orders while catching real differences.
#   - Column order differences are reported as notes, not failures (the
#     values are what matter for replication).
#   - Type differences, NA-vs-0 differences, and row-set differences are
#     reported as failures.
#
# Created: 2026-09-21
# =============================================================================

# The pipe operator (%>%) comes from magrittr (loaded via tidyverse in the
# original Rmds). We import it explicitly so this file is self-contained.
`%>%` <- magrittr::`%>%`

#' Compare two data frames with a relative tolerance
#'
#' Compares two data frames column-by-column. Returns a list with:
#'   - `identical`: TRUE if the frames match within tolerance
#'   - `differences`: character vector of human-readable difference reports
#'   - `notes`: character vector of non-fatal observations (e.g. column order)
#'
#' @param df1       A data frame (the new pipeline output).
#' @param df2       A data frame (the vintage fixture).
#' @param tolerance Numeric: relative tolerance (default 1e-9).
#' @param key_cols  Character vector: columns that identify rows (e.g.
#'                  c("iso3c", "date")) used to align rows for comparison.
#'
#' @return A list with `identical`, `differences`, and `notes`.
#' @export
compare_frames <- function(df1, df2, tolerance = 1e-9, key_cols = NULL) {
  differences <- character()
  notes <- character()

  # --- Column set check ------------------------------------------------------
  # Report missing/extra columns (fail loudly, R8)
  missing_cols <- setdiff(names(df2), names(df1))
  extra_cols   <- setdiff(names(df1), names(df2))
  if (length(missing_cols) > 0) {
    differences <- c(differences, sprintf(
      "Missing column(s) in new output: %s", paste(missing_cols, collapse = ", ")
    ))
  }
  if (length(extra_cols) > 0) {
    differences <- c(differences, sprintf(
      "Extra column(s) in new output: %s", paste(extra_cols, collapse = ", ")
    ))
  }

  # --- Column order note -----------------------------------------------------
  if (!identical(names(df1), names(df2))) {
    notes <- c(notes, sprintf(
      "Column order differs: new = [%s], vintage = [%s]",
      paste(names(df1), collapse = ", "),
      paste(names(df2), collapse = ", ")
    ))
  }

  # --- Row count check -------------------------------------------------------
  if (nrow(df1) != nrow(df2)) {
    differences <- c(differences, sprintf(
      "Row count differs: new = %d, vintage = %d", nrow(df1), nrow(df2)
    ))
  }

  # --- Align rows by key columns if provided ---------------------------------
  if (!is.null(key_cols) && all(key_cols %in% names(df1)) && all(key_cols %in% names(df2))) {
    df1 <- df1 %>% dplyr::arrange(dplyr::across(dplyr::all_of(key_cols)))
    df2 <- df2 %>% dplyr::arrange(dplyr::across(dplyr::all_of(key_cols)))
  }

  # Helper: describe a row by its key values (for precise error reports)
  row_label <- function(df, idx) {
    if (!is.null(key_cols) && all(key_cols %in% names(df))) {
      keys <- sapply(key_cols, function(k) as.character(df[[k]][idx]))
      paste(paste(key_cols, keys, sep = "="), collapse = ", ")
    } else {
      paste0("row ", idx)
    }
  }

  # --- Compare common columns ------------------------------------------------
  common_cols <- intersect(names(df1), names(df2))

  for (col in common_cols) {
    v1 <- df1[[col]]
    v2 <- df2[[col]]

    # Type check (fail loudly)
    if (typeof(v1) != typeof(v2)) {
      differences <- c(differences, sprintf(
        "Column '%s': type differs (new = %s, vintage = %s)",
        col, typeof(v1), typeof(v2)
      ))
      next
    }

    # Numeric comparison with relative tolerance
    if (is.numeric(v1) && is.numeric(v2)) {
      # Compare element-wise, treating NA as equal to NA
      na_mismatch <- xor(is.na(v1), is.na(v2))
      if (any(na_mismatch)) {
        idx <- which(na_mismatch)[1]
        differences <- c(differences, sprintf(
          "Column '%s' %s: NA vs value (new = %s, vintage = %s)",
          col, row_label(df1, idx), v1[idx], v2[idx]
        ))
      }
      # Relative difference check on non-NA pairs
      valid <- !is.na(v1) & !is.na(v2)
      if (any(valid)) {
        rel_diff <- abs(v1[valid] - v2[valid]) / pmax(abs(v2[valid]), .Machine$double.eps)
        bad <- which(rel_diff > tolerance)
        if (length(bad) > 0) {
          idx <- bad[1]
          differences <- c(differences, sprintf(
            "Column '%s' %s: value differs (new = %.10g, vintage = %.10g, rel diff = %.3g)",
            col, row_label(df1, which(valid)[idx]), v1[valid][idx], v2[valid][idx], rel_diff[idx]
          ))
        }
      }
    } else {
      # Non-numeric: exact comparison
      mismatch <- !identical(v1, v2)
      if (mismatch) {
        idx <- which(v1 != v2 | (is.na(v1) != is.na(v2)))
        if (length(idx) > 0) {
          idx <- idx[1]
          differences <- c(differences, sprintf(
            "Column '%s' %s: value differs (new = %s, vintage = %s)",
            col, row_label(df1, idx), v1[idx], v2[idx]
          ))
        } else {
          # identical() is stricter than element-wise equality (e.g. factor
          # vs character); report the type-level difference.
          differences <- c(differences, sprintf(
            "Column '%s': values differ (identical() FALSE, no element-wise mismatch found)",
            col
          ))
        }
      }
    }
  }

  list(
    identical = length(differences) == 0,
    differences = differences,
    notes = notes
  )
}

#' Assert that two data frames match within tolerance
#'
#' Wrapper around compare_frames() that FAILS LOUDLY (stops) when the frames
#' differ. Used by the stage-compare tests.
#'
#' @param df1       A data frame (the new pipeline output).
#' @param df2       A data frame (the vintage fixture).
#' @param label     Character: a label for the comparison (e.g. "SPI_data.csv").
#' @param tolerance Numeric: relative tolerance (default 1e-9).
#' @param key_cols  Character vector: key columns for row alignment.
#'
#' @return Invisibly TRUE if the frames match.
#' @export
expect_frames_match <- function(df1, df2, label = "output", tolerance = 1e-9, key_cols = NULL) {
  result <- compare_frames(df1, df2, tolerance = tolerance, key_cols = key_cols)

  if (!result$identical) {
    stop(
      sprintf("COMPARISON FAILED for '%s':\n  %s\n",
        label,
        paste(result$differences, collapse = "\n  ")
      ),
      call. = FALSE
    )
  }

  invisible(TRUE)
}
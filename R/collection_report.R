# =============================================================================
# Collection status reports
# =============================================================================
# Created: 2026-10-05
# =============================================================================

#' Write machine-readable and human-readable collection status reports.
#'
#' @param status A data frame returned by evaluate_collection_status().
#' @param csv_path CSV destination.
#' @param markdown_path Markdown destination.
#' @param warnings Optional data frame with `source_id` and `message` columns.
#' @return Invisibly returns both paths.
#' @export
write_collection_status_report <- function(status, csv_path, markdown_path,
                                           warnings = NULL) {
  required <- c("source_id", "status", "reason", "analyst_action")
  missing <- setdiff(required, names(status))
  if (length(missing) > 0L) {
    stop(
      "COLLECTION REPORT STATUS MISMATCH: missing column(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  dir.create(dirname(csv_path), recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(markdown_path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(status, csv_path)

  status_counts <- table(status$status)
  lines <- c(
    "# Collection Status Report",
    "",
    paste0("Generated: ", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    "",
    "| Source | Dimension | Type | Status | Reason | Analyst action |",
    "|---|---|---|---|---|---|"
  )
  rows <- apply(status, 1, function(row) {
    paste0(
      "| ", row[["source_id"]],
      " | ", row[["dimension_id"]],
      " | ", row[["source_type"]],
      " | ", row[["status"]],
      " | ", row[["reason"]],
      " | ", row[["analyst_action"]],
      " |"
    )
  })
  lines <- c(lines, rows, "", "## Counts", "")
  lines <- c(lines, paste0("- `", names(status_counts), "`: ", as.integer(status_counts)))
  if (!is.null(warnings) && nrow(warnings) > 0L) {
    required_warnings <- c("source_id", "message")
    missing_warnings <- setdiff(required_warnings, names(warnings))
    if (length(missing_warnings) > 0L) {
      stop(
        "COLLECTION REPORT WARNINGS MISMATCH: missing column(s): ",
        paste(missing_warnings, collapse = ", "),
        call. = FALSE
      )
    }
    warning_rows <- apply(warnings, 1, function(row) {
      paste0("| ", row[["source_id"]], " | ", row[["message"]], " |")
    })
    lines <- c(
      lines,
      "",
      "## Collection warnings",
      "",
      "| Source | Warning |",
      "|---|---|",
      warning_rows
    )
  }
  writeLines(lines, markdown_path)

  invisible(c(csv = csv_path, markdown = markdown_path))
}

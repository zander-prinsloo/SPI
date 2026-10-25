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
    "SPL_admin_data_availability.csv",
    sprintf("vintage_diff_%d.csv", end_date),
    sprintf("vintage_diff_%d.md", end_date),
    sprintf("revision_summary_%d.md", end_date),
    sprintf("revision_indicators_%d.csv", end_date),
    sprintf("revision_index_%d.csv", end_date),
    sprintf("revision_new_year_%d.csv", end_date)
  )
}

#' Ensure the candidate output directory exists without deleting its contents.
#'
#' Each writer target owns and overwrites its own files; `{targets}` reruns a
#' writer when its file is missing or changed. Wiping the folder on every run
#' would delete the files of up-to-date writers and break partial rebuilds.
#'
#' @param candidate_dir Candidate directory used during estimation.
#' @return The candidate path.
#' @export
ensure_output_candidate <- function(candidate_dir) {
  dir.create(candidate_dir, recursive = TRUE, showWarnings = FALSE)
  candidate_dir
}

# Output columns that depend on ODIN: SPI.D2.2 (online access), SPI.D4.3
# (geospatial), their dimension indices, Pillars 2 and 4, and the overall
# index (ranks, quantiles and databank rows derive from these).
odin_dependent_column_patterns <- c(
  "^(SPI|RAW)[.]D2[.]2[.]",
  "^(SPI|RAW)[.]D4[.]3[.]",
  "^SPI[.]DIM2[.]2[.]",
  "^SPI[.]DIM4[.]3[.]",
  "^SPI[.]INDEX[.]PIL2$",
  "^SPI[.]INDEX[.]PIL4$",
  "^SPI[.]INDEX$"
)

odin_marker_file <- "PROVISIONAL_ODIN.md"

#' Read and verify the approved official ODIN release record.
#'
#' An official status is not a label attached to an unchanged provisional
#' file. The record names the source release, the exact files approved for it,
#' their current hashes and the hashes they supersede.
#'
#' @param path Release-record JSON path.
#' @param odin_files ODIN files consumed by estimation.
#' @return The validated release record.
#' @export
read_odin_release_record <- function(path, odin_files) {
  if (!file.exists(path)) {
    stop(
      "OFFICIAL ODIN RELEASE RECORD NOT FOUND: ", path,
      ". Record the official release and its file hashes before setting odin_status to 'official'.",
      call. = FALSE
    )
  }
  record <- jsonlite::read_json(path, simplifyVector = FALSE)
  required <- c("schema_version", "source_url", "release_label", "released_at", "approved_by", "files")
  missing <- setdiff(required, names(record))
  if (length(missing) > 0L || !identical(record$schema_version, "spi-odin-release-v1")) {
    stop("OFFICIAL ODIN RELEASE RECORD SCHEMA INVALID: ", path, call. = FALSE)
  }
  text_fields <- c("source_url", "release_label", "approved_by")
  if (any(!vapply(record[text_fields], function(value) {
    length(value) == 1L && !is.na(value) && nzchar(trimws(value))
  }, logical(1)))) {
    stop("OFFICIAL ODIN RELEASE RECORD HAS BLANK METADATA: ", path, call. = FALSE)
  }
  if (length(record$released_at) != 1L ||
      is.na(as.POSIXct(record$released_at, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))) {
    stop("OFFICIAL ODIN RELEASE RECORD HAS INVALID released_at: ", path, call. = FALSE)
  }
  if (!is.list(record$files) || length(record$files) != length(odin_files)) {
    stop("OFFICIAL ODIN RELEASE RECORD FILE COUNT MISMATCH: ", path, call. = FALSE)
  }
  names_in_record <- vapply(record$files, function(entry) as.character(entry$file), character(1))
  expected_names <- basename(odin_files)
  if (anyNA(names_in_record) || anyDuplicated(names_in_record) > 0L ||
      !setequal(names_in_record, expected_names)) {
    stop("OFFICIAL ODIN RELEASE RECORD FILE SET MISMATCH: ", path, call. = FALSE)
  }
  for (entry in record$files) {
    current_path <- odin_files[match(entry$file, expected_names)]
    hashes <- c(entry$sha256, entry$provisional_sha256)
    if (length(hashes) != 2L || any(!grepl("^[0-9a-fA-F]{64}$", hashes))) {
      stop("OFFICIAL ODIN RELEASE RECORD HASH INVALID for ", entry$file, call. = FALSE)
    }
    if (identical(tolower(as.character(entry$sha256)), tolower(as.character(entry$provisional_sha256)))) {
      stop(
        "OFFICIAL ODIN RELEASE RECORD DOES NOT REPLACE THE PROVISIONAL HASH for ",
        entry$file,
        call. = FALSE
      )
    }
    actual <- digest::digest(current_path, algo = "sha256", file = TRUE)
    if (!identical(tolower(as.character(entry$sha256)), tolower(actual))) {
      stop("OFFICIAL ODIN RELEASE RECORD HASH MISMATCH for ", entry$file, call. = FALSE)
    }
  }
  record
}

output_artifact_key_columns <- function(file) {
  if (identical(file, "SPI_databank_country_and_aggregates.csv")) {
    return(c("iso3c", "date", "source_id"))
  }
  if (identical(file, "SPI_databank_country_and_aggregates_DCS.csv")) {
    return(c("Time", "Country", "Series"))
  }
  if (identical(file, "SPI_databank_country_and_aggregates_DCS_wide.csv")) {
    return(c("Country", "Series"))
  }
  if (identical(file, "SPI_databank_footnotes.csv")) {
    return(c("Country", "Series", "Time"))
  }
  if (grepl(
    "^(SPI_data[.](csv|dta)|SPI_index[.]csv|SPI_indicators_|SPI_quantiles_|SPI_quantiles[.]csv|SPL_admin_data_availability)",
    file
  )) {
    return(c("iso3c", "date"))
  }
  if (identical(file, "SPI_treemap.csv")) {
    return(c("country", "source_id"))
  }
  if (grepl("^vintage_diff_", file)) {
    return(c("indicator", "iso3c", "date"))
  }
  if (grepl("^revision_indicators_|^revision_new_year_", file)) {
    return(c("indicator", "dimension"))
  }
  if (grepl("^revision_index_", file)) {
    return(c("year", "measure", "iso3c"))
  }
  character()
}

validate_output_artifact <- function(path) {
  file <- basename(path)
  extension <- tolower(tools::file_ext(file))
  if (extension == "md") {
    if (length(readLines(path, warn = FALSE)) == 0L) {
      stop("FINAL OUTPUT ARTIFACT IS HEADER-ONLY: ", file, call. = FALSE)
    }
    return(invisible(TRUE))
  }
  if (extension == "dta") {
    if (!requireNamespace("haven", quietly = TRUE)) {
      stop("FINAL OUTPUT VALIDATION REQUIRES haven for ", file, call. = FALSE)
    }
    data <- as.data.frame(haven::zap_labels(haven::read_dta(path)))
    names(data) <- gsub("_", ".", names(data), fixed = TRUE)
  } else if (extension == "csv") {
    data <- readr::read_csv(
      path,
      col_types = readr::cols(.default = readr::col_character()),
      progress = FALSE
    )
  } else {
    stop("FINAL OUTPUT ARTIFACT FORMAT UNSUPPORTED: ", file, call. = FALSE)
  }
  if (nrow(data) == 0L) {
    stop("FINAL OUTPUT ARTIFACT IS HEADER-ONLY: ", file, call. = FALSE)
  }
  keys <- output_artifact_key_columns(file)
  missing <- setdiff(keys, names(data))
  if (length(missing) > 0L) {
    stop(
      "FINAL OUTPUT ARTIFACT SCHEMA INVALID in ", file, ": missing ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  if (length(keys) > 0L) {
    blank <- vapply(data[keys], function(column) {
      values <- as.character(column)
      all(is.na(values) | !nzchar(trimws(values)))
    }, logical(1))
    if (any(blank)) {
      stop(
        "FINAL OUTPUT ARTIFACT HAS NO KEY COVERAGE in ", file, ": ",
        paste(keys[blank], collapse = ", "),
        call. = FALSE
      )
    }
  }
  invisible(TRUE)
}

validate_output_artifacts <- function(output_dir, files) {
  invisible(lapply(file.path(output_dir, files), validate_output_artifact))
}

# ODIN-dependent columns present in the candidate SPI_data.csv and SPI_index.csv.
odin_dependent_columns <- function(output_dir) {
  columns <- unlist(lapply(c("SPI_data.csv", "SPI_index.csv"), function(file) {
    names(readr::read_csv(file.path(output_dir, file), n_max = 0, show_col_types = FALSE))
  }))
  unique(columns[Reduce(`|`, lapply(odin_dependent_column_patterns, grepl, x = columns))])
}

odin_marker_text <- function(odin_files, end_date) {
  c(
    "# Provisional SPI outputs: ODIN",
    "",
    sprintf(
      "The outputs in this folder use a provisional ODIN file for %d (%s).",
      end_date,
      basename(odin_files[[length(odin_files)]])
    ),
    "Only the ODIN-dependent columns listed in `_estimation_manifest.json`",
    "(`odin_dependent_columns`: SPI.D2.2, SPI.D4.3, their dimension indices,",
    "Pillars 2 and 4, the overall index, and the ranks, quantiles and databank",
    "rows derived from them) are provisional. Every other value is final.",
    "",
    "After the official ODIN release, replace the file, set",
    "`odin_status <- \"official\"` in `config/params.R`, and rerun the estimation",
    "pipeline; this marker is then removed."
  )
}

#' Validate the complete final output set.
#'
#' With `odin`, the manifest records the ODIN status, the ODIN file hashes
#' and the ODIN-dependent output columns; a provisional run writes
#' `PROVISIONAL_ODIN.md` next to the outputs and an official run removes it.
#'
#' @param output_dir Final output directory.
#' @param end_date Output vintage.
#' @param odin Optional list with `status` ("provisional" or "official") and
#'   `files` (the ODIN file paths read by the estimation).
#' @param odin_release_record Validated record returned by
#'   [read_odin_release_record()] when `odin$status` is official.
#' @return A data frame with expected paths and existence flags.
#' @export
validate_output_manifest <- function(output_dir, end_date = 2024, odin = NULL,
                                     odin_release_record = NULL) {
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
  empty <- paths[file.info(paths)$size <= 0]
  if (length(empty) > 0L) {
    stop(
      "FINAL OUTPUT SET CONTAINS EMPTY FILE(S): ",
      paste(basename(empty), collapse = ", "),
      call. = FALSE
    )
  }
  validate_output_artifacts(output_dir, files)
  result <- data.frame(file = files, path = paths, present = present, stringsAsFactors = FALSE)
  manifest <- list(
    end_date = end_date,
    checked_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    files = files
  )
  if (!is.null(odin)) {
    if (!(identical(odin$status, "provisional") || identical(odin$status, "official"))) {
      stop("ODIN STATUS MUST BE 'provisional' OR 'official'; found: ", format(odin$status), call. = FALSE)
    }
    missing_odin <- odin$files[!file.exists(odin$files)]
    if (length(odin$files) == 0L || length(missing_odin) > 0L) {
      stop("ODIN FILES FOR THE OUTPUT MANIFEST NOT FOUND: ", paste(missing_odin, collapse = ", "), call. = FALSE)
    }
    if (identical(odin$status, "official") && is.null(odin_release_record)) {
      stop("OFFICIAL ODIN OUTPUTS REQUIRE A VALIDATED RELEASE RECORD.", call. = FALSE)
    }
    manifest$odin_status <- odin$status
    manifest$odin_files <- lapply(odin$files, function(path) {
      list(file = basename(path), sha256 = digest::digest(path, algo = "sha256", file = TRUE))
    })
    manifest$odin_dependent_columns <- odin_dependent_columns(output_dir)
    if (identical(odin$status, "official")) {
      manifest$odin_release_record <- odin_release_record
    }
    marker <- file.path(output_dir, odin_marker_file)
    if (identical(odin$status, "provisional")) {
      writeLines(odin_marker_text(odin$files, end_date), marker)
    } else if (file.exists(marker)) {
      unlink(marker)
    }
  }
  jsonlite::write_json(
    manifest,
    file.path(output_dir, "_estimation_manifest.json"),
    auto_unbox = TRUE,
    pretty = TRUE
  )
  result
}

#' Promote a complete candidate output set to the final directory.
#'
#' Only the expected output files, the manifest and (for a provisional ODIN
#' run) `PROVISIONAL_ODIN.md` are promoted; any other file in the candidate
#' directory is ignored. An official ODIN run removes the marker from the
#' final directory.
#'
#' @param candidate_dir Validated candidate directory.
#' @param output_dir Final output directory.
#' @param end_date Current output vintage.
#' @return Character vector of the promoted file paths.
#' @export
promote_output_set <- function(candidate_dir, output_dir, end_date = 2024) {
  files <- c(expected_estimation_outputs(end_date), "_estimation_manifest.json")
  missing <- files[!file.exists(file.path(candidate_dir, files))]
  if (length(missing) > 0L) {
    stop("CANDIDATE OUTPUT SET INCOMPLETE: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  empty <- files[file.info(file.path(candidate_dir, files))$size <= 0]
  if (length(empty) > 0L) {
    stop(
      "CANDIDATE OUTPUT SET CONTAINS EMPTY FILE(S): ",
      paste(empty, collapse = ", "),
      call. = FALSE
    )
  }
  validate_output_artifacts(candidate_dir, expected_estimation_outputs(end_date))
  release_diff <- sprintf("release_diff_%d.%s", as.integer(end_date), c("csv", "md"))
  files <- c(files, release_diff[file.exists(file.path(candidate_dir, release_diff))])
  odin_status <- jsonlite::read_json(file.path(candidate_dir, "_estimation_manifest.json"))$odin_status
  if (identical(odin_status, "provisional")) {
    if (!file.exists(file.path(candidate_dir, odin_marker_file))) {
      stop("CANDIDATE OUTPUT SET INCOMPLETE: ", odin_marker_file, call. = FALSE)
    }
    files <- c(files, odin_marker_file)
  }

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  backup_dir <- tempfile("spi-output-backup-")
  dir.create(backup_dir, recursive = TRUE)
  on.exit(unlink(backup_dir, recursive = TRUE, force = TRUE), add = TRUE)
  existing <- files[file.exists(file.path(output_dir, files))]
  if (length(existing) > 0L) {
    file.copy(file.path(output_dir, existing), backup_dir, overwrite = TRUE)
  }

  tryCatch({
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
  if (identical(odin_status, "official")) {
    unlink(file.path(output_dir, odin_marker_file))
  }

  file.path(output_dir, files)
}

# =============================================================================
# Vintage-diff policy report
# =============================================================================
# Compares the candidate SPI_data.csv with the previous published vintage for
# 2004 to end_date - 1 and applies the 202611 revision policy:
#   - refresh (reported only): D1.5, D4.1, D4.2
#   - frozen (blocks promotion unless approved): D2, D3, D4.3, D5
# Approvals: 01_raw_data/_collection/vintage_diff_approvals_<end_date>.csv
# with columns indicator, iso3c, date, reason, approved_by ("*" matches any
# indicator, country or year). Duplicate country-year keys always block.
#
# Created: 2026-10-24
# =============================================================================

.vintage_diff_columns <- c(
  "indicator", "dimension", "policy", "iso3c", "date", "previous", "current",
  "status", "approval_reason", "approved_by"
)
.vintage_diff_approval_columns <- c("indicator", "iso3c", "date", "reason", "approved_by")
.vintage_diff_duplicate <- "<duplicate key>"

#' Dimension of SPI indicator columns (for example "D1.5", "D3", "D4.3").
#'
#' @param columns SPI indicator column names.
#' @return Character vector of dimension identifiers.
#' @export
vintage_diff_dimension <- function(columns) {
  sub("^SPI[.](D[0-9]+)([.]([0-9]+))?([.].*)?$", "\\1\\2", columns)
}

#' Revision policy of SPI indicator columns.
#'
#' @param columns SPI indicator column names.
#' @return "refresh" or "frozen" for each column; stops on any other column.
#' @export
vintage_diff_policy <- function(columns) {
  dimension <- vintage_diff_dimension(columns)
  major <- sub("[.].*$", "", dimension)
  policy <- ifelse(
    dimension %in% c("D1.5", "D4.1", "D4.2"),
    "refresh",
    ifelse(major %in% c("D2", "D3", "D5") | dimension == "D4.3", "frozen", NA_character_)
  )
  unclassified <- columns[is.na(policy) | !grepl("^SPI[.]D[0-9]", columns)]
  if (length(unclassified) > 0L) {
    stop(
      "VINTAGE DIFF: UNCLASSIFIED INDICATOR(S) ", paste(unclassified, collapse = ", "),
      ". Add the dimension to the revision policy in R/vintage_diff.R.",
      call. = FALSE
    )
  }
  policy
}

#' Path of the previous published SPI_data file.
#'
#' @param params Pipeline parameters.
#' @return `previous_vintages/SPI_data_<end_date - 1>.csv` under raw_dir.
#' @export
vintage_baseline_manifest_path <- function(params) {
  file.path(params$raw_dir, "previous_vintages", "manifest.json")
}

#' Read and verify the approved previous-vintage baseline inventory.
#'
#' The inventory is a small, versioned allow-list. Every file it names must
#' exist under `previous_vintages/` and match its recorded SHA-256; a file is
#' not accepted merely because its filename is the expected one.
#'
#' @param params Pipeline parameters.
#' @return The validated manifest invisibly.
#' @export
read_vintage_baseline_manifest <- function(params) {
  path <- vintage_baseline_manifest_path(params)
  if (!file.exists(path)) {
    stop(
      "VINTAGE BASELINE MANIFEST NOT FOUND: ", path,
      ". Record approved SHA-256 hashes for the previous published files.",
      call. = FALSE
    )
  }
  manifest <- jsonlite::read_json(path, simplifyVector = FALSE)
  required <- c("schema_version", "approved_by", "approved_at", "files")
  missing <- setdiff(required, names(manifest))
  if (length(missing) > 0L || !identical(manifest$schema_version, "spi-vintage-baseline-v1")) {
    stop("VINTAGE BASELINE MANIFEST SCHEMA INVALID: ", path, call. = FALSE)
  }
  if (length(manifest$approved_by) != 1L || !nzchar(trimws(manifest$approved_by)) ||
      length(manifest$approved_at) != 1L ||
      is.na(as.POSIXct(manifest$approved_at, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))) {
    stop("VINTAGE BASELINE MANIFEST APPROVAL METADATA INVALID: ", path, call. = FALSE)
  }
  if (!is.list(manifest$files) || length(manifest$files) == 0L) {
    stop("VINTAGE BASELINE MANIFEST HAS NO FILES: ", path, call. = FALSE)
  }
  previous_dir <- normalizePath(dirname(path), winslash = "/", mustWork = TRUE)
  paths <- vapply(manifest$files, function(entry) as.character(entry$path), character(1))
  hashes <- vapply(manifest$files, function(entry) as.character(entry$sha256), character(1))
  if (anyNA(paths) || any(!nzchar(paths)) || anyDuplicated(paths) > 0L ||
      any(!grepl("^[0-9a-fA-F]{64}$", hashes))) {
    stop("VINTAGE BASELINE MANIFEST FILE ENTRIES INVALID: ", path, call. = FALSE)
  }
  resolved <- vapply(paths, function(relative) {
    candidate <- normalizePath(file.path(dirname(path), relative), winslash = "/", mustWork = FALSE)
    if (!startsWith(candidate, paste0(previous_dir, "/"))) {
      stop("VINTAGE BASELINE MANIFEST FILE OUTSIDE previous_vintages: ", relative, call. = FALSE)
    }
    candidate
  }, character(1))
  missing_files <- paths[!file.exists(resolved)]
  if (length(missing_files) > 0L) {
    stop("VINTAGE BASELINE FILE(S) NOT FOUND: ", paste(missing_files, collapse = ", "), call. = FALSE)
  }
  actual <- vapply(resolved, digest::digest, character(1), algo = "sha256", file = TRUE)
  changed <- paths[tolower(actual) != tolower(hashes)]
  if (length(changed) > 0L) {
    stop("VINTAGE BASELINE HASH MISMATCH: ", paste(changed, collapse = ", "), call. = FALSE)
  }
  manifest$resolved_files <- resolved
  manifest
}

vintage_baseline_control_paths <- function(params) {
  if (!file.exists(vintage_baseline_manifest_path(params))) {
    return(character())
  }
  manifest <- read_vintage_baseline_manifest(params)
  c(vintage_baseline_manifest_path(params), manifest$resolved_files)
}

vintage_diff_previous_path <- function(params) {
  path <- file.path(
    params$raw_dir,
    "previous_vintages",
    sprintf("SPI_data_%d.csv", as.integer(params$end_date) - 1L)
  )
  if (!file.exists(path)) {
    stop("PREVIOUS VINTAGE NOT FOUND: ", path, call. = FALSE)
  }
  manifest <- read_vintage_baseline_manifest(params)
  if (!any(normalizePath(path, winslash = "/", mustWork = TRUE) == manifest$resolved_files)) {
    stop("PREVIOUS VINTAGE IS NOT IN THE APPROVED BASELINE MANIFEST: ", path, call. = FALSE)
  }
  path
}

#' Path of the vintage-diff approvals file.
#'
#' @param params Pipeline parameters.
#' @return `_collection/vintage_diff_approvals_<end_date>.csv`.
#' @export
vintage_diff_approvals_path <- function(params) {
  file.path(params$collection_dir, sprintf("vintage_diff_approvals_%d.csv", as.integer(params$end_date)))
}

#' Create the approvals template once; never overwrite it.
#'
#' @param path Approvals file path.
#' @return The path.
#' @export
ensure_vintage_diff_approvals <- function(path) {
  if (!file.exists(path)) {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    writeLines(paste(.vintage_diff_approval_columns, collapse = ","), path)
  }
  path
}

.read_vintage_diff_approvals <- function(path, indicators, years) {
  if (!file.exists(path)) {
    return(as.data.frame(
      stats::setNames(replicate(5, character(), simplify = FALSE), .vintage_diff_approval_columns),
      stringsAsFactors = FALSE
    ))
  }
  approvals <- readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    na = character(),
    progress = FALSE
  )
  missing <- setdiff(.vintage_diff_approval_columns, names(approvals))
  if (length(missing) > 0L) {
    stop("VINTAGE DIFF APPROVALS SCHEMA MISMATCH: missing ", paste(missing, collapse = ", "), call. = FALSE)
  }
  approvals <- as.data.frame(approvals[.vintage_diff_approval_columns], stringsAsFactors = FALSE)
  approvals[] <- lapply(approvals, trimws)
  if (any(!nzchar(approvals$reason)) || any(!nzchar(approvals$approved_by))) {
    stop("VINTAGE DIFF APPROVALS: every row needs a reason and approved_by (", path, ")", call. = FALSE)
  }
  unknown <- setdiff(approvals$indicator, c("*", indicators))
  if (length(unknown) > 0L) {
    stop("VINTAGE DIFF APPROVALS NAME UNKNOWN INDICATOR(S): ", paste(unknown, collapse = ", "), call. = FALSE)
  }
  bad_date <- setdiff(approvals$date, c("*", as.character(years)))
  if (length(bad_date) > 0L) {
    stop("VINTAGE DIFF APPROVALS HAVE INVALID DATE(S): ", paste(bad_date, collapse = ", "), call. = FALSE)
  }
  if (any(!nzchar(approvals$iso3c))) {
    stop("VINTAGE DIFF APPROVALS: iso3c must be a code or *", call. = FALSE)
  }
  approvals
}

.vintage_diff_read <- function(path) {
  data <- readr::read_csv(path, show_col_types = FALSE, guess_max = Inf, progress = FALSE)
  if (!all(c("iso3c", "date") %in% names(data))) {
    stop("VINTAGE DIFF: iso3c and date columns required in ", path, call. = FALSE)
  }
  data$date <- as.integer(data$date)
  data
}

.vintage_diff_format <- function(value) {
  ifelse(is.na(value), NA_character_, format(value, digits = 15, trim = TRUE))
}

#' Compare the candidate SPI_data with the previous vintage.
#'
#' @param candidate Candidate SPI_data.csv path.
#' @param previous Previous published SPI_data path.
#' @param approvals_path Approvals file path.
#' @param end_date Reference year; years 2004 to end_date - 1 are compared.
#' @param tolerance Relative tolerance for numeric equality.
#' @return A data frame with one row per changed cell or duplicate key.
#' @export
build_vintage_diff <- function(candidate, previous, approvals_path, end_date,
                               tolerance = 1e-9) {
  end_date <- as.integer(end_date)
  years <- seq.int(2004L, end_date - 1L)
  current_data <- .vintage_diff_read(candidate)
  previous_data <- .vintage_diff_read(previous)

  duplicate_rows <- lapply(list(current = current_data, previous = previous_data), function(data) {
    keys <- data[c("iso3c", "date")]
    unique(keys[duplicated(keys), , drop = FALSE])
  })
  duplicates <- unique(do.call(rbind, duplicate_rows))

  indicators <- sort(unique(c(
    grep("^SPI[.]", names(current_data), value = TRUE),
    grep("^SPI[.]", names(previous_data), value = TRUE)
  )))
  policy <- stats::setNames(vintage_diff_policy(indicators), indicators)
  approvals <- .read_vintage_diff_approvals(approvals_path, indicators, years)

  long <- function(data) {
    unique_keys <- !(duplicated(data[c("iso3c", "date")]) |
      duplicated(data[c("iso3c", "date")], fromLast = TRUE))
    data <- data[unique_keys & data$date %in% years, , drop = FALSE]
    present <- intersect(indicators, names(data))
    out <- tidyr::pivot_longer(
      data[c("iso3c", "date", present)],
      cols = dplyr::all_of(present),
      names_to = "indicator",
      values_to = "value",
      values_transform = list(value = function(x) suppressWarnings(as.numeric(x)))
    )
    absent <- setdiff(indicators, present)
    if (length(absent) > 0L) {
      keys <- unique(data[c("iso3c", "date")])
      out <- rbind(out, merge(keys, data.frame(indicator = absent, value = NA_real_)))
    }
    out
  }
  joined <- dplyr::full_join(
    long(previous_data),
    long(current_data),
    by = c("iso3c", "date", "indicator"),
    suffix = c(".previous", ".current")
  )
  if (nrow(duplicates) > 0L) {
    joined <- dplyr::anti_join(joined, duplicates, by = c("iso3c", "date"))
  }
  x <- joined$value.previous
  y <- joined$value.current
  one_missing <- xor(is.na(x), is.na(y))
  both <- !is.na(x) & !is.na(y)
  differs <- rep(FALSE, length(x))
  differs[both] <- abs(x[both] - y[both]) > tolerance * pmax(1, abs(x[both]), abs(y[both]))
  changed <- joined[one_missing | differs, , drop = FALSE]

  report <- data.frame(
    indicator = changed$indicator,
    dimension = vintage_diff_dimension(changed$indicator),
    policy = unname(policy[changed$indicator]),
    iso3c = changed$iso3c,
    date = as.integer(changed$date),
    previous = .vintage_diff_format(changed$value.previous),
    current = .vintage_diff_format(changed$value.current),
    status = rep(NA_character_, nrow(changed)),
    approval_reason = rep(NA_character_, nrow(changed)),
    approved_by = rep(NA_character_, nrow(changed)),
    stringsAsFactors = FALSE
  )
  report$status <- ifelse(report$policy == "refresh", "reported", "blocking")
  for (index in which(report$policy == "frozen")) {
    match <- which(
      approvals$indicator %in% c("*", report$indicator[[index]]) &
        approvals$iso3c %in% c("*", report$iso3c[[index]]) &
        approvals$date %in% c("*", as.character(report$date[[index]]))
    )
    if (length(match) > 0L) {
      report$status[[index]] <- "approved"
      report$approval_reason[[index]] <- approvals$reason[[match[[1]]]]
      report$approved_by[[index]] <- approvals$approved_by[[match[[1]]]]
    }
  }

  if (nrow(duplicates) > 0L) {
    report <- rbind(report, data.frame(
      indicator = .vintage_diff_duplicate,
      dimension = NA_character_,
      policy = "integrity",
      iso3c = duplicates$iso3c,
      date = as.integer(duplicates$date),
      previous = NA_character_,
      current = NA_character_,
      status = "blocking",
      approval_reason = NA_character_,
      approved_by = NA_character_,
      stringsAsFactors = FALSE
    ))
  }
  report <- report[order(report$policy, report$indicator, report$iso3c, report$date, method = "radix"), .vintage_diff_columns, drop = FALSE]
  rownames(report) <- NULL
  attr(report, "unused_approvals") <- approvals[!vapply(seq_len(nrow(approvals)), function(index) {
    any(
      report$policy == "frozen" &
        (approvals$indicator[[index]] == "*" | report$indicator == approvals$indicator[[index]]) &
        (approvals$iso3c[[index]] == "*" | report$iso3c == approvals$iso3c[[index]]) &
        (approvals$date[[index]] == "*" | as.character(report$date) == approvals$date[[index]])
    )
  }, logical(1)), , drop = FALSE]
  report
}

#' Stop when the vintage diff has blocking rows.
#'
#' @param report Result of build_vintage_diff().
#' @param report_path Report path named in the error.
#' @return Invisibly TRUE.
#' @export
enforce_vintage_diff <- function(report, report_path) {
  blocking <- report$status == "blocking"
  if (any(blocking)) {
    duplicates <- sum(blocking & report$indicator == .vintage_diff_duplicate)
    stop(
      sprintf(
        paste0(
          "VINTAGE DIFF BLOCKS PROMOTION: %d frozen-dimension change(s) without approval ",
          "and %d duplicate country-year key(s). See %s; record approved changes in the ",
          "vintage-diff approvals file."
        ),
        sum(blocking) - duplicates,
        duplicates,
        report_path
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

.vintage_diff_years <- function(dates) {
  if (min(dates) == max(dates)) as.character(min(dates)) else sprintf("%d-%d", min(dates), max(dates))
}

vintage_diff_markdown <- function(report, end_date, previous, approvals_path) {
  counts <- table(factor(report$status, levels = c("blocking", "approved", "reported")))
  lines <- c(
    sprintf("# Vintage diff: SPI_data %d vs %s", end_date, basename(previous)),
    "",
    sprintf(
      "Years compared: 2004-%d. Revision policy: D1.5, D4.1 and D4.2 are refreshed (changes reported); D2, D3, D4.3 and D5 are frozen (changes need approval in `%s`).",
      end_date - 1L,
      basename(approvals_path)
    ),
    "",
    sprintf(
      "%d changed cells: %d blocking, %d approved, %d reported.",
      sum(report$indicator != .vintage_diff_duplicate),
      counts[["blocking"]] - sum(report$indicator == .vintage_diff_duplicate),
      counts[["approved"]],
      counts[["reported"]]
    ),
    ""
  )
  cells <- report[report$indicator != .vintage_diff_duplicate, , drop = FALSE]
  if (nrow(cells) == 0L) {
    lines <- c(lines, "No history changes.", "")
  } else {
    lines <- c(lines, "| Indicator | Policy | Cells | Countries | Years | Status |", "|---|---|---|---|---|---|")
    groups <- split(cells, list(cells$indicator, cells$policy, cells$status), drop = TRUE)
    for (group in groups[order(names(groups))]) {
      lines <- c(lines, sprintf(
        "| %s | %s | %d | %d | %s | %s |",
        group$indicator[[1]], group$policy[[1]], nrow(group),
        length(unique(group$iso3c)), .vintage_diff_years(group$date), group$status[[1]]
      ))
    }
    lines <- c(lines, "")
  }
  duplicates <- report[report$indicator == .vintage_diff_duplicate, , drop = FALSE]
  if (nrow(duplicates) > 0L) {
    lines <- c(
      lines,
      sprintf("## Duplicate country-year keys (%d, blocking)", nrow(duplicates)),
      "",
      paste0("- ", duplicates$iso3c, " ", duplicates$date),
      ""
    )
  }
  unused <- attr(report, "unused_approvals")
  if (!is.null(unused) && nrow(unused) > 0L) {
    lines <- c(
      lines,
      sprintf("## Approvals that match no change (%d)", nrow(unused)),
      "",
      paste0("- ", unused$indicator, " ", unused$iso3c, " ", unused$date, ": ", unused$reason),
      ""
    )
  }
  lines
}

#' Write the vintage-diff report next to the candidate outputs.
#'
#' Writes `vintage_diff_<end_date>.csv` and `.md` to `candidate_dir`, then
#' stops when frozen-dimension changes lack approval or keys are duplicated.
#'
#' @param candidate_dir Candidate output directory (with SPI_data.csv).
#' @param previous Previous published SPI_data path.
#' @param approvals_path Approvals file path.
#' @param end_date Reference year.
#' @param enforce Whether blocking rows stop the run.
#' @return The CSV and Markdown report paths.
#' @export
write_vintage_diff <- function(candidate_dir, previous, approvals_path, end_date,
                               enforce = TRUE) {
  report <- build_vintage_diff(
    file.path(candidate_dir, "SPI_data.csv"),
    previous,
    approvals_path,
    end_date
  )
  csv_path <- file.path(candidate_dir, sprintf("vintage_diff_%d.csv", as.integer(end_date)))
  md_path <- file.path(candidate_dir, sprintf("vintage_diff_%d.md", as.integer(end_date)))
  readr::write_csv(report, csv_path, na = "")
  writeLines(vintage_diff_markdown(report, as.integer(end_date), previous, approvals_path), md_path)
  if (enforce) {
    enforce_vintage_diff(report, md_path)
  }
  c(csv_path, md_path)
}

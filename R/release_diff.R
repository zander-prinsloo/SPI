# =============================================================================
# Provisional-to-final release diff
# =============================================================================
# When a release lock exists (see R/release_lock.R), the estimation compares
# every candidate output with the archived provisional output before
# promotion. Only ODIN-dependent values may change: SPI.D2.2 and SPI.D4.3
# (and their RAW columns), their dimension indices, Pillars 2 and 4, the
# overall index, the quintiles and scores derived from them, the plotting
# jitter of SPI_quantiles_<end_date>.csv, and the treemap and databank rows
# of those series (including aggregates). Any other change, and any added or
# removed row or column, blocks promotion.
#
# Created: 2026-10-24
# =============================================================================

release_diff_allowed_series <- c(
  "^(SPI|RAW)[.]D2[.]2[.]",
  "^(SPI|RAW)[.]D4[.]3[.]",
  "^SPI[.]DIM2[.]2[.]INDEX$",
  "^SPI[.]DIM4[.]3[.]INDEX$",
  "^SPI[.]INDEX[.]PIL2$",
  "^SPI[.]INDEX[.]PIL4$",
  "^SPI[.]INDEX$"
)

# build_quantiles_2024() draws the jitter in row order and the rows follow
# the overall index, so an ODIN change that reorders countries moves the
# jitter between rows, including rows whose own values did not change.
release_diff_allowed_columns <- c(
  release_diff_allowed_series,
  "^SPI[.]INDEX([.]PIL2|[.]PIL4)?[.]quintile$",
  "^jitter_[xy]$",
  "^Data Services Score$",
  "^Data Sources Score$",
  "^SPI Overall Score$"
)

# Comparison keys per output. Long files allow a whole row when its series
# is ODIN-dependent; wide files allow individual ODIN-dependent columns.
# SPI_data.dta is written from the same data as SPI_data.csv.
release_diff_specs <- function(end_date) {
  wide <- function(keys, reader = "csv") {
    list(keys = keys, series = NULL, reader = reader)
  }
  long <- function(keys, series) {
    list(keys = keys, series = series, reader = "csv")
  }
  specs <- list(
    wide(c("iso3c", "date")),
    wide(c("iso3c", "date"), reader = "dta"),
    wide(c("iso3c", "date")),
    wide(c("iso3c", "date")),
    wide(c("iso3c", "date")),
    wide(c("iso3c", "date")),
    long(c("country", "source_id"), "source_id"),
    long(c("iso3c", "date", "source_id"), "source_id"),
    long(c("Time", "Country", "Series"), "Series"),
    long(c("Country", "Series"), "Series"),
    long(c("Country", "Series", "Time"), "Series"),
    wide(c("iso3c", "date"))
  )
  names(specs) <- c(
    "SPI_data.csv",
    "SPI_data.dta",
    "SPI_index.csv",
    sprintf("SPI_indicators_%d.csv", end_date),
    "SPI_quantiles.csv",
    sprintf("SPI_quantiles_%d.csv", end_date),
    "SPI_treemap.csv",
    "SPI_databank_country_and_aggregates.csv",
    "SPI_databank_country_and_aggregates_DCS.csv",
    "SPI_databank_country_and_aggregates_DCS_wide.csv",
    "SPI_databank_footnotes.csv",
    "SPL_admin_data_availability.csv"
  )
  specs[[sprintf("vintage_diff_%d.csv", end_date)]] <-
    long(c("indicator", "iso3c", "date"), "indicator")
  specs[[sprintf("revision_indicators_%d.csv", end_date)]] <-
    long(c("indicator", "dimension"), "indicator")
  specs[[sprintf("revision_index_%d.csv", end_date)]] <-
    long(c("year", "measure", "iso3c"), "measure")
  specs[[sprintf("revision_new_year_%d.csv", end_date)]] <-
    long(c("indicator", "dimension"), "indicator")
  specs[[sprintf("vintage_diff_%d.md", end_date)]] <- list(
    keys = character(), series = NULL, reader = "text",
    related = sprintf("vintage_diff_%d.csv", end_date)
  )
  specs[[sprintf("revision_summary_%d.md", end_date)]] <- list(
    keys = character(), series = NULL, reader = "text",
    related = c(
      sprintf("revision_indicators_%d.csv", end_date),
      sprintf("revision_index_%d.csv", end_date),
      sprintf("revision_new_year_%d.csv", end_date)
    )
  )
  specs[["_estimation_manifest.json"]] <- list(
    keys = character(), series = NULL, reader = "json",
    allowed_paths = c(
      "^odin_status$",
      "^odin_files([.]|$)",
      "^odin_dependent_columns([.]|$)",
      "^checked_at$"
    )
  )
  specs[["PROVISIONAL_ODIN.md"]] <- list(
    keys = character(), series = NULL, reader = "text",
    related = "SPI_data.csv",
    allow_missing_candidate = TRUE
  )
  specs
}

#' Output files compared by the release diff.
#'
#' @param end_date Reference year.
#' @return Character vector of file names.
#' @export
release_diff_files <- function(end_date) {
  names(release_diff_specs(as.integer(end_date)))
}

.release_diff_matches <- function(values, patterns) {
  Reduce(`|`, lapply(patterns, grepl, x = values), rep(FALSE, length(values)))
}

.release_diff_same <- function(x, y, tolerance = 1e-9) {
  both_na <- is.na(x) & is.na(y)
  one_na <- xor(is.na(x), is.na(y))
  nx <- suppressWarnings(as.numeric(x))
  ny <- suppressWarnings(as.numeric(y))
  numeric <- !is.na(nx) & !is.na(ny)
  same <- both_na
  same[numeric] <- abs(nx[numeric] - ny[numeric]) <= tolerance * pmax(1, abs(nx[numeric]), abs(ny[numeric]))
  text <- !both_na & !one_na & !numeric
  same[text] <- x[text] == y[text]
  same
}

.release_diff_read <- function(path, keys) {
  data <- readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    progress = FALSE
  )
  missing <- setdiff(keys, names(data))
  if (length(missing) > 0L) {
    stop("RELEASE DIFF: KEY COLUMN(S) MISSING in ", path, ": ", paste(missing, collapse = ", "), call. = FALSE)
  }
  data <- data[do.call(order, unname(lapply(data, function(column) column))), , drop = FALSE]
  sequence <- stats::ave(seq_len(nrow(data)), do.call(paste, c(data[keys], sep = "\r")), FUN = seq_along)
  data$.key <- paste0(
    do.call(paste, c(lapply(keys, function(key) paste0(key, "=", data[[key]])), sep = ";")),
    ifelse(sequence > 1L, paste0(";#", sequence), "")
  )
  data
}

.release_diff_read_dta <- function(path, keys) {
  if (!requireNamespace("haven", quietly = TRUE)) {
    stop("RELEASE DIFF: haven is required to compare ", basename(path), call. = FALSE)
  }
  data <- haven::zap_labels(haven::read_dta(path))
  data <- as.data.frame(data, stringsAsFactors = FALSE)
  names(data) <- gsub("_", ".", names(data), fixed = TRUE)
  missing <- setdiff(keys, names(data))
  if (length(missing) > 0L) {
    stop("RELEASE DIFF: KEY COLUMN(S) MISSING in ", path, ": ", paste(missing, collapse = ", "), call. = FALSE)
  }
  data <- data[do.call(order, unname(lapply(data, as.character))), , drop = FALSE]
  sequence <- stats::ave(seq_len(nrow(data)), do.call(paste, c(data[keys], sep = "\r")), FUN = seq_along)
  data$.key <- paste0(
    do.call(paste, c(lapply(keys, function(key) paste0(key, "=", data[[key]])), sep = ";")),
    ifelse(sequence > 1L, paste0(";#", sequence), "")
  )
  data
}

.release_diff_read_text <- function(path) {
  data.frame(
    .key = "<file>",
    .value = paste(readLines(path, warn = FALSE), collapse = "\n"),
    stringsAsFactors = FALSE
  )
}

.release_diff_json_flatten <- function(value, prefix = "") {
  if (is.list(value)) {
    if (length(value) == 0L) {
      return(stats::setNames(character(), character()))
    }
    out <- list()
    value_names <- names(value)
    for (index in seq_along(value)) {
      name <- if (is.null(value_names) || is.na(value_names[[index]]) || !nzchar(value_names[[index]])) {
        as.character(index)
      } else {
        value_names[[index]]
      }
      child <- .release_diff_json_flatten(
        value[[index]],
        if (nzchar(prefix)) paste0(prefix, ".", name) else name
      )
      out <- c(out, as.list(child))
    }
    return(unlist(out, use.names = TRUE))
  }
  values <- as.character(value)
  if (length(values) == 0L) {
    values <- NA_character_
  }
  stats::setNames(values, paste0(prefix, if (length(values) > 1L) seq_along(values) else ""))
}

.release_diff_read_json <- function(path, ignored = character()) {
  value <- jsonlite::read_json(path, simplifyVector = FALSE)
  flat <- .release_diff_json_flatten(value)
  keep <- !vapply(names(flat), function(name) any(grepl(
    paste0("^", gsub("([.])", "\\\\1", ignored), "$"),
    name
  )), logical(1))
  flat[keep]
}

#' Compare archived provisional outputs with candidate outputs.
#'
#' @param archive_dir Archived provisional outputs.
#' @param candidate_dir Candidate outputs of the current run.
#' @param end_date Reference year.
#' @param files Output files to compare (default: all).
#' @return A data frame of changes with an `allowed` flag.
#' @export
build_release_diff <- function(archive_dir, candidate_dir, end_date,
                               files = release_diff_files(end_date)) {
  specs <- release_diff_specs(as.integer(end_date))
  rows <- lapply(files, function(file) {
    spec <- specs[[file]]
    if (is.null(spec)) {
      stop("RELEASE DIFF: UNKNOWN OUTPUT ", file, call. = FALSE)
    }
    paths <- file.path(c(archive_dir, candidate_dir), file)
    if (!all(file.exists(paths))) {
      candidate_official <- FALSE
      manifest_path <- file.path(candidate_dir, "_estimation_manifest.json")
      if (file.exists(manifest_path)) {
        candidate_manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
        candidate_official <- identical(candidate_manifest$odin_status, "official")
      }
      return(data.frame(
        file = file, key = NA_character_, column = "<file missing>",
        previous = NA_character_, current = NA_character_,
        allowed = isTRUE(spec$allow_missing_candidate) &&
          file.exists(paths[[1]]) && !file.exists(paths[[2]]) &&
          candidate_official,
        stringsAsFactors = FALSE
      ))
    }
    if (identical(spec$reader, "text")) {
      previous <- .release_diff_read_text(paths[[1]])
      current <- .release_diff_read_text(paths[[2]])
    } else if (identical(spec$reader, "json")) {
      previous <- .release_diff_read_json(paths[[1]])
      current <- .release_diff_read_json(paths[[2]])
    } else if (identical(spec$reader, "dta")) {
      previous <- .release_diff_read_dta(paths[[1]], spec$keys)
      current <- .release_diff_read_dta(paths[[2]], spec$keys)
    } else {
      previous <- .release_diff_read(paths[[1]], spec$keys)
      current <- .release_diff_read(paths[[2]], spec$keys)
    }
    if (identical(spec$reader, "text")) {
      if (identical(previous$.value, current$.value)) {
        return(data.frame(
          file = character(), key = character(), column = character(),
          previous = character(), current = character(), allowed = logical(),
          stringsAsFactors = FALSE
        ))
      }
      return(data.frame(
        file = file, key = "<file>", column = "<file>",
        previous = digest::digest(previous$.value, algo = "sha256", serialize = FALSE),
        current = digest::digest(current$.value, algo = "sha256", serialize = FALSE),
        allowed = FALSE,
        stringsAsFactors = FALSE
      ))
    }
    if (identical(spec$reader, "json")) {
      previous <- data.frame(.key = names(previous), value = unname(previous), stringsAsFactors = FALSE)
      current <- data.frame(.key = names(current), value = unname(current), stringsAsFactors = FALSE)
    }
    out <- list()
    for (column in setdiff(names(previous), names(current))) {
      out[[length(out) + 1L]] <- data.frame(file = file, key = column, column = "<column removed>",
                                            previous = NA_character_, current = NA_character_,
                                            allowed = FALSE, stringsAsFactors = FALSE)
    }
    for (column in setdiff(names(current), names(previous))) {
      out[[length(out) + 1L]] <- data.frame(file = file, key = column, column = "<column added>",
                                            previous = NA_character_, current = NA_character_,
                                            allowed = FALSE, stringsAsFactors = FALSE)
    }
    for (key in setdiff(previous$.key, current$.key)) {
      out[[length(out) + 1L]] <- data.frame(file = file, key = key, column = "<row removed>",
                                            previous = NA_character_, current = NA_character_,
                                            allowed = FALSE, stringsAsFactors = FALSE)
    }
    for (key in setdiff(current$.key, previous$.key)) {
      out[[length(out) + 1L]] <- data.frame(file = file, key = key, column = "<row added>",
                                            previous = NA_character_, current = NA_character_,
                                            allowed = FALSE, stringsAsFactors = FALSE)
    }
    common <- intersect(previous$.key, current$.key)
    previous <- previous[match(common, previous$.key), , drop = FALSE]
    current <- current[match(common, current$.key), , drop = FALSE]
    series_allowed <- if (is.null(spec$series)) {
      rep(FALSE, length(common))
    } else {
      .release_diff_matches(previous[[spec$series]], release_diff_allowed_series)
    }
    for (column in setdiff(intersect(names(previous), names(current)), c(spec$keys, ".key"))) {
      differs <- !.release_diff_same(previous[[column]], current[[column]])
      if (!any(differs)) next
      column_allowed <- .release_diff_matches(column, release_diff_allowed_columns)
      json_allowed <- if (identical(spec$reader, "json")) {
        .release_diff_matches(common[differs], spec$allowed_paths)
      } else {
        rep(FALSE, sum(differs))
      }
      out[[length(out) + 1L]] <- data.frame(
        file = file,
        key = common[differs],
        column = column,
        previous = previous[[column]][differs],
        current = current[[column]][differs],
        allowed = series_allowed[differs] |
          (is.null(spec$series) & column_allowed) |
          json_allowed,
        stringsAsFactors = FALSE
      )
    }
    do.call(rbind, out)
  })
  report <- do.call(rbind, rows)
  if (is.null(report)) {
    report <- data.frame(file = character(), key = character(), column = character(),
                         previous = character(), current = character(), allowed = logical(),
                         stringsAsFactors = FALSE)
  }
  text_rows <- which(vapply(files, function(file) identical(specs[[file]]$reader, "text"), logical(1)))
  if (length(text_rows) > 0L && nrow(report) > 0L) {
    for (index in text_rows) {
      file <- files[[index]]
      if (!any(report$file == file)) next
      related <- specs[[file]]$related
      related_report <- report[report$file %in% related, , drop = FALSE]
      allowed <- nrow(related_report) > 0L &&
        any(related_report$allowed) &&
        all(related_report$allowed)
      report$allowed[report$file == file] <- allowed
    }
  }
  rownames(report) <- NULL
  report
}

#' Stop when the release diff has changes outside the ODIN-dependent outputs.
#'
#' @param report Result of build_release_diff().
#' @param report_path Report path named in the error.
#' @return Invisibly TRUE.
#' @export
enforce_release_diff <- function(report, report_path) {
  outside <- sum(!report$allowed)
  if (outside > 0L) {
    stop(
      sprintf(
        "RELEASE DIFF BLOCKS PROMOTION: %d change(s) outside the ODIN-dependent outputs. See %s.",
        outside,
        report_path
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

.release_diff_markdown <- function(report, end_date, archive) {
  lines <- c(
    sprintf("# Release diff: %d outputs vs %s", end_date, archive),
    "",
    sprintf(
      "%d changed cells: %d within the ODIN-dependent outputs, %d outside the ODIN-dependent outputs.",
      nrow(report), sum(report$allowed), sum(!report$allowed)
    ),
    ""
  )
  if (nrow(report) > 0L) {
    lines <- c(lines, "| File | Column | Cells | Allowed |", "|---|---|---|---|")
    groups <- split(report, list(report$file, report$column, report$allowed), drop = TRUE)
    for (group in groups[order(names(groups))]) {
      lines <- c(lines, sprintf(
        "| %s | %s | %d | %s |",
        group$file[[1]], group$column[[1]], nrow(group), if (group$allowed[[1]]) "yes" else "no"
      ))
    }
    lines <- c(lines, "")
  }
  lines
}

#' Compare the candidate outputs with the locked provisional archive.
#'
#' Without a release lock this does nothing. With a lock it checks that the
#' archive still matches the lock, writes `release_diff_<end_date>.csv` and
#' `.md` to the candidate directory, and stops when a change falls outside
#' the ODIN-dependent outputs.
#'
#' @param params Pipeline parameters.
#' @return The report paths, or NULL without a lock.
#' @export
write_release_diff <- function(params) {
  lock <- read_release_lock(params)
  if (is.null(lock)) {
    unlink(file.path(
      params$estimation_write_dir,
      sprintf("release_diff_%d.%s", as.integer(params$end_date), c("csv", "md"))
    ))
    return(NULL)
  }
  archive <- file.path(params$output_dir, "releases", basename(lock$archive))
  changed <- character()
  for (output in lock$outputs) {
    path <- file.path(archive, output$file)
    if (!file.exists(path) || !identical(digest::digest(path, algo = "sha256", file = TRUE), output$sha256)) {
      changed <- c(changed, output$file)
    }
  }
  if (length(changed) > 0L) {
    stop("RELEASE ARCHIVE CHANGED SINCE THE LOCK: ", paste(changed, collapse = ", "), call. = FALSE)
  }
  end_date <- as.integer(params$end_date)
  report <- build_release_diff(archive, params$estimation_write_dir, end_date)
  csv_path <- file.path(params$estimation_write_dir, sprintf("release_diff_%d.csv", end_date))
  md_path <- file.path(params$estimation_write_dir, sprintf("release_diff_%d.md", end_date))
  readr::write_csv(report, csv_path, na = "")
  writeLines(.release_diff_markdown(report, end_date, lock$archive), md_path)
  enforce_release_diff(report, md_path)
  c(csv_path, md_path)
}

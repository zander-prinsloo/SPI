# =============================================================================
# Review candidates for the technical lead
# =============================================================================
# Collects the countries each collector flags for review into
# 01_raw_data/_collection/review_candidates_<end_date>.csv. Candidates are
# informational: they guide the per-vintage review workbooks and never block
# the collection gate. When a run changes the list, the previous list is kept
# unchanged in review_candidates_history/ (named by its write time and
# SHA-256 prefix) and review_candidates_<end_date>_changes.csv records the
# rows added and removed per source, so a list already sent to reviewers is
# never lost.
#
# Created: 2026-10-23
# =============================================================================

.review_candidate_columns <- c("source_id", "iso3c", "country", "current_value", "reason", "evidence_hint")

#' Combine collector candidates into the review-candidate file.
#'
#' @param candidates List of candidate data frames (NULL entries are skipped).
#' @param path Output CSV path.
#' @param history_dir Folder that keeps every superseded list and the change log.
#' @return Invisibly returns `path`.
#' @export
assemble_review_candidates <- function(candidates, path,
                                       history_dir = file.path(dirname(path), "review_candidates_history")) {
  frames <- Filter(Negate(is.null), candidates)
  for (frame in frames) {
    missing <- setdiff(.review_candidate_columns, names(frame))
    if (length(missing) > 0L) {
      stop("REVIEW CANDIDATES SCHEMA MISMATCH: missing ", paste(missing, collapse = ", "), call. = FALSE)
    }
  }
  combined <- do.call(rbind, c(
    list(as.data.frame(
      stats::setNames(replicate(length(.review_candidate_columns), character(), simplify = FALSE), .review_candidate_columns),
      stringsAsFactors = FALSE
    )),
    lapply(frames, function(frame) {
      out <- as.data.frame(frame[.review_candidate_columns], stringsAsFactors = FALSE)
      out[] <- lapply(out, as.character)
      out
    })
  ))
  combined <- combined[order(combined$source_id, combined$iso3c, combined$country, combined$reason, method = "radix"), , drop = FALSE]
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  new_path <- paste0(path, ".new")
  readr::write_csv(combined, new_path, na = "")
  if (file.exists(path)) {
    previous_hash <- digest::digest(path, algo = "sha256", file = TRUE)
    current_hash <- digest::digest(new_path, algo = "sha256", file = TRUE)
    if (!identical(previous_hash, current_hash)) {
      archived <- .archive_review_candidates(path, previous_hash, history_dir)
      .log_review_candidate_changes(path, new_path, previous_hash, current_hash, archived, history_dir)
    }
  }
  if (!file.rename(new_path, path)) {
    stop("REVIEW CANDIDATES COULD NOT BE WRITTEN: ", path, call. = FALSE)
  }
  invisible(path)
}

# Keep the superseded list byte for byte; reuse an archive of the same content.
.archive_review_candidates <- function(path, hash, history_dir) {
  dir.create(history_dir, recursive = TRUE, showWarnings = FALSE)
  stem <- tools::file_path_sans_ext(basename(path))
  pattern <- sprintf("^%s[.][0-9]{8}T[0-9]{6}Z[.]%s[.]csv$", gsub(".", "[.]", stem, fixed = TRUE), substr(hash, 1L, 8L))
  for (existing in list.files(history_dir, pattern = pattern)) {
    if (identical(digest::digest(file.path(history_dir, existing), algo = "sha256", file = TRUE), hash)) {
      return(existing)
    }
  }
  name <- sprintf(
    "%s.%s.%s.csv",
    stem,
    format(file.mtime(path), "%Y%m%dT%H%M%SZ", tz = "UTC"),
    substr(hash, 1L, 8L)
  )
  if (!file.copy(path, file.path(history_dir, name), copy.date = TRUE)) {
    stop("REVIEW CANDIDATES COULD NOT BE ARCHIVED: ", file.path(history_dir, name), call. = FALSE)
  }
  name
}

.log_review_candidate_changes <- function(previous_path, current_path, previous_hash, current_hash,
                                          archived, history_dir) {
  read <- function(path) {
    readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()), na = character(), progress = FALSE)
  }
  previous <- read(previous_path)
  current <- read(current_path)
  row_key <- function(data) {
    present <- intersect(.review_candidate_columns, names(data))
    do.call(paste, c(as.list(data[present]), sep = "\r"))
  }
  previous_keys <- row_key(previous)
  current_keys <- row_key(current)
  sources <- sort(unique(c(previous$source_id, current$source_id)))
  changed_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  log <- do.call(rbind, lapply(sources, function(source_id) {
    before <- previous_keys[previous$source_id == source_id]
    after <- current_keys[current$source_id == source_id]
    data.frame(
      changed_at = changed_at,
      source_id = source_id,
      previous_rows = length(before),
      current_rows = length(after),
      added = length(setdiff(after, before)),
      removed = length(setdiff(before, after)),
      previous_sha256 = previous_hash,
      current_sha256 = current_hash,
      archived_as = archived,
      stringsAsFactors = FALSE
    )
  }))
  if (is.null(log) || !any(log$added > 0L | log$removed > 0L)) {
    log <- data.frame(
      changed_at = changed_at, source_id = "(format only)", previous_rows = nrow(previous),
      current_rows = nrow(current), added = 0L, removed = 0L, previous_sha256 = previous_hash,
      current_sha256 = current_hash, archived_as = archived, stringsAsFactors = FALSE
    )
  } else {
    log <- log[log$added > 0L | log$removed > 0L, , drop = FALSE]
  }
  stem <- tools::file_path_sans_ext(basename(previous_path))
  log_path <- file.path(history_dir, paste0(stem, "_changes.csv"))
  readr::write_csv(log, log_path, append = file.exists(log_path), na = "")
  invisible(log_path)
}

.d41_years <- function(text) {
  text <- ifelse(is.na(text), "", as.character(text))
  as.integer(unlist(regmatches(text, gregexpr("[0-9]{4}", text)), use.names = FALSE))
}

.d41_format_years <- function(years) {
  if (length(years) == 0L) "none" else paste(sort(unique(years)), collapse = ", ")
}

# Score at end_date with the census_fun()/survey_fun() rules.
.d41_score <- function(years, census, register, end_date) {
  years <- years[years <= end_date]
  if (census) {
    if (register) return(1)
    if (length(years) == 0L) return(0)
    age <- end_date - max(years)
    if (age <= 10) 1 else if (age <= 20) 0.5 else 0
  } else {
    count <- length(unique(years[end_date - years <= 12]))
    if (count >= 3) 1 else if (count == 2) 0.67 else if (count == 1) 0.33 else 0
  }
}

#' List D4.1 countries for the economist review.
#'
#' For each census and survey indicator, lists the countries of the current
#' derived CSV whose latest census or survey (workbook, normalized catalogue
#' companion and all review vintages) is outside the full-score window for
#' `end_date`: 10 years for censuses (register-based censuses excepted) and
#' the 12-year survey window. Also lists countries where the catalogue
#' companion changes the `end_date` score relative to the workbook and review
#' alone, so a misclassified catalogue study cannot move a score unreviewed.
#'
#' @param params Collection parameters with `raw_dir` and `end_date`.
#' @return A review-candidate data frame.
#' @export
d41_review_candidates <- function(params) {
  end_date <- as.integer(params$end_date)
  paths <- dim4_1_artifact_paths(params$raw_dir, end_date)
  columns <- dim4_1_derived_specs()
  review <- .read_manual_review(params)
  review_file <- basename(paths$review_file)

  rows <- lapply(names(columns), function(stem) {
    column <- columns[[stem]]
    census <- grepl("[.]CEN[.]", stem)
    label <- if (census) "census" else "survey"
    full_window <- if (census) 10L else 12L
    scoring_window <- if (census) 20L else 12L

    derived <- readr::read_csv(
      paths$derived_files[[stem]],
      col_types = readr::cols(.default = readr::col_character()),
      progress = FALSE
    )
    if (!all(c("iso3c", column) %in% names(derived))) {
      stop("D4.1 DERIVED FILE SCHEMA MISMATCH: ", paths$derived_files[[stem]], call. = FALSE)
    }
    companion <- readr::read_csv(
      paths$normalized_companion_files[[stem]],
      col_types = readr::cols(
        iso3c = readr::col_character(),
        indicator_date = readr::col_double(),
        .default = readr::col_character()
      ),
      progress = FALSE
    )
    review_values <- if (column %in% names(review)) {
      review[[column]][match(derived$iso3c, review$iso3c)]
    } else {
      rep(NA_character_, nrow(derived))
    }
    country <- if ("country" %in% names(derived)) derived$country else rep(NA_character_, nrow(derived))

    per_country <- lapply(seq_len(nrow(derived)), function(index) {
      iso3c <- derived$iso3c[[index]]
      workbook_text <- derived[[column]][[index]]
      review_text <- review_values[[index]]
      workbook_years <- .d41_years(workbook_text)
      workbook_years <- workbook_years[workbook_years <= end_date]
      catalogue_years <- as.integer(companion$indicator_date[companion$iso3c == iso3c])
      catalogue_years <- catalogue_years[catalogue_years <= end_date]
      review_years <- .d41_years(review_text)
      years <- sort(unique(c(workbook_years, catalogue_years, review_years[review_years <= end_date])))
      register <- census && end_date >= 2021L && any(grepl(
        "register.*based.*census",
        c(workbook_text, review_text),
        ignore.case = TRUE
      ))
      current <- paste(c(if (register) "Register based census", if (length(years)) .d41_format_years(years)), collapse = ", ")

      reasons <- character()
      hints <- character()
      if (!register) {
        if (length(years) == 0L) {
          reasons <- c(reasons, sprintf("no %s recorded", label))
        } else if (max(years) < end_date - full_window) {
          reasons <- c(reasons, if (census) {
            sprintf("latest census %d is more than 10 years before %d", max(years), end_date)
          } else {
            sprintf("latest survey %d is outside the 12-year window for %d", max(years), end_date)
          })
        }
        if (length(reasons) > 0L) {
          hints <- c(hints, sprintf(
            "Check the NSO website and microdata libraries for a more recent %s; record it with evidence in %s",
            label,
            review_file
          ))
        }
      }
      base_years <- unique(c(workbook_years, review_years[review_years <= end_date]))
      base_score <- .d41_score(base_years, census, register, end_date)
      full_score <- .d41_score(years, census, register, end_date)
      if (!isTRUE(all.equal(base_score, full_score))) {
        lower <- end_date - scoring_window
        added <- setdiff(catalogue_years[catalogue_years >= lower], base_years)
        reasons <- c(reasons, sprintf(
          "catalogue evidence changes the %d score from %s to %s; catalogue-only years in the window: %s",
          end_date,
          format(base_score),
          format(full_score),
          .d41_format_years(added)
        ))
        hints <- c(hints, sprintf(
          "Confirm the catalogue study type and year; correct the workbook or record the evidence in %s",
          review_file
        ))
      }
      if (length(reasons) == 0L) {
        return(NULL)
      }
      data.frame(
        source_id = stem,
        iso3c = iso3c,
        country = country[[index]],
        current_value = if (nzchar(current)) current else NA_character_,
        reason = reasons,
        evidence_hint = hints,
        stringsAsFactors = FALSE
      )
    })
    do.call(rbind, per_country)
  })
  out <- do.call(rbind, rows)
  if (is.null(out)) {
    out <- as.data.frame(
      stats::setNames(replicate(length(.review_candidate_columns), character(), simplify = FALSE), .review_candidate_columns),
      stringsAsFactors = FALSE
    )
  }
  out[.review_candidate_columns]
}

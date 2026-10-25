# =============================================================================
# Revision evidence for the SPI Working Group
# =============================================================================
# Written by the estimation pipeline (revision_report target) next to the
# outputs. Compares the candidate outputs with the previous published vintage:
#   1. indicator revisions 2004 to end_date - 1, per indicator (from the
#      vintage diff, whose CSV lists every changed cell);
#   2. revisions to the overall index and the five pillars for every year the
#      previous index covers, with ranks and overall-index quintiles (the rule
#      of R/quantiles.R);
#   3. the new reference year: coverage of each indicator and how many values
#      equal the previous year, which shows carried-forward and provisional
#      (ODIN) values.
# The release's revision report (docs/revisions/) explains why values
# changed; these files are its evidence.
#
# Created: 2026-10-24
# =============================================================================

#' Files written by the revision report.
#'
#' @param end_date Reference year.
#' @return Named character vector of file names.
#' @export
revision_report_files <- function(end_date) {
  end_date <- as.integer(end_date)
  c(
    summary = sprintf("revision_summary_%d.md", end_date),
    indicators = sprintf("revision_indicators_%d.csv", end_date),
    index = sprintf("revision_index_%d.csv", end_date),
    new_year = sprintf("revision_new_year_%d.csv", end_date)
  )
}

#' Path of the previous published SPI_index file.
#'
#' @param params Pipeline parameters.
#' @return `previous_vintages/SPI_index_<end_date - 1>.csv` under raw_dir.
#' @export
revision_previous_index_path <- function(params) {
  path <- file.path(
    params$raw_dir,
    "previous_vintages",
    sprintf("SPI_index_%d.csv", as.integer(params$end_date) - 1L)
  )
  if (!file.exists(path)) {
    stop(
      "PREVIOUS VINTAGE INDEX NOT FOUND: ", path,
      "\nCopy the SPI_index.csv of the previous published release there ",
      "(docs/user-guide.md, release checklist).",
      call. = FALSE
    )
  }
  manifest <- read_vintage_baseline_manifest(params)
  resolved <- normalizePath(path, winslash = "/", mustWork = TRUE)
  if (!any(resolved == manifest$resolved_files)) {
    stop(
      "PREVIOUS VINTAGE INDEX IS NOT IN THE APPROVED BASELINE MANIFEST: ",
      path,
      call. = FALSE
    )
  }
  path
}

.revision_number <- function(x) suppressWarnings(as.numeric(x))

.revision_same <- function(x, y, tolerance = 1e-9) {
  !is.na(x) & !is.na(y) & abs(x - y) <= tolerance * pmax(1, abs(x), abs(y))
}

.revision_dimension <- function(indicator) {
  sub("^SPI[.](D[0-9]+([.][0-9]+)?).*$", "\\1", indicator)
}

#' Summarise the vintage diff per indicator.
#'
#' @param vintage_diff Data frame from build_vintage_diff() (or its CSV).
#' @return One row per revised indicator: cells, countries, years, direction
#'   and approval status.
#' @export
revision_indicator_summary <- function(vintage_diff) {
  cells <- vintage_diff[vintage_diff$policy %in% c("refresh", "frozen"), , drop = FALSE]
  columns <- c(
    "indicator", "dimension", "policy", "cells", "countries", "first_year", "last_year",
    "increased", "decreased", "added", "removed", "mean_change", "reported", "approved",
    "blocking", "country_codes"
  )
  if (nrow(cells) == 0L) {
    return(as.data.frame(
      stats::setNames(replicate(length(columns), character(), simplify = FALSE), columns),
      stringsAsFactors = FALSE
    ))
  }
  previous <- .revision_number(cells$previous)
  current <- .revision_number(cells$current)
  rows <- lapply(split(seq_len(nrow(cells)), cells$indicator), function(index) {
    before <- previous[index]
    after <- current[index]
    both <- !is.na(before) & !is.na(after)
    data.frame(
      indicator = cells$indicator[[index[[1]]]],
      dimension = cells$dimension[[index[[1]]]],
      policy = cells$policy[[index[[1]]]],
      cells = length(index),
      countries = length(unique(cells$iso3c[index])),
      first_year = min(as.integer(cells$date[index])),
      last_year = max(as.integer(cells$date[index])),
      increased = sum(both & after > before),
      decreased = sum(both & after < before),
      added = sum(is.na(before) & !is.na(after)),
      removed = sum(!is.na(before) & is.na(after)),
      mean_change = if (any(both)) round(mean(after[both] - before[both]), 4) else NA_real_,
      reported = sum(cells$status[index] == "reported"),
      approved = sum(cells$status[index] == "approved"),
      blocking = sum(cells$status[index] == "blocking"),
      country_codes = paste(sort(unique(cells$iso3c[index])), collapse = " "),
      stringsAsFactors = FALSE
    )
  })
  summary <- do.call(rbind, rows)
  summary <- summary[order(summary$dimension, summary$indicator, method = "radix"), , drop = FALSE]
  rownames(summary) <- NULL
  summary
}

# Overall-index quintiles with the rule of R/quantiles.R.
.revision_quintile <- function(values) {
  if (sum(!is.na(values)) < 5L) {
    return(rep(NA_character_, length(values)))
  }
  breaks <- stats::quantile(values, probs = c(0, 0.2, 0.4, 0.6, 0.8, 1), na.rm = TRUE)
  if (anyDuplicated(breaks)) {
    return(rep(NA_character_, length(values)))
  }
  as.character(cut(
    values,
    breaks,
    right = FALSE,
    include.lowest = TRUE,
    labels = c("Bottom 20%", "2nd Quintile", "3rd Quintile", "4th Quintile", "Top Quintile")
  ))
}

#' Compare index scores, ranks and quintiles between two vintages.
#'
#' @param previous_index Previous published SPI_index data.
#' @param current_index Candidate SPI_index data.
#' @param years Years to compare.
#' @return One row per year, measure (overall index and pillars) and country.
#' @export
revision_index_changes <- function(previous_index, current_index, years) {
  measures <- c("SPI.INDEX", paste0("SPI.INDEX.PIL", 1:5))
  measures <- intersect(measures, intersect(names(previous_index), names(current_index)))
  rows <- list()
  for (year in years) {
    for (measure in measures) {
      before <- previous_index[previous_index$date == year, c("iso3c", "country", measure), drop = FALSE]
      after <- current_index[current_index$date == year, c("iso3c", "country", measure), drop = FALSE]
      names(before)[[3]] <- "previous"
      names(after)[[3]] <- "current"
      joined <- merge(before, after, by = "iso3c", all = TRUE, suffixes = c(".previous", ".current"))
      previous <- .revision_number(joined$previous)
      current <- .revision_number(joined$current)
      keep <- !(is.na(previous) & is.na(current))
      if (!any(keep)) next
      joined <- joined[keep, , drop = FALSE]
      previous <- previous[keep]
      current <- current[keep]
      previous_rank <- as.integer(rank(-previous, ties.method = "min", na.last = "keep"))
      current_rank <- as.integer(rank(-current, ties.method = "min", na.last = "keep"))
      overall <- identical(measure, "SPI.INDEX")
      rows[[length(rows) + 1L]] <- data.frame(
        year = as.integer(year),
        measure = measure,
        iso3c = joined$iso3c,
        country = ifelse(is.na(joined$country.current), joined$country.previous, joined$country.current),
        previous = previous,
        current = current,
        change = current - previous,
        previous_rank = previous_rank,
        current_rank = current_rank,
        rank_change = previous_rank - current_rank,
        previous_quintile = if (overall) .revision_quintile(previous) else NA_character_,
        current_quintile = if (overall) .revision_quintile(current) else NA_character_,
        status = ifelse(
          is.na(previous), "added",
          ifelse(is.na(current), "dropped", ifelse(.revision_same(previous, current), "unchanged", "revised"))
        ),
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(rows) == 0L) {
    return(NULL)
  }
  changes <- do.call(rbind, rows)
  changes <- changes[order(changes$year, changes$measure, changes$iso3c, method = "radix"), , drop = FALSE]
  rownames(changes) <- NULL
  changes
}

#' Coverage and change of every indicator in the reference year.
#'
#' @param data Candidate SPI_data.
#' @param end_date Reference year.
#' @param provisional_columns Columns that depend on provisional data (ODIN).
#' @return One row per indicator.
#' @export
revision_new_year_summary <- function(data, end_date, provisional_columns = character()) {
  end_date <- as.integer(end_date)
  indicators <- grep("^SPI[.]D[0-9]", names(data), value = TRUE)
  before <- data[data$date == end_date - 1L, c("iso3c", indicators), drop = FALSE]
  after <- data[data$date == end_date, c("iso3c", indicators), drop = FALSE]
  joined <- merge(before, after, by = "iso3c", all = TRUE, suffixes = c(".before", ".after"))
  rows <- lapply(indicators, function(indicator) {
    previous <- .revision_number(joined[[paste0(indicator, ".before")]])
    current <- .revision_number(joined[[paste0(indicator, ".after")]])
    both <- !is.na(previous) & !is.na(current)
    same <- sum(.revision_same(previous, current))
    changed <- sum(both) - same
    new_values <- sum(is.na(previous) & !is.na(current))
    dropped <- sum(!is.na(previous) & is.na(current))
    countries <- sum(!is.na(current))
    status <- if (indicator %in% provisional_columns) {
      "provisional (ODIN)"
    } else if (countries == 0L) {
      "no values"
    } else if (changed == 0L && new_values == 0L && dropped == 0L) {
      sprintf("identical to %d for every country", end_date - 1L)
    } else {
      "updated"
    }
    data.frame(
      indicator = indicator,
      dimension = .revision_dimension(indicator),
      countries = countries,
      previous_year_countries = sum(!is.na(previous)),
      same_as_previous_year = same,
      changed = changed,
      new_values = new_values,
      dropped_values = dropped,
      status = status,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

.revision_format <- function(x, digits = 1) {
  ifelse(is.na(x), "", formatC(x, format = "f", digits = digits))
}

.revision_table <- function(header, rows) {
  c(
    paste0("| ", paste(header, collapse = " | "), " |"),
    paste0("|", paste(rep("---", length(header)), collapse = "|"), "|"),
    if (length(rows) > 0L) paste0("| ", rows, " |") else character()
  )
}

.revision_markdown <- function(end_date, indicators, index, new_year, previous_index_path,
                               odin_status, vintage_diff_file) {
  previous_year <- end_date - 1L
  lines <- c(
    sprintf("# SPI revision evidence: %d outputs vs the %d vintage", end_date, previous_year),
    "",
    sprintf(
      "Generated by the estimation pipeline (`revision_report`). Previous vintage: `previous_vintages/SPI_data_%d.csv` (indicators) and `%s` (index, SHA-256 `%s`). ODIN status: %s. Cell-level detail: `%s`.",
      previous_year,
      basename(previous_index_path),
      digest::digest(previous_index_path, algo = "sha256", file = TRUE),
      odin_status,
      vintage_diff_file
    ),
    "",
    sprintf("## 1. Indicator revisions, 2004-%d", previous_year),
    ""
  )
  if (nrow(indicators) == 0L) {
    lines <- c(lines, "No indicator values changed.", "")
  } else {
    totals <- vapply(c("refresh", "frozen"), function(policy) sum(as.integer(indicators$cells[indicators$policy == policy])), integer(1))
    lines <- c(
      lines,
      sprintf(
        "%d changed cells in %d indicators: %d in refreshed dimensions (D1.5, D4.1, D4.2; reported), %d in frozen dimensions (D2, D3, D4.3, D5; %d approved, %d awaiting a decision).",
        sum(totals), nrow(indicators), totals[["refresh"]], totals[["frozen"]],
        sum(as.integer(indicators$approved)), sum(as.integer(indicators$blocking))
      ),
      "",
      .revision_table(
        c("Indicator", "Dimension", "Policy", "Cells", "Countries", "Years", "Up", "Down", "New", "Removed", "Status"),
        sprintf(
          "%s | %s | %s | %s | %s | %s-%s | %s | %s | %s | %s | %s",
          indicators$indicator, indicators$dimension, indicators$policy, indicators$cells,
          indicators$countries, indicators$first_year, indicators$last_year, indicators$increased,
          indicators$decreased, indicators$added, indicators$removed,
          ifelse(
            indicators$policy == "refresh",
            "reported",
            paste0(
              ifelse(as.integer(indicators$approved) > 0L, paste0(indicators$approved, " approved "), ""),
              ifelse(as.integer(indicators$blocking) > 0L, paste0(indicators$blocking, " blocking"), "")
            )
          )
        )
      ),
      ""
    )
  }
  lines <- c(lines, sprintf("## 2. Index revisions (%d and earlier)", previous_year), "")
  latest <- if (is.null(index)) NULL else index[index$year == previous_year, , drop = FALSE]
  if (is.null(latest) || nrow(latest) == 0L) {
    lines <- c(
      lines,
      sprintf("Index revisions are not available: the previous index has no %d rows.", previous_year),
      ""
    )
  } else {
    by_measure <- split(latest, latest$measure)
    lines <- c(
      lines,
      sprintf("### %d overall index and pillars, previous vs revised", previous_year),
      "",
      .revision_table(
        c("Measure", "Countries compared", "Revised", "Added", "Dropped", "Mean abs change", "Max abs change", "Rank changes"),
        vapply(names(by_measure), function(measure) {
          rows <- by_measure[[measure]]
          compared <- !is.na(rows$previous) & !is.na(rows$current)
          sprintf(
            "%s | %d | %d | %d | %d | %s | %s | %d",
            measure, sum(compared), sum(rows$status == "revised"), sum(rows$status == "added"),
            sum(rows$status == "dropped"),
            .revision_format(if (any(compared)) mean(abs(rows$change[compared])) else NA_real_, 2),
            .revision_format(if (any(compared)) max(abs(rows$change[compared])) else NA_real_, 2),
            sum(compared & rows$rank_change != 0L, na.rm = TRUE)
          )
        }, character(1))
      ),
      ""
    )
    overall <- latest[latest$measure == "SPI.INDEX" & latest$status == "revised", , drop = FALSE]
    overall <- overall[order(-abs(overall$change), overall$iso3c), , drop = FALSE]
    shown <- utils::head(overall, 20L)
    lines <- c(
      lines,
      sprintf("### Largest revisions to the %d overall SPI score (top %d of %d)", previous_year, nrow(shown), nrow(overall)),
      "",
      .revision_table(
        c("Country", "ISO3", "Previous", "Revised", "Change", "Rank", "Quintile"),
        sprintf(
          "%s | %s | %s | %s | %s | %s to %s | %s",
          shown$country, shown$iso3c, .revision_format(shown$previous), .revision_format(shown$current),
          .revision_format(shown$change), shown$previous_rank, shown$current_rank,
          ifelse(
            shown$previous_quintile == shown$current_quintile | is.na(shown$previous_quintile),
            ifelse(is.na(shown$current_quintile), "", shown$current_quintile),
            paste(shown$previous_quintile, "to", shown$current_quintile)
          )
        )
      ),
      ""
    )
    all_overall <- index[index$measure == "SPI.INDEX", , drop = FALSE]
    by_year <- split(all_overall, all_overall$year)
    lines <- c(
      lines,
      "### Overall SPI score, every year compared",
      "",
      .revision_table(
        c("Year", "Countries compared", "Revised", "Added", "Dropped", "Mean abs change", "Max abs change", "Quintile changes"),
        vapply(names(by_year), function(year) {
          rows <- by_year[[year]]
          compared <- !is.na(rows$previous) & !is.na(rows$current)
          sprintf(
            "%s | %d | %d | %d | %d | %s | %s | %d",
            year, sum(compared), sum(rows$status == "revised"), sum(rows$status == "added"),
            sum(rows$status == "dropped"),
            .revision_format(if (any(compared)) mean(abs(rows$change[compared])) else NA_real_, 2),
            .revision_format(if (any(compared)) max(abs(rows$change[compared])) else NA_real_, 2),
            sum(compared & rows$previous_quintile != rows$current_quintile, na.rm = TRUE)
          )
        }, character(1))
      ),
      ""
    )
  }
  lines <- c(
    lines,
    sprintf("## 3. Reference year %d", end_date),
    "",
    sprintf(
      "Countries with a value, and how %d values compare with the revised %d values of the same run.",
      end_date, previous_year
    ),
    "",
    .revision_table(
      c("Indicator", "Countries", sprintf("Same as %d", previous_year), "Changed", "New", "Dropped", "Status"),
      sprintf(
        "%s | %d | %d | %d | %d | %d | %s",
        new_year$indicator, new_year$countries, new_year$same_as_previous_year, new_year$changed,
        new_year$new_values, new_year$dropped_values, new_year$status
      )
    ),
    ""
  )
  lines
}

#' Write the revision evidence next to the candidate outputs.
#'
#' @param candidate_dir Candidate output directory (with SPI_data.csv,
#'   SPI_index.csv and the vintage-diff CSV).
#' @param previous_index_path Previous published SPI_index file.
#' @param end_date Reference year.
#' @param odin_status ODIN status of the run.
#' @param provisional_columns Output columns that depend on provisional data.
#' @return Named character vector of the written paths.
#' @export
write_revision_report <- function(candidate_dir, previous_index_path, end_date,
                                  odin_status, provisional_columns = character()) {
  end_date <- as.integer(end_date)
  read <- function(path) {
    if (!file.exists(path)) {
      stop("REVISION REPORT INPUT NOT FOUND: ", path, call. = FALSE)
    }
    readr::read_csv(path, show_col_types = FALSE, guess_max = Inf, progress = FALSE)
  }
  vintage_diff_file <- sprintf("vintage_diff_%d.csv", end_date)
  vintage_diff <- readr::read_csv(
    file.path(candidate_dir, vintage_diff_file),
    col_types = readr::cols(.default = readr::col_character()),
    progress = FALSE
  )
  current_data <- read(file.path(candidate_dir, "SPI_data.csv"))
  current_index <- read(file.path(candidate_dir, "SPI_index.csv"))
  previous_index <- read(previous_index_path)

  indicators <- revision_indicator_summary(as.data.frame(vintage_diff, stringsAsFactors = FALSE))
  years <- sort(intersect(unique(previous_index$date), unique(current_index$date)))
  years <- years[years < end_date]
  index <- revision_index_changes(previous_index, current_index, years)
  new_year <- revision_new_year_summary(current_data, end_date, provisional_columns)

  files <- revision_report_files(end_date)
  paths <- stats::setNames(file.path(candidate_dir, files), names(files))
  readr::write_csv(indicators, paths[["indicators"]], na = "")
  index_columns <- c(
    "year", "measure", "iso3c", "country", "previous", "current", "change", "previous_rank",
    "current_rank", "rank_change", "previous_quintile", "current_quintile", "status"
  )
  readr::write_csv(
    if (is.null(index)) {
      as.data.frame(stats::setNames(replicate(length(index_columns), character(), simplify = FALSE), index_columns))
    } else {
      index
    },
    paths[["index"]],
    na = ""
  )
  readr::write_csv(new_year, paths[["new_year"]], na = "")
  writeLines(
    .revision_markdown(end_date, indicators, index, new_year, previous_index_path, odin_status, vintage_diff_file),
    paths[["summary"]]
  )
  paths
}

# =============================================================================
# JMP safely managed drinking water collection (SPI.D1.5.SAFE.MAN.WATER)
# =============================================================================
# Port of hyper_read() in 02_programs/01-SPI_data_prep.Rmd (chunk
# `safely_managed`). Each country workbook comes from
#   https://washdata.org/data/country/<ISO3>/household/download
# Only its "Data Summary" sheet is cached (every cell as text, which preserves
# numbers exactly); the workbook URL, SHA-256 and size go in the provenance
# record and the workbook itself is not kept.
#
# The sheet is transformed exactly as the original code, including two
# documented behaviours of the current method (missing data credited as full
# coverage; national columns read by the `_n` suffix). See
# docs/jmp-safely-managed-water-brief.md before changing them.
#
# Created: 2026-09-22 (rewritten 2026-10-23 for the 202611 update)
# =============================================================================

# The pipe operator (%>%) comes from magrittr (loaded via tidyverse in the
# original Rmds). We import it explicitly so this file is self-contained.
`%>%` <- magrittr::`%>%`

# dplyr functions (if_else, case_when, etc.) are used unqualified throughout
# the pipeline files, matching the tidyverse style of the original Rmds.
library(dplyr)

.jmp_sheet <- "Data Summary"

#' Return the JMP country download URL.
#'
#' Kosovo uses the Serbia file, as in the original code.
#'
#' @param iso3c Character country code.
#' @return Character URL.
#' @export
jmp_country_url <- function(iso3c) {
  if (iso3c == "XKX") {
    return("https://washdata.org/data/country/SRB/household/download")
  }
  sprintf("https://washdata.org/data/country/%s/household/download", iso3c)
}

#' Download a JMP country workbook to a file.
#'
#' @param url Workbook URL.
#' @param destfile Destination path.
#' @param timeout HTTP timeout in seconds.
#' @return A list with the `effective_url` after redirects.
#' @export
jmp_download_workbook <- function(url, destfile, timeout = 300) {
  response <- with_http_retry(function() {
    httr::GET(url, httr::write_disk(destfile, overwrite = TRUE), httr::timeout(timeout))
  })
  if (httr::status_code(response) != 200) {
    stop(sprintf("JMP DOWNLOAD FAILED: HTTP %d for %s", httr::status_code(response), url), call. = FALSE)
  }
  list(effective_url = response$url)
}

#' Read every cell of a workbook sheet as text.
#'
#' @param path Workbook path.
#' @param sheet Sheet name.
#' @return A tibble of character columns without names.
#' @export
jmp_read_sheet_text <- function(path, sheet = .jmp_sheet) {
  if (!sheet %in% readxl::excel_sheets(path)) {
    stop(sprintf("JMP WORKBOOK HAS NO '%s' SHEET: %s", sheet, path), call. = FALSE)
  }
  readxl::read_excel(path, sheet = sheet, col_names = FALSE, col_types = "text", .name_repair = "minimal")
}

#' Serialise a text sheet to CSV bytes (empty cells written as empty fields).
#'
#' @param sheet Tibble from [jmp_read_sheet_text()].
#' @return Raw CSV bytes.
#' @export
jmp_sheet_csv <- function(sheet) {
  sheet <- as.data.frame(sheet, stringsAsFactors = FALSE, optional = TRUE)
  names(sheet) <- paste0("X", seq_along(sheet))
  charToRaw(enc2utf8(readr::format_csv(sheet, col_names = FALSE, na = "", quote = "all")))
}

#' Read a cached "Data Summary" sheet.
#'
#' @param path Cached CSV path.
#' @return A tibble of character columns.
#' @export
jmp_read_cached_sheet <- function(path) {
  readr::read_csv(
    path,
    col_names = FALSE,
    col_types = readr::cols(.default = readr::col_character()),
    na = "",
    trim_ws = FALSE,
    skip_empty_rows = FALSE,
    progress = FALSE
  )
}

#' Read the release stamp ("Updated <month year>") from a workbook.
#'
#' @param path Workbook path.
#' @return The stamp, or NA when the workbook has none.
#' @export
jmp_release_stamp <- function(path) {
  if (!"Introduction" %in% readxl::excel_sheets(path)) {
    return(NA_character_)
  }
  cells <- unlist(jmp_read_sheet_text(path, "Introduction"), use.names = FALSE)
  stamp <- grep("^\\s*Updated\\s", cells, value = TRUE)
  if (length(stamp) == 0L) NA_character_ else trimws(stamp[[1]])
}

#' Fetch one country's "Data Summary" sheet with the workbook identity.
#'
#' @param iso3c Character country code.
#' @param download_fn Function `(url, destfile)` that downloads the workbook.
#' @return A [collection_payload()] with the sheet CSV and workbook metadata.
#' @export
jmp_fetch_data_summary <- function(iso3c, download_fn = jmp_download_workbook) {
  url <- jmp_country_url(iso3c)
  workbook <- tempfile(fileext = ".xlsx")
  on.exit(unlink(workbook), add = TRUE)
  download <- download_fn(url, workbook)
  effective_url <- if (is.null(download$effective_url)) url else download$effective_url
  collection_payload(
    jmp_sheet_csv(jmp_read_sheet_text(workbook)),
    list(
      sheet = .jmp_sheet,
      workbook_url = url,
      workbook_effective_url = effective_url,
      workbook_sha256 = digest::digest(workbook, algo = "sha256", file = TRUE),
      workbook_bytes = file.size(workbook),
      jmp_release = jmp_release_stamp(workbook)
    )
  )
}

#' Transform one "Data Summary" sheet as hyper_read() does.
#'
#' @param sheet Text sheet from [jmp_read_sheet_text()] or
#'   [jmp_read_cached_sheet()].
#' @param iso3c Character country code (for messages and output).
#' @param end_date Last year of the year template (2000 to end_date).
#' @return One row per source, year and area, plus template rows, with
#'   `data_available`, `data_quality`, `data_value` and `max_value`.
#' @export
parse_jmp_data_summary <- function(sheet, iso3c, end_date) {
  sheet <- as.data.frame(sheet, stringsAsFactors = FALSE, optional = TRUE)
  header_row <- which(apply(sheet, 1, function(row) all(c("source", "type", "year") %in% row)))
  if (length(header_row) != 1L) {
    stop(
      sprintf("JMP DATA SUMMARY HEADER ROW NOT FOUND for %s (expected one row with the source, type and year codes).", iso3c),
      call. = FALSE
    )
  }
  # read_excel() repairs header names to unique ones; mirror it so columns
  # resolve exactly as in the original call.
  header <- as.character(unlist(sheet[header_row, ], use.names = FALSE))
  header[is.na(header)] <- ""
  names(sheet) <- vctrs::vec_as_names(header, repair = "unique", quiet = TRUE)
  data <- sheet[-seq_len(header_row), , drop = FALSE]

  water <- grep("^w_", names(data), value = TRUE)
  if (!any(grepl("_u$", water)) || !any(grepl("_r$", water))) {
    stop(sprintf("JMP DATA SUMMARY HAS NO URBAN AND RURAL WATER COLUMNS for %s.", iso3c), call. = FALSE)
  }
  year <- suppressWarnings(as.numeric(data$year))
  bad_year <- !is.na(data$year) & is.na(year)
  if (any(bad_year)) {
    stop(
      sprintf("JMP DATA SUMMARY HAS NON-NUMERIC YEARS for %s: %s", iso3c, paste(unique(data$year[bad_year]), collapse = ", ")),
      call. = FALSE
    )
  }

  span <- c(2000:end_date)
  template <- data.frame(geo = c("National", "Rural", "Urban"))
  empty_years <- dplyr::bind_rows(replicate(length(span), template, simplify = FALSE), .id = "year") %>%
    dplyr::mutate(year = as.numeric(year) + span[1] - 1)

  tibble::tibble(source = data$source, type = data$type, year = year) %>%
    dplyr::bind_cols(data[, water, drop = FALSE]) %>%
    dplyr::filter(!is.na(year)) %>%
    tidyr::pivot_longer(cols = dplyr::all_of(water), names_to = "label", values_to = "value") %>%
    dplyr::mutate(geo = dplyr::case_when(
      grepl("_n$", label) ~ "National",
      grepl("_u$", label) ~ "Urban",
      grepl("_r$", label) ~ "Rural"
    )) %>%
    dplyr::mutate(data_available = dplyr::if_else(!is.na(value), 1, 0)) %>%
    # Values in brackets were not used in the JMP estimates.
    dplyr::mutate(data_quality = dplyr::if_else((!grepl("\\[", value) & data_available == 1), 1, 0)) %>%
    dplyr::group_by(source, type, year, geo) %>%
    dplyr::summarise(
      # Countries without sources reach summarise() with no rows, where
      # max() warns on empty input (as in the original); nothing is lost.
      data_available = suppressWarnings(max(data_available, na.rm = TRUE)),
      data_quality = suppressWarnings(max(data_quality, na.rm = TRUE)),
      data_value = suppressWarnings(mean(as.numeric(value), na.rm = TRUE)),
      .groups = "drop"
    ) %>%
    dplyr::right_join(empty_years, by = c("year", "geo")) %>%
    dplyr::group_by(geo) %>%
    # JMP carries estimates forward once coverage passes 99.5%. As in the
    # original code, an area without data (-99) also meets this rule.
    dplyr::mutate(
      max_value = suppressWarnings(max(data_value, na.rm = TRUE)),
      has_observed_value = max_value != -Inf,
      max_value = dplyr::if_else(has_observed_value, max_value, -99),
      data_quality = dplyr::if_else(
        has_observed_value & (max_value >= 99.5 | max_value <= 0.5),
        1,
        dplyr::coalesce(as.numeric(data_quality), 0)
      )
    ) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(type = as.character(type)) %>%
    dplyr::select(-has_observed_value)
}

#' Collect the JMP country files and write Safely_Managed_Water_data.csv.
#'
#' @param params Pipeline parameters (`raw_dir`, `end_date`,
#'   `collection_age_warning_days`, `collection_dir`).
#' @param country_metadata Saved country snapshot; defaults to
#'   `params$country_metadata` or the collection snapshot on disk.
#' @param fetch_fn Function `(iso3c)` returning the cached payload; defaults to
#'   [jmp_fetch_data_summary()].
#' @return A list with the output `path`, `rows`, `countries` and
#'   `release_identifier`.
#' @export
pull_jmp_water <- function(params, country_metadata = NULL, fetch_fn = jmp_fetch_data_summary) {
  if (is.null(country_metadata)) {
    country_metadata <- params$country_metadata
  }
  if (is.null(country_metadata) || nrow(country_metadata) == 0L) {
    country_path <- file.path(params$collection_dir, "world_bank", "country_metadata.rds")
    if (!file.exists(country_path)) {
      stop(
        "WORLD BANK COUNTRY COLLECTION ARTIFACT NOT FOUND: ", country_path,
        "\nRun world bank collection before JMP collection.",
        call. = FALSE
      )
    }
    country_metadata <- readRDS(country_path)
  }
  countries <- country_metadata %>%
    dplyr::filter(region != "Aggregates") %>%
    dplyr::mutate(hyperlink = vapply(iso3c, jmp_country_url, character(1)))
  max_age_days <- if (is.null(params$collection_age_warning_days)) Inf else params$collection_age_warning_days

  message("Collecting JMP 'Data Summary' sheets for ", nrow(countries), " countries...")
  records <- lapply(countries$iso3c, function(iso3c) {
    collect_cached_raw(
      cache_dir = file.path(params$raw_dir, "1.5_DUIO", "raw", "jmp"),
      source_id = paste0("jmp_", iso3c),
      request = list(endpoint = jmp_country_url(iso3c), iso3c = iso3c, sheet = .jmp_sheet),
      vintage = params$end_date,
      collector_version = "jmp-data-summary-v1",
      fetch = function() fetch_fn(iso3c),
      max_age_days = max_age_days
    )
  })

  combined <- dplyr::bind_rows(lapply(seq_len(nrow(countries)), function(i) {
    parsed <- parse_jmp_data_summary(
      jmp_read_cached_sheet(records[[i]]$raw_path),
      countries$iso3c[[i]],
      params$end_date
    )
    dplyr::bind_cols(countries[rep(i, nrow(parsed)), , drop = FALSE], parsed)
  }))

  out_path <- file.path(params$raw_dir, "1.5_DUIO", "Safely_Managed_Water_data.csv")
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  readr::write_excel_csv(combined, out_path)

  retrieved <- vapply(records, function(record) as.character(record$retrieved_at), character(1))
  releases <- unique(stats::na.omit(vapply(records, function(record) {
    if (is.null(record$jmp_release)) NA_character_ else as.character(record$jmp_release)
  }, character(1))))
  release_identifier <- sprintf(
    "JMP country files, %s (retrieved %s)",
    if (length(releases) > 0L) paste(releases, collapse = "; ") else "release unstamped",
    paste(unique(range(substr(retrieved, 1, 10))), collapse = " to ")
  )
  write_artifact_provenance(
    out_path,
    source_id = "d1_5_jmp",
    retrieved_at = min(retrieved),
    release_identifier = release_identifier,
    raw_path = file.path(params$raw_dir, "1.5_DUIO", "raw", "jmp"),
    extra = list(countries = nrow(countries), jmp_release = releases)
  )
  message(sprintf("JMP water data written to %s (%d rows)", out_path, nrow(combined)))
  list(
    path = normalizePath(out_path, winslash = "/", mustWork = FALSE),
    rows = nrow(combined),
    countries = nrow(countries),
    release_identifier = release_identifier
  )
}

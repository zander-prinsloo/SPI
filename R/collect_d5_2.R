# =============================================================================
# D5.2 annual source files (EMPL 5.2.6, CNIN 5.2.3, FINA 5.2.8)
# =============================================================================
# Builds the current vintage's D5.2 input files in 01_raw_data/5.2_DISM/ from
# the previous vintage and the documented sources, replacing the manual
# notebook steps (02_programs/misc_scripts/imf_dsbb_scrape.ipynb). Earlier
# vintages are never rewritten.
#
# Created: 2026-10-23
# =============================================================================

`%>%` <- magrittr::`%>%`

.d5_2_dir <- function(params) file.path(params$raw_dir, "5.2_DISM")

.read_d5_2_previous <- function(params, stem) {
  path <- file.path(.d5_2_dir(params), sprintf("%s.%d.csv", stem, as.integer(params$end_date) - 1L))
  if (!file.exists(path)) {
    stop("D5.2 PREVIOUS VINTAGE NOT FOUND: ", path, call. = FALSE)
  }
  readr::read_csv(path, show_col_types = FALSE)
}

.require_columns <- function(data, columns, what) {
  missing <- setdiff(columns, names(data))
  if (length(missing) > 0L) {
    stop(sprintf("%s SCHEMA MISMATCH: missing %s", what, paste(missing, collapse = ", ")), call. = FALSE)
  }
  invisible(TRUE)
}

#' Build the EMPL (5.2.6) vintage from the previous file and the ILO catalogue.
#'
#' Port of cell 10 of imf_dsbb_scrape.ipynb: labour force surveys in the ILO
#' national sources catalogue are mapped to ISO3 through ILO_reference_area.csv
#' and flagged when "International classifications" mentions ICSE; the flag is
#' the maximum per country, and `ISCE` is the higher of the previous `ISCE`
#' and that flag (a flag is never lowered). Catalogue countries that do not
#' map to an ISO3 code are dropped, as in the notebook, and reported.
#'
#' @param previous Previous vintage (`iso3c`, `Country`, `ISCE`).
#' @param catalogue ILO national sources catalogue.
#' @param reference_area ILO reference areas (`ref_area`, `ref_area.label`).
#' @return A list with `data` (`iso3c, Country, ISCE, ISCE_previous,
#'   ISCE_catalogue`), `unmatched` catalogue countries and `changed` countries
#'   whose flag rose.
#' @export
build_empl_vintage <- function(previous, catalogue, reference_area) {
  names(reference_area) <- trimws(names(reference_area))
  .require_columns(previous, c("iso3c", "Country", "ISCE"), "EMPL PREVIOUS VINTAGE")
  .require_columns(catalogue, c("Source type", "Country", "International classifications"), "ILO SOURCES CATALOGUE")
  .require_columns(reference_area, c("ref_area", "ref_area.label"), "ILO REFERENCE AREAS")

  codes <- reference_area %>%
    dplyr::transmute(Country = as.character(ref_area.label), iso3c = as.character(ref_area))
  surveys <- catalogue %>%
    dplyr::filter(`Source type` == "Labour force survey") %>%
    dplyr::left_join(codes, by = "Country", relationship = "many-to-many") %>%
    dplyr::mutate(flag = as.integer(grepl("ICSE", as.character(`International classifications`))))
  catalogue_flags <- surveys %>%
    dplyr::filter(!is.na(iso3c)) %>%
    dplyr::group_by(iso3c) %>%
    dplyr::summarise(ISCE_catalogue = max(flag), .groups = "drop")

  data <- previous %>%
    dplyr::transmute(iso3c = as.character(iso3c), Country = as.character(Country), ISCE_previous = as.numeric(ISCE)) %>%
    dplyr::left_join(catalogue_flags, by = "iso3c") %>%
    dplyr::mutate(ISCE = pmax(ISCE_previous, ISCE_catalogue, na.rm = TRUE)) %>%
    dplyr::select(iso3c, Country, ISCE, ISCE_previous, ISCE_catalogue)

  list(
    data = data,
    unmatched = sort(unique(surveys$Country[is.na(surveys$iso3c)])),
    changed = data$iso3c[!is.na(data$ISCE) & (is.na(data$ISCE_previous) | data$ISCE != data$ISCE_previous)]
  )
}

#' EMPL countries for review: raised flags and unmapped catalogue countries.
#'
#' @param result Output of [build_empl_vintage()].
#' @return Candidate rows (`iso3c` is NA for unmapped catalogue countries).
#' @export
empl_candidates <- function(result) {
  raised <- result$data[result$data$iso3c %in% result$changed, , drop = FALSE]
  out <- rbind(
    data.frame(
      source_id = rep("d5_2_empl", nrow(raised)),
      iso3c = raised$iso3c,
      country = raised$Country,
      current_value = as.character(raised$ISCE),
      reason = rep("ILO catalogue raised the ISCE flag", nrow(raised)),
      evidence_hint = rep("ILOSTAT national sources catalogue entry for the labour force survey", nrow(raised)),
      stringsAsFactors = FALSE
    ),
    data.frame(
      source_id = rep("d5_2_empl", length(result$unmatched)),
      iso3c = rep(NA_character_, length(result$unmatched)),
      country = result$unmatched,
      current_value = rep(NA_character_, length(result$unmatched)),
      reason = rep("ILO catalogue country not mapped to ISO3 (dropped, as in the notebook)", length(result$unmatched)),
      evidence_hint = rep("ILO_reference_area.csv label versus the catalogue Country name", length(result$unmatched)),
      stringsAsFactors = FALSE
    )
  )
  out[order(out$country), , drop = FALSE]
}

#' Write the EMPL (5.2.6) file for the current vintage.
#'
#' @param params Pipeline parameters (`raw_dir`, `end_date`).
#' @return A list with the output `path`, `unmatched` and `changed` countries.
#' @export
collect_empl_vintage <- function(params) {
  catalogue_path <- file.path(params$raw_dir, "4.1_SOCS", "ilo_sources_catalog.csv")
  reference_path <- file.path(params$raw_dir, "metadata", "ILO_reference_area.csv")
  for (path in c(catalogue_path, reference_path)) {
    if (!file.exists(path)) stop("EMPL INPUT NOT FOUND: ", path, call. = FALSE)
  }
  previous <- .read_d5_2_previous(params, "D5.2.6.EMPL")
  result <- build_empl_vintage(
    previous,
    readr::read_csv(catalogue_path, show_col_types = FALSE),
    readr::read_csv(reference_path, show_col_types = FALSE)
  )
  if (length(result$unmatched) > 0L) {
    warning(
      "EMPL: ILO catalogue countries without an ISO3 code were dropped (as in the notebook): ",
      paste(result$unmatched, collapse = "; "),
      call. = FALSE
    )
  }
  out_path <- file.path(.d5_2_dir(params), sprintf("D5.2.6.EMPL.%d.csv", as.integer(params$end_date)))
  readr::write_csv(result$data, out_path, na = "")
  write_artifact_provenance(
    out_path,
    source_id = "d5_2_empl",
    retrieved_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    extra = list(
      catalogue_sha256 = digest::digest(catalogue_path, algo = "sha256", file = TRUE),
      unmatched_catalogue_countries = result$unmatched,
      raised_flags = result$changed
    )
  )
  list(
    path = normalizePath(out_path, winslash = "/", mustWork = FALSE),
    unmatched = result$unmatched,
    changed = result$changed,
    candidates = empl_candidates(result)
  )
}

# --- CNIN (5.2.3) and FINA (5.2.8): carry-forward with a per-vintage review ---

.fina_review_values <- c("2014", "ESA 2010", "2001", "1986", "other")
.candidate_columns <- c("source_id", "iso3c", "country", "current_value", "reason", "evidence_hint")

.year_columns <- function(data) grep("^[0-9]{4}$", names(data), value = TRUE)

.empty_candidates <- function() {
  as.data.frame(
    stats::setNames(replicate(length(.candidate_columns), character(), simplify = FALSE), .candidate_columns),
    stringsAsFactors = FALSE
  )
}

.validated_review <- function(review, spec, valid_iso3c) {
  validate_manual_review(review, spec, valid_iso3c = valid_iso3c)
  for (column in c("iso3c", spec$value_columns, spec$evidence_column)) {
    review[[column]] <- .manual_review_normalize(review[[column]])
  }
  review
}

#' Classification values observed in the CNIN files and historical review.
#'
#' @param previous Previous CNIN vintage.
#' @param historical_review Historical review workbook data, or NULL.
#' @return Sorted unique non-blank values.
#' @export
cnin_vocabulary <- function(previous, historical_review = NULL) {
  values <- unlist(lapply(previous[.year_columns(previous)], as.character), use.names = FALSE)
  if (!is.null(historical_review)) {
    values <- c(values, unlist(lapply(historical_review[.year_columns(historical_review)], as.character), use.names = FALSE))
  }
  values <- trimws(values)
  sort(unique(values[!is.na(values) & nzchar(values)]))
}

#' Review contract for the CNIN vintage (values from the observed vocabulary).
#'
#' @param vocabulary Allowed values from [cnin_vocabulary()].
#' @return A [manual_review_spec()].
#' @export
cnin_review_spec <- function(vocabulary) {
  manual_review_spec("CNIN", "CNIN", list(CNIN = function(values) values %in% vocabulary))
}

#' Validate the historical CNIN review workbook used for carry-forward.
#'
#' @param historical Historical review workbook.
#' @param valid_iso3c ISO3 codes in the previous vintage.
#' @return Invisibly returns TRUE.
#' @export
validate_cnin_historical_review <- function(historical, valid_iso3c) {
  required <- c("iso3c", "country", "Evidence")
  missing <- setdiff(required, names(historical))
  if (length(missing) > 0L) {
    stop(
      "CNIN HISTORICAL REVIEW SCHEMA MISMATCH: missing ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  years <- .year_columns(historical)
  if (length(years) == 0L) {
    stop("CNIN HISTORICAL REVIEW HAS NO YEAR COLUMNS.", call. = FALSE)
  }
  keys <- trimws(as.character(historical$iso3c))
  if (anyNA(keys) || any(!nzchar(keys)) || anyDuplicated(keys) > 0L) {
    stop("CNIN HISTORICAL REVIEW HAS BLANK OR DUPLICATE COUNTRY KEYS.", call. = FALSE)
  }
  has_override <- apply(
    as.data.frame(historical[years]),
    1,
    function(row) any(!is.na(row) & nzchar(trimws(as.character(row))))
  )
  evidence <- trimws(as.character(historical$Evidence))
  unknown <- setdiff(keys[has_override], as.character(valid_iso3c))
  if (length(unknown) > 0L) {
    stop(
      "CNIN HISTORICAL REVIEW HAS UNKNOWN COUNTRY KEYS: ",
      paste(sort(unknown), collapse = ", "),
      call. = FALSE
    )
  }
  if (any(has_override & (is.na(evidence) | !nzchar(evidence)))) {
    stop("CNIN HISTORICAL REVIEW OVERRIDES REQUIRE EVIDENCE.", call. = FALSE)
  }
  invisible(TRUE)
}

#' Review contract for the FINA vintage.
#'
#' @return A [manual_review_spec()].
#' @export
fina_review_spec <- function() {
  manual_review_spec("FINA", "FINA", list(FINA = function(values) values %in% .fina_review_values))
}

#' Build the CNIN vintage: previous year carried forward, then reviewed.
#'
#' The carried value is the previous year as published: where the historical
#' review workbook overrides that year, its value is carried, so a verified
#' correction is not undone in the new year.
#'
#' @param previous Previous vintage (`Code`, `Country`, 2020 to end_date - 1).
#' @param review Review rows (`iso3c`, `country`, `CNIN`, `Evidence`).
#' @param end_date Current reference year.
#' @param vocabulary Allowed review values.
#' @param historical_review Historical review workbook data, or NULL.
#' @return A list with `data` (`Code`, `Country`, 2020 to end_date), the
#'   applied `overrides` and the countries whose historical override was
#'   `carried`.
#' @export
build_cnin_vintage <- function(previous, review, end_date, vocabulary, historical_review = NULL) {
  year <- as.character(end_date)
  year_columns <- as.character(2020:(end_date - 1))
  .require_columns(previous, c("Code", "Country", year_columns), "CNIN PREVIOUS VINTAGE")
  spec <- cnin_review_spec(vocabulary)
  review <- .validated_review(review, spec, previous$Code)
  if (!is.null(historical_review)) {
    validate_cnin_historical_review(historical_review, previous$Code)
  }

  data <- as.data.frame(previous[c("Code", "Country", year_columns)], stringsAsFactors = FALSE, optional = TRUE)
  for (column in year_columns) data[[column]] <- as.character(data[[column]])
  last <- as.character(end_date - 1)
  data[[year]] <- data[[last]]
  carried <- character()
  if (!is.null(historical_review) && last %in% names(historical_review)) {
    # Same normalisation score_cnin() applies to the historical review.
    historical <- stringr::str_squish(as.character(historical_review[[last]]))
    historical[!is.na(historical) & !nzchar(historical)] <- NA_character_
    value <- historical[match(data$Code, as.character(historical_review$iso3c))]
    carried <- data$Code[!is.na(value)]
    data[[year]][!is.na(value)] <- value[!is.na(value)]
  }
  applied <- apply_manual_review(
    data.frame(iso3c = data$Code, CNIN = data[[year]], stringsAsFactors = FALSE),
    review,
    spec
  )
  data[[year]] <- applied$data$CNIN
  list(data = data, overrides = applied$overrides, carried = carried)
}

#' Build the FINA vintage: previous value carried forward, then reviewed.
#'
#' @param previous Previous vintage (`Code`, `Country`, `FINA`).
#' @param review Review rows (`iso3c`, `country`, `FINA`, `Evidence`).
#' @return A list with `data` (`Code`, `Country`, `FINA`) and the applied
#'   `overrides`.
#' @export
build_fina_vintage <- function(previous, review) {
  .require_columns(previous, c("Code", "Country", "FINA"), "FINA PREVIOUS VINTAGE")
  spec <- fina_review_spec()
  review <- .validated_review(review, spec, previous$Code)
  data <- data.frame(
    Code = as.character(previous$Code),
    Country = as.character(previous$Country),
    FINA = as.character(previous$FINA),
    stringsAsFactors = FALSE
  )
  applied <- apply_manual_review(data.frame(iso3c = data$Code, FINA = data$FINA, stringsAsFactors = FALSE), review, spec)
  data$FINA <- applied$data$FINA
  list(data = data, overrides = applied$overrides)
}

#' Create a blank per-vintage review workbook unless it already exists.
#'
#' @param path Workbook path.
#' @param countries Data frame with `iso3c` and `country`.
#' @param value_column Name of the reviewed value column.
#' @return Invisibly TRUE when a template was written.
#' @export
write_review_template <- function(path, countries, value_column) {
  if (file.exists(path)) {
    return(invisible(FALSE))
  }
  template <- data.frame(iso3c = countries$iso3c, country = countries$country, stringsAsFactors = FALSE)
  template[[value_column]] <- NA_character_
  template$Evidence <- NA_character_
  writexl::write_xlsx(template, path)
  invisible(TRUE)
}

.candidate_frame <- function(source_id, iso3c, country, value, reasons, hint) {
  keep <- nzchar(reasons)
  out <- data.frame(
    source_id = rep(source_id, sum(keep)),
    iso3c = iso3c[keep],
    country = country[keep],
    current_value = value[keep],
    reason = reasons[keep],
    evidence_hint = rep(hint, sum(keep)),
    stringsAsFactors = FALSE
  )
  out[order(out$iso3c), , drop = FALSE]
}

.join_reasons <- function(...) {
  parts <- list(...)
  vapply(seq_along(parts[[1]]), function(i) {
    paste(Filter(nzchar, vapply(parts, function(p) p[[i]], character(1))), collapse = "; ")
  }, character(1))
}

#' CNIN countries for the technical lead to review.
#'
#' @param data Built CNIN vintage.
#' @param end_date Current reference year.
#' @param historical_review Historical review workbook data, or NULL.
#' @return Candidate rows (`source_id, iso3c, country, current_value, reason,
#'   evidence_hint`).
#' @export
cnin_candidates <- function(data, end_date, historical_review = NULL) {
  values <- data[[as.character(end_date)]]
  not_scored <- is.na(values) | !tolower(trimws(values)) %in% c("rev4", "nace rev2")
  overridden <- character()
  if (!is.null(historical_review) && nrow(historical_review) > 0L) {
    years <- .year_columns(historical_review)
    has_value <- apply(as.data.frame(historical_review[years]), 1, function(row) any(!is.na(row) & nzchar(trimws(as.character(row)))))
    overridden <- as.character(historical_review$iso3c[has_value])
  }
  reasons <- .join_reasons(
    ifelse(not_scored, "value is not Rev.4 or NACE Rev.2", ""),
    ifelse(data$Code %in% overridden, "historical override in D5.2.3.CNIN.Manual.Review.xlsx", "")
  )
  .candidate_frame(
    "d5_2_cnin", data$Code, data$Country, values, reasons,
    "NSO or IMF DSBB documentation of the industry classification (ISIC Rev.4 or NACE Rev.2)"
  )
}

#' FINA countries for the technical lead to review.
#'
#' @param data Built FINA vintage.
#' @param previous_text,current_text IMF GFS metadata text from
#'   [read_imf_gfs_text()] for the previous and current workbooks, or NULL.
#' @return Candidate rows.
#' @export
fina_candidates <- function(data, previous_text = NULL, current_text = NULL) {
  values <- data$FINA
  scored <- !is.na(values) & values %in% c("2014", "ESA 2010")
  blank_like <- is.na(values) | !nzchar(trimws(values)) | values %in% c("other", "Not Found")
  changed <- mentions <- rep(FALSE, nrow(data))
  if (!is.null(previous_text) && !is.null(current_text)) {
    before <- previous_text$common[match(data$Code, previous_text$iso3c)]
    after <- current_text$common[match(data$Code, current_text$iso3c)]
    all_after <- current_text$all[match(data$Code, current_text$iso3c)]
    changed <- !is.na(after) & (is.na(before) | before != after)
    mentions <- !is.na(all_after) & grepl("GFSM 2014", all_after, fixed = TRUE)
  }
  reasons <- .join_reasons(
    ifelse(!scored & changed, "IMF GFS text changed since the previous workbook", ""),
    ifelse(!scored & mentions, "IMF GFS text mentions GFSM 2014", ""),
    ifelse(blank_like, "value is blank, other or Not Found", "")
  )
  .candidate_frame(
    "d5_2_fina", data$Code, data$Country, values, reasons,
    "IMF GFS metadata (sheet 5 of the compiled workbook) or the GFS Yearbook"
  )
}

#' Read the IMF GFS compilation text (sheet 5) per ISO3.
#'
#' @param path Compiled IMF workbook.
#' @param codes IMF country codes (`IMF_code`, `iso3c`).
#' @param common_columns Prefixes of the text sections compared between
#'   workbooks (sections present in both editions).
#' @return A data frame with `iso3c`, `common` (compared sections) and `all`
#'   (every section).
#' @export
read_imf_gfs_text <- function(path, codes, common_columns = c("3.1", "3.2")) {
  sheet <- readxl::read_excel(path, sheet = "5. Comp of Gvt Fin Stats", skip = 1, col_types = "text")
  .require_columns(sheet, c("Code", "Country"), "IMF GFS SHEET")
  text_columns <- setdiff(names(sheet), c("Code", "Country"))
  text_columns <- text_columns[!grepl("^Metadata confirmed", text_columns)]
  common <- text_columns[vapply(text_columns, function(n) any(startsWith(n, common_columns)), logical(1))]
  collapse <- function(columns) {
    if (length(columns) == 0L) return(rep(NA_character_, nrow(sheet)))
    apply(as.data.frame(sheet[columns]), 1, function(row) paste(ifelse(is.na(row), "", trimws(row)), collapse = " | "))
  }
  out <- data.frame(
    iso3c = as.character(codes$iso3c[match(trimws(sheet$Code), as.character(codes$IMF_code))]),
    common = collapse(common),
    all = collapse(text_columns),
    stringsAsFactors = FALSE
  )
  out <- out[!is.na(out$iso3c), , drop = FALSE]
  out[!duplicated(out$iso3c), , drop = FALSE]
}

.imf_text_for_fina <- function(params) {
  codes_path <- file.path(params$raw_dir, "metadata", "IMF_country_codes.csv")
  files <- c(params$imf_file_2024, params$imf_file)
  if (length(files) != 2L || !file.exists(codes_path)) {
    stop("FINA CANDIDATES NEED imf_file, imf_file_2024 AND metadata/IMF_country_codes.csv.", call. = FALSE)
  }
  codes <- readr::read_csv(codes_path, show_col_types = FALSE)
  list(
    previous = read_imf_gfs_text(file.path(.d5_2_dir(params), params$imf_file_2024), codes),
    current = read_imf_gfs_text(file.path(.d5_2_dir(params), params$imf_file), codes)
  )
}

.write_d5_2_output <- function(params, stem, data, source_id, review_path, review, overrides,
                               extra = list()) {
  out_path <- file.path(.d5_2_dir(params), sprintf("%s.%d.csv", stem, as.integer(params$end_date)))
  readr::write_csv(data, out_path, na = "")
  provenance <- c(
    list(review = manual_review_metadata(review_path, review, overrides)),
    extra
  )
  write_artifact_provenance(
    out_path,
    source_id = source_id,
    retrieved_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    extra = provenance
  )
  normalizePath(out_path, winslash = "/", mustWork = FALSE)
}

#' Write the CNIN (5.2.3) file for the current vintage.
#'
#' Creates `D5.2.3.CNIN.Manual.Review.<end_date>.xlsx` as a blank template on
#' the first run; the technical lead records overrides with evidence there.
#'
#' @param params Pipeline parameters (`raw_dir`, `end_date`).
#' @return A list with the output `path`, `review_path`, `overrides` and
#'   `candidates`.
#' @export
collect_cnin_vintage <- function(params) {
  previous <- .read_d5_2_previous(params, "D5.2.3.CNIN")
  historical_path <- file.path(.d5_2_dir(params), "D5.2.3.CNIN.Manual.Review.xlsx")
  historical <- if (file.exists(historical_path)) readxl::read_xlsx(historical_path, .name_repair = "minimal") else NULL
  review_path <- file.path(.d5_2_dir(params), sprintf("D5.2.3.CNIN.Manual.Review.%d.xlsx", as.integer(params$end_date)))
  write_review_template(review_path, data.frame(iso3c = previous$Code, country = previous$Country), "CNIN")
  review <- readxl::read_xlsx(review_path, .name_repair = "minimal")

  built <- build_cnin_vintage(previous, review, params$end_date, cnin_vocabulary(previous, historical), historical)
  historical_provenance <- if (is.null(historical)) {
    NULL
  } else {
    list(
      path = gsub("\\\\", "/", historical_path),
      sha256 = digest::digest(historical_path, algo = "sha256", file = TRUE),
      rows = nrow(historical),
      carried_iso3c = built$carried
    )
  }
  path <- .write_d5_2_output(
    params,
    "D5.2.3.CNIN",
    built$data,
    "d5_2_cnin",
    review_path,
    review,
    built$overrides,
    extra = list(historical_review = historical_provenance)
  )
  list(
    path = path,
    review_path = review_path,
    overrides = built$overrides,
    candidates = cnin_candidates(built$data, params$end_date, historical)
  )
}

#' Write the FINA (5.2.8) file for the current vintage.
#'
#' @param params Pipeline parameters (`raw_dir`, `end_date`, `imf_file`,
#'   `imf_file_2024`).
#' @param imf_text IMF GFS text used for candidates (previous and current), or
#'   NULL to skip the IMF comparison.
#' @return A list with the output `path`, `review_path`, `overrides` and
#'   `candidates`.
#' @export
collect_fina_vintage <- function(params, imf_text = .imf_text_for_fina(params)) {
  previous <- .read_d5_2_previous(params, "D5.2.8.FINA")
  review_path <- file.path(.d5_2_dir(params), sprintf("D5.2.8.FINA.Manual.Review.%d.xlsx", as.integer(params$end_date)))
  write_review_template(review_path, data.frame(iso3c = previous$Code, country = previous$Country), "FINA")
  review <- readxl::read_xlsx(review_path, .name_repair = "minimal")

  built <- build_fina_vintage(previous, review)
  path <- .write_d5_2_output(params, "D5.2.8.FINA", built$data, "d5_2_fina", review_path, review, built$overrides)
  list(
    path = path,
    review_path = review_path,
    overrides = built$overrides,
    candidates = fina_candidates(built$data, imf_text$previous, imf_text$current)
  )
}

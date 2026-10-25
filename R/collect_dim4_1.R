# =============================================================================
# Dimension 4.1 collection contracts and validation
# =============================================================================
# Created: 2026-10-20
# =============================================================================

#' Describe the eight manually maintained Dimension 4.1 workbooks.
#'
#' @return A named list of workbook specifications.
dim4_1_workbook_specs <- function() {
  list(
    D4.1.1.CEN.POPU = list(
      file = "D2.1.CEN.POPU.xlsx",
      sheet = "Data",
      skip = 0,
      required_cols = c("Code", "Country", "Years")
    ),
    D4.1.2.CEN.AGRI = list(
      file = "D2.2.CEN.AGRI.xlsx",
      sheet = "Data",
      skip = 2,
      required_cols = c("Code", "Country", "Years")
    ),
    D4.1.3.CEN.BIZZ = list(
      file = "D2.3.CEN.BIZZ.xlsx",
      sheet = "Data",
      skip = 2,
      required_cols = c("Code", "Country", "Years")
    ),
    D4.1.4.SVY.HOUS = list(
      file = "D2.4.SVY.HOUS.xlsx",
      sheet = "Data",
      skip = 2,
      required_cols = c("Code", "Country"),
      required_patterns = c("Houseshold survey")
    ),
    D4.1.5.SVY.AGRI = list(
      file = "D2.5.SVY.AGRI.xlsx",
      sheet = "Data",
      skip = 2,
      required_cols = c("Code", "Country", "Years")
    ),
    D4.1.6.SVY.LABR = list(
      file = "D2.6.SVY.LABR.xlsx",
      sheet = "Data",
      skip = 2,
      required_cols = c("Code", "Country", "Years")
    ),
    D4.1.7.SVY.HLTH = list(
      file = "D2.7.SVY.HLTH.xlsx",
      sheet = "NSO websites",
      skip = 2,
      required_cols = c("Country", "country name", "Year")
    ),
    D4.1.8.SVY.BIZZ = list(
      file = "D2.8.SVY.BIZZ.xlsx",
      sheet = "Data",
      skip = 2,
      required_cols = c("Code", "Country", "Years")
    )
  )
}

#' Locate the D4.1 country-naming files.
#'
#' CLASS.xlsx ("List of economies") is the naming authority for the D4.1
#' catalogue companions. The crosswalk maps catalogue spellings that differ
#' from CLASS to ISO3 codes; the exclusions file records catalogue entries
#' that are not economies.
#'
#' @param raw_dir Root raw-data directory.
#' @return A named list with `class_file`, `crosswalk_file` and
#'   `exclusions_file`.
#' @export
dim4_1_naming_files <- function(raw_dir,
                                class_file = file.path(raw_dir, "misc", "CLASS.xlsx"),
                                crosswalk_file = here::here("config", "d41_country_crosswalk.csv"),
                                exclusions_file = here::here("config", "d41_companion_exclusions.csv")) {
  list(
    class_file = class_file,
    crosswalk_file = crosswalk_file,
    exclusions_file = exclusions_file
  )
}

dim4_1_exclusion_categories <- c(
  "non_economy",
  "multi_country_study",
  "blank_country",
  "outside_country_universe"
)
dim4_1_blank_country <- "<blank>"

.dim4_1_require_file <- function(path, label) {
  if (!file.exists(path)) {
    stop(sprintf("D4.1 %s NOT FOUND: %s", label, path), call. = FALSE)
  }
  invisible(path)
}

.dim4_1_read_text_csv <- function(path) {
  readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    progress = FALSE
  )
}

#' Read the CLASS economies (rows with a region; aggregates have none).
#'
#' @param class_file Path to CLASS.xlsx.
#' @return A tibble with `country` (CLASS economy name) and `iso3c`.
#' @export
dim4_1_class_economies <- function(class_file) {
  .dim4_1_require_file(class_file, "NAMING AUTHORITY (CLASS.xlsx)")
  sheets <- readxl::excel_sheets(class_file)
  if (!"List of economies" %in% sheets) {
    stop(
      "D4.1 NAMING AUTHORITY HAS NO 'List of economies' SHEET: ", class_file,
      call. = FALSE
    )
  }
  data <- readxl::read_xlsx(class_file, sheet = "List of economies")
  missing <- setdiff(c("Economy", "Code", "Region"), names(data))
  if (length(missing) > 0L) {
    stop(
      "D4.1 NAMING AUTHORITY SCHEMA MISMATCH: missing ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  keep <- !is.na(data$Code) & !is.na(data$Economy) & !is.na(data$Region)
  economies <- tibble::tibble(
    country = trimws(as.character(data$Economy[keep])),
    iso3c = trimws(as.character(data$Code[keep]))
  )
  if (nrow(economies) == 0L) {
    stop("D4.1 NAMING AUTHORITY LISTS NO ECONOMIES: ", class_file, call. = FALSE)
  }
  if (anyDuplicated(economies$iso3c) > 0L || anyDuplicated(economies$country) > 0L) {
    stop("D4.1 NAMING AUTHORITY HAS DUPLICATE ECONOMIES: ", class_file, call. = FALSE)
  }
  economies
}

#' Build the catalogue-name to ISO3 lookup from CLASS and the crosswalk.
#'
#' @param naming Naming files from dim4_1_naming_files().
#' @return A tibble with `catalogue_name`, `iso3c`, `country` (CLASS name)
#'   and `source` ("class" or "crosswalk").
#' @export
dim4_1_country_lookup <- function(naming) {
  economies <- dim4_1_class_economies(naming$class_file)
  .dim4_1_require_file(naming$crosswalk_file, "COUNTRY CROSSWALK")
  crosswalk <- .dim4_1_read_text_csv(naming$crosswalk_file)
  missing <- setdiff(c("catalogue_name", "iso3c"), names(crosswalk))
  if (length(missing) > 0L) {
    stop(
      "D4.1 CROSSWALK SCHEMA MISMATCH: missing ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  names_in <- trimws(crosswalk$catalogue_name)
  codes_in <- trimws(crosswalk$iso3c)
  if (anyNA(names_in) || any(!nzchar(names_in)) || anyDuplicated(names_in) > 0L) {
    stop("D4.1 CROSSWALK HAS BLANK OR DUPLICATE CATALOGUE NAMES", call. = FALSE)
  }
  unknown <- setdiff(codes_in, economies$iso3c)
  if (length(unknown) > 0L) {
    stop(
      "D4.1 CROSSWALK CODE NOT IN CLASS: ",
      paste(unknown, collapse = ", "),
      call. = FALSE
    )
  }
  in_class <- match(names_in, economies$country)
  conflict <- !is.na(in_class) & economies$iso3c[in_class] != codes_in
  if (any(conflict)) {
    stop(
      "D4.1 CROSSWALK CONFLICTS WITH CLASS: ",
      paste(
        sprintf(
          "%s -> %s (CLASS: %s)",
          names_in[conflict],
          codes_in[conflict],
          economies$iso3c[in_class[conflict]]
        ),
        collapse = "; "
      ),
      call. = FALSE
    )
  }
  extra <- is.na(in_class)
  lookup <- tibble::tibble(
    catalogue_name = c(economies$country, names_in[extra]),
    iso3c = c(economies$iso3c, codes_in[extra]),
    source = c(rep("class", nrow(economies)), rep("crosswalk", sum(extra)))
  )
  lookup$country <- economies$country[match(lookup$iso3c, economies$iso3c)]
  lookup[, c("catalogue_name", "iso3c", "country", "source")]
}

#' Read the recorded catalogue-companion exclusions.
#'
#' @param naming Naming files from dim4_1_naming_files().
#' @return A tibble with `companion` (stem or "*"), `catalogue_name`,
#'   `category` and `reason`.
#' @export
dim4_1_companion_exclusion_rules <- function(naming) {
  .dim4_1_require_file(naming$exclusions_file, "COMPANION EXCLUSIONS")
  rules <- .dim4_1_read_text_csv(naming$exclusions_file)
  required <- c("companion", "catalogue_name", "category", "reason")
  missing <- setdiff(required, names(rules))
  if (length(missing) > 0L) {
    stop(
      "D4.1 EXCLUSIONS SCHEMA MISMATCH: missing ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  rules <- rules[, required]
  rules[] <- lapply(rules, trimws)
  if (any(is.na(as.matrix(rules))) || any(!nzchar(as.matrix(rules)))) {
    stop("D4.1 EXCLUSIONS HAVE EMPTY FIELDS; every rule needs a reason.", call. = FALSE)
  }
  bad_companion <- setdiff(rules$companion, c("*", names(dim4_1_workbook_specs())))
  if (length(bad_companion) > 0L) {
    stop(
      "D4.1 EXCLUSIONS NAME UNKNOWN COMPANION(S): ",
      paste(bad_companion, collapse = ", "),
      call. = FALSE
    )
  }
  bad_category <- setdiff(rules$category, dim4_1_exclusion_categories)
  if (length(bad_category) > 0L) {
    stop(
      "D4.1 EXCLUSIONS USE UNKNOWN CATEGORY(IES): ",
      paste(bad_category, collapse = ", "),
      call. = FALSE
    )
  }
  blank_rule <- rules$catalogue_name == dim4_1_blank_country
  if (any(blank_rule != (rules$category == "blank_country"))) {
    stop(
      "D4.1 EXCLUSIONS: category 'blank_country' must name '<blank>' and only it",
      call. = FALSE
    )
  }
  if (any(blank_rule & rules$companion == "*")) {
    stop(
      "D4.1 EXCLUSIONS: blank-country rows must be recorded per companion",
      call. = FALSE
    )
  }
  if (anyDuplicated(rules$catalogue_name[!blank_rule]) > 0L ||
      anyDuplicated(rules$companion[blank_rule]) > 0L) {
    stop("D4.1 EXCLUSIONS LIST A CATALOGUE NAME MORE THAN ONCE", call. = FALSE)
  }
  rules
}

#' Normalize one catalogue companion to CLASS names and ISO3 codes.
#'
#' @param data Raw companion read as text.
#' @param stem Companion stem (for example "D4.1.4.SVY.HOUS").
#' @param lookup Lookup from dim4_1_country_lookup().
#' @param rules Rules from dim4_1_companion_exclusion_rules().
#' @param end_date Reference year; catalogue dates after it stop the run.
#'   NULL skips that check.
#' @return A list with the normalized `data`, `exclusions`, `crosswalked`
#'   name counts, `raw_rows` and `duplicate_keys`.
#' @export
dim4_1_normalize_companion <- function(data, stem, lookup, rules, end_date = NULL) {
  required <- c("country", "indicator_date", "nada_dates", "nada_title")
  missing <- setdiff(required, names(data))
  if (length(missing) > 0L) {
    stop(
      sprintf(
        "D4.1 CATALOGUE COMPANION SCHEMA MISMATCH in '%s': %s",
        stem,
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  name <- trimws(as.character(data$country))
  name[is.na(name) | !nzchar(name)] <- dim4_1_blank_country
  dates <- suppressWarnings(as.numeric(data$indicator_date))
  if (anyNA(dates) || any(!is.finite(dates))) {
    stop(
      sprintf("D4.1 CATALOGUE COMPANION HAS INVALID DATES in '%s'", stem),
      call. = FALSE
    )
  }
  # A catalogue refreshed after the reference year lists studies that started
  # later (for example 2026 labour force surveys in an October 2026 pull). As
  # in the legacy scoring, they never count for an earlier reference year, so
  # they are kept and counted. Dates beyond what a refresh can plausibly list
  # indicate a parsing error and stop.
  after_end_date <- 0L
  if (!is.null(end_date)) {
    implausible <- dates > end_date + dim4_1_catalogue_future_years
    if (any(implausible)) {
      stop(
        sprintf(
          "D4.1 CATALOGUE COMPANION HAS DATES MORE THAN %d YEARS AFTER END_DATE in '%s': %s",
          dim4_1_catalogue_future_years,
          stem,
          paste(sort(unique(dates[implausible])), collapse = ", ")
        ),
        call. = FALSE
      )
    }
    after_end_date <- sum(dates > end_date)
  }

  applicable <- rules[rules$companion %in% c("*", stem), , drop = FALSE]
  excluded <- name %in% applicable$catalogue_name
  matched <- match(name, lookup$catalogue_name)
  unknown <- unique(name[!excluded & is.na(matched)])
  if (length(unknown) > 0L) {
    stop(
      sprintf(
        paste0(
          "D4.1 CATALOGUE COMPANION HAS UNKNOWN COUNTRY NAME(S) in '%s': %s. ",
          "Map economies in config/d41_country_crosswalk.csv or record ",
          "non-economies in config/d41_companion_exclusions.csv."
        ),
        stem,
        paste(unknown, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  kept <- !excluded
  normalized <- tibble::tibble(
    iso3c = lookup$iso3c[matched[kept]],
    country = lookup$country[matched[kept]],
    indicator_date = dates[kept],
    nada_dates = as.character(data$nada_dates[kept]),
    nada_title = as.character(data$nada_title[kept])
  )

  exclusions <- lapply(unique(name[excluded]), function(value) {
    rule <- applicable[applicable$catalogue_name == value, , drop = FALSE][1, ]
    rows <- excluded & name == value
    list(
      catalogue_name = value,
      category = rule$category,
      reason = rule$reason,
      rows = sum(rows),
      dates = sort(unique(dates[rows]))
    )
  })

  crosswalk_rows <- kept & !is.na(matched) & lookup$source[matched] == "crosswalk"
  counts <- table(name[crosswalk_rows])
  crosswalked <- stats::setNames(as.list(as.integer(counts)), names(counts))

  list(
    data = normalized,
    exclusions = exclusions,
    crosswalked = crosswalked,
    raw_rows = nrow(data),
    after_end_date = after_end_date,
    duplicate_keys = sum(duplicated(paste(normalized$iso3c, normalized$indicator_date)))
  )
}

# Years after end_date a refreshed catalogue may list (studies that started
# between the reference year and the refresh).
dim4_1_catalogue_future_years <- 2L

#' Normalize the eight D4.1 catalogue companions.
#'
#' Reads each raw companion (`4.1_SOCS/<stem>_NADA.csv`, preserved
#' unchanged), maps country names to ISO3 codes through CLASS.xlsx plus the
#' crosswalk, drops recorded exclusions, and writes
#' `4.1_SOCS/collection/<stem>_NADA.iso3c.csv`. Any unmatched name stops.
#'
#' @param raw_dir Root raw-data directory.
#' @param end_date Reference year (NULL skips the date checks); studies dated
#'   up to dim4_1_catalogue_future_years later are kept and counted.
#' @param output_dir Directory for the normalized companions.
#' @param naming Naming files from dim4_1_naming_files().
#' @param write Whether to write the normalized files.
#' @return A list with per-companion `files` statistics, `exclusions`, and
#'   the normalized `data`.
#' @export
normalize_dim4_1_companions <- function(raw_dir, end_date,
                                        output_dir = file.path(raw_dir, "4.1_SOCS", "collection"),
                                        naming = dim4_1_naming_files(raw_dir),
                                        write = TRUE, valid_iso3c = NULL) {
  paths <- dim4_1_artifact_paths(raw_dir, end_date = if (is.null(end_date)) 0L else end_date)
  missing_raw <- paths$companion_files[!file.exists(paths$companion_files)]
  if (length(missing_raw) > 0L) {
    stop(
      sprintf("D4.1 CATALOGUE COMPANION NOT FOUND: %s", paste(missing_raw, collapse = ", ")),
      call. = FALSE
    )
  }
  lookup <- dim4_1_country_lookup(naming)
  rules <- dim4_1_companion_exclusion_rules(naming)
  economy_rules <- intersect(
    rules$catalogue_name[rules$category != "outside_country_universe"],
    lookup$catalogue_name
  )
  if (length(economy_rules) > 0L) {
    stop(
      "D4.1 EXCLUSIONS NAME CLASS ECONOMIES: ",
      paste(economy_rules, collapse = ", "),
      call. = FALSE
    )
  }

  # Report every unmatched name of every companion at once, so a refreshed
  # catalogue needs one round of crosswalk or exclusion updates.
  unknown <- lapply(names(paths$companion_files), function(stem) {
    data <- .dim4_1_read_text_csv(paths$companion_files[[stem]])
    if (!"country" %in% names(data)) {
      return(character())
    }
    name <- trimws(as.character(data$country))
    name[is.na(name) | !nzchar(name)] <- dim4_1_blank_country
    applicable <- rules$catalogue_name[rules$companion %in% c("*", stem)]
    sort(unique(name[!name %in% applicable & !name %in% lookup$catalogue_name]))
  })
  names(unknown) <- names(paths$companion_files)
  unknown <- unknown[lengths(unknown) > 0L]
  if (length(unknown) > 0L) {
    stop(
      "D4.1 CATALOGUE COMPANIONS HAVE UNKNOWN COUNTRY NAME(S): ",
      paste(sprintf("'%s': %s", names(unknown), vapply(unknown, paste, character(1), collapse = ", ")), collapse = "; "),
      ". Map economies in config/d41_country_crosswalk.csv or record non-economies in ",
      "config/d41_companion_exclusions.csv.",
      call. = FALSE
    )
  }

  results <- lapply(names(paths$companion_files), function(stem) {
    raw_path <- paths$companion_files[[stem]]
    normalized <- dim4_1_normalize_companion(
      .dim4_1_read_text_csv(raw_path),
      stem,
      lookup,
      rules,
      end_date
    )
    path <- file.path(output_dir, basename(paths$normalized_companion_files[[stem]]))
    list(
      path = path,
      file = list(
        path = path,
        raw_path = raw_path,
        raw_rows = normalized$raw_rows,
        rows = nrow(normalized$data),
        after_end_date = normalized$after_end_date,
        duplicate_keys = normalized$duplicate_keys,
        crosswalked = normalized$crosswalked
      ),
      exclusions = normalized$exclusions,
      data = normalized$data
    )
  })
  names(results) <- names(paths$companion_files)
  if (!is.null(valid_iso3c)) {
    valid_iso3c <- unique(trimws(as.character(valid_iso3c)))
    observed <- unique(unlist(lapply(results, function(result) result$data$iso3c), use.names = FALSE))
    outside <- sort(setdiff(observed, valid_iso3c))
    if (length(outside) > 0L) {
      stop(
        "D4.1 CATALOGUE EVIDENCE OUTSIDE ESTIMATION COUNTRY UNIVERSE: ",
        paste(outside, collapse = ", "),
        call. = FALSE
      )
    }
  }
  if (isTRUE(write)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    for (result in results) {
      temporary <- paste0(result$path, ".partial")
      readr::write_csv(result$data, temporary, na = "")
      if (!file.rename(temporary, result$path)) {
        unlink(temporary, force = TRUE)
        stop(
          "D4.1 NORMALIZED COMPANION COULD NOT BE WRITTEN: ",
          result$path,
          call. = FALSE
        )
      }
    }
  }
  list(
    files = lapply(results, `[[`, "file"),
    exclusions = lapply(results, `[[`, "exclusions"),
    data = lapply(results, `[[`, "data")
  )
}

#' Return the current Dimension 4.1 artifact paths.
#'
#' @param raw_dir Root raw-data directory.
#' @param end_date Current SPI reference year.
#' @return A list containing input, review, derived, and companion paths.
#' @export
dim4_1_artifact_paths <- function(raw_dir, end_date) {
  dim4_1_recover_catalogue_promotion(file.path(raw_dir, "4.1_SOCS"))
  specs <- dim4_1_workbook_specs()
  input_dir <- file.path(raw_dir, "4.1_SOCS", "raw", "input")
  output_dir <- file.path(raw_dir, "4.1_SOCS", "raw")
  stems <- names(specs)

  list(
    input_files = setNames(
      file.path(input_dir, vapply(specs, `[[`, character(1), "file")),
      stems
    ),
    review_file = file.path(
      output_dir,
      sprintf("D4.1.Manual.Review.%d.xlsx", end_date)
    ),
    derived_files = setNames(
      file.path(output_dir, sprintf("%s.%d.csv", stems, end_date)),
      stems
    ),
    companion_files = setNames(
      file.path(raw_dir, "4.1_SOCS", paste0(stems, "_NADA.csv")),
      stems
    ),
    normalized_companion_files = setNames(
      file.path(raw_dir, "4.1_SOCS", "collection", paste0(stems, "_NADA.iso3c.csv")),
      stems
    ),
    naming_files = dim4_1_naming_files(raw_dir)
  )
}

dim4_1_promotion_marker_path <- function(target_dir) {
  file.path(target_dir, "collection", "catalogue_promotion_in_progress.json")
}

dim4_1_recover_catalogue_promotion <- function(target_dir) {
  marker_path <- dim4_1_promotion_marker_path(target_dir)
  if (!file.exists(marker_path)) {
    return(invisible(FALSE))
  }
  marker <- jsonlite::read_json(marker_path, simplifyVector = TRUE)
  required <- c("schema_version", "targets", "existed", "backup_dir", "staging_root")
  missing <- setdiff(required, names(marker))
  if (length(missing) > 0L || !identical(marker$schema_version, "spi-d41-promotion-v1")) {
    stop(
      "D4.1 CATALOGUE PROMOTION JOURNAL INVALID: ",
      marker_path,
      call. = FALSE
    )
  }
  targets <- as.character(marker$targets)
  existed <- as.logical(marker$existed)
  backup_dir <- as.character(marker$backup_dir)
  if (length(targets) == 0L || length(targets) != length(existed)) {
    stop("D4.1 CATALOGUE PROMOTION JOURNAL HAS INVALID TARGETS: ", marker_path, call. = FALSE)
  }
  missing_backups <- targets[existed & !file.exists(file.path(backup_dir, basename(targets)))]
  if (length(missing_backups) > 0L) {
    stop(
      "D4.1 CATALOGUE PROMOTION CANNOT RECOVER; backups missing for ",
      paste(basename(missing_backups), collapse = ", "),
      call. = FALSE
    )
  }
  for (index in seq_along(targets)) {
    if (existed[[index]]) {
      restored <- file.copy(
        file.path(backup_dir, basename(targets[[index]])),
        targets[[index]],
        overwrite = TRUE,
        copy.date = TRUE
      )
      if (!isTRUE(restored)) {
        stop(
          "D4.1 CATALOGUE PROMOTION RECOVERY FAILED: ",
          targets[[index]],
          call. = FALSE
        )
      }
    } else {
      unlink(targets[[index]], force = TRUE)
    }
  }
  unlink(marker_path, force = TRUE)
  unlink(as.character(marker$staging_root), recursive = TRUE, force = TRUE)
  invisible(TRUE)
}

validate_dim4_1_columns <- function(columns, spec, file_name) {
  missing <- setdiff(spec$required_cols, columns)
  if (length(missing) > 0L) {
    stop(
      sprintf(
        "D4.1 WORKBOOK SCHEMA MISMATCH in '%s': missing column(s): %s",
        file_name,
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  patterns <- if (is.null(spec$required_patterns)) {
    character()
  } else {
    spec$required_patterns
  }
  pattern_missing <- patterns[!vapply(
    patterns,
    function(pattern) any(grepl(pattern, columns, fixed = TRUE)),
    logical(1)
  )]
  if (length(pattern_missing) > 0L) {
    stop(
      sprintf(
        "D4.1 WORKBOOK SCHEMA MISMATCH in '%s': missing column pattern(s): %s",
        file_name,
        paste(pattern_missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
}

validate_dim4_1_key <- function(data, file_name, key_col) {
  if (!(key_col %in% names(data))) {
    stop(
      sprintf(
        "D4.1 WORKBOOK KEY COLUMN MISSING in '%s': %s",
        file_name,
        key_col
      ),
      call. = FALSE
    )
  }

  keys <- trimws(as.character(data[[key_col]]))
  keys <- keys[!is.na(keys) & nzchar(keys)]
  if (length(keys) == 0L) {
    stop(
      sprintf("D4.1 WORKBOOK HAS NO COUNTRY KEYS in '%s'", file_name),
      call. = FALSE
    )
  }
  if (anyDuplicated(keys) > 0L) {
    stop(
      sprintf("D4.1 WORKBOOK HAS DUPLICATE COUNTRY KEYS in '%s'", file_name),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Validate one Dimension 4.1 workbook.
#'
#' @param path Workbook path.
#' @param spec Workbook specification from dim4_1_workbook_specs().
#' @return Invisibly returns TRUE.
#' @export
validate_dim4_1_workbook <- function(path, spec) {
  if (!file.exists(path)) {
    stop(
      sprintf("D4.1 INPUT FILE NOT FOUND: %s", path),
      call. = FALSE
    )
  }

  sheets <- readxl::excel_sheets(path)
  if (!(spec$sheet %in% sheets)) {
    stop(
      sprintf(
        "D4.1 WORKBOOK SHEET NOT FOUND in '%s': expected '%s'; found: %s",
        basename(path),
        spec$sheet,
        paste(sheets, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  header <- readxl::read_xlsx(
    path,
    sheet = spec$sheet,
    skip = spec$skip,
    n_max = 0,
    .name_repair = "minimal"
  )
  validate_dim4_1_columns(names(header), spec, basename(path))

  data <- readxl::read_xlsx(
    path,
    sheet = spec$sheet,
    skip = spec$skip,
    .name_repair = "minimal"
  )
  key_col <- if ("Code" %in% names(data)) "Code" else "Country"
  validate_dim4_1_key(data, basename(path), key_col)
  invisible(TRUE)
}

#' Validate the country-level manual review workbook.
#'
#' @param review_data Review data frame.
#' @return Invisibly returns TRUE.
#' @export
validate_dim4_1_review <- function(review_data, country_metadata = NULL) {
  required <- c(
    "iso3c", "country", "POP.CENSUS", "AGRI.CENSUS", "BIZZ.CENSUS",
    "HOUS.SURVEYS", "AGRI.SURVEYS", "LABR.SURVEYS", "HLTH.SURVEYS",
    "BIZZ.SURVEYS", "Evidence"
  )
  missing <- setdiff(required, names(review_data))
  if (length(missing) > 0L) {
    stop(
      sprintf(
        "D4.1 MANUAL REVIEW SCHEMA MISMATCH: missing column(s): %s",
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  keys <- trimws(as.character(review_data$iso3c))
  if (anyNA(keys) || any(!nzchar(keys))) {
    stop("D4.1 MANUAL REVIEW HAS MISSING COUNTRY KEYS", call. = FALSE)
  }
  if (anyDuplicated(keys) > 0L) {
    stop("D4.1 MANUAL REVIEW HAS DUPLICATE COUNTRY KEYS", call. = FALSE)
  }
  value_columns <- setdiff(
    names(review_data),
    c("iso3c", "country", "Evidence")
  )
  has_override <- rep(FALSE, nrow(review_data))
  for (column in value_columns) {
    values <- trimws(as.character(review_data[[column]]))
    nonempty <- !is.na(values) & nzchar(values)
    has_override <- has_override | nonempty
    invalid <- !is.na(values) & nzchar(values) &
      !grepl(
        "^(?:[0-9]{4}(?:\\s*,\\s*[0-9]{4})*|register[ -]based[ -]census(?:\\s*,\\s*[0-9]{4})*)$",
        values,
        ignore.case = TRUE
      )
    if (any(invalid)) {
      stop(
        sprintf("D4.1 MANUAL REVIEW HAS INVALID VALUE(S) in '%s'", column),
        call. = FALSE
      )
    }
  }
  evidence <- trimws(as.character(review_data$Evidence))
  missing_evidence <- has_override & (is.na(evidence) | !nzchar(evidence))
  if (any(missing_evidence)) {
    stop(
      "D4.1 MANUAL REVIEW OVERRIDES REQUIRE EVIDENCE for country key(s): ",
      paste(keys[missing_evidence], collapse = ", "),
      call. = FALSE
    )
  }
  if (!is.null(country_metadata)) {
    if (!is.data.frame(country_metadata) || !"iso3c" %in% names(country_metadata)) {
      stop("D4.1 REVIEW COUNTRY METADATA MUST HAVE an iso3c COLUMN.", call. = FALSE)
    }
    unknown <- setdiff(keys, as.character(country_metadata$iso3c))
    if (length(unknown) > 0L) {
      stop(
        "D4.1 MANUAL REVIEW HAS UNKNOWN COUNTRY KEYS: ",
        paste(unknown, collapse = ", "),
        call. = FALSE
      )
    }
  }
  invisible(TRUE)
}

#' Read and validate a Dimension 4.1 manual-review workbook.
#'
#' @param review_path Review workbook path.
#' @return A validated review tibble.
#' @export
read_dim4_1_review <- function(review_path) {
  if (!file.exists(review_path)) {
    stop(
      sprintf("D4.1 MANUAL REVIEW FILE NOT FOUND: %s", review_path),
      call. = FALSE
    )
  }
  review_data <- readxl::read_xlsx(review_path, .name_repair = "minimal")
  validate_dim4_1_review(review_data)
  review_data
}

#' Summarize manual-review provenance for the collection manifest.
#'
#' @param review_path Review workbook path.
#' @param end_date Current SPI reference year.
#' @return A list of review provenance fields.
#' @export
dim4_1_review_metadata <- function(review_path, end_date,
                                   country_metadata = NULL) {
  review_data <- read_dim4_1_review(review_path)
  validate_dim4_1_review(review_data, country_metadata = country_metadata)
  review_columns <- setdiff(
    names(review_data),
    c("iso3c", "country", "Evidence")
  )
  override_count <- sum(
    !is.na(as.matrix(review_data[review_columns])) &
      trimws(as.character(as.matrix(review_data[review_columns]))) != ""
  )

  list(
    path = dim4_1_project_relative_path(review_path),
    end_date = end_date,
    sha256 = digest::digest(review_path, algo = "sha256", file = TRUE),
    rows = nrow(review_data),
    evidence_rows = sum(
      !is.na(review_data$Evidence) &
        nzchar(trimws(as.character(review_data$Evidence)))
    ),
    override_count = override_count
  )
}

dim4_1_project_relative_path <- function(path) {
  project_root <- normalizePath(here::here(), winslash = "/", mustWork = TRUE)
  absolute_path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  prefix <- paste0(project_root, "/")
  if (startsWith(absolute_path, prefix)) {
    substring(absolute_path, nchar(prefix) + 1L)
  } else {
    absolute_path
  }
}

dim4_1_resolve_manifest_path <- function(path) {
  if (grepl("^/", path) || grepl("^[A-Za-z]:[/\\\\]", path)) {
    path
  } else {
    file.path(here::here(), path)
  }
}

dim4_1_file_metadata <- function(path, role) {
  if (!file.exists(path)) {
    stop(
      sprintf("D4.1 COLLECTION ARTIFACT NOT FOUND (%s): %s", role, path),
      call. = FALSE
    )
  }
  list(
    role = role,
    path = dim4_1_project_relative_path(path),
    sha256 = digest::digest(path, algo = "sha256", file = TRUE),
    size_bytes = unname(file.info(path)$size),
    modified_at = format(file.info(path)$mtime, tz = "UTC", usetz = TRUE)
  )
}

#' Validate the normalized D4.1 catalogue companions.
#'
#' Recomputes the normalization from the raw companions and the naming files
#' and requires the files on disk to match it, so a companion refreshed or
#' edited after normalization cannot reach estimation.
#'
#' @param raw_dir Root raw-data directory.
#' @param end_date Reference year (NULL skips the date checks); studies dated
#'   up to dim4_1_catalogue_future_years later are kept and counted.
#' @param naming Naming files from dim4_1_naming_files().
#' @return A list with per-companion `files` statistics and `exclusions`.
#' @export
validate_dim4_1_companions <- function(raw_dir, end_date = NULL,
                                       naming = dim4_1_naming_files(raw_dir),
                                       valid_iso3c = NULL) {
  expected <- normalize_dim4_1_companions(
    raw_dir,
    end_date = end_date,
    naming = naming,
    write = FALSE,
    valid_iso3c = valid_iso3c
  )
  for (stem in names(expected$files)) {
    path <- expected$files[[stem]]$path
    if (!file.exists(path)) {
      stop(
        "D4.1 NORMALIZED COMPANION NOT FOUND: ", path,
        ". Run the D4.1 catalogue collection target.",
        call. = FALSE
      )
    }
    on_disk <- readr::read_csv(
      path,
      col_types = readr::cols(
        iso3c = readr::col_character(),
        country = readr::col_character(),
        indicator_date = readr::col_double(),
        nada_dates = readr::col_character(),
        nada_title = readr::col_character()
      ),
      progress = FALSE
    )
    current <- isTRUE(all.equal(
      as.data.frame(on_disk),
      as.data.frame(expected$data[[stem]]),
      check.attributes = FALSE
    )) && identical(names(on_disk), names(expected$data[[stem]]))
    if (!current) {
      stop(
        sprintf(
          "D4.1 NORMALIZED COMPANION IS STALE in '%s': %s does not match its raw companion and naming files. Rerun the D4.1 catalogue collection target.",
          stem,
          path
        ),
        call. = FALSE
      )
    }
  }
  list(files = expected$files, exclusions = expected$exclusions)
}

dim4_1_derived_specs <- function() {
  c(
    D4.1.1.CEN.POPU = "POP.CENSUS",
    D4.1.2.CEN.AGRI = "AGRI.CENSUS",
    D4.1.3.CEN.BIZZ = "BIZZ.CENSUS",
    D4.1.4.SVY.HOUS = "HOUS.SURVEYS",
    D4.1.5.SVY.AGRI = "AGRI.SURVEYS",
    D4.1.6.SVY.LABR = "LABR.SURVEYS",
    D4.1.7.SVY.HLTH = "HLTH.SURVEYS",
    D4.1.8.SVY.BIZZ = "BIZZ.SURVEYS"
  )
}

#' Validate generated current-vintage D4.1 CSVs.
#'
#' @param raw_dir Root raw-data directory.
#' @param end_date Current SPI reference year.
#' @param output_dir Optional derived-output directory.
#' @return Invisibly returns TRUE.
#' @export
validate_dim4_1_derived <- function(raw_dir, end_date,
                                     output_dir = file.path(raw_dir, "4.1_SOCS", "raw"),
                                     source_paths = character()) {
  paths <- dim4_1_artifact_paths(raw_dir, end_date)$derived_files
  paths <- setNames(file.path(output_dir, basename(paths)), names(paths))
  indicators <- dim4_1_derived_specs()

  for (name in names(paths)) {
    path <- paths[[name]]
    data <- readr::read_csv(path, show_col_types = FALSE)
    missing <- setdiff(c("iso3c", "date", indicators[[name]]), names(data))
    if (length(missing) > 0L) {
      stop(
        sprintf(
          "D4.1 DERIVED FILE SCHEMA MISMATCH in '%s': %s",
          basename(path),
          paste(missing, collapse = ", ")
        ),
        call. = FALSE
      )
    }
    if (nrow(data) == 0L) {
      stop("D4.1 DERIVED FILE IS EMPTY: ", path, call. = FALSE)
    }
    if (anyNA(data$iso3c) || !all(nzchar(trimws(as.character(data$iso3c))))) {
      stop("D4.1 DERIVED FILE HAS MISSING iso3c: ", path, call. = FALSE)
    }
    if (anyNA(data$date) || any(data$date != end_date)) {
      stop("D4.1 DERIVED FILE HAS WRONG VINTAGE DATE: ", path, call. = FALSE)
    }
    key <- interaction(data$iso3c, data$date, drop = TRUE)
    if (anyDuplicated(key) > 0L) {
      stop("D4.1 DERIVED FILE HAS DUPLICATE COUNTRY/YEAR KEYS: ", path, call. = FALSE)
    }
    if (length(source_paths) > 0L) {
      latest_source <- max(file.info(source_paths)$mtime, na.rm = TRUE)
      if (file.info(path)$mtime < latest_source) {
        stop("D4.1 DERIVED FILE IS STALE: ", path, call. = FALSE)
      }
    }
  }
  invisible(TRUE)
}

#' Build a provenance manifest for validated Dimension 4.1 artifacts.
#'
#' @param raw_dir Root raw-data directory.
#' @param end_date Current SPI reference year.
#' @return A manifest list suitable for JSON serialization.
#' @export
dim4_1_build_manifest <- function(raw_dir, end_date,
                                  country_metadata = NULL) {
  paths <- dim4_1_artifact_paths(raw_dir, end_date)
  refresh_record <- dim4_1_read_refresh_record(raw_dir, end_date)
  validate_dim4_1_workbooks(raw_dir, end_date)
  validate_dim4_1_derived(
    raw_dir,
    end_date,
    source_paths = c(unname(paths$input_files), paths$review_file)
  )
  review_metadata <- dim4_1_review_metadata(
    paths$review_file,
    end_date,
    country_metadata = country_metadata
  )
  companions <- validate_dim4_1_companions(
    raw_dir,
    end_date = end_date,
    naming = paths$naming_files,
    valid_iso3c = if (is.null(country_metadata)) NULL else country_metadata$iso3c
  )
  normalized_entries <- lapply(names(companions$files), function(stem) {
    statistics <- companions$files[[stem]]
    c(
      dim4_1_file_metadata(
        paths$normalized_companion_files[[stem]],
        role = "d41_catalogue_companion"
      ),
      statistics[c("raw_rows", "rows", "after_end_date", "duplicate_keys", "crosswalked")]
    )
  })
  names(normalized_entries) <- names(companions$files)

  manifest <- list(
    schema_version = "spi-d4.1-collection-v2",
    end_date = end_date,
    naming = list(
      class_file = dim4_1_file_metadata(
        paths$naming_files$class_file,
        role = "naming_authority"
      ),
      crosswalk_file = dim4_1_file_metadata(
        paths$naming_files$crosswalk_file,
        role = "naming_crosswalk"
      ),
      exclusions_file = dim4_1_file_metadata(
        paths$naming_files$exclusions_file,
        role = "naming_exclusions"
      )
    ),
    inputs = lapply(
      paths$input_files,
      dim4_1_file_metadata,
      role = "manual_input_workbook"
    ),
    review = review_metadata,
    derived = lapply(
      paths$derived_files,
      dim4_1_file_metadata,
      role = "derived_indicator_csv"
    ),
    catalogue_raw = lapply(
      paths$companion_files,
      dim4_1_file_metadata,
      role = "d41_catalogue_raw"
    ),
    companions = normalized_entries,
    exclusions = companions$exclusions,
    catalogue_refresh = if (is.null(refresh_record)) {
      NULL
    } else {
      c(
        dim4_1_file_metadata(
          dim4_1_catalogue_refresh_record_path(raw_dir),
          role = "d41_catalogue_refresh_record"
        ),
        list(record = refresh_record)
      )
    }
  )
  manifest
}

#' Validate a D4.1 manifest and every artifact it authorizes.
#'
#' @param manifest_path JSON manifest path.
#' @param raw_dir Root raw-data directory.
#' @param end_date Current SPI reference year.
#' @return The validated manifest invisibly.
#' @export
validate_dim4_1_manifest <- function(manifest_path, raw_dir, end_date,
                                     valid_iso3c = NULL) {
  if (!file.exists(manifest_path)) {
    stop("D4.1 MANIFEST NOT FOUND: ", manifest_path, call. = FALSE)
  }
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
  if (!identical(manifest$schema_version, "spi-d4.1-collection-v2") ||
      is.null(manifest$naming) || is.null(manifest$catalogue_raw)) {
    stop(
      "D4.1 MANIFEST SCHEMA OUTDATED: expected spi-d4.1-collection-v2; found ",
      if (is.null(manifest$schema_version)) "none" else manifest$schema_version,
      ". Rerun the collection pipeline (_targets_data.R).",
      call. = FALSE
    )
  }
  if (!identical(as.integer(manifest$end_date), as.integer(end_date))) {
    stop(
      "D4.1 MANIFEST VINTAGE MISMATCH: expected ", end_date,
      "; found ", manifest$end_date,
      call. = FALSE
    )
  }

  expected <- dim4_1_artifact_paths(raw_dir, end_date)
  validate_entry <- function(entry, expected_path, role) {
    actual_path <- dim4_1_resolve_manifest_path(entry$path)
    expected_path <- normalizePath(expected_path, winslash = "/", mustWork = FALSE)
    actual_path <- normalizePath(actual_path, winslash = "/", mustWork = FALSE)
    if (!identical(actual_path, expected_path)) {
      stop(
        sprintf("D4.1 MANIFEST PATH MISMATCH (%s): %s", role, entry$path),
        call. = FALSE
      )
    }
    if (!file.exists(actual_path)) {
      stop(
        sprintf("D4.1 MANIFEST ARTIFACT MISSING (%s): %s", role, actual_path),
        call. = FALSE
      )
    }
    actual_hash <- digest::digest(actual_path, algo = "sha256", file = TRUE)
    if (!identical(as.character(entry$sha256), actual_hash)) {
      stop(
        sprintf("D4.1 MANIFEST HASH MISMATCH (%s): %s", role, actual_path),
        call. = FALSE
      )
    }
    invisible(TRUE)
  }

  if (length(manifest$inputs) != length(expected$input_files)) {
    stop("D4.1 MANIFEST INPUT COUNT MISMATCH", call. = FALSE)
  }
  if (length(manifest$derived) != length(expected$derived_files)) {
    stop("D4.1 MANIFEST DERIVED COUNT MISMATCH", call. = FALSE)
  }
  if (length(manifest$companions) != length(expected$normalized_companion_files)) {
    stop("D4.1 MANIFEST COMPANION COUNT MISMATCH", call. = FALSE)
  }
  if (length(manifest$catalogue_raw) != length(expected$companion_files)) {
    stop("D4.1 MANIFEST CATALOGUE COUNT MISMATCH", call. = FALSE)
  }
  naming_roles <- c(
    class_file = "naming_authority",
    crosswalk_file = "naming_crosswalk",
    exclusions_file = "naming_exclusions"
  )
  for (name in names(naming_roles)) {
    if (is.null(manifest$naming[[name]])) {
      stop(
        sprintf("D4.1 MANIFEST NAMING ENTRY MISSING (%s)", naming_roles[[name]]),
        call. = FALSE
      )
    }
    validate_entry(
      manifest$naming[[name]],
      expected$naming_files[[name]],
      naming_roles[[name]]
    )
  }

  Map(
    validate_entry,
    manifest$inputs,
    unname(expected$input_files),
    "manual_input_workbook"
  )
  validate_entry(
    manifest$review,
    expected$review_file,
    "manual_review"
  )
  Map(
    validate_entry,
    manifest$derived,
    unname(expected$derived_files),
    "derived_indicator_csv"
  )
  Map(
    validate_entry,
    manifest$catalogue_raw,
    unname(expected$companion_files),
    "d41_catalogue_raw"
  )
  Map(
    validate_entry,
    manifest$companions,
    unname(expected$normalized_companion_files),
    "d41_catalogue_companion"
  )
  refresh_path <- dim4_1_catalogue_refresh_record_path(raw_dir)
  has_refresh <- !is.null(manifest$catalogue_refresh) && length(manifest$catalogue_refresh) > 0L
  if (file.exists(refresh_path) && !has_refresh) {
    stop(
      "D4.1 MANIFEST REFRESH PROVENANCE MISSING: rerun the D4.1 collection target.",
      call. = FALSE
    )
  }
  if (has_refresh) {
    validate_entry(
      manifest$catalogue_refresh,
      refresh_path,
      "d41_catalogue_refresh_record"
    )
    dim4_1_read_refresh_record(raw_dir, end_date)
  }
  if (!is.null(valid_iso3c)) {
    valid_iso3c <- unique(trimws(as.character(valid_iso3c)))
    outside <- lapply(manifest$companions, function(entry) {
      data <- readr::read_csv(
        dim4_1_resolve_manifest_path(entry$path),
        col_types = readr::cols_only(iso3c = readr::col_character()),
        progress = FALSE
      )
      sort(setdiff(unique(trimws(data$iso3c)), valid_iso3c))
    })
    outside <- sort(unique(unlist(outside, use.names = FALSE)))
    if (length(outside) > 0L) {
      stop(
        "D4.1 MANIFEST EVIDENCE OUTSIDE ESTIMATION COUNTRY UNIVERSE: ",
        paste(outside, collapse = ", "),
        call. = FALSE
      )
    }
  }
  invisible(manifest)
}

#' Locate the legacy microdata-catalogue script.
#'
#' @return Path to `02_programs/misc_scripts/microdata_library_pull.Rmd`.
#' @export
dim4_1_catalogue_script_path <- function() {
  here::here("02_programs", "misc_scripts", "microdata_library_pull.Rmd")
}

#' Purl the legacy catalogue script into runnable code.
#'
#' The script is not edited: its code is purled and adjusted for the current
#' environment (packages that are not installed, the `path` argument that
#' readr 2 removed, a wrapped comment, and a diagnostic block).
#'
#' @param script_path Path to `microdata_library_pull.Rmd`.
#' @return A character vector of R code lines.
#' @export
dim4_1_legacy_catalogue_code <- function(script_path) {
  if (!file.exists(script_path)) {
    stop("D4.1 CATALOGUE SCRIPT NOT FOUND: ", script_path, call. = FALSE)
  }
  if (!requireNamespace("knitr", quietly = TRUE)) {
    stop("D4.1 CATALOGUE REFRESH REQUIRES the `knitr` package.", call. = FALSE)
  }
  code_path <- tempfile("d41-catalogue-", fileext = ".R")
  on.exit(unlink(code_path), add = TRUE)
  knitr::purl(
    input = script_path,
    output = code_path,
    quiet = TRUE,
    documentation = 0
  )
  code <- readLines(code_path, warn = FALSE)
  continuation <- which(grepl("# keep jus$", code))
  for (index in rev(continuation)) {
    if (index < length(code) && grepl("^t nationally", code[[index + 1L]])) {
      code[[index]] <- paste0(code[[index]], code[[index + 1L]])
      code <- code[-(index + 1L)]
    }
  }
  code <- code[!grepl("^`[[:space:]]*$", code)]
  unavailable_setup <- c(
    "skimr", "kableExtra", "Hmisc", "gt", "tidytext", "rsdmx", "ggthemes"
  )
  setup_pattern <- paste0(
    "^library[(](", paste(unavailable_setup, collapse = "|"), ")[)]"
  )
  code <- code[!grepl(setup_pattern, code)]
  code <- code[!grepl("^gt[(]", trimws(code))]
  code <- gsub("path[[:space:]]*=", "file =", code)
  code <- c(
    "write_excel_csv <- function(x, file, ...) {",
    "  if (!is.data.frame(x)) x <- as.data.frame(x)",
    "  readr::write_excel_csv(x, file, ...)",
    "}",
    code
  )
  match_start <- grep("^# check for matches", code)
  next_block <- if (length(match_start) == 1L) {
    candidates <- grep("^# get list of survey ids", code)
    candidates[candidates > match_start[[1L]]]
  } else {
    integer()
  }
  if (length(next_block) > 0L) {
    code <- code[-seq.int(match_start, next_block[[1L]] - 1L)]
  }
  code
}

#' List the catalogue endpoints a catalogue script requests.
#'
#' @param code Code lines from dim4_1_legacy_catalogue_code().
#' @return Sorted unique URLs.
#' @export
dim4_1_catalogue_request_urls <- function(code) {
  active <- code[!grepl("^[[:space:]]*#", code)]
  urls <- unlist(regmatches(active, gregexpr("https?://[^\"' ,)]+", active)))
  sort(unique(urls))
}

#' Companions a catalogue script writes.
#'
#' The legacy script writes seven of the eight companions: it writes the FAO
#' agricultural census list to `D4.1.2.CEN.AGRI_NADA_FAO.csv`, which the
#' estimation does not read, and never writes `D4.1.2.CEN.AGRI_NADA.csv`.
#'
#' @param code Code lines from dim4_1_legacy_catalogue_code().
#' @return Companion stems whose `<stem>_NADA.csv` the code names.
#' @export
dim4_1_catalogue_written_companions <- function(code) {
  active <- paste(code[!grepl("^[[:space:]]*#", code)], collapse = "\n")
  stems <- names(dim4_1_workbook_specs())
  stems[vapply(stems, function(stem) grepl(paste0('"', stem, '_NADA.csv"'), active, fixed = TRUE), logical(1))]
}

#' Run the legacy catalogue script with its output redirected to staging.
#'
#' The script writes to `paste(here(), "01_raw_data", "4.1_SOCS/", sep = "/")`;
#' `here()` is shadowed so that this resolves to `staging_dir`. With a
#' `fetcher`, every catalogue response the script requests is fetched first
#' (dim4_1_catalogue_prefetch()) and the script's `fromJSON()` is served from
#' that cache (dim4_1_cached_fromjson()). The script runs in a separate R
#' process that is stopped when the budget runs out.
#'
#' @param params Collection parameters.
#' @param staging_dir Staging copy of `01_raw_data/4.1_SOCS`.
#' @param code Code lines from dim4_1_legacy_catalogue_code().
#' @param budget_seconds Run-time budget for the prefetch and the script.
#' @param sources Endpoint descriptions from dim4_1_catalogue_sources().
#' @param fetcher Optional `function(urls)` for the prefetch; without it the
#'   script requests the catalogue itself.
#' @param retry_wait_seconds Pauses before successive retry rounds.
#' @param passthrough fromJSON() used for requests that are not cached.
#' @param retired Retired sources (dim4_1_retired_sources()) replayed from
#'   their snapshot after dim4_1_check_retired_source() confirms they are
#'   still retired; requires a `fetcher`.
#' @param extra_urls Other URLs the script reads with readLines()
#'   (dim4_1_catalogue_extra_urls()), cached with the catalogue responses.
#' @return Invisibly, a list with the `prefetch` summary, the checks of the
#'   `retired_sources`, and the script's `legacy_requests` (served from the
#'   cache or a snapshot, requested outside them).
#' @export
dim4_1_legacy_catalogue_adapter <- function(params, staging_dir, code,
                                            budget_seconds,
                                            sources = dim4_1_catalogue_sources(),
                                            fetcher = NULL,
                                            retry_wait_seconds = c(5, 30, 120),
                                            passthrough = jsonlite::fromJSON,
                                            retired = NULL,
                                            extra_urls = character()) {
  deadline <- Sys.time() + budget_seconds
  cache <- dim4_1_catalogue_cache_paths(params$raw_dir)
  prefetch <- NULL
  if (!is.null(fetcher)) {
    prefetch <- dim4_1_catalogue_prefetch(
      cache,
      sources = sources,
      fetcher = fetcher,
      max_attempts = .d41_param(params, "d41_catalogue_max_attempts", 4L),
      retry_wait_seconds = retry_wait_seconds,
      max_age_days = .d41_param(params, "d41_catalogue_cache_max_age_days", 7),
      deadline = deadline,
      extra_urls = extra_urls
    )
  }
  retired_checks <- NULL
  if (length(retired) > 0L) {
    if (is.null(fetcher)) {
      stop("D4.1 RETIRED CATALOGUE REPLAY REQUIRES A FETCHER to confirm the retirement.", call. = FALSE)
    }
    retired_checks <- lapply(retired, dim4_1_check_retired_source, fetcher = fetcher)
  }
  code_path <- tempfile("d41-catalogue-", fileext = ".R")
  on.exit(unlink(code_path), add = TRUE)
  writeLines(code, code_path, useBytes = TRUE)
  staging_root <- dirname(dirname(normalizePath(staging_dir, winslash = "/")))
  # Functions passed to the child process must not carry the caller's
  # environment with them.
  factory <- dim4_1_cached_fromjson
  environment(factory) <- globalenv()
  replay_factory <- dim4_1_snapshot_download_file
  environment(replay_factory) <- globalenv()
  lines_factory <- dim4_1_cached_readlines
  environment(lines_factory) <- globalenv()
  if (!isNamespace(environment(passthrough))) {
    environment(passthrough) <- globalenv()
  }
  remaining <- as.numeric(difftime(deadline, Sys.time(), units = "secs"))
  if (remaining <= 0) {
    stop("D4.1 CATALOGUE REFRESH: the prefetch used the whole budget.", call. = FALSE)
  }
  requests <- tryCatch(callr::r(
    function(code_path, staging_root, factory, index_path, body_dir, passthrough,
             replay_factory, retired, lines_factory) {
      env <- new.env(parent = globalenv())
      assign("here", function(...) staging_root, envir = env)
      cached <- NULL
      if (!is.null(factory)) {
        cached <- factory(index_path, body_dir, fallback = passthrough)
        assign("fromJSON", cached, envir = env)
      }
      lines <- NULL
      if (!is.null(lines_factory)) {
        lines <- lines_factory(index_path, body_dir, fallback = base::readLines)
        assign("readLines", lines, envir = env)
      }
      replay <- NULL
      if (!is.null(replay_factory)) {
        replay <- replay_factory(retired, fallback = utils::download.file)
        assign("download.file", replay, envir = env)
      }
      sys.source(code_path, envir = env)
      if (is.null(cached) && is.null(replay)) {
        return(NULL)
      }
      empty <- data.frame(url = character(), message = character(), stringsAsFactors = FALSE)
      cached_log <- if (is.null(cached)) NULL else attr(cached, "log")
      replay_log <- if (is.null(replay)) NULL else attr(replay, "log")
      list(
        served_ok = if (is.null(cached_log)) 0L else cached_log$served[["ok"]],
        served_not_found = if (is.null(cached_log)) 0L else cached_log$served[["not_found"]],
        passthrough = c(cached_log$passthrough, replay_log$passthrough),
        passthrough_failures = rbind(
          if (is.null(cached_log)) empty else cached_log$passthrough_failures,
          if (is.null(replay_log)) empty else replay_log$passthrough_failures
        ),
        retired_pages_served = if (is.null(replay_log)) 0L else replay_log$served,
        served_lines = if (is.null(lines)) 0L else attr(lines, "log")$served,
        lines_passthrough = if (is.null(lines)) character() else attr(lines, "log")$passthrough
      )
    },
    args = list(
      code_path = code_path,
      staging_root = staging_root,
      factory = if (is.null(prefetch)) NULL else factory,
      index_path = cache$index,
      body_dir = cache$bodies,
      passthrough = passthrough,
      replay_factory = if (is.null(retired_checks)) NULL else replay_factory,
      retired = retired,
      lines_factory = if (is.null(prefetch) || length(extra_urls) == 0L) NULL else lines_factory
    ),
    timeout = remaining,
    show = TRUE
  ), error = function(error) {
    # Document the failure for a later retry, then stop as before.
    .d41_append_failures(
      cache,
      data.frame(url = NA_character_, message = conditionMessage(error), stringsAsFactors = FALSE),
      source = "legacy_script"
    )
    stop(error)
  })
  if (!is.null(requests) && nrow(requests$passthrough_failures) > 0L) {
    .d41_append_failures(cache, requests$passthrough_failures)
    stop(
      sprintf(
        "D4.1 CATALOGUE REQUEST FAILED OUTSIDE THE CACHE: %d request(s) the script made itself failed (%s); documented in %s. Nothing was promoted.",
        nrow(requests$passthrough_failures),
        paste(utils::head(requests$passthrough_failures$url, 3L), collapse = ", "),
        cache$failures
      ),
      call. = FALSE
    )
  }
  invisible(list(prefetch = prefetch, retired_sources = retired_checks, legacy_requests = requests))
}

# Move staged files into place under a recoverable complete-set transaction.
dim4_1_promote_staged_files <- function(staged_files, target_dir, backup_dir,
                                        fail_after = NULL) {
  dim4_1_recover_catalogue_promotion(target_dir)
  targets <- file.path(target_dir, basename(staged_files))
  existed <- file.exists(targets)
  dir.create(backup_dir, recursive = TRUE, showWarnings = FALSE)
  if (any(existed) &&
      !all(file.copy(targets[existed], backup_dir, overwrite = TRUE, copy.date = TRUE))) {
    stop(
      "D4.1 CATALOGUE PROMOTION FAILED: the previous companion set could not be backed up",
      call. = FALSE
    )
  }
  marker_path <- dim4_1_promotion_marker_path(target_dir)
  marker <- list(
    schema_version = "spi-d41-promotion-v1",
    targets = targets,
    existed = existed,
    backup_dir = normalizePath(backup_dir, winslash = "/", mustWork = FALSE),
    staging_root = normalizePath(dirname(backup_dir), winslash = "/", mustWork = FALSE)
  )
  marker_partial <- paste0(marker_path, ".partial")
  jsonlite::write_json(marker, marker_partial, auto_unbox = TRUE, pretty = TRUE)
  if (!file.rename(marker_partial, marker_path)) {
    unlink(marker_partial, force = TRUE)
    stop("D4.1 CATALOGUE PROMOTION FAILED: could not write promotion journal", call. = FALSE)
  }
  outcome <- tryCatch({
    for (index in seq_along(staged_files)) {
      if (!is.null(fail_after) && identical(as.integer(index), as.integer(fail_after))) {
        stop("injected promotion failure", call. = FALSE)
      }
      if (!file.rename(staged_files[[index]], targets[[index]]) &&
          !file.copy(staged_files[[index]], targets[[index]], overwrite = TRUE)) {
        stop("could not write ", targets[[index]], call. = FALSE)
      }
    }
    TRUE
  }, error = function(error) error)
  if (!isTRUE(outcome)) {
    dim4_1_recover_catalogue_promotion(target_dir)
    stop(
      "D4.1 CATALOGUE PROMOTION FAILED and was rolled back: ",
      conditionMessage(outcome),
      call. = FALSE
    )
  }
  unlink(marker_path, force = TRUE)
  invisible(targets)
}

#' Refresh the D4.1 catalogue companions through a staging directory.
#'
#' The adapter writes a complete companion set into a staging copy of
#' `4.1_SOCS`. All eight companions must be present and pass the Step 16
#' normalization rules before any file is promoted; promotion restores the
#' previous set if it fails. The adapter runs within
#' `params$d41_catalogue_budget_minutes`.
#'
#' @param params Collection parameters.
#' @param refresh_fn Adapter `function(params, staging_dir)`.
#' @param adapter Adapter label recorded in the manifest.
#' @param request Request identity recorded in the manifest.
#' @param companions Companion stems the adapter produces; any other
#'   companion is carried forward unchanged and recorded as such.
#' @return The refresh record.
#' @export
dim4_1_refresh_catalogue <- function(params, refresh_fn, adapter = "injected",
                                     request = list(),
                                     companions = names(dim4_1_workbook_specs()),
                                     valid_iso3c = NULL) {
  budget_minutes <- params$d41_catalogue_budget_minutes
  if (is.null(budget_minutes) || !is.numeric(budget_minutes) ||
      length(budget_minutes) != 1L || !is.finite(budget_minutes) ||
      budget_minutes <= 0) {
    stop(
      "D4.1 CATALOGUE REFRESH REQUIRES a positive d41_catalogue_budget_minutes.",
      call. = FALSE
    )
  }
  budget_seconds <- budget_minutes * 60
  target_dir <- file.path(params$raw_dir, "4.1_SOCS")
  staging_root <- file.path(
    target_dir,
    "collection",
    paste0("staging-", format(Sys.time(), "%Y%m%dT%H%M%S"), "-", Sys.getpid())
  )
  staging_dir <- file.path(staging_root, "01_raw_data", "4.1_SOCS")
  dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(staging_root, recursive = TRUE, force = TRUE), add = TRUE)

  inputs <- "ilo_sources_catalog.csv"
  available_inputs <- file.path(target_dir, inputs)
  available_inputs <- available_inputs[file.exists(available_inputs)]
  file.copy(available_inputs, staging_dir, overwrite = TRUE, copy.date = TRUE)

  started <- Sys.time()
  on.exit(setTimeLimit(elapsed = Inf), add = TRUE)
  adapter_value <- NULL
  outcome <- tryCatch({
    setTimeLimit(elapsed = budget_seconds, transient = TRUE)
    adapter_value <- refresh_fn(params, staging_dir)
    setTimeLimit(elapsed = Inf)
    TRUE
  }, error = function(error) {
    setTimeLimit(elapsed = Inf)
    error
  })
  finished <- Sys.time()
  elapsed <- as.numeric(difftime(finished, started, units = "secs"))
  if (isTRUE(outcome) && elapsed > budget_seconds) {
    outcome <- simpleError("the adapter returned after the budget")
  }
  if (!isTRUE(outcome)) {
    if (elapsed >= budget_seconds || inherits(outcome, "callr_timeout_error")) {
      stop(
        sprintf(
          "D4.1 CATALOGUE REFRESH EXCEEDED ITS BUDGET (%.0f s): the previous companion set is unchanged. %s",
          budget_seconds,
          conditionMessage(outcome)
        ),
        call. = FALSE
      )
    }
    stop(
      "D4.1 CATALOGUE REFRESH FAILED; the previous companion set is unchanged: ",
      conditionMessage(outcome),
      call. = FALSE
    )
  }

  stems <- names(dim4_1_workbook_specs())
  produced <- intersect(stems, companions)
  carried <- setdiff(stems, produced)
  staged_companions <- file.path(staging_dir, paste0(produced, "_NADA.csv"))
  missing <- produced[!file.exists(staged_companions)]
  if (length(missing) > 0L) {
    stop(
      "D4.1 STAGED CATALOGUE INCOMPLETE; nothing promoted. Missing: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  # Companions the adapter does not produce keep their current file; a copy
  # joins the staged set only so that all eight are validated together.
  for (stem in carried) {
    current <- file.path(target_dir, paste0(stem, "_NADA.csv"))
    if (!file.exists(current)) {
      stop(
        "D4.1 CATALOGUE COMPANION NEITHER REFRESHED NOR PRESENT: ", current,
        call. = FALSE
      )
    }
    file.copy(current, staging_dir, overwrite = TRUE, copy.date = TRUE)
  }
  staged_check <- tryCatch(
    normalize_dim4_1_companions(
      file.path(staging_root, "01_raw_data"),
      end_date = params$end_date,
      output_dir = file.path(staging_root, "normalized"),
      naming = dim4_1_naming_files(params$raw_dir),
      valid_iso3c = valid_iso3c
    ),
    error = function(error) error
  )
  if (inherits(staged_check, "error")) {
    stop(
      "D4.1 STAGED CATALOGUE REJECTED; nothing promoted: ",
      conditionMessage(staged_check),
      call. = FALSE
    )
  }

  staged_files <- list.files(staging_dir, pattern = "[.]csv$", full.names = TRUE)
  staged_files <- staged_files[!basename(staged_files) %in% c(inputs, paste0(carried, "_NADA.csv"))]
  dim4_1_promote_staged_files(
    staged_files,
    target_dir,
    backup_dir = file.path(staging_root, "previous")
  )

  companion_records <- lapply(stems, function(stem) {
    path <- file.path(target_dir, paste0(stem, "_NADA.csv"))
    list(
      rows = staged_check$files[[stem]]$raw_rows,
      sha256 = digest::digest(path, algo = "sha256", file = TRUE),
      refreshed = stem %in% produced
    )
  })
  names(companion_records) <- stems
  record <- list(
    adapter = adapter,
    request = request,
    started_at = format(started, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    finished_at = format(finished, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    elapsed_seconds = round(elapsed, 1),
    budget_seconds = budget_seconds,
    companions = companion_records,
    carried_forward = carried,
    promoted_files = basename(staged_files),
    fetch = if (is.list(adapter_value)) adapter_value else NULL
  )
  record_path <- dim4_1_catalogue_refresh_record_path(params$raw_dir)
  dir.create(dirname(record_path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(record, record_path, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null")
  record
}

#' Path of the record of the last promoted catalogue refresh.
#'
#' @param raw_dir Root raw-data directory.
#' @return `4.1_SOCS/collection/catalogue_refresh.json` under `raw_dir`.
#' @export
dim4_1_catalogue_refresh_record_path <- function(raw_dir) {
  file.path(raw_dir, "4.1_SOCS", "collection", "catalogue_refresh.json")
}

.d41_validate_refresh_record <- function(record, raw_dir, end_date, path) {
  required <- c(
    "adapter", "request", "started_at", "finished_at", "elapsed_seconds",
    "budget_seconds", "companions", "carried_forward", "promoted_files", "fetch"
  )
  missing <- setdiff(required, names(record))
  if (length(missing) > 0L) {
    stop(
      "D4.1 CATALOGUE REFRESH RECORD SCHEMA INVALID; missing ",
      paste(missing, collapse = ", "), " in ", path,
      call. = FALSE
    )
  }
  if (length(record$adapter) != 1L || is.na(record$adapter) || !nzchar(record$adapter)) {
    stop("D4.1 CATALOGUE REFRESH RECORD HAS NO adapter: ", path, call. = FALSE)
  }
  for (field in c("started_at", "finished_at")) {
    value <- as.character(record[[field]])
    parsed <- as.POSIXct(value, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    if (length(value) != 1L || is.na(parsed)) {
      stop("D4.1 CATALOGUE REFRESH RECORD HAS INVALID ", field, ": ", path, call. = FALSE)
    }
  }
  numeric_fields <- c("elapsed_seconds", "budget_seconds")
  if (any(!vapply(record[numeric_fields], function(value) {
    length(value) == 1L && is.numeric(value) && is.finite(value) && value >= 0
  }, logical(1)))) {
    stop("D4.1 CATALOGUE REFRESH RECORD HAS INVALID TIMING FIELDS: ", path, call. = FALSE)
  }

  stems <- names(dim4_1_workbook_specs())
  if (!is.list(record$companions) || !identical(sort(names(record$companions)), sort(stems))) {
    stop("D4.1 CATALOGUE REFRESH RECORD COMPANION SET INVALID: ", path, call. = FALSE)
  }
  companion_files <- dim4_1_artifact_paths(raw_dir, end_date)$companion_files
  for (stem in stems) {
    companion <- record$companions[[stem]]
    if (!is.list(companion) || !all(c("rows", "sha256", "refreshed") %in% names(companion))) {
      stop("D4.1 CATALOGUE REFRESH RECORD COMPANION ENTRY INVALID: ", stem, call. = FALSE)
    }
    if (length(companion$rows) != 1L || is.na(companion$rows) ||
        !is.numeric(companion$rows) || companion$rows < 0 ||
        length(companion$refreshed) != 1L || is.na(companion$refreshed) ||
        !is.logical(companion$refreshed) ||
        length(companion$sha256) != 1L ||
        !grepl("^[0-9a-fA-F]{64}$", companion$sha256)) {
      stop("D4.1 CATALOGUE REFRESH RECORD COMPANION ENTRY INVALID: ", stem, call. = FALSE)
    }
    current <- companion_files[[stem]]
    if (!file.exists(current) || !identical(
      tolower(as.character(companion$sha256)),
      tolower(digest::digest(current, algo = "sha256", file = TRUE))
    )) {
      stop(
        "D4.1 CATALOGUE REFRESH RECORD DOES NOT MATCH CURRENT COMPANION: ",
        stem,
        call. = FALSE
      )
    }
  }

  # Production catalogue runs must carry identities for the prefetch index
  # and failure log. Injected adapters remain intentionally lightweight test
  # fixtures, but any identities they provide are still checked.
  prefetch <- if (is.list(record$fetch)) record$fetch$prefetch else NULL
  production <- !identical(as.character(record$adapter), "injected")
  if (production && !is.list(prefetch)) {
    stop("D4.1 CATALOGUE REFRESH RECORD HAS NO PREFETCH PROVENANCE: ", path, call. = FALSE)
  }
  if (is.list(prefetch)) {
    present <- intersect(c("index", "failures"), names(prefetch))
    if (production && !all(c("index", "failures") %in% present)) {
      stop("D4.1 CATALOGUE REFRESH RECORD HAS INCOMPLETE PREFETCH PROVENANCE: ", path, call. = FALSE)
    }
    for (field in present) {
      identity <- prefetch[[field]]
      if (is.null(identity) || !is.list(identity) || length(identity) == 0L ||
          length(identity$path) != 1L || !nzchar(identity$path)) {
        stop(
          "D4.1 CATALOGUE REFRESH RECORD HAS INVALID PREFETCH ", field, ": ",
          path,
          call. = FALSE
        )
      }
      identity_path <- dim4_1_resolve_manifest_path(identity$path)
      if (!file.exists(identity_path)) {
        stop("D4.1 CATALOGUE REFRESH PREFETCH FILE MISSING: ", identity_path, call. = FALSE)
      }
      if (!is.null(identity$sha256) && !identical(
        tolower(as.character(identity$sha256)),
        tolower(digest::digest(identity_path, algo = "sha256", file = TRUE))
      )) {
        stop("D4.1 CATALOGUE REFRESH PREFETCH HASH MISMATCH: ", identity_path, call. = FALSE)
      }
    }
  }
  invisible(TRUE)
}

#' Read the last refresh record and compare it with the current companions.
#'
#' @param raw_dir Root raw-data directory.
#' @param end_date Current SPI reference year.
#' @return The record with `matches_current_companions` and
#'   `changed_companions`, or NULL when no refresh was recorded.
#' @export
dim4_1_read_refresh_record <- function(raw_dir, end_date) {
  path <- dim4_1_catalogue_refresh_record_path(raw_dir)
  if (!file.exists(path)) {
    return(NULL)
  }
  record <- jsonlite::read_json(path, simplifyVector = FALSE)
  .d41_validate_refresh_record(record, raw_dir, end_date, path)
  companion_files <- dim4_1_artifact_paths(raw_dir, end_date)$companion_files
  changed <- names(companion_files)[vapply(names(companion_files), function(stem) {
    recorded <- record$companions[[stem]]$sha256
    current <- if (file.exists(companion_files[[stem]])) {
      digest::digest(companion_files[[stem]], algo = "sha256", file = TRUE)
    } else {
      NA_character_
    }
    is.null(recorded) || !identical(recorded, current)
  }, logical(1))]
  record$matches_current_companions <- length(changed) == 0L
  record$changed_companions <- changed
  record
}

#' Refresh or validate D4.1 catalogue companion artifacts.
#'
#' Without a refresh, the existing raw companions are normalized and
#' validated. With `run_downloads = TRUE` (or an injected adapter), the
#' companions are refreshed through dim4_1_refresh_catalogue() first.
#'
#' @param params Collection parameters.
#' @param refresh_fn Optional injected adapter `function(params, staging_dir)`.
#' @return A catalogue collection result, including the refresh record.
#' @export
collect_dim4_1_catalogue <- function(params, refresh_fn = NULL, valid_iso3c = NULL) {
  if (is.null(params$end_date)) {
    stop("D4.1 CATALOGUE COLLECTION REQUIRES end_date.", call. = FALSE)
  }
  refresh <- NULL
  if (!is.null(refresh_fn)) {
    refresh <- dim4_1_refresh_catalogue(
      params,
      refresh_fn,
      valid_iso3c = valid_iso3c
    )
  } else if (isTRUE(params$run_downloads)) {
    script_path <- dim4_1_catalogue_script_path()
    code <- dim4_1_legacy_catalogue_code(script_path)
    dim4_1_check_catalogue_sources(code)
    fetcher <- dim4_1_catalogue_curl_fetcher(
      connections = .d41_param(params, "d41_catalogue_connections", 8L)
    )
    refresh <- dim4_1_refresh_catalogue(
      params,
      refresh_fn = function(params, staging_dir) {
        dim4_1_legacy_catalogue_adapter(
          params,
          staging_dir,
          code = code,
          budget_seconds = params$d41_catalogue_budget_minutes * 60,
          fetcher = fetcher,
          retired = dim4_1_retired_sources(params$raw_dir),
          extra_urls = dim4_1_catalogue_extra_urls()
        )
      },
      adapter = dim4_1_project_relative_path(script_path),
      request = list(
        script_sha256 = digest::digest(script_path, algo = "sha256", file = TRUE),
        urls = dim4_1_catalogue_request_urls(code)
      ),
      companions = dim4_1_catalogue_written_companions(code),
      valid_iso3c = valid_iso3c
    )
  }

  normalized <- normalize_dim4_1_companions(
    params$raw_dir,
    end_date = params$end_date,
    valid_iso3c = valid_iso3c
  )
  last_refresh <- if (is.null(refresh)) {
    dim4_1_read_refresh_record(params$raw_dir, params$end_date)
  } else {
    NULL
  }
  if (!is.null(last_refresh) && !isTRUE(last_refresh$matches_current_companions)) {
    stop(
      "D4.1 CATALOGUE REFRESH RECORD DOES NOT MATCH CURRENT COMPANIONS: ",
      paste(last_refresh$changed_companions, collapse = ", "),
      call. = FALSE
    )
  }
  list(
    status = if (is.null(refresh)) "validated_external_artifacts" else "refreshed",
    refreshed = !is.null(refresh),
    refresh = refresh,
    last_refresh = last_refresh,
    companion_files = vapply(normalized$files, `[[`, character(1), "path"),
    raw_companion_files = vapply(normalized$files, `[[`, character(1), "raw_path"),
    rows = vapply(normalized$files, `[[`, integer(1), "rows"),
    exclusions = normalized$exclusions
  )
}

#' Write a D4.1 collection manifest as JSON.
#'
#' @param manifest Manifest list from dim4_1_build_manifest().
#' @param path Output JSON path.
#' @return The output path.
#' @export
write_dim4_1_manifest <- function(manifest, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(manifest, path, auto_unbox = TRUE, pretty = TRUE)
  path
}

#' Merge one manual-review value with a source value.
#'
#' @param base_values Source values from a generated D4.1 CSV.
#' @param review_values Manual-review values.
#' @param register_based Whether to preserve register-based census text.
#' @return Character values containing the combined evidence.
#' @export
dim4_1_merge_review_values <- function(base_values, review_values,
                                       register_based = FALSE) {
  if (length(base_values) != length(review_values)) {
    stop("D4.1 REVIEW MERGE REQUIRES VECTORS OF EQUAL LENGTH.", call. = FALSE)
  }

  vapply(seq_along(base_values), function(index) {
    base <- if (is.na(base_values[[index]])) "" else trimws(as.character(base_values[[index]]))
    review <- if (is.na(review_values[[index]])) "" else trimws(as.character(review_values[[index]]))
    combined <- paste(c(base, review)[nzchar(c(base, review))], collapse = ", ")
    if (register_based && grepl("register.*based.*census", combined, ignore.case = TRUE)) {
      remaining <- gsub(
        "register.*based.*census",
        "",
        combined,
        ignore.case = TRUE
      )
      remaining <- trimws(gsub(",+", " ", remaining))
      combined <- paste(
        c("Register based census", remaining)[nzchar(c("Register based census", remaining))],
        collapse = ", "
      )
    }
    if (nzchar(combined)) combined else NA_character_
  }, character(1))
}

#' Validate all current Dimension 4.1 manual inputs.
#'
#' @param raw_dir Root raw-data directory.
#' @param end_date Current SPI reference year.
#' @return A validation manifest list.
#' @export
validate_dim4_1_workbooks <- function(raw_dir, end_date) {
  specs <- dim4_1_workbook_specs()
  paths <- dim4_1_artifact_paths(raw_dir, end_date)

  for (name in names(specs)) {
    validate_dim4_1_workbook(paths$input_files[[name]], specs[[name]])
  }

  if (!file.exists(paths$review_file)) {
    stop(
      sprintf("D4.1 MANUAL REVIEW FILE NOT FOUND: %s", paths$review_file),
      call. = FALSE
    )
  }
  review_data <- readxl::read_xlsx(paths$review_file, .name_repair = "minimal")
  validate_dim4_1_review(review_data)

  list(
    valid = TRUE,
    end_date = end_date,
    input_files = unname(paths$input_files),
    review_file = paths$review_file,
    derived_files = unname(paths$derived_files),
    companion_files = unname(paths$companion_files)
  )
}

dim4_1_clean_year_values <- function(values) {
  gsub("^,*|(?<=,),|,*$", "", as.character(values), perl = TRUE)
}

#' Require workbook year values to be four-digit years.
#'
#' Census workbooks may also say "Register based census" (any case, space or
#' hyphen), which the census scorer recognizes.
#'
#' @param values Raw workbook values.
#' @param file_name Workbook name for the error message.
#' @param allow_register Whether register-based census text is valid.
#' @return Invisibly TRUE; stops on any other text.
#' @export
dim4_1_check_year_values <- function(values, file_name, allow_register) {
  cleaned <- trimws(dim4_1_clean_year_values(values))
  present <- !is.na(cleaned) & nzchar(cleaned)
  tokens <- trimws(unlist(strsplit(cleaned[present], ",", fixed = TRUE), use.names = FALSE))
  valid <- grepl("^[0-9]{4}$", tokens)
  if (allow_register) {
    valid <- valid |
      grepl("^register[ -]based[ -]census$", tokens, ignore.case = TRUE)
  }
  invalid <- unique(tokens[!valid])
  if (length(invalid) > 0L) {
    stop(
      sprintf(
        "D4.1 INVALID YEAR TEXT in '%s': %s. Values must be comma-separated four-digit years%s.",
        file_name,
        paste(sprintf("'%s'", invalid), collapse = ", "),
        if (allow_register) " or 'Register based census'" else ""
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Require a workbook to cover every country of the previous derived CSV.
#'
#' @param codes ISO3 codes read from the workbook.
#' @param previous_path Derived CSV of the previous reference year.
#' @param file_name Workbook name for the error message.
#' @return Invisibly TRUE; stops when countries are lost.
#' @export
dim4_1_check_coverage <- function(codes, previous_path, file_name) {
  if (!file.exists(previous_path)) {
    stop(
      sprintf(
        "D4.1 PREVIOUS DERIVED FILE NOT FOUND (coverage baseline for '%s'): %s",
        file_name,
        previous_path
      ),
      call. = FALSE
    )
  }
  previous <- .dim4_1_read_text_csv(previous_path)
  if (!"iso3c" %in% names(previous)) {
    stop("D4.1 PREVIOUS DERIVED FILE HAS NO iso3c COLUMN: ", previous_path, call. = FALSE)
  }
  expected <- unique(trimws(previous$iso3c[!is.na(previous$iso3c)]))
  current <- unique(trimws(as.character(codes[!is.na(codes)])))
  lost <- sort(setdiff(expected, current))
  if (length(lost) > 0L) {
    stop(
      sprintf(
        "D4.1 WORKBOOK COVERAGE LOSS in '%s': %d countr%s of %s missing: %s",
        file_name,
        length(lost),
        if (length(lost) == 1L) "y" else "ies",
        basename(previous_path),
        paste(lost, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

dim4_1_find_column <- function(data, pattern, file_name) {
  matches <- grep(pattern, names(data), value = TRUE)
  if (length(matches) != 1L) {
    stop(
      sprintf(
        "D4.1 INPUT COLUMN MATCH FAILED in '%s': pattern '%s' matched %d column(s)",
        file_name,
        pattern,
        length(matches)
      ),
      call. = FALSE
    )
  }
  matches[[1]]
}

dim4_1_join_country_metadata <- function(data, country_metadata, file_name) {
  if (!is.data.frame(country_metadata) || !"iso3c" %in% names(country_metadata)) {
    stop(
      "D4.1 COUNTRY METADATA MUST BE A DATA FRAME WITH AN iso3c COLUMN.",
      call. = FALSE
    )
  }
  if (anyDuplicated(country_metadata$iso3c) > 0L) {
    stop(
      "D4.1 COUNTRY METADATA HAS DUPLICATE iso3c KEYS.",
      call. = FALSE
    )
  }

  joined <- dplyr::left_join(data, country_metadata, by = "iso3c")
  missing_metadata <- unique(joined$iso3c[is.na(joined$country)])
  if (length(missing_metadata) > 0L && "country" %in% names(country_metadata)) {
    stop(
      sprintf(
        "D4.1 COUNTRY METADATA MISSING in '%s': %s",
        file_name,
        paste(missing_metadata, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  dplyr::select(joined, dplyr::all_of(names(country_metadata)), dplyr::everything())
}

dim4_1_read_workbook <- function(path, spec) {
  readxl::read_xlsx(
    path,
    sheet = spec$sheet,
    skip = spec$skip,
    .name_repair = "universal"
  )
}

#' Preprocess the eight manual Dimension 4.1 workbooks.
#'
#' Year values must be comma-separated four-digit years (census workbooks may
#' also say "Register based census"), and every workbook must still list each
#' country of the previous reference year's derived CSV.
#'
#' @param raw_dir Root raw-data directory.
#' @param end_date Current SPI reference year.
#' @param country_metadata Country metadata with a unique iso3c key.
#' @param output_dir Directory for generated current-vintage CSVs.
#' @return A named character vector of generated CSV paths.
#' @export
preprocess_dim4_1 <- function(raw_dir, end_date, country_metadata,
                              output_dir = file.path(raw_dir, "4.1_SOCS", "raw")) {
  paths <- dim4_1_artifact_paths(raw_dir, end_date)
  validate_dim4_1_workbooks(raw_dir, end_date)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  paths$derived_files <- setNames(
    file.path(output_dir, basename(paths$derived_files)),
    names(paths$derived_files)
  )

  transform_specs <- list(
    D4.1.1.CEN.POPU = list(
      code_col = "Code", value_col = "Years", indicator = "POP.CENSUS"
    ),
    D4.1.2.CEN.AGRI = list(
      code_col = "Code", value_col = "Years", indicator = "AGRI.CENSUS"
    ),
    D4.1.3.CEN.BIZZ = list(
      code_col = "Code", value_col = "Years", indicator = "BIZZ.CENSUS"
    ),
    D4.1.4.SVY.HOUS = list(
      code_col = "Code", value_pattern = "Houseshold.*survey",
      indicator = "HOUS.SURVEYS"
    ),
    D4.1.5.SVY.AGRI = list(
      code_col = "Code", value_col = "Years", indicator = "AGRI.SURVEYS"
    ),
    D4.1.6.SVY.LABR = list(
      code_col = "Code", value_col = "Years", indicator = "LABR.SURVEYS"
    ),
    D4.1.7.SVY.HLTH = list(
      code_col = "Country", value_col = "Year", indicator = "HLTH.SURVEYS"
    ),
    D4.1.8.SVY.BIZZ = list(
      code_col = "Code", value_col = "Years", indicator = "BIZZ.SURVEYS"
    )
  )

  generated <- vapply(names(transform_specs), function(name) {
    spec <- dim4_1_workbook_specs()[[name]]
    transform <- transform_specs[[name]]
    source_path <- paths$input_files[[name]]
    source_data <- dim4_1_read_workbook(source_path, spec)
    value_col <- if (!is.null(transform$value_col)) {
      transform$value_col
    } else {
      dim4_1_find_column(
        source_data,
        transform$value_pattern,
        basename(source_path)
      )
    }

    output <- data.frame(
      iso3c = as.character(source_data[[transform$code_col]]),
      date = as.numeric(end_date),
      stringsAsFactors = FALSE
    )
    dim4_1_check_year_values(
      source_data[[value_col]],
      basename(source_path),
      allow_register = grepl("[.]CEN[.]", name)
    )
    dim4_1_check_coverage(
      output$iso3c,
      file.path(raw_dir, "4.1_SOCS", "raw", sprintf("%s.%d.csv", name, end_date - 1L)),
      basename(source_path)
    )
    output[[transform$indicator]] <- dim4_1_clean_year_values(
      source_data[[value_col]]
    )
    output <- dim4_1_join_country_metadata(
      output,
      country_metadata,
      basename(source_path)
    )

    readr::write_excel_csv(output, paths$derived_files[[name]])
    paths$derived_files[[name]]
  }, character(1))

  validate_dim4_1_derived(
    raw_dir,
    end_date,
    output_dir = output_dir,
    source_paths = c(
      unname(paths$input_files),
      paths$review_file
    )
  )
  generated
}

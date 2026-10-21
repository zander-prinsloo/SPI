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

dim4_1_country_aliases <- c(
  "Bahamas" = "Bahamas, The",
  "Cote d'Ivoire" = "Cote d'Ivoire",
  "Côte d'Ivoire" = "Cote d'Ivoire",
  "Côte d’Ivoire" = "Cote d'Ivoire",
  "São Tomé and Príncipe" = "Sao Tome and Principe",
  "Sao Tome and Principe" = "Sao Tome and Principe",
  "Bolivia (Plurinational State of)" = "Bolivia",
  "Democratic Republic of the Congo" = "Congo, Dem. Rep.",
  "Congo" = "Congo, Rep.",
  "Egypt" = "Egypt, Arab Rep.",
  "Gambia" = "Gambia, The",
  "Iran (Islamic Republic of)" = "Iran, Islamic Rep.",
  "Republic of Korea" = "Korea, Rep.",
  "Kyrgyzstan" = "Kyrgyz Republic",
  "Lao People's Democratic Republic" = "Lao PDR",
  "Micronesia (Federated States of)" = "Micronesia, Fed. Sts.",
  "Republic of Moldova" = "Moldova",
  "Slovakia" = "Slovak Republic",
  "Saint Lucia" = "St. Lucia",
  "Tanzania" = "Tanzania",
  "Turkey" = "Turkiye",
  "United Kingdom of Great Britain and Northern Ireland" = "United Kingdom",
  "United States of America" = "United States",
  "China, Hong Kong Special Administrative Region" = "Hong Kong SAR, China",
  "Somalia" = "Somalia, Fed. Rep."
)

dim4_1_canonical_country <- function(value) {
  value <- trimws(as.character(value))
  ifelse(value %in% names(dim4_1_country_aliases),
         unname(dim4_1_country_aliases[value]),
         value)
}

#' Return the current Dimension 4.1 artifact paths.
#'
#' @param raw_dir Root raw-data directory.
#' @param end_date Current SPI reference year.
#' @return A list containing input, review, derived, and companion paths.
#' @export
dim4_1_artifact_paths <- function(raw_dir, end_date) {
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
    )
  )
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
  for (column in value_columns) {
    values <- trimws(as.character(review_data[[column]]))
    invalid <- !is.na(values) & nzchar(values) &
      !grepl("[0-9]{4}|register[ -]based[ -]census", values, ignore.case = TRUE)
    if (any(invalid)) {
      stop(
        sprintf("D4.1 MANUAL REVIEW HAS INVALID VALUE(S) in '%s'", column),
        call. = FALSE
      )
    }
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

#' Validate D4.1 catalogue companion files.
#'
#' @param raw_dir Root raw-data directory.
#' @return A named list of validated companion paths and row counts.
#' @export
validate_dim4_1_companions <- function(raw_dir, country_metadata = NULL,
                                       end_date = NULL) {
  paths <- dim4_1_artifact_paths(raw_dir, end_date = 2000)$companion_files
  required <- c("country", "indicator_date", "nada_dates", "nada_title")
  exclusions <- list()
  results <- lapply(paths, function(path) {
    if (!file.exists(path)) {
      stop(
        sprintf("D4.1 CATALOGUE COMPANION NOT FOUND: %s", path),
        call. = FALSE
      )
    }
    data <- readr::read_csv(path, show_col_types = FALSE)
    missing <- setdiff(required, names(data))
    if (length(missing) > 0L) {
      stop(
        sprintf(
          "D4.1 CATALOGUE COMPANION SCHEMA MISMATCH in '%s': %s",
          basename(path),
          paste(missing, collapse = ", ")
        ),
        call. = FALSE
      )
    }

    missing_country <- is.na(data$country) | !nzchar(trimws(data$country))
    if (any(missing_country)) {
      pip_path <- file.path(raw_dir, "1.5_DUIO", "PIP_comparability_latest.csv")
      twn_dates <- if (file.exists(pip_path)) {
        pip <- readr::read_csv(pip_path, show_col_types = FALSE)
        sort(unique(as.numeric(pip$year[pip$country_code == "TWN"])))
      } else {
        numeric()
      }
      observed_dates <- sort(unique(data$indicator_date[missing_country]))
      if (identical(basename(path), "D4.1.4.SVY.HOUS_NADA.csv") &&
          length(twn_dates) > 0L && identical(observed_dates, twn_dates)) {
        exclusions[[basename(path)]] <<- list(
          source_code = "TWN",
          rows = sum(missing_country),
          dates = observed_dates,
          reason = "Source universe excludes TWN; PIP evidence is retained as an explicit exclusion."
        )
      } else {
        stop(
          sprintf("D4.1 CATALOGUE COMPANION HAS MISSING COUNTRY in '%s'", basename(path)),
          call. = FALSE
        )
      }
    }

    if (!is.null(country_metadata)) {
      allowed <- as.character(country_metadata$country)
      canonical_country <- dim4_1_canonical_country(data$country[!missing_country])
      unknown <- setdiff(
        unique(canonical_country),
        allowed
      )
      if (length(unknown) > 0L) {
        stop(
          sprintf(
            "D4.1 CATALOGUE COMPANION HAS UNKNOWN COUNTRY NAME(S) in '%s': %s",
            basename(path),
            paste(unknown, collapse = ", ")
          ),
          call. = FALSE
        )
      }
    }

    if (anyNA(data$indicator_date) ||
        any(!is.finite(as.numeric(data$indicator_date)))) {
      stop(
        sprintf("D4.1 CATALOGUE COMPANION HAS INVALID DATES in '%s'", basename(path)),
        call. = FALSE
      )
    }
    if (!is.null(end_date) && any(as.numeric(data$indicator_date) > end_date)) {
      stop(
        sprintf("D4.1 CATALOGUE COMPANION EXCEEDS END_DATE in '%s'", basename(path)),
        call. = FALSE
      )
    }
    canonical_for_key <- dim4_1_canonical_country(data$country)
    key <- interaction(canonical_for_key, data$indicator_date, drop = TRUE)
    list(
      path = path,
      rows = nrow(data),
      duplicate_keys = sum(duplicated(key)),
      canonical_countries = canonical_for_key
    )
  })
  names(results) <- names(paths)
  list(files = results, exclusions = exclusions)
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
    country_metadata = country_metadata,
    end_date = end_date
  )

  list(
    schema_version = "spi-d4.1-collection-v1",
    end_date = end_date,
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
    companions = lapply(
      vapply(companions$files, `[[`, character(1), "path"),
      dim4_1_file_metadata,
      role = "d41_catalogue_companion"
    ),
    exclusions = companions$exclusions
  )
}

#' Validate a D4.1 manifest and every artifact it authorizes.
#'
#' @param manifest_path JSON manifest path.
#' @param raw_dir Root raw-data directory.
#' @param end_date Current SPI reference year.
#' @return The validated manifest invisibly.
#' @export
validate_dim4_1_manifest <- function(manifest_path, raw_dir, end_date) {
  if (!file.exists(manifest_path)) {
    stop("D4.1 MANIFEST NOT FOUND: ", manifest_path, call. = FALSE)
  }
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
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
  if (length(manifest$companions) != length(expected$companion_files)) {
    stop("D4.1 MANIFEST COMPANION COUNT MISMATCH", call. = FALSE)
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
    manifest$companions,
    unname(expected$companion_files),
    "d41_catalogue_companion"
  )
  invisible(manifest)
}

#' Refresh or validate D4.1 catalogue companion artifacts.
#'
#' @param params Collection parameters.
#' @param refresh_fn Optional injected refresh function for tests or adapters.
#' @return A catalogue collection result.
#' @export
collect_dim4_1_catalogue <- function(params, refresh_fn = NULL) {
  refreshed <- FALSE
  if (!is.null(refresh_fn)) {
    refresh_fn(params)
    refreshed <- TRUE
  } else if (isTRUE(params$run_downloads)) {
    script_path <- here::here(
      "02_programs",
      "misc_scripts",
      "microdata_library_pull.Rmd"
    )
    if (!file.exists(script_path)) {
      stop(
        "D4.1 CATALOGUE SCRIPT NOT FOUND: ", script_path,
        call. = FALSE
      )
    }
    if (!requireNamespace("knitr", quietly = TRUE)) {
      stop(
        "D4.1 CATALOGUE REFRESH REQUIRES the `knitr` package.",
        call. = FALSE
      )
    }
    code_path <- tempfile("d41-catalogue-", fileext = ".R")
    knitr::purl(
      input = script_path,
      output = code_path,
      quiet = TRUE,
      documentation = 0
    )
    code <- readLines(code_path, warn = FALSE)
    continuation <- which(grepl("# keep jus$", code))
    if (length(continuation) > 0L) {
      for (index in rev(continuation)) {
        if (index < length(code) && grepl("^t nationally", code[[index + 1L]])) {
          code[[index]] <- paste0(code[[index]], code[[index + 1L]])
          code <- code[-(index + 1L)]
        }
      }
      writeLines(code, code_path, useBytes = TRUE)
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
    writeLines(code, code_path, useBytes = TRUE)
    sys.source(code_path, envir = new.env(parent = globalenv()))
    refreshed <- TRUE
  }

  country_metadata <- if (
    is.data.frame(params$country_metadata) &&
      nrow(params$country_metadata) > 0L
  ) {
    params$country_metadata
  } else {
    NULL
  }
  companions <- validate_dim4_1_companions(
    params$raw_dir,
    country_metadata = country_metadata,
    end_date = params$end_date
  )
  list(
    status = if (refreshed) "refreshed" else "validated_external_artifacts",
    refreshed = refreshed,
    companion_files = vapply(companions$files, `[[`, character(1), "path"),
    rows = vapply(companions$files, `[[`, integer(1), "rows"),
    exclusions = companions$exclusions
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

# =============================================================================
# Shared manual-review helpers
# Created: 2026-10-21
# =============================================================================

manual_review_spec <- function(indicator, value_columns, validators,
                               evidence_column = "Evidence") {
  if (length(indicator) != 1L || is.na(indicator) || !nzchar(indicator)) {
    stop("MANUAL REVIEW INDICATOR MUST BE A NON-BLANK STRING.", call. = FALSE)
  }
  if (length(value_columns) == 0L || anyDuplicated(value_columns) > 0L) {
    stop("MANUAL REVIEW VALUE COLUMNS MUST BE UNIQUE AND NON-EMPTY.", call. = FALSE)
  }
  if (!is.list(validators) || !identical(sort(names(validators)), sort(value_columns))) {
    stop(
      "MANUAL REVIEW VALIDATORS MUST BE A NAMED FUNCTION FOR EACH VALUE COLUMN.",
      call. = FALSE
    )
  }
  if (any(!vapply(validators, is.function, logical(1)))) {
    stop("MANUAL REVIEW VALIDATORS MUST BE FUNCTIONS.", call. = FALSE)
  }

  list(
    indicator = indicator,
    value_columns = value_columns,
    validators = validators[value_columns],
    evidence_column = evidence_column
  )
}

.manual_review_normalize <- function(values) {
  normalized <- trimws(as.character(values))
  normalized[is.na(values) | !nzchar(normalized)] <- NA_character_
  normalized
}

.manual_review_required_columns <- function(spec) {
  c("iso3c", "country", spec$value_columns, spec$evidence_column)
}

.manual_review_cast_to_base <- function(values, base_values) {
  if (is.integer(base_values)) {
    as.integer(values)
  } else if (is.numeric(base_values)) {
    as.numeric(values)
  } else {
    values
  }
}

#' Validate a manual review data frame against an indicator contract.
#'
#' @param review_data Review data frame.
#' @param spec Contract from [manual_review_spec()].
#' @param valid_iso3c Optional vector of allowed country keys.
#' @return Invisibly returns TRUE.
#' @export
validate_manual_review <- function(review_data, spec, valid_iso3c = NULL) {
  if (anyDuplicated(names(review_data)) > 0L) {
    stop(
      sprintf("%s MANUAL REVIEW HAS DUPLICATE COLUMN NAMES", spec$indicator),
      call. = FALSE
    )
  }
  required <- .manual_review_required_columns(spec)
  missing <- setdiff(required, names(review_data))
  if (length(missing) > 0L) {
    stop(
      sprintf(
        "%s MANUAL REVIEW SCHEMA MISMATCH: missing column(s): %s",
        spec$indicator,
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  keys <- .manual_review_normalize(review_data$iso3c)
  if (anyNA(keys)) {
    stop(
      sprintf("%s MANUAL REVIEW HAS MISSING COUNTRY KEYS", spec$indicator),
      call. = FALSE
    )
  }
  if (anyDuplicated(keys) > 0L) {
    stop(
      sprintf("%s MANUAL REVIEW HAS DUPLICATE COUNTRY KEYS", spec$indicator),
      call. = FALSE
    )
  }
  if (!is.null(valid_iso3c)) {
    unknown <- setdiff(keys, .manual_review_normalize(valid_iso3c))
    if (length(unknown) > 0L) {
      stop(
        sprintf(
          "%s MANUAL REVIEW HAS UNKNOWN COUNTRY KEYS: %s",
          spec$indicator,
          paste(unknown, collapse = ", ")
        ),
        call. = FALSE
      )
    }
  }

  for (column in spec$value_columns) {
    values <- .manual_review_normalize(review_data[[column]])
    invalid <- !is.na(values) & !spec$validators[[column]](values)
    if (length(invalid) != length(values) || any(is.na(invalid)) || any(invalid)) {
      stop(
        sprintf(
          "%s MANUAL REVIEW HAS INVALID VALUE(S) in '%s'",
          spec$indicator,
          column
        ),
        call. = FALSE
      )
    }
  }

  evidence <- .manual_review_normalize(review_data[[spec$evidence_column]])
  value_matrix <- do.call(
    cbind,
    lapply(
      spec$value_columns,
      function(column) !is.na(.manual_review_normalize(review_data[[column]]))
    )
  )
  has_override <- if (nrow(review_data) == 0L) {
    logical()
  } else {
    apply(value_matrix, 1L, any)
  }
  if (any(has_override & is.na(evidence))) {
    stop(
      sprintf(
        "%s MANUAL REVIEW OVERRIDE REQUIRES EVIDENCE",
        spec$indicator
      ),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

#' Read and validate a manual review workbook.
#'
#' @param review_path Path to an `.xlsx` review workbook.
#' @param spec Contract from [manual_review_spec()].
#' @param valid_iso3c Optional vector of allowed country keys.
#' @return A normalized validated data frame.
#' @export
read_manual_review <- function(review_path, spec, valid_iso3c = NULL) {
  if (!file.exists(review_path)) {
    stop(
      sprintf(
        "%s MANUAL REVIEW FILE NOT FOUND: %s",
        spec$indicator,
        review_path
      ),
      call. = FALSE
    )
  }
  review_data <- readxl::read_xlsx(review_path, .name_repair = "minimal")
  validate_manual_review(review_data, spec, valid_iso3c = valid_iso3c)

  for (column in c("iso3c", spec$value_columns, spec$evidence_column)) {
    review_data[[column]] <- .manual_review_normalize(review_data[[column]])
  }
  review_data
}

#' Apply validated manual-review values and record each override.
#'
#' @param base Base indicator data keyed by `iso3c`.
#' @param review Validated review data from [read_manual_review()].
#' @param spec Contract from [manual_review_spec()].
#' @return A list with updated `data` and an `overrides` data frame.
#' @export
apply_manual_review <- function(base, review, spec) {
  if (!"iso3c" %in% names(base)) {
    stop("MANUAL REVIEW BASE DATA MUST HAVE AN iso3c COLUMN.", call. = FALSE)
  }
  if (anyNA(base$iso3c) || anyDuplicated(base$iso3c) > 0L) {
    stop("MANUAL REVIEW BASE DATA MUST HAVE UNIQUE COUNTRY KEYS.", call. = FALSE)
  }
  unmatched <- setdiff(review$iso3c, base$iso3c)
  if (length(unmatched) > 0L) {
    stop(
      sprintf(
        "%s MANUAL REVIEW HAS UNMATCHED COUNTRY KEYS: %s",
        spec$indicator,
        paste(unmatched, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  missing <- setdiff(spec$value_columns, names(base))
  if (length(missing) > 0L) {
    stop(
      sprintf(
        "%s MANUAL REVIEW BASE DATA IS MISSING COLUMN(S): %s",
        spec$indicator,
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  validate_manual_review(review, spec)

  result <- base
  review_index <- match(base$iso3c, review$iso3c)
  override_rows <- list()
  row_number <- 0L
  for (column in spec$value_columns) {
    new_values <- review[[column]][review_index]
    has_override <- !is.na(new_values)
    if (any(has_override)) {
      old_values <- as.character(result[[column]][has_override])
      result[[column]][has_override] <- .manual_review_cast_to_base(
        new_values[has_override],
        result[[column]]
      )
      row_number <- row_number + 1L
      override_rows[[row_number]] <- data.frame(
        iso3c = base$iso3c[has_override],
        column = column,
        old = old_values,
        new = new_values[has_override],
        Evidence = review[[spec$evidence_column]][review_index[has_override]],
        stringsAsFactors = FALSE
      )
    }
  }

  overrides <- if (length(override_rows) == 0L) {
    data.frame(
      iso3c = character(),
      column = character(),
      old = character(),
      new = character(),
      Evidence = character(),
      stringsAsFactors = FALSE
    )
  } else {
    do.call(rbind, override_rows)
  }

  list(data = result, overrides = overrides)
}

#' Record manual-review file provenance and applied override counts.
#'
#' @param review_path Path to the review workbook.
#' @param review Validated review data.
#' @param overrides Output from [apply_manual_review()].
#' @return A list of provenance fields.
#' @export
manual_review_metadata <- function(review_path, review, overrides) {
  root <- normalizePath(here::here(), winslash = "/", mustWork = FALSE)
  path <- normalizePath(review_path, winslash = "/", mustWork = FALSE)
  prefix <- paste0(root, "/")
  relative_path <- if (startsWith(path, prefix)) {
    substring(path, nchar(prefix) + 1L)
  } else {
    path
  }

  list(
    path = relative_path,
    sha256 = digest::digest(review_path, algo = "sha256", file = TRUE),
    rows = nrow(review),
    override_count = nrow(overrides)
  )
}

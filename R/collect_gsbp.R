# =============================================================================
# GSBP (5.2.10) vintage builder
# =============================================================================
# Steps 5-6 of .cg-docs/plans/2026-10-21-nada-gsbp-collection-pipeline.md.
# The legacy GSBP section of
# 02_programs/misc_scripts/preprocess-manual-data-4.1-and-5.2.10.R copied the
# cumulative desk review (5.2_DISM/raw/D1.12.MSC.csv) into
# D5.2.10.GSBP.<year>.csv. The builder keeps that result through a union rule
# (previous "Yes" or desk review "Yes"), applies the per-vintage review
# ("No" is stored as NA, so the vocabulary stays {"Yes", NA}) and joins the
# saved country snapshot in the legacy column order.
#
# Created: 2026-10-23
# =============================================================================

`%>%` <- magrittr::`%>%`

.gsbp_desk_column <- "Business Process (GSBPM)"

#' Paths of the GSBP artifacts for a vintage.
#'
#' @param raw_dir Root `01_raw_data` directory.
#' @param end_date Current reference year.
#' @return A list of paths.
#' @export
gsbp_artifact_paths <- function(raw_dir, end_date) {
  dir <- file.path(raw_dir, "5.2_DISM")
  list(
    previous = file.path(dir, sprintf("D5.2.10.GSBP.%d.csv", as.integer(end_date) - 1L)),
    desk_review = file.path(dir, "raw", "D1.12.MSC.csv"),
    review = file.path(dir, sprintf("D5.2.10.GSBP.Manual.Review.%d.xlsx", as.integer(end_date))),
    output = file.path(dir, sprintf("D5.2.10.GSBP.%d.csv", as.integer(end_date))),
    manifest = file.path(dir, "collection", sprintf("D5.2.10.GSBP_manifest_%d.json", as.integer(end_date))),
    previous_manifest = file.path(dir, "collection", sprintf("D5.2.10.GSBP_manifest_%d.json", as.integer(end_date) - 1L))
  )
}

.gsbp_is_yes <- function(values) !is.na(values) & tolower(trimws(as.character(values))) == "yes"

.validate_gsbp_desk_review <- function(desk) {
  .require_columns(desk, c("Code", "Country", .gsbp_desk_column), "GSBP DESK REVIEW")
  values <- trimws(as.character(desk[[.gsbp_desk_column]]))
  invalid <- !is.na(values) & nzchar(values) & tolower(values) != "yes"
  if (any(invalid)) {
    stop(
      "GSBP DESK REVIEW HAS INVALID VALUES (expected blank or Yes): ",
      paste(unique(values[invalid]), collapse = ", "),
      call. = FALSE
    )
  }
  if (anyNA(desk$Code) || anyDuplicated(desk$Code) > 0L) {
    stop("GSBP DESK REVIEW HAS MISSING OR DUPLICATE Code VALUES.", call. = FALSE)
  }
  invisible(TRUE)
}

#' Read and validate the GSBPM desk review.
#'
#' @param path Path to D1.12.MSC.csv.
#' @return The desk review data frame.
#' @export
read_gsbp_desk_review <- function(path) {
  if (!file.exists(path)) {
    stop("GSBP DESK REVIEW NOT FOUND: ", path, call. = FALSE)
  }
  desk <- readr::read_csv(path, show_col_types = FALSE)
  .validate_gsbp_desk_review(desk)
  desk
}

#' Review contract for the GSBP vintage.
#'
#' @return A [manual_review_spec()].
#' @export
gsbp_review_spec <- function() {
  manual_review_spec("GSBP", "GSBP", list(GSBP = function(values) tolower(values) %in% c("yes", "no")))
}

#' Build the GSBP vintage.
#'
#' @param previous Previous vintage (`iso3c`, `GSBP`).
#' @param desk_review Desk review from [read_gsbp_desk_review()].
#' @param review Review rows (`iso3c`, `country`, `GSBP`, `Evidence`).
#' @param country_metadata Saved country snapshot (defines the output columns).
#' @param end_date Current reference year.
#' @param previous_desk_sha256,desk_sha256 Desk-review hashes of the previous
#'   and current vintages; equal hashes produce a stale warning.
#' @return A list with `data`, `overrides` and `warnings`.
#' @export
build_gsbp_vintage <- function(previous, desk_review, review, country_metadata, end_date,
                               previous_desk_sha256 = NULL, desk_sha256 = NULL) {
  .require_columns(previous, c("iso3c", "GSBP"), "GSBP PREVIOUS VINTAGE")
  .validate_gsbp_desk_review(desk_review)
  spec <- gsbp_review_spec()
  scope <- union(as.character(previous$iso3c), as.character(desk_review$Code))
  review <- .validated_review(review, spec, scope)

  one_sided <- union(
    setdiff(as.character(previous$iso3c), as.character(desk_review$Code)),
    setdiff(as.character(desk_review$Code), as.character(previous$iso3c))
  )
  unresolved <- setdiff(one_sided, review$iso3c)
  if (length(unresolved) > 0L) {
    stop(
      "GSBP COUNTRY SCOPE MISMATCH between the previous vintage and the desk review (add a review row): ",
      paste(sort(unresolved), collapse = ", "),
      call. = FALSE
    )
  }

  scope <- sort(scope)
  yes <- scope %in% as.character(previous$iso3c[.gsbp_is_yes(previous$GSBP)]) |
    scope %in% as.character(desk_review$Code[.gsbp_is_yes(desk_review[[.gsbp_desk_column]])])
  base <- data.frame(iso3c = scope, GSBP = ifelse(yes, "Yes", NA_character_), stringsAsFactors = FALSE)
  applied <- apply_manual_review(base, review, spec)
  gsbp <- applied$data$GSBP
  gsbp <- ifelse(.gsbp_is_yes(gsbp), "Yes", NA_character_)

  missing_metadata <- setdiff(scope, as.character(country_metadata$iso3c))
  if (length(missing_metadata) > 0L) {
    stop("GSBP COUNTRIES MISSING FROM COUNTRY METADATA: ", paste(missing_metadata, collapse = ", "), call. = FALSE)
  }
  data <- data.frame(iso3c = scope, date = as.integer(end_date), GSBP = gsbp, stringsAsFactors = FALSE) %>%
    dplyr::left_join(country_metadata, by = "iso3c") %>%
    dplyr::select(dplyr::all_of(colnames(country_metadata)), date, GSBP)

  warnings <- data.frame(source_id = character(), message = character(), stringsAsFactors = FALSE)
  if (!is.null(previous_desk_sha256) && !is.null(desk_sha256) && identical(previous_desk_sha256, desk_sha256)) {
    warnings <- data.frame(
      source_id = "d5_2_10_gsbp_desk_review",
      message = sprintf(
        "GSBP desk review D1.12.MSC.csv is unchanged since the %d vintage (sha256 %s); refresh it or confirm the carry-forward.",
        as.integer(end_date) - 1L, substr(desk_sha256, 1, 12)
      ),
      stringsAsFactors = FALSE
    )
  }
  list(data = data, overrides = applied$overrides, warnings = warnings)
}

#' GSBP countries without GSBPM evidence, for review.
#'
#' @param data Built GSBP vintage.
#' @return Candidate rows.
#' @export
gsbp_candidates <- function(data) {
  no_evidence <- !.gsbp_is_yes(data$GSBP)
  .candidate_frame(
    "d5_2_10_gsbp", data$iso3c, data$country, data$GSBP,
    ifelse(no_evidence, "no GSBPM evidence in the previous vintage or the desk review", ""),
    "NSO quality framework or statistical business process documentation (GSBPM)"
  )
}

#' Write the GSBP vintage and its manifest.
#'
#' @param result Output of [build_gsbp_vintage()].
#' @param paths Output of [gsbp_artifact_paths()].
#' @param end_date Current reference year.
#' @param first_collected_vintage First vintage built by the pipeline.
#' @param allow_historical Allow writing an earlier vintage (tests only).
#' @return A list with the `output` and `manifest` paths and `warnings`.
#' @export
write_gsbp_vintage <- function(result, paths, end_date, first_collected_vintage = 2025,
                               allow_historical = FALSE) {
  if (end_date < first_collected_vintage && !allow_historical) {
    stop("REFUSING TO WRITE HISTORICAL GSBP VINTAGE: use the current end_date.", call. = FALSE)
  }
  dir.create(dirname(paths$manifest), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(result$data, paths$output, na = "NA")
  record <- function(path) list(path = .collection_relative_path(path), sha256 = digest::digest(path, algo = "sha256", file = TRUE))
  manifest <- list(
    indicator = "SPI.D5.2.10.GSBP",
    end_date = end_date,
    created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    output = record(paths$output),
    previous = record(paths$previous),
    desk_review = record(paths$desk_review),
    review = manual_review_metadata(paths$review, read_manual_review(paths$review, gsbp_review_spec()), result$overrides),
    rows = nrow(result$data),
    overrides = result$overrides,
    warnings = result$warnings
  )
  jsonlite::write_json(manifest, paths$manifest, auto_unbox = TRUE, pretty = TRUE, na = "null")
  list(output = paths$output, manifest = paths$manifest, warnings = result$warnings)
}

#' Build and write the GSBP file for the current vintage.
#'
#' @param params Pipeline parameters (`raw_dir`, `end_date`,
#'   `first_collected_vintage`).
#' @param country_metadata Saved country snapshot.
#' @return A list with `output`, `manifest`, `warnings` and `candidates`.
#' @export
collect_gsbp_vintage <- function(params, country_metadata) {
  first <- if (is.null(params$first_collected_vintage)) 2025 else params$first_collected_vintage
  if (params$end_date < first) {
    stop("REFUSING TO WRITE HISTORICAL GSBP VINTAGE: use the current end_date.", call. = FALSE)
  }
  paths <- gsbp_artifact_paths(params$raw_dir, params$end_date)
  if (!file.exists(paths$previous)) {
    stop("GSBP PREVIOUS VINTAGE NOT FOUND: ", paths$previous, call. = FALSE)
  }
  previous <- readr::read_csv(paths$previous, show_col_types = FALSE)
  desk <- read_gsbp_desk_review(paths$desk_review)
  review <- read_manual_review(paths$review, gsbp_review_spec())
  previous_desk_sha256 <- if (file.exists(paths$previous_manifest)) {
    jsonlite::read_json(paths$previous_manifest)$desk_review$sha256
  } else {
    NULL
  }
  result <- build_gsbp_vintage(
    previous, desk, review, country_metadata, params$end_date,
    previous_desk_sha256 = previous_desk_sha256,
    desk_sha256 = digest::digest(paths$desk_review, algo = "sha256", file = TRUE)
  )
  written <- write_gsbp_vintage(result, paths, params$end_date, first)
  c(written, list(candidates = gsbp_candidates(result$data)))
}

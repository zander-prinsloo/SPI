# =============================================================================
# Availability intermediates
# =============================================================================
# Created: 2026-10-05
# =============================================================================

#' Build a complete binary country-indicator-year availability table.
#'
#' Availability is based on raw value presence. Nature classifications are kept
#' in the normalized source data for scoring and do not turn a present value
#' into an unavailable value.
#'
#' @param normalized Normalized SDG series data.
#' @param country_year_grid Data frame with `iso3c` and `date`.
#' @return A data frame with binary `available` values.
#' @export
build_sdg_availability <- function(normalized, country_year_grid) {
  required_normalized <- c("series_code", "date", "iso3c", "Value")
  missing_normalized <- setdiff(required_normalized, names(normalized))
  if (length(missing_normalized) > 0L) {
    stop(
      "SDG AVAILABILITY INPUT MISMATCH: missing column(s): ",
      paste(missing_normalized, collapse = ", "),
      call. = FALSE
    )
  }
  if (!all(c("iso3c", "date") %in% names(country_year_grid))) {
    stop("SDG AVAILABILITY GRID MUST HAVE iso3c AND date.", call. = FALSE)
  }

  series_codes <- unique(normalized$series_code)
  if (length(series_codes) != 1L) {
    stop("SDG AVAILABILITY EXPECTS EXACTLY ONE SERIES.", call. = FALSE)
  }

  observed <- normalized |>
    dplyr::group_by(iso3c, date) |>
    dplyr::summarise(
      available = as.integer(any(!is.na(Value))),
      .groups = "drop"
    )

  grid <- country_year_grid |>
    dplyr::distinct(iso3c, date) |>
    dplyr::mutate(series_code = series_codes[[1]])

  grid |>
    dplyr::left_join(observed, by = c("iso3c", "date")) |>
    dplyr::mutate(available = dplyr::if_else(is.na(available), 0L, available)) |>
    dplyr::select(series_code, iso3c, date, available)
}

#' Reproduce the Rmd five-year SDG goal aggregation.
#'
#' @param normalized Normalized SDG data with `goal` and `quality` columns.
#' @param country_year_grid Complete country-year grid.
#' @param start_year First output year.
#' @param end_year Last output year.
#' @return A wide country-year score table.
#' @export
build_sdg_five_year_scores <- function(normalized, country_year_grid,
                                       start_year, end_year) {
  required <- c("series_code", "iso3c", "date", "goal", "quality")
  missing <- setdiff(required, names(normalized))
  if (length(missing) > 0L) {
    stop(
      "SDG SCORE INPUT MISMATCH: missing column(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  if (!"available" %in% names(normalized)) {
    normalized$available <- as.integer(!is.na(normalized$quality))
  }
  complete <- complete_sdg_quality(normalized, country_year_grid)

  scores <- lapply(start_year:end_year, function(reference_year) {
    windowed <- complete |>
      dplyr::filter(
        date >= reference_year - 4,
        date <= reference_year,
        !is.na(quality)
      ) |>
      dplyr::group_by(iso3c, goal, series_code) |>
      dplyr::summarise(ind_quality = max(quality, na.rm = TRUE), .groups = "drop") |>
      dplyr::group_by(iso3c, goal) |>
      dplyr::summarise(ind_quality = mean(ind_quality), .groups = "drop") |>
      dplyr::mutate(date = reference_year)

    grid <- country_year_grid |>
      dplyr::filter(date == reference_year) |>
      dplyr::select(iso3c, date)

    grid |>
      dplyr::left_join(windowed, by = c("iso3c", "date")) |>
      tidyr::pivot_wider(
        names_from = goal,
        values_from = ind_quality,
        names_glue = "SPI.D3.{goal}"
      )
  })

  dplyr::bind_rows(scores)
}

#' Complete normalized SDG quality to the Rmd country-year-series grid.
#'
#' When a series has no value anywhere in a year, its quality is NA for every
#' country. Otherwise missing country values are zero, matching `un_pull()`.
#'
#' @param normalized Normalized SDG data with `available` and `quality`.
#' @param country_year_grid Complete country-year grid.
#' @return Completed quality data.
#' @export
complete_sdg_quality <- function(normalized, country_year_grid) {
  required <- c("series_code", "iso3c", "date", "available", "quality")
  missing <- setdiff(required, names(normalized))
  if (length(missing) > 0L) {
    stop(
      "SDG QUALITY INPUT MISMATCH: missing column(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  observed <- normalized |>
    dplyr::group_by(series_code, iso3c, date) |>
    dplyr::summarise(
      available = as.integer(any(available == 1L)),
      quality = if (all(is.na(quality))) NA_real_ else mean(quality, na.rm = TRUE),
      .groups = "drop"
    )
  year_available <- observed |>
    dplyr::group_by(series_code, date) |>
    dplyr::summarise(year_available = any(available == 1L), .groups = "drop")

  grid <- tidyr::crossing(
    series_code = unique(normalized$series_code),
    country_year_grid |>
      dplyr::distinct(iso3c, date)
  )

  grid |>
    dplyr::left_join(observed, by = c("series_code", "iso3c", "date")) |>
    dplyr::left_join(year_available, by = c("series_code", "date")) |>
    dplyr::left_join(
      normalized |>
        dplyr::select(dplyr::any_of(c("series_code", "goal"))) |>
        dplyr::distinct(),
      by = "series_code"
    ) |>
    dplyr::mutate(
      available = dplyr::if_else(is.na(available), 0L, available),
      quality = dplyr::case_when(
        is.na(year_available) | !year_available ~ NA_real_,
        is.na(quality) ~ 0,
        TRUE ~ quality
      )
    )
}

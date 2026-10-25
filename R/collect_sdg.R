# =============================================================================
# UN SDG collection and the Pillar 3 (D3) scorer
# =============================================================================
# Port of 02_programs/misc_scripts/un_stats_cleaning.Rmd (un_pull(), the
# per-series collection loop, the OECD blend, the country-year grid fill and
# un_aki_fun() with the 5-year window). Each Tier-1 series is requested once
# from the UN SDG API DataCSV endpoint through the raw cache. The scores for
# every year 2004 to end_date are written to
# 01_raw_data/3_DP/<end_date>/SPI_D3_UNSD_data_5yr.csv in the legacy layout;
# earlier year folders are frozen and never written.
#
# Created: 2026-10-05 (rewritten 2026-10-23 for the 202611 update)
# =============================================================================

`%>%` <- magrittr::`%>%`

#' Read and validate the SDG indicator list used by the collection.
#'
#' @param path Path to SDG_indicator_list.csv.
#' @return A tibble containing the indicator list (read as the legacy code
#'   reads it, with default column types).
#' @export
read_sdg_indicator_list <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("SDG INDICATOR LIST NOT FOUND: %s", path), call. = FALSE)
  }
  result <- readr::read_csv(path, show_col_types = FALSE)
  required <- c("goal", "target", "code", "code1", "description1", "Tier_Nov2020")
  missing <- setdiff(required, names(result))
  if (length(missing) > 0L) {
    stop(
      "SDG INDICATOR LIST SCHEMA MISMATCH: missing column(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  result
}

#' Request a UN SDG CSV response.
#'
#' @param series_code Character series identifier.
#' @param start_year Numeric lower year.
#' @param end_year Numeric upper year.
#' @param timeout HTTP timeout in seconds. Some series (for example
#'   SE_TOT_CPLR) return tens of megabytes, so the default is generous.
#' @return Raw response bytes.
#' @export
sdg_api_csv_request <- function(series_code, start_year, end_year, timeout = 1800) {
  url <- "https://unstats.un.org/SDGAPI/v1/sdg/Series/DataCSV"
  response <- with_http_retry(function() httr::POST(
    url,
    httr::add_headers(`Content-Type` = "application/x-www-form-urlencoded"),
    httr::accept("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"),
    body = paste0(
      "seriesCodes=", series_code,
      "&timePeriodStart=", start_year,
      "&timePeriodEnd=", end_year
    ),
    httr::timeout(timeout)
  )
  )
  if (httr::status_code(response) != 200) {
    stop(
      sprintf("UN SDG CSV API returned HTTP %d for series %s", httr::status_code(response), series_code),
      call. = FALSE
    )
  }
  sdg_clean_csv_body(httr::content(response, as = "raw"), series_code)
}

#' Strip DataCSV buffer padding and detect truncated responses.
#'
#' The DataCSV endpoint returns the body in a power-of-two buffer padded with
#' NUL bytes. Padding is removed; a body that fills its buffer without padding,
#' ends mid-line, or carries embedded NULs stops, because it may be truncated.
#'
#' @param content Raw response bytes.
#' @param series_code Character series identifier (for messages).
#' @return The CSV body without padding.
#' @export
sdg_clean_csv_body <- function(content, series_code) {
  size <- length(content)
  non_nul <- which(content != as.raw(0))
  if (length(non_nul) == 0L) {
    stop(sprintf("UN SDG CSV API returned NO DATA for series %s", series_code), call. = FALSE)
  }
  body <- content[seq_len(max(non_nul))]
  padded <- length(body) < size
  if (any(body == as.raw(0))) {
    stop(sprintf("UN SDG CSV RESPONSE HAS EMBEDDED NUL BYTES for series %s", series_code), call. = FALSE)
  }
  fills_buffer <- size >= 65536 && abs(log2(size) - round(log2(size))) < 1e-9
  if (!padded && fills_buffer) {
    stop(
      sprintf(
        "UN SDG CSV RESPONSE POSSIBLY TRUNCATED for series %s: the body fills a %.0f-byte buffer without padding.",
        series_code, size
      ),
      call. = FALSE
    )
  }
  if (body[[length(body)]] != as.raw(0x0a)) {
    stop(
      sprintf("UN SDG CSV RESPONSE POSSIBLY TRUNCATED for series %s: the last line is incomplete.", series_code),
      call. = FALSE
    )
  }
  body
}

#' Gzip a DataCSV body for the raw cache.
#'
#' Responses run to several megabytes per series; the cache keeps them
#' compressed (read back with `gzfile()`), with the size and SHA-256 of the
#' uncompressed body in provenance.
#'
#' @param body Raw response bytes.
#' @return A [collection_payload()].
#' @export
sdg_compressed_payload <- function(body) {
  path <- tempfile(fileext = ".csv.gz")
  on.exit(unlink(path), add = TRUE)
  con <- gzfile(path, "wb")
  writeBin(body, con)
  close(con)
  collection_payload(
    readBin(path, "raw", file.size(path)),
    list(
      compression = "gzip",
      response_bytes = length(body),
      response_sha256 = digest::digest(body, algo = "sha256", serialize = FALSE)
    )
  )
}

#' Tier-1 series scored in Pillar 3 (each requested once).
#'
#' @param indicator_list Tibble from [read_sdg_indicator_list()].
#' @return Character vector of unique Tier-1 `code1` values.
#' @export
d3_tier1_series <- function(indicator_list) {
  unique(as.character(indicator_list$code1[indicator_list$Tier_Nov2020 %in% 1]))
}

#' Country-year quality of one series, as un_pull() in the legacy Rmd.
#'
#' Values are scored by their Nature (1 for C, CA, E, G or no Nature; 0 for M
#' or missing; NA for N), a year with no value for any country is not scored,
#' and disaggregations are averaged within each country-year.
#'
#' @param raw_data DataCSV response read with default column types.
#' @param iso_codes UN geography lookup from [read_unsdg_iso_codes()].
#' @param span Years of the country-year template.
#' @param series Series code (for messages).
#' @return One row per `(iso3c, date)` with `ind_value`, `ind_metadata`
#'   and `ind_quality`.
#' @export
d3_series_quality <- function(raw_data, iso_codes, span, series = "") {
  required <- c("TimePeriod", "[Nature]", "GeoAreaCode", "Value")
  missing <- setdiff(required, names(raw_data))
  if (length(missing) > 0L) {
    stop(sprintf("SDG SERIES SCHEMA MISMATCH for %s: missing %s", series, paste(missing, collapse = ", ")), call. = FALSE)
  }
  clash <- intersect(names(raw_data), c("country", "iso3c", "date", "Nature", "geoAreaCode"))
  if (length(clash) > 0L) {
    stop(sprintf("SDG SERIES COLUMN CLASH for %s: %s", series, paste(clash, collapse = ", ")), call. = FALSE)
  }
  unknown_geo <- setdiff(
    unique(as.character(raw_data$GeoAreaCode)),
    as.character(iso_codes$geoAreaCode)
  )
  if (length(unknown_geo) > 0L) {
    stop(
      sprintf(
        "SDG SERIES HAS UNKNOWN GEOGRAPHY CODE(S) for %s: %s",
        series,
        paste(sort(unknown_geo), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  iso_empty <- dplyr::bind_rows(replicate(length(span), iso_codes, simplify = FALSE), .id = "date") %>%
    dplyr::mutate(date = as.numeric(date) + span[1] - 1) %>%
    dplyr::select(iso3c, date, geoAreaCode)

  raw_data %>%
    dplyr::mutate(
      date = as.numeric(TimePeriod),
      Nature = `[Nature]`,
      geoAreaCode = as.character(GeoAreaCode)
    ) %>%
    dplyr::left_join(iso_codes, by = "geoAreaCode") %>%
    dplyr::right_join(iso_empty, by = c("iso3c", "date", "geoAreaCode")) %>%
    dplyr::mutate(
      available = !is.na(Value),
      quality = dplyr::case_when(
        (available & Nature == "C") ~ 1,
        (available & Nature == "CA") ~ 1,
        (available & is.na(Nature)) ~ 1,
        (available & (Nature == "E" | Nature == "G")) ~ 1,
        (available & Nature == "M") ~ 0,
        Nature == "N" ~ as.numeric(NA),
        !available ~ 0
      )
    ) %>%
    dplyr::group_by(date) %>%
    # A year with no value for any country is not scored.
    dplyr::mutate(
      available_year = (max(available, na.rm = TRUE) == 1),
      quality = dplyr::if_else(available_year == FALSE, as.numeric(NA), quality)
    ) %>%
    dplyr::group_by(iso3c, date) %>%
    dplyr::summarise(
      ind_value = suppressWarnings(mean(as.numeric(Value), na.rm = TRUE)),
      ind_metadata = dplyr::first(Nature),
      ind_quality = mean(quality, na.rm = TRUE),
      .groups = "drop"
    )
}

#' Attach a series to every (goal, target, code) row it has in the list.
#'
#' @param quality Output of [d3_series_quality()].
#' @param list_rows Indicator-list rows of the series.
#' @return Rows for every list row of the series, as the legacy loop wrote.
#' @export
d3_expand_series <- function(quality, list_rows) {
  list_rows %>%
    dplyr::transmute(
      goal = as.character(goal),
      target = as.character(target),
      code = as.character(code),
      code1 = as.character(code1),
      description1 = as.character(description1)
    ) %>%
    dplyr::cross_join(quality) %>%
    dplyr::select(iso3c, date, goal, target, code, code1, description1, ind_value, ind_metadata, ind_quality)
}

#' Blend OECD quality into the UN quality, as the legacy save chunk.
#'
#' The OECD quality replaces the UN quality when it is higher; a missing UN
#' quality stays missing.
#'
#' @param un_sdg Expanded UN series rows.
#' @param oecd OECD scores read from OECD_data_scored.csv.
#' @return `un_sdg` with the blended `ind_quality`.
#' @export
d3_blend_oecd <- function(un_sdg, oecd) {
  required <- c("iso3c", "date", "goal", "code", "ind_quality.oecd")
  missing <- setdiff(required, names(oecd))
  if (length(missing) > 0L) {
    stop("OECD SCORES SCHEMA MISMATCH: missing ", paste(missing, collapse = ", "), call. = FALSE)
  }
  un_sdg %>%
    dplyr::mutate(goal = as.numeric(goal)) %>%
    dplyr::left_join(oecd, by = c("iso3c", "date", "goal", "code"), relationship = "many-to-one") %>%
    dplyr::mutate(goal = as.character(goal)) %>%
    dplyr::mutate(ind_quality = dplyr::if_else(ind_quality.oecd > ind_quality, ind_quality.oecd, ind_quality, ind_quality))
}

#' Complete the country-year-series grid and set missing quality to 0.
#'
#' @param un_sdg Blended UN series rows.
#' @param countries Economies scored (World Bank economies in the UN list).
#' @param span Years of the grid.
#' @param series Series codes of the grid.
#' @return The filled table (legacy `un_sdg_filled_df`).
#' @export
d3_fill_grid <- function(un_sdg, countries, span, series) {
  grid <- tidyr::expand_grid(code1 = unique(series), iso3c = unique(countries), date = as.numeric(span))
  missing_series <- setdiff(unique(series), unique(un_sdg$code1))
  if (length(missing_series) > 0L) {
    stop("D3 SERIES WITHOUT DATA ROWS: ", paste(missing_series, collapse = ", "), call. = FALSE)
  }
  grid %>%
    dplyr::left_join(un_sdg, by = c("iso3c", "date", "code1"), relationship = "one-to-many") %>%
    dplyr::mutate(ind_quality = dplyr::if_else(is.na(ind_quality), 0, ind_quality))
}

#' Score one window, as un_aki_fun() in the legacy Rmd.
#'
#' @param filled Output of [d3_fill_grid()].
#' @param tier1 Tier-1 series codes.
#' @param country_metadata Data frame with `iso3c`, `country`, `region` and
#'   `income`.
#' @param date_start,date_end Window bounds (inclusive).
#' @return One row per economy with `SPI.D3.<goal>` columns.
#' @export
d3_score_window <- function(filled, tier1, country_metadata, date_start, date_end) {
  filled %>%
    dplyr::filter(dplyr::between(date, date_start, date_end)) %>%
    dplyr::filter(!is.na(ind_quality)) %>%
    dplyr::filter(code1 %in% tier1) %>%
    dplyr::group_by(iso3c, code, goal) %>%
    dplyr::summarise(ind_quality = max(ind_quality, na.rm = TRUE), .groups = "drop") %>%
    dplyr::mutate(ind_quality = dplyr::if_else(is.na(ind_quality), 0, ind_quality)) %>%
    dplyr::group_by(iso3c, goal) %>%
    dplyr::summarise(ind_quality = round(mean(ind_quality), 3), .groups = "drop") %>%
    dplyr::left_join(country_metadata, by = "iso3c") %>%
    dplyr::filter(!is.na(region)) %>%
    dplyr::transmute(iso3c, date = date_end, country, region, income, goal, ind_quality) %>%
    tidyr::pivot_wider(names_from = "goal", values_from = "ind_quality", names_glue = "SPI.D3.{goal}")
}

#' Pillar 3 scores for every year 2004 to end_date (5-year windows).
#'
#' @param filled Output of [d3_fill_grid()].
#' @param tier1 Tier-1 series codes.
#' @param country_metadata Data frame with `iso3c`, `country`, `region`,
#'   `income`.
#' @param end_date Last reference year.
#' @return The legacy table (`iso3c, date, country, region, income`, then
#'   `SPI.D3.<goal>` in goal order), sorted by descending date and iso3c.
#' @export
build_d3_scores <- function(filled, tier1, country_metadata, end_date) {
  scores <- dplyr::bind_rows(lapply(2004:end_date, function(i) {
    d3_score_window(filled, tier1, country_metadata, i - 4, i)
  })) %>%
    dplyr::arrange(-date, iso3c)
  goal_columns <- grep("^SPI\\.D3\\.", names(scores), value = TRUE)
  goal_columns <- goal_columns[order(as.numeric(sub("^SPI\\.D3\\.", "", goal_columns)))]
  dplyr::select(scores, iso3c, date, country, region, income, dplyr::all_of(goal_columns))
}

#' Economies scored in Pillar 3 and their descriptive columns.
#'
#' @param iso_codes UN geography lookup.
#' @param snapshot Saved World Bank country snapshot.
#' @return A data frame with `iso3c`, `country`, `region`, `income`.
#' @export
d3_country_metadata <- function(iso_codes, snapshot) {
  snapshot %>%
    dplyr::filter(!is.na(region), region != "Aggregates", iso3c %in% iso_codes$iso3c) %>%
    dplyr::transmute(iso3c, country, region, income = income_level)
}

#' Collect the Tier-1 UN SDG series and write the Pillar 3 scores.
#'
#' @param params Pipeline parameters (`raw_dir`, `end_date`,
#'   `sdg_indicator_list_file`, `collection_age_warning_days`).
#' @param country_metadata Saved World Bank country snapshot.
#' @param request_fn Function `(series, start_year, end_year)` returning the
#'   DataCSV body; defaults to [sdg_api_csv_request()].
#' @param required_goals Goals that must be scored.
#' @return A list with the output `path`, `rows`, `series` and
#'   `release_identifier`.
#' @export
collect_d3_scores <- function(params, country_metadata, request_fn = sdg_api_csv_request,
                              required_goals = 1:17) {
  indicator_list <- read_sdg_indicator_list(params$sdg_indicator_list_file)
  tier1 <- d3_tier1_series(indicator_list)
  iso_codes <- read_unsdg_iso_codes(params$raw_dir)
  span <- c(2004:params$end_date)
  max_age_days <- if (is.null(params$collection_age_warning_days)) Inf else params$collection_age_warning_days

  oecd_path <- file.path(params$raw_dir, "oecd_data", "OECD_data_scored.csv")
  if (!file.exists(oecd_path)) {
    stop("OECD SCORES NOT FOUND: ", oecd_path, "\nRun the OECD SDG collection first.", call. = FALSE)
  }
  oecd <- readr::read_csv(oecd_path, show_col_types = FALSE)

  retrieved <- character()
  un_sdg <- dplyr::bind_rows(lapply(seq_along(tier1), function(i) {
    series <- tier1[[i]]
    if (i %% 50 == 0 || i == length(tier1)) {
      message(sprintf("D3: %d of %d Tier-1 series collected", i, length(tier1)))
    }
    record <- collect_cached_raw(
      cache_dir = file.path(params$raw_dir, "3_DP", "sdg_data", "raw"),
      source_id = paste0("sdg_", series),
      request = list(
        endpoint = "https://unstats.un.org/SDGAPI/v1/sdg/Series/DataCSV",
        series_code = series,
        start_year = min(span),
        end_year = max(span)
      ),
      vintage = params$end_date,
      collector_version = "sdg-datacsv-legacy-gzip-v1",
      fetch = function() sdg_compressed_payload(request_fn(series, min(span), max(span))),
      max_age_days = max_age_days
    )
    retrieved <<- c(retrieved, as.character(record$retrieved_at))
    raw_data <- readr::read_csv(gzfile(record$raw_path), show_col_types = FALSE, progress = FALSE)
    d3_expand_series(
      d3_series_quality(raw_data, iso_codes, span, series),
      indicator_list[as.character(indicator_list$code1) == series, , drop = FALSE]
    )
  }))

  metadata <- d3_country_metadata(iso_codes, country_metadata)
  filled <- d3_fill_grid(d3_blend_oecd(un_sdg, oecd), metadata$iso3c, span, tier1)
  scores <- build_d3_scores(filled, tier1, metadata, params$end_date)
  missing_goals <- setdiff(paste0("SPI.D3.", required_goals), names(scores))
  if (length(missing_goals) > 0L) {
    stop("D3 SCORES MISSING GOAL COLUMNS: ", paste(missing_goals, collapse = ", "), call. = FALSE)
  }

  out_path <- file.path(params$raw_dir, "3_DP", params$end_date, "SPI_D3_UNSD_data_5yr.csv")
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  readr::write_excel_csv(scores, out_path)
  oecd_release <- read_artifact_provenance(oecd_path)$release_identifier
  release_identifier <- sprintf(
    "UN SDG API DataCSV, %d Tier-1 series, retrieved %s; %s",
    length(tier1),
    paste(unique(range(substr(retrieved, 1, 10))), collapse = " to "),
    if (is.null(oecd_release)) "OECD release unrecorded" else oecd_release
  )
  write_artifact_provenance(
    out_path,
    source_id = "d3_sdg",
    retrieved_at = min(retrieved),
    release_identifier = release_identifier,
    raw_path = file.path(params$raw_dir, "3_DP", "sdg_data", "raw"),
    extra = list(series = length(tier1), end_date = params$end_date)
  )
  list(
    path = normalizePath(out_path, winslash = "/", mustWork = FALSE),
    rows = nrow(scores),
    series = length(tier1),
    release_identifier = release_identifier
  )
}

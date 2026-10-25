# =============================================================================
# OECD SDG collection for the Pillar 3 OECD blend
# =============================================================================
# Port of 02_programs/misc_scripts/oecd_bulk_download.R. The bulk SDMX CSV is
# downloaded once per vintage and cached gzip-compressed in
# 01_raw_data/oecd_data/raw/ (the full download; about 5 MB compressed versus
# about 330 MB plain), with the URL, SHA-256 and size of the uncompressed
# download in provenance. It is transformed exactly as the original script
# into 01_raw_data/oecd_data/OECD_data_scored.csv, which the D3 scorer blends
# with the UN SDG data. The uncompressed copy the original script kept
# (oecd_sdg_data.csv) is not written.
#
# Created: 2026-10-23
# =============================================================================

`%>%` <- magrittr::`%>%`

.oecd_sdg_url <- paste0(
  "https://sdmx.oecd.org/public/rest/data/OECD.WISE.RSB,DSD_SDG@DF_SDG,1.0/all",
  "?dimensionAtObservation=AllDimensions&format=csvfilewithlabels"
)
.oecd_sdg_dataflow <- "OECD.WISE.RSB:DSD_SDG@DF_SDG(1.0)"

#' Download the OECD SDG bulk CSV to a file.
#'
#' @param url Bulk download URL.
#' @param destfile Destination path.
#' @param timeout HTTP timeout in seconds.
#' @return A list with the `effective_url` and `content_type`.
#' @export
oecd_download_csv <- function(url, destfile, timeout = 1800) {
  response <- with_http_retry(function() {
    httr::GET(url, httr::write_disk(destfile, overwrite = TRUE), httr::timeout(timeout))
  })
  if (httr::status_code(response) != 200) {
    stop(sprintf("OECD SDG DOWNLOAD FAILED: HTTP %d for %s", httr::status_code(response), url), call. = FALSE)
  }
  list(effective_url = response$url, content_type = httr::headers(response)[["content-type"]])
}

.gzip_copy <- function(source, target) {
  input <- file(source, "rb")
  on.exit(close(input), add = TRUE)
  output <- gzfile(target, "wb")
  on.exit(close(output), add = TRUE)
  repeat {
    chunk <- readBin(input, "raw", 8L * 1024L^2)
    if (length(chunk) == 0L) break
    writeBin(chunk, output)
  }
  invisible(target)
}

#' Fetch the OECD SDG bulk CSV as a compressed cache payload.
#'
#' @param download_fn Function `(url, destfile)` that downloads the CSV.
#' @param url Bulk download URL.
#' @return A [collection_payload()] with gzip bytes and download metadata.
#' @export
oecd_fetch_sdg <- function(download_fn = oecd_download_csv, url = .oecd_sdg_url) {
  plain <- tempfile(fileext = ".csv")
  packed <- tempfile(fileext = ".csv.gz")
  on.exit(unlink(c(plain, packed)), add = TRUE)
  download <- download_fn(url, plain)
  size <- file.size(plain)
  if (is.na(size) || size == 0) {
    stop("OECD SDG DOWNLOAD IS EMPTY: ", url, call. = FALSE)
  }
  .gzip_copy(plain, packed)
  collection_payload(
    readBin(packed, "raw", file.size(packed)),
    list(
      download_url = url,
      download_effective_url = if (is.null(download$effective_url)) url else download$effective_url,
      download_sha256 = digest::digest(plain, algo = "sha256", file = TRUE),
      download_bytes = size,
      compression = "gzip",
      dataflow = .oecd_sdg_dataflow
    )
  )
}

#' Score the OECD SDG data as oecd_bulk_download.R does.
#'
#' @param oecd_data Data frame read from the bulk CSV.
#' @return One row per `(iso3c, date, goal, code)` with the mean value, a
#'   0/1 quality flag and the first source.
#' @export
transform_oecd_sdg <- function(oecd_data) {
  required <- c("REF_AREA", "TIME_PERIOD", "SDG_GOAL", "SDG indicator", "OBS_VALUE", "Source")
  missing <- setdiff(required, names(oecd_data))
  if (length(missing) > 0L) {
    stop("OECD SDG DATA SCHEMA MISMATCH: missing ", paste(missing, collapse = ", "), call. = FALSE)
  }
  if (nrow(oecd_data) == 0L) {
    stop("OECD SDG DATA HAS NO ROWS.", call. = FALSE)
  }
  oecd_data %>%
    dplyr::transmute(
      iso3c = REF_AREA,
      date = TIME_PERIOD,
      goal = SDG_GOAL,
      goal = stringr::str_replace(goal, "G_", ""),
      # The code is everything before the first space of the indicator label.
      code = stringr::str_extract(`SDG indicator`, "^[^ ]+"),
      ind_value.oecd = OBS_VALUE,
      ind_quality.oecd = dplyr::if_else(!is.na(ind_value.oecd), 1, 0),
      ind_metadata.oecd = Source
    ) %>%
    tidyr::separate_rows(code, sep = "/") %>%
    dplyr::mutate(code = stringr::str_trim(code)) %>%
    dplyr::group_by(iso3c, date, goal, code) %>%
    dplyr::summarise(
      ind_value.oecd = mean(ind_value.oecd, na.rm = TRUE),
      ind_quality.oecd = sum(ind_quality.oecd, na.rm = TRUE),
      ind_metadata.oecd = dplyr::first(ind_metadata.oecd),
      .groups = "drop_last"
    ) %>%
    dplyr::mutate(ind_quality.oecd = dplyr::if_else(ind_quality.oecd > 0, 1, 0))
}

#' Collect the OECD SDG data and write OECD_data_scored.csv.
#'
#' @param params Pipeline parameters (`raw_dir`, `end_date`,
#'   `collection_age_warning_days`).
#' @param fetch_fn Zero-argument function returning the cache payload;
#'   defaults to [oecd_fetch_sdg()].
#' @return A list with the output `path`, `rows` and `release_identifier`.
#' @export
collect_oecd_sdg <- function(params, fetch_fn = oecd_fetch_sdg) {
  max_age_days <- if (is.null(params$collection_age_warning_days)) Inf else params$collection_age_warning_days
  record <- collect_cached_raw(
    cache_dir = file.path(params$raw_dir, "oecd_data", "raw"),
    source_id = "oecd_sdg",
    request = list(endpoint = .oecd_sdg_url),
    vintage = params$end_date,
    collector_version = "oecd-sdg-csv-gzip-v1",
    fetch = function() fetch_fn(),
    max_age_days = max_age_days
  )
  oecd_data <- readr::read_csv(gzfile(record$raw_path), col_names = TRUE, show_col_types = FALSE, progress = FALSE)
  scored <- transform_oecd_sdg(oecd_data)

  out_path <- file.path(params$raw_dir, "oecd_data", "OECD_data_scored.csv")
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(scored, out_path, na = "", col_names = TRUE)
  release_identifier <- sprintf(
    "OECD SDG dataflow %s, retrieved %s",
    .oecd_sdg_dataflow,
    substr(record$retrieved_at, 1, 10)
  )
  write_artifact_provenance(
    out_path,
    source_id = "d3_oecd_sdg",
    retrieved_at = record$retrieved_at,
    release_identifier = release_identifier,
    raw_path = record$raw_path,
    extra = list(download_sha256 = record$download_sha256, rows = nrow(scored))
  )
  list(
    path = normalizePath(out_path, winslash = "/", mustWork = FALSE),
    rows = nrow(scored),
    release_identifier = release_identifier
  )
}

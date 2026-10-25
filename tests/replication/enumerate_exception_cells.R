# =============================================================================
# Enumerate approved vintage-replication exception cells
# =============================================================================
# Compares two promoted output folders and records changed country-level cells
# for a named methodology correction. Aggregate rows are excluded: their
# rounding is tested separately and is not a country-level exception.
#
# Usage:
#   Rscript tests/replication/enumerate_exception_cells.R \
#     --baseline <folder> --new <folder> --out <csv>
#
# Created: 2026-10-24
# =============================================================================

suppressPackageStartupMessages(library(dplyr))

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag) {
  hit <- which(args == flag)
  if (length(hit) == 0L || hit[[1]] == length(args)) {
    stop("MISSING ", flag, call. = FALSE)
  }
  args[[hit[[1]] + 1L]]
}

baseline_dir <- arg_value("--baseline")
new_dir <- arg_value("--new")
out_file <- arg_value("--out")

files <- list(
  "SPI_data.csv" = c("iso3c", "date"),
  "SPI_index.csv" = c("iso3c", "date"),
  "SPI_indicators_2024.csv" = c("iso3c", "date"),
  "SPI_quantiles.csv" = c("iso3c", "date"),
  "SPI_quantiles_2024.csv" = c("iso3c", "date"),
  "SPI_treemap.csv" = c("country", "source_id"),
  "SPI_databank_country_and_aggregates.csv" = c("iso3c", "date", "source_id"),
  "SPI_databank_country_and_aggregates_DCS.csv" = c("Time", "Country", "Series"),
  "SPI_databank_country_and_aggregates_DCS_wide.csv" = c("Country", "Series"),
  "SPI_databank_footnotes.csv" = c("Country", "Series", "Time"),
  "SPL_admin_data_availability.csv" = c("iso3c", "date")
)

read_text <- function(path) {
  readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    progress = FALSE,
    na = c("", "NA")
  )
}

country_codes <- unique(read_text(file.path(baseline_dir, "SPI_data.csv"))$iso3c)
country_names <- unique(c(
  read_text(file.path(baseline_dir, "SPI_data.csv"))$country,
  read_text(file.path(new_dir, "SPI_data.csv"))$country
))

country_rows <- function(data) {
  if ("iso3c" %in% names(data)) {
    return(dplyr::filter(data, iso3c %in% country_codes))
  }
  if ("Country" %in% names(data)) {
    return(dplyr::filter(data, Country %in% country_codes))
  }
  if ("country" %in% names(data)) {
    return(dplyr::filter(data, country %in% country_names))
  }
  data
}

same_value <- function(x, y, tolerance = 1e-9) {
  both_na <- is.na(x) & is.na(y)
  one_na <- xor(is.na(x), is.na(y))
  nx <- suppressWarnings(as.numeric(x))
  ny <- suppressWarnings(as.numeric(y))
  numeric <- !is.na(nx) & !is.na(ny)
  equal <- rep(FALSE, length(x))
  equal[both_na] <- TRUE
  equal[numeric] <- abs(nx[numeric] - ny[numeric]) <=
    tolerance * pmax(1, abs(nx[numeric]), abs(ny[numeric]))
  text <- !both_na & !one_na & !numeric
  equal[text] <- x[text] == y[text]
  equal
}

add_sequence <- function(data, key) {
  data <- data[do.call(order, unname(lapply(data, as.character))), , drop = FALSE]
  data %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(key))) %>%
    dplyr::mutate(.seq = as.character(dplyr::row_number())) %>%
    dplyr::ungroup()
}

rows <- list()
for (file in names(files)) {
  baseline <- country_rows(read_text(file.path(baseline_dir, file)))
  current <- country_rows(read_text(file.path(new_dir, file)))
  key <- files[[file]]
  if (!identical(sort(names(baseline)), sort(names(current)))) {
    stop("COLUMNS DIFFER IN ", file, call. = FALSE)
  }
  baseline <- add_sequence(baseline, key)
  current <- add_sequence(current, key)
  join_key <- c(key, ".seq")
  joined <- dplyr::full_join(
    baseline,
    current,
    by = join_key,
    suffix = c(".baseline", ".new"),
    relationship = "one-to-one"
  )
  value_columns <- setdiff(names(baseline), join_key)
  for (column in value_columns) {
    x <- joined[[paste0(column, ".baseline")]]
    y <- joined[[paste0(column, ".new")]]
    differs <- !same_value(x, y)
    if (any(differs)) {
      key_text <- do.call(
        paste,
        c(
          lapply(join_key, function(k) {
            paste0(k, "=", joined[[k]][differs])
          }),
          sep = ";"
        )
      )
      rows[[length(rows) + 1L]] <- tibble::tibble(
        file = file,
        key = sub(";[.]seq=[0-9]+$", "", key_text),
        column = column,
        baseline = x[differs],
        new = y[differs]
      )
    }
  }
}

cells <- dplyr::bind_rows(rows) %>%
  dplyr::distinct(file, key, column, .keep_all = TRUE) %>%
  dplyr::arrange(file, column, key)
dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
readr::write_csv(cells, out_file, na = "")
message(sprintf("Enumerated %d country-level exception cells -> %s", nrow(cells), out_file))

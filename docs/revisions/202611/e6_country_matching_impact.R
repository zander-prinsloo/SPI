# =============================================================================
# Impact of correction E6 (D1.5 country matching) on the SPI outputs
# =============================================================================
# Compares two estimation output folders produced from the SAME inputs, one
# with the legacy country matching and one with E6, and writes the effect of
# E6 on every country estimate and every published aggregate:
#
#   e6/e6_<label>_indicator_cells.csv  every changed indicator value
#   e6/e6_<label>_economies.csv        changed values per economy and indicator
#   e6/e6_<label>_index.csv            overall SPI score and pillar 1 of the
#                                      corrected economies, with rank and
#                                      quintile, every year
#   e6/e6_<label>_side_effects.csv     other economies whose rank or quintile
#                                      moved because the corrected economies
#                                      moved
#   e6/e6_<label>_aggregates.csv       regional, income and world aggregates
#                                      (SPI_databank_country_and_aggregates.csv)
#   e6/e6_<label>_summary.md           headline figures
#
# The script stops if any value other than SPI.D1.5.CHLD.MORT, SPI.D1.5.LFP
# and the index measures built on them differs, so the evidence measures E6
# alone.
#
# Usage (repository root):
#   Rscript docs/revisions/202611/e6_country_matching_impact.R \
#     --before <folder> --after <folder> --label <label>
# Labels used for the 202611 report:
#   202611            preview estimations of the 202611 inputs without and
#                     with E6 (what E6 changes in this release)
#   2024_replication  the 2024 vintage re-estimated from the 202511 inputs
#                     without and with E6 (what E6 changes in the published
#                     history, apart from every other 202611 change)
#
# Created: 2026-10-24
# =============================================================================

suppressPackageStartupMessages(library(dplyr))
source(file.path("R", "setup.R"))
source(file.path("R", "databank.R"))

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag) {
  hit <- which(args == flag)
  if (length(hit) == 0L || hit[[1]] == length(args)) stop("MISSING ", flag, call. = FALSE)
  args[[hit[[1]] + 1L]]
}
before_dir <- arg_value("--before")
after_dir <- arg_value("--after")
label <- arg_value("--label")
out_dir <- file.path("docs", "revisions", "202611", "e6")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

e6_indicators <- c("SPI.D1.5.CHLD.MORT", "SPI.D1.5.LFP")
# Index measures that are built on the two corrected indicators.
e6_index_measures <- c("SPI.DIM1.5.INDEX", "SPI.INDEX.PIL1", "SPI.INDEX")

read_output <- function(dir, file) {
  path <- file.path(dir, file)
  if (!file.exists(path)) stop("OUTPUT NOT FOUND: ", path, call. = FALSE)
  readr::read_csv(path, show_col_types = FALSE, guess_max = 1e6, progress = FALSE)
}
differs <- function(x, y, tolerance = 1e-9) {
  if (is.numeric(x) && is.numeric(y)) {
    xor(is.na(x), is.na(y)) | (!is.na(x) & !is.na(y) & abs(x - y) > tolerance * pmax(1, abs(x), abs(y)))
  } else {
    x <- as.character(x)
    y <- as.character(y)
    xor(is.na(x), is.na(y)) | (!is.na(x) & !is.na(y) & x != y)
  }
}
# The 2024 replication repeats some (iso3c, 2024) rows (replication-only
# artefact of exception X1). Repeated rows are paired in the order of all
# their columns: E6 moves the repeated rows of an economy-year by the same
# amount, so the order is the same before and after.
duplicated_keys <- list()
paired <- function(file, key) {
  before <- read_output(before_dir, file)
  after <- read_output(after_dir, file)
  if (!identical(sort(names(before)), sort(names(after)))) stop("COLUMNS DIFFER IN ", file, call. = FALSE)
  after <- after[, names(before)]
  repeats <- sum(duplicated(before[key]))
  if (repeats != sum(duplicated(after[key]))) stop("REPEATED KEYS DIFFER IN ", file, call. = FALSE)
  if (repeats > 0L) {
    duplicated_keys[[file]] <<- repeats
    with_seq <- function(df) {
      df <- df[do.call(order, c(unname(as.list(df[key])), unname(as.list(df[setdiff(names(df), key)])))), , drop = FALSE]
      df %>% dplyr::group_by(dplyr::across(dplyr::all_of(key))) %>% dplyr::mutate(.seq = dplyr::row_number()) %>% dplyr::ungroup()
    }
    before <- with_seq(before)
    after <- with_seq(after)
    key <- c(key, ".seq")
  }
  joined <- dplyr::full_join(before, after, by = key, suffix = c(".before", ".after"))
  if (nrow(joined) != nrow(before) || nrow(joined) != nrow(after)) stop("ROWS DIFFER IN ", file, call. = FALSE)
  joined
}
changed_columns <- function(joined, columns) {
  columns[vapply(columns, function(column) {
    any(differs(joined[[paste0(column, ".before")]], joined[[paste0(column, ".after")]]))
  }, logical(1))]
}

# --- Indicators (SPI_data.csv) -------------------------------------------------
data <- paired("SPI_data.csv", c("iso3c", "date"))
value_columns <- setdiff(sub("[.]before$", "", grep("[.]before$", names(data), value = TRUE)), c("iso3c", "date", ".seq"))
moved <- changed_columns(data, value_columns)
unexpected <- setdiff(moved, e6_indicators)
if (length(unexpected) > 0L) {
  stop("SPI_data.csv DIFFERS OUTSIDE THE E6 INDICATORS: ", paste(unexpected, collapse = ", "), call. = FALSE)
}
country_name <- data %>%
  dplyr::transmute(iso3c, country = dplyr::coalesce(country.after, country.before)) %>%
  dplyr::distinct(iso3c, .keep_all = TRUE)
name_of <- function(code) country_name$country[match(code, country_name$iso3c)]

cells <- dplyr::bind_rows(lapply(e6_indicators, function(indicator) {
  before <- data[[paste0(indicator, ".before")]]
  after <- data[[paste0(indicator, ".after")]]
  hit <- differs(before, after)
  tibble::tibble(iso3c = data$iso3c[hit], date = data$date[hit], indicator = indicator,
                 before = before[hit], after = after[hit])
})) %>%
  dplyr::distinct() %>%
  dplyr::mutate(country = name_of(iso3c), .after = iso3c) %>%
  dplyr::arrange(indicator, iso3c, date)
readr::write_csv(cells, file.path(out_dir, sprintf("e6_%s_indicator_cells.csv", label)), na = "")

span_text <- function(years) {
  years <- sort(unique(years))
  breaks <- c(0, which(diff(years) != 1), length(years))
  paste(vapply(seq_len(length(breaks) - 1L), function(i) {
    run <- years[(breaks[i] + 1L):breaks[i + 1L]]
    if (length(run) == 1L) as.character(run) else paste0(run[1], "-", run[length(run)])
  }, character(1)), collapse = ", ")
}
value_text <- function(x) {
  x <- ifelse(is.na(x), "NA", format(x, trim = TRUE))
  counts <- table(factor(x, levels = unique(x)))
  paste(sprintf("%s (%d)", names(counts), as.integer(counts)), collapse = ", ")
}
economies <- cells %>%
  dplyr::group_by(iso3c, country, indicator) %>%
  dplyr::summarise(
    cells = dplyr::n(),
    years = span_text(date),
    before_values = value_text(before),
    after_values = value_text(after),
    mean_change = round(mean(after - before, na.rm = TRUE), 3),
    .groups = "drop"
  ) %>%
  dplyr::arrange(indicator, iso3c)
readr::write_csv(economies, file.path(out_dir, sprintf("e6_%s_economies.csv", label)), na = "")

# --- Index, ranks and quintiles --------------------------------------------------
index <- paired("SPI_index.csv", c("iso3c", "date"))
index_columns <- setdiff(sub("[.]before$", "", grep("[.]before$", names(index), value = TRUE)), c("iso3c", "date", "country", ".seq"))
moved_index <- changed_columns(index, index_columns)
unexpected_index <- setdiff(moved_index, c(e6_indicators, e6_index_measures))
if (length(unexpected_index) > 0L) {
  stop("SPI_index.csv DIFFERS OUTSIDE THE E6 MEASURES: ", paste(unexpected_index, collapse = ", "), call. = FALSE)
}
quantiles <- paired("SPI_quantiles.csv", c("iso3c", "date"))
rank_desc <- function(value) {
  out <- rep(NA_integer_, length(value))
  out[!is.na(value)] <- as.integer(rank(-value[!is.na(value)], ties.method = "min"))
  out
}
# Ranks and quintiles are left blank in a year with repeated rows.
quintile_columns <- quantiles %>%
  dplyr::group_by(iso3c, date) %>%
  dplyr::filter(dplyr::n() == 1L) %>%
  dplyr::ungroup() %>%
  dplyr::select(iso3c, date, quintile_before = SPI.INDEX.quintile.before, quintile_after = SPI.INDEX.quintile.after)
ranked <- index %>%
  dplyr::select(iso3c, date, SPI.INDEX.before, SPI.INDEX.after, SPI.INDEX.PIL1.before, SPI.INDEX.PIL1.after) %>%
  dplyr::group_by(date) %>%
  dplyr::mutate(
    repeated_year = anyDuplicated(iso3c) > 0L,
    rank_before = if (repeated_year[1]) NA_integer_ else rank_desc(SPI.INDEX.before),
    rank_after = if (repeated_year[1]) NA_integer_ else rank_desc(SPI.INDEX.after),
    ranked = if (repeated_year[1]) NA_integer_ else sum(!is.na(SPI.INDEX.after))
  ) %>%
  dplyr::ungroup() %>%
  dplyr::left_join(quintile_columns, by = c("iso3c", "date")) %>%
  dplyr::mutate(
    quintile_before = dplyr::if_else(repeated_year, NA_character_, quintile_before),
    quintile_after = dplyr::if_else(repeated_year, NA_character_, quintile_after)
  )
corrected <- unique(cells$iso3c)
index_rows <- ranked %>%
  dplyr::filter(iso3c %in% corrected) %>%
  dplyr::transmute(
    iso3c, country = name_of(iso3c), date,
    spi_before = round(SPI.INDEX.before, 2), spi_after = round(SPI.INDEX.after, 2),
    spi_change = round(SPI.INDEX.after - SPI.INDEX.before, 2),
    pillar1_before = round(SPI.INDEX.PIL1.before, 2), pillar1_after = round(SPI.INDEX.PIL1.after, 2),
    rank_before, rank_after, ranked, quintile_before, quintile_after
  ) %>%
  dplyr::filter(differs(pillar1_before, pillar1_after) | differs(spi_before, spi_after)) %>%
  dplyr::distinct() %>%
  dplyr::arrange(iso3c, date)
readr::write_csv(index_rows, file.path(out_dir, sprintf("e6_%s_index.csv", label)), na = "")

side_effects <- ranked %>%
  dplyr::filter(!iso3c %in% corrected, differs(rank_before, rank_after) | differs(quintile_before, quintile_after)) %>%
  dplyr::transmute(iso3c, country = name_of(iso3c), date, spi = round(SPI.INDEX.after, 2),
                   rank_before, rank_after, quintile_before, quintile_after) %>%
  dplyr::arrange(date, rank_after)
readr::write_csv(side_effects, file.path(out_dir, sprintf("e6_%s_side_effects.csv", label)), na = "")

# --- Published aggregates --------------------------------------------------------
# Recompute group means from country rows in both runs. The published
# aggregate rows were summed in the legacy SPI_index order, so a country
# reorder can move an unrelated rounded mean by 0.01; that is not an E6
# country-level change and must not contaminate this evidence.
databank <- paired("SPI_databank_country_and_aggregates.csv", c("iso3c", "date", "source_id"))
country_codes <- unique(data$iso3c)
country_databank <- function(side) {
  databank %>%
    dplyr::filter(iso3c %in% country_codes) %>%
    dplyr::transmute(
      country = .data[[paste0("country.", side)]],
      iso3c,
      date,
      source_name = .data[[paste0("source_name.", side)]],
      source_id,
      value = .data[[paste0("value.", side)]],
      footnote = .data[[paste0("footnote.", side)]]
    )
}
params <- load_params(file.path("config", "params.R"), require_country_metadata = FALSE)
class_df <- read_classifications(params)
aggregate_side <- function(side) {
  aggregate_databank(country_databank(side), class_df) %>%
    dplyr::transmute(
      iso3c = WB_Group_Code,
      aggregate = WB_Group_Name,
      date,
      series = source_id,
      members = N,
      observed = N_obs,
      value = value
    )
}
aggregate_before <- aggregate_side("before")
aggregate_after <- aggregate_side("after")
aggregates_joined <- dplyr::full_join(
  aggregate_before,
  aggregate_after,
  by = c("iso3c", "aggregate", "date", "series"),
  suffix = c(".before", ".after")
)
if (nrow(aggregates_joined) != nrow(aggregate_before) ||
    nrow(aggregates_joined) != nrow(aggregate_after)) {
  stop("RECOMPUTED AGGREGATE ROWS DIFFER BETWEEN E6 RUNS", call. = FALSE)
}
moved_country <- databank %>%
  dplyr::filter(iso3c %in% country_codes) %>%
  dplyr::filter(
    differs(value.before, value.after) |
      differs(N_obs.before, N_obs.after)
  )
moved_series <- unique(moved_country$source_id)
unexpected_series <- setdiff(moved_series, c(e6_indicators, e6_index_measures))
if (length(unexpected_series) > 0L) {
  stop(
    "THE COUNTRY ROWS OF THE DATABANK DIFFER OUTSIDE THE E6 SERIES: ",
    paste(unexpected_series, collapse = ", "),
    call. = FALSE
  )
}
aggregates <- aggregates_joined %>%
  dplyr::filter(
    differs(value.before, value.after) |
      differs(observed.before, observed.after)
  ) %>%
  dplyr::transmute(
    iso3c, aggregate, date, series,
    members = members.before,
    observed_before = observed.before,
    observed_after = observed.after,
    before = round(value.before, 3), after = round(value.after, 3), change = round(value.after - value.before, 3)
  ) %>%
  dplyr::distinct() %>%
  dplyr::arrange(series, iso3c, date)
readr::write_csv(aggregates, file.path(out_dir, sprintf("e6_%s_aggregates.csv", label)), na = "")

# --- Summary -----------------------------------------------------------------------
latest <- max(index_rows$date[!is.na(index_rows$rank_after)], na.rm = TRUE)
lines <- c(
  sprintf("# E6 impact: %s", label),
  "",
  sprintf("Before: `%s`. After: `%s`. Generated by `docs/revisions/202611/e6_country_matching_impact.R`.", before_dir, after_dir),
  "",
  if (length(duplicated_keys) > 0L) c(sprintf(
    "Repeated rows (replication-only artefact, exception X1): %s. Ranks and quintiles are not computed for years with repeated rows.",
    paste(sprintf("%s %d", names(duplicated_keys), unlist(duplicated_keys)), collapse = "; ")
  ), "") else character(),
  "## Indicator values",
  "",
  "| Indicator | Changed values | Economies | Up | Down |",
  "|---|---|---|---|---|",
  vapply(e6_indicators, function(indicator) {
    x <- cells[cells$indicator == indicator, ]
    sprintf("| %s | %d | %d | %d | %d |", indicator, nrow(x), length(unique(x$iso3c)),
            sum(x$after > x$before, na.rm = TRUE), sum(x$after < x$before, na.rm = TRUE))
  }, character(1)),
  "",
  sprintf("## Overall SPI score of the corrected economies, %d", latest),
  "",
  "| Economy | Before | After | Change | Rank | Quintile |",
  "|---|---|---|---|---|---|",
  with(index_rows[index_rows$date == latest & !is.na(index_rows$spi_after), ], sprintf(
    "| %s (%s) | %.1f | %.1f | %+.1f | %s to %s of %s | %s |", country, iso3c, spi_before, spi_after, spi_change,
    rank_before, rank_after, ranked,
    ifelse(quintile_before == quintile_after, quintile_after, paste(quintile_before, "to", quintile_after))
  )),
  "",
  sprintf(
    "Overall SPI score: %d economy-years revised, %d economies; mean change %+.2f, largest %+.2f. Other economies with a rank change: %d economy-years; with a quintile change: %d.",
    sum(differs(index_rows$spi_before, index_rows$spi_after)), length(unique(index_rows$iso3c[differs(index_rows$spi_before, index_rows$spi_after)])),
    mean(index_rows$spi_change, na.rm = TRUE), index_rows$spi_change[which.max(abs(index_rows$spi_change))],
    sum(differs(side_effects$rank_before, side_effects$rank_after)), sum(differs(side_effects$quintile_before, side_effects$quintile_after))
  ),
  "",
  "## Aggregates (SPI_databank_country_and_aggregates.csv)",
  "",
  "| Series | Aggregate-years changed | Aggregates | Largest change |",
  "|---|---|---|---|",
  vapply(intersect(c(e6_indicators, e6_index_measures), unique(aggregates$series)), function(series) {
    x <- aggregates[aggregates$series == series, ]
    biggest <- x[which.max(abs(dplyr::coalesce(x$change, 0))), ]
    sprintf("| %s | %d | %d | %+.3f (%s, %s) |", series, nrow(x), length(unique(x$iso3c)),
            dplyr::coalesce(biggest$change, NA_real_), biggest$aggregate, biggest$date)
  }, character(1))
)
writeLines(lines, file.path(out_dir, sprintf("e6_%s_summary.md", label)))
message(sprintf("E6 impact (%s): %d indicator values, %d index rows, %d side effects, %d aggregate values -> %s",
                label, nrow(cells), nrow(index_rows), nrow(side_effects), nrow(aggregates), out_dir))

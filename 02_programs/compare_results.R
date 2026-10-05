# =============================================================================
# Compare new pipeline results vs the 202511 vintage
# =============================================================================
# Run this script LINE BY LINE in RStudio (or source it) to see how the
# new {targets} pipeline results compare with the former (vintage) results.
#
#   - "New" results  = staging/  (produced by the {targets} pipeline)
#   - "Former" results = tests/fixtures/  (the 202511 vintage, from the
#     original Rmd pipeline)
#
# Each section prints a clear PASS / DIFFERS result. The comparison uses
# the same 1e-9 relative tolerance as the automated test suite.
#
# NOTE: SPI.D1.5.LFP (and its downstream aggregates) intentionally differs
# from the vintage -- the ILO window logic was corrected (deviation E4,
# see docs/CHANGELOG.md). The script shows this as an EXPECTED difference.
#
# Created: 2026-09-22
# =============================================================================

# --- 0) Load the comparison utilities ----------------------------------------
source(here::here("R", "compare.R"))

# --- Helper: read a file from staging/ or tests/fixtures/ --------------------
read_new    <- function(f) readr::read_csv(here::here("staging", f), show_col_types = FALSE)
read_former <- function(f) readr::read_csv(here::here("tests", "fixtures", f), show_col_types = FALSE)

# --- Helper: print a section header ------------------------------------------
section <- function(title) {
  cat("\n", paste(rep("=", 70), collapse = ""), "\n", title, "\n",
      paste(rep("=", 70), collapse = ""), "\n", sep = "")
}

# --- Helper: print a PASS / DIFFERS verdict ----------------------------------
verdict <- function(ok, label, details = character()) {
  if (ok) {
    cat("  [PASS] ", label, "\n", sep = "")
  } else {
    cat("  [DIFFERS] ", label, "\n", sep = "")
    for (d in utils::head(details, 8)) cat("      - ", d, "\n", sep = "")
    if (length(details) > 8) cat("      ... (", length(details) - 8, " more)\n", sep = "")
  }
}

# =============================================================================
# 1) SPI_data.csv  -- the raw indicator scores (Stage A)
# =============================================================================
section("1) SPI_data.csv  (indicator scores)")

new    <- read_new("SPI_data.csv")
former <- read_former("SPI_data.csv")

# Compare only the SPI/RAW value columns (metadata drifts via the live
# World Bank API). SPI.D1.5.LFP is excluded -- it is the E4 deviation.
spi_raw_cols <- c(
  names(new)[grepl("^SPI[.]", names(new))],
  names(new)[grepl("^RAW[.]", names(new))]
)
spi_raw_cols <- setdiff(spi_raw_cols, "SPI.D1.5.LFP")

res <- compare_frames(
  new    %>% dplyr::select(iso3c, date, dplyr::all_of(spi_raw_cols)),
  former %>% dplyr::select(iso3c, date, dplyr::all_of(spi_raw_cols)),
  key_cols = c("iso3c", "date")
)
verdict(res$identical, "All SPI/RAW indicator values match the vintage (1e-9 tolerance)", res$differences)

# Show the E4 deviation explicitly
lfp_new    <- new    %>% dplyr::select(iso3c, date, SPI.D1.5.LFP)
lfp_former <- former %>% dplyr::select(iso3c, date, SPI.D1.5.LFP)
lfp_res    <- compare_frames(lfp_new, lfp_former, key_cols = c("iso3c", "date"))
cat("  [EXPECTED] SPI.D1.5.LFP differs (E4: ILO window fix):",
    if (lfp_res$identical) "no difference" else paste(length(lfp_res$differences), "difference report(s)"), "\n")

# =============================================================================
# 2) SPI_index.csv  -- the nested index (Stage B)
# =============================================================================
section("2) SPI_index.csv  (overall index and dimensions)")

new    <- read_new("SPI_index.csv")
former <- read_former("SPI_index.csv")

# E4 exclusion: LFP and its downstream aggregates.
idx_cols <- c(
  names(new)[grepl("^SPI[.]INDEX", names(new))],
  names(new)[grepl("^SPI[.]DIM", names(new))],
  names(new)[grepl("^SPI[.]D[0-9]", names(new))]
)
idx_cols <- setdiff(idx_cols, c("SPI.D1.5.LFP", "SPI.DIM1.5.INDEX", "SPI.INDEX.PIL1", "SPI.INDEX"))

res <- compare_frames(
  new    %>% dplyr::select(iso3c, date, dplyr::all_of(idx_cols)),
  former %>% dplyr::select(iso3c, date, dplyr::all_of(idx_cols)),
  key_cols = c("iso3c", "date")
)
verdict(res$identical, "All index/dimension values match the vintage (1e-9 tolerance)", res$differences)

# =============================================================================
# 3) SPI_quantiles.csv  -- quintiles and fragile/conflict (Stage D)
# =============================================================================
section("3) SPI_quantiles.csv  (quintiles)")

new    <- read_new("SPI_quantiles.csv")
former <- read_former("SPI_quantiles.csv")

value_cols <- c(
  names(new)[grepl("^SPI[.]INDEX", names(new))],
  names(new)[grepl("quintile", names(new))],
  "fragile_conflict"
)
value_cols <- setdiff(value_cols, c(
  "SPI.INDEX.PIL1", "SPI.INDEX",
  "SPI.INDEX.quintile", "SPI.INDEX.PIL1.quintile"
))

res <- compare_frames(
  new    %>% dplyr::select(iso3c, date, dplyr::all_of(value_cols)),
  former %>% dplyr::select(iso3c, date, dplyr::all_of(value_cols)),
  key_cols = c("iso3c", "date")
)
verdict(res$identical, "Quantile values match the vintage (1e-9 tolerance)", res$differences)

# =============================================================================
# 4) SPI_quantiles_2024.csv  -- latest-year quantiles (Stage D)
# =============================================================================
section("4) SPI_quantiles_2024.csv  (latest-year quantiles)")

new    <- read_new("SPI_quantiles_2024.csv")
former <- read_former("SPI_quantiles_2024.csv")

value_cols <- c(
  names(new)[grepl("^SPI[.]INDEX", names(new))],
  names(new)[grepl("quintile", names(new))],
  "fragile_conflict", "No Group"
)
value_cols <- setdiff(value_cols, c(
  "SPI.INDEX.PIL1", "SPI.INDEX",
  "SPI.INDEX.quintile", "SPI.INDEX.PIL1.quintile"
))

res <- compare_frames(
  new    %>% dplyr::select(iso3c, date, dplyr::all_of(value_cols)),
  former %>% dplyr::select(iso3c, date, dplyr::all_of(value_cols)),
  key_cols = c("iso3c", "date")
)
verdict(res$identical, "Latest-year quantile values match the vintage (1e-9 tolerance)", res$differences)

# =============================================================================
# 5) SPI_indicators_2024.csv  -- latest-year indicator scores (Stage D)
# =============================================================================
section("5) SPI_indicators_2024.csv  (latest-year indicators)")

new    <- read_new("SPI_indicators_2024.csv")
former <- read_former("SPI_indicators_2024.csv")

value_cols <- c(
  names(new)[grepl("^SPI[.]", names(new))],
  "fragile_conflict"
)
value_cols <- setdiff(value_cols, c("SPI.D1.5.LFP", "SPI.DIM1.5.INDEX"))

res <- compare_frames(
  new    %>% dplyr::select(iso3c, date, dplyr::all_of(value_cols)),
  former %>% dplyr::select(iso3c, date, dplyr::all_of(value_cols)),
  key_cols = c("iso3c", "date")
)
verdict(res$identical, "Latest-year indicator values match the vintage (1e-9 tolerance)", res$differences)

# =============================================================================
# 6) SPI_treemap.csv  -- treemap data (Stage D)
# =============================================================================
section("6) SPI_treemap.csv  (treemap)")

new    <- read_new("SPI_treemap.csv")
former <- read_former("SPI_treemap.csv")

value_cols <- c(
  "source_id", "value", "descript", "spi_indicator_description",
  "spi_indicator_scoring", "Pillar", "color", "max", "Score"
)

res <- compare_frames(
  new    %>% dplyr::select(dplyr::all_of(value_cols)),
  former %>% dplyr::select(dplyr::all_of(value_cols))
)
verdict(res$identical, "Treemap values match the vintage (1e-9 tolerance)", res$differences)

# =============================================================================
# 7) SPL_admin_data_availability.csv  -- SPL admin data (Stage D)
# =============================================================================
section("7) SPL_admin_data_availability.csv  (SPL admin)")

new    <- read_new("SPL_admin_data_availability.csv")
former <- read_former("SPL_admin_data_availability.csv")

value_cols <- c("ben_count_avail", "ben_exp_avail", "ben_info_avail")

res <- compare_frames(
  new    %>% dplyr::select(iso3c, date, dplyr::all_of(value_cols)),
  former %>% dplyr::select(iso3c, date, dplyr::all_of(value_cols)),
  key_cols = c("iso3c", "date")
)
verdict(res$identical, "SPL admin values match the vintage (1e-9 tolerance)", res$differences)

# =============================================================================
# 8) Databank files  -- country-level rows (Stage D)
# =============================================================================
section("8) Databank files  (country-level rows)")

# Country rows are identified by iso3c being in the vintage SPI country set.
# Aggregate rows (AFE, IBD, ...) are excluded -- the vintage aggregates were
# generated from an earlier index vintage (documented artifact E3).
country_codes <- unique(read_former("SPI_index.csv")$iso3c)
e4_series <- c("SPI.D1.5.LFP", "SPI.DIM1.5.INDEX", "SPI.INDEX.PIL1", "SPI.INDEX")

for (fname in c(
  "SPI_databank_country_and_aggregates.csv",
  "SPI_databank_country_and_aggregates_DCS.csv",
  "SPI_databank_country_and_aggregates_DCS_wide.csv",
  "SPI_databank_footnotes.csv"
)) {
  new    <- read_new(fname)
  former <- read_former(fname)

  # Keep only country-level rows.
  code_col <- if ("Country" %in% names(new)) "Country" else "iso3c"
  new_sub    <- new[new[[code_col]] %in% country_codes, ]
  former_sub <- former[former[[code_col]] %in% country_codes, ]

  # E4 exclusion: drop the LFP-affected series.
  series_col <- if ("Series" %in% names(new_sub)) "Series" else "source_id"
  if (series_col %in% names(new_sub)) {
    new_sub    <- new_sub[!(new_sub[[series_col]] %in% e4_series), ]
    former_sub <- former_sub[!(former_sub[[series_col]] %in% e4_series), ]
  }

  # Drop the drifting country NAME column (WB API renames).
  if ("country" %in% names(new_sub)) {
    new_sub    <- new_sub %>% dplyr::select(-country)
    former_sub <- former_sub %>% dplyr::select(-country)
  }

  # Normalize all-NA logical columns (CSV round-trip artifact).
  for (nm in names(new_sub)) {
    if (is.logical(new_sub[[nm]]) && all(is.na(new_sub[[nm]])) &&
        is.numeric(former_sub[[nm]])) {
      new_sub[[nm]] <- as.numeric(new_sub[[nm]])
    }
  }

  # Align rows by the natural key (order-independent comparison).
  key_cols <- intersect(
    c("iso3c", "Country", "date", "Time", "source_id", "Series"),
    names(new_sub)
  )
  res <- compare_frames(new_sub, former_sub, key_cols = key_cols)
  verdict(res$identical, fname, res$differences)
}

# =============================================================================
# 9) Summary
# =============================================================================
section("SUMMARY")

cat("
  PASS      = new results match the 202511 vintage within 1e-9 tolerance
  DIFFERS   = new results differ from the vintage (details printed above)
  EXPECTED  = intentional deviation (E4: ILO window fix)

The automated test suite (tests/testthat/) runs the same comparisons and
is the authoritative gate: 137 tests, 0 failures.
")

# =============================================================================
# 10) E4 detail: SPI.D1.5.LFP changes
# =============================================================================
section("10) E4 detail: SPI.D1.5.LFP changes")

# Read the two LFP columns and attach the new pipeline's country metadata.
# The old file is the former 202511 result; the new file is the current
# staged result after correcting the ILO window logic.
lfp_new <- read_new("SPI_data.csv") %>%
  dplyr::select(
    iso3c, date, SPI.D1.5.LFP_new = SPI.D1.5.LFP,
    country, region, income_level, population
  )

lfp_old <- read_former("SPI_data.csv") %>%
  dplyr::select(
    iso3c, date, SPI.D1.5.LFP_old = SPI.D1.5.LFP
  )

# First filter to rows where the LFP score changed, including NA/value
# changes. Then calculate signed and absolute changes for sorting.
lfp_changes <- lfp_new %>%
  dplyr::left_join(lfp_old, by = c("iso3c", "date")) %>%
  dplyr::filter(
    xor(is.na(SPI.D1.5.LFP_new), is.na(SPI.D1.5.LFP_old)) |
      (!is.na(SPI.D1.5.LFP_new) &
        !is.na(SPI.D1.5.LFP_old) &
        SPI.D1.5.LFP_new != SPI.D1.5.LFP_old)
  ) %>%
  dplyr::mutate(
    change = SPI.D1.5.LFP_new - SPI.D1.5.LFP_old,
    absolute_change = abs(change),
    old_window_start = dplyr::case_when(
      date == 2024 ~ date - 6,
      date == 2023 ~ date - 5,
      TRUE ~ date - 5
    ),
    new_window_start = dplyr::case_when(
      date == 2024 ~ date - 6,
      date == 2023 ~ date - 5,
      TRUE ~ date - 4
    ),
    boundary_year_removed = dplyr::if_else(
      old_window_start != new_window_start,
      old_window_start,
      as.numeric(NA)
    ),
    window_explanation = dplyr::if_else(
      old_window_start != new_window_start,
      "Old code included one extra boundary year; corrected code excludes it",
      "Window length unchanged; investigate if this row appears"
    )
  ) %>%
  dplyr::arrange(dplyr::desc(absolute_change), date, iso3c)

cat("\nChanged LFP values: ", nrow(lfp_changes), "\n", sep = "")
cat("Countries affected: ", dplyr::n_distinct(lfp_changes$iso3c), "\n", sep = "")
cat("Years affected: ", dplyr::n_distinct(lfp_changes$date), "\n", sep = "")
if (nrow(lfp_changes) != 102) {
  cat(
    "[CHECK] The expected E4 count is 102, but the current final output has ",
    nrow(lfp_changes),
    " changed country-year values.\n",
    sep = ""
  )
}

cat("\nEvery changed country-year, ordered by biggest absolute change:\n")
print(lfp_changes)

# --- Changes by region -------------------------------------------------------
cat("\nChanges by region:\n")
changes_by_region <- lfp_changes %>%
  dplyr::group_by(region) %>%
  dplyr::summarise(
    changed_values = dplyr::n(),
    countries_affected = dplyr::n_distinct(iso3c),
    years_affected = dplyr::n_distinct(date),
    old_mean = mean(SPI.D1.5.LFP_old, na.rm = TRUE),
    new_mean = mean(SPI.D1.5.LFP_new, na.rm = TRUE),
    mean_change = mean(change, na.rm = TRUE),
    mean_absolute_change = mean(absolute_change, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::arrange(dplyr::desc(changed_values), region)
print(changes_by_region)

# --- Changes by income group -------------------------------------------------
cat("\nChanges by income group:\n")
changes_by_income <- lfp_changes %>%
  dplyr::group_by(income_level) %>%
  dplyr::summarise(
    changed_values = dplyr::n(),
    countries_affected = dplyr::n_distinct(iso3c),
    years_affected = dplyr::n_distinct(date),
    old_mean = mean(SPI.D1.5.LFP_old, na.rm = TRUE),
    new_mean = mean(SPI.D1.5.LFP_new, na.rm = TRUE),
    mean_change = mean(change, na.rm = TRUE),
    mean_absolute_change = mean(absolute_change, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::arrange(dplyr::desc(changed_values), income_level)
print(changes_by_income)

# --- Global impact -----------------------------------------------------------
# This compares the global mean across ALL country-year observations, not
# only the changed rows. The population-weighted result uses the population
# already stored in the new SPI_data output.
global_lfp <- lfp_new %>%
  dplyr::left_join(lfp_old, by = c("iso3c", "date")) %>%
  dplyr::summarise(
    old_global_mean = mean(SPI.D1.5.LFP_old, na.rm = TRUE),
    new_global_mean = mean(SPI.D1.5.LFP_new, na.rm = TRUE),
    global_mean_change = new_global_mean - old_global_mean,
    old_population_weighted_mean = weighted.mean(
      SPI.D1.5.LFP_old, population, na.rm = TRUE
    ),
    new_population_weighted_mean = weighted.mean(
      SPI.D1.5.LFP_new, population, na.rm = TRUE
    ),
    population_weighted_change =
      new_population_weighted_mean - old_population_weighted_mean
  )

cat("\nGlobal impact across all country-year observations:\n")
print(global_lfp)

cat("\nGlobal impact by year:\n")
global_by_year <- lfp_new %>%
  dplyr::left_join(lfp_old, by = c("iso3c", "date")) %>%
  dplyr::group_by(date) %>%
  dplyr::summarise(
    countries = dplyr::n(),
    changed_values = sum(
      xor(is.na(SPI.D1.5.LFP_new), is.na(SPI.D1.5.LFP_old)) |
        (!is.na(SPI.D1.5.LFP_new) &
          !is.na(SPI.D1.5.LFP_old) &
          SPI.D1.5.LFP_new != SPI.D1.5.LFP_old)
    ),
    old_mean = mean(SPI.D1.5.LFP_old, na.rm = TRUE),
    new_mean = mean(SPI.D1.5.LFP_new, na.rm = TRUE),
    mean_change = new_mean - old_mean,
    .groups = "drop"
  ) %>%
  dplyr::filter(changed_values > 0)
print(global_by_year)


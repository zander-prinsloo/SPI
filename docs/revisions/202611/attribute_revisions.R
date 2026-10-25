# =============================================================================
# Attribution of the 202611 revisions to their causes
# =============================================================================
# Recomputes the refreshed indicators with the pipeline's own scoring
# functions, changing one group of inputs at a time, and attributes every
# revised 2004-2024 value to the step(s) that changed it.
#
#   D1.5 and D4.2 (refresh policy)
#     step 1  202511 inputs, end_date 2024: reproduces the published values,
#             except SPI.D1.5.LFP, where the pipeline corrects the legacy
#             window condition (documented exception E4, approved September
#             2026 and first published in 202611)
#     step 2  202511 inputs, end_date 2025: the recency windows of the
#             poverty and child-mortality scores depend on the reference year
#             ("window shift")
#     step 3  202611 inputs, end_date 2025 ("source update")
#   D4.1 (refresh policy)
#     step 1  202511 inputs, current code, end_date 2024: cells listed in the
#             E5 fixture are the CLASS.xlsx name normalization (E5); any other
#             change comes from D4.1 inputs updated after the 202511 release
#             (accepted exception X1)
#     step 2  the same inputs scored for end_date 2025: the survey window is
#             12 years for the latest year, 11 for the year before and 10
#             otherwise ("window shift")
#     step 3  2025 workbooks and review files, previous catalogue companions
#     step 4  refreshed catalogue companions (the current inputs)
#
# 202511 inputs: the files of commit 25b534706ff6 (PIP, JMP, UN SDG CRVS series,
# D4.1 catalogue companions) and the 202511 files kept in 01_raw_data under
# their own names (UN IGME 2021 extract, ILO September 2025 bulk files).
#
# Writes, next to this script:
#   revision_attribution.csv          one row per revised cell
#   revision_attribution_summary.csv  revised cells per indicator and cause
#
# Usage (repository root): Rscript docs/revisions/202611/attribute_revisions.R
#   [--current <folder with the estimation's SPI_data.csv>] checks that the
#   last step reproduces the pipeline output.
#
# Created: 2026-10-24
# =============================================================================

suppressPackageStartupMessages(library(dplyr))
for (file in list.files("R", full.names = TRUE, pattern = "[.]R$")) source(file)

reference_commit <- "25b534706ff6"
previous_end_date <- 2024L
current_end_date <- 2025L
out_dir <- file.path("docs", "revisions", "202611")
scratch_dir <- file.path(here::here(), "replication", ".scratch")
dir.create(scratch_dir, recursive = TRUE, showWarnings = FALSE)
args <- commandArgs(trailingOnly = TRUE)
current_dir <- if ("--current" %in% args) args[[which(args == "--current") + 1L]] else NULL

params <- load_params(here::here("config", "params.R"), require_country_metadata = TRUE)
real_raw <- normalizePath(params$raw_dir, mustWork = TRUE)
old_files <- list(
  unigme_file = "UNICEF-CME_DF_2021_WQ-1.0-download.csv",
  ilo_modelled_file = "EAP_2WAP_SEX_AGE_RT_A-20250923T0014.csv",
  ilo_survey_file = "EAP_DWAP_SEX_AGE_RT_A-20250923T0014.csv"
)

with_vintage <- function(base, end_date, raw_dir = base$raw_dir, files = list()) {
  base$end_date <- end_date
  base$span <- 2004:end_date
  base$raw_dir <- raw_dir
  for (name in names(files)) base[[name]] <- files[[name]]
  base
}

# A raw folder whose top-level entries link to the real raw folder, except the
# folders in `own`, which are real folders whose entries link to the real ones.
# Files are only written after their link is removed, so nothing is written
# through to 01_raw_data.
link_raw <- function(own) {
  root <- tempfile("attribution-raw-", tmpdir = scratch_dir)
  dir.create(root)
  for (child in list.files(real_raw, no.. = TRUE)) {
    if (child %in% own) {
      dir.create(file.path(root, child))
      for (entry in list.files(file.path(real_raw, child), all.files = TRUE, no.. = TRUE)) {
        file.symlink(file.path(real_raw, child, entry), file.path(root, child, entry))
      }
    } else {
      file.symlink(file.path(real_raw, child), file.path(root, child))
    }
  }
  root
}

detach_link <- function(path) {
  link <- Sys.readlink(path)
  if (!is.na(link) && nzchar(link)) unlink(path)
  parent <- Sys.readlink(dirname(path))
  if (file.exists(path) || (!is.na(parent) && nzchar(parent))) {
    stop("ATTRIBUTION REFUSES TO WRITE THROUGH A LINK: ", path, call. = FALSE)
  }
  path
}

use_reference_file <- function(root, relative) {
  destination <- detach_link(file.path(root, relative))
  status <- system2("git", c("show", sprintf("%s:01_raw_data/%s", reference_commit, relative)), stdout = destination)
  if (!identical(as.integer(status), 0L)) {
    stop("git show failed for ", relative, call. = FALSE)
  }
  destination
}

# Normalize the raw companions of `root` into a private collection folder.
normalize_into <- function(root, end_date) {
  collection <- file.path(root, "4.1_SOCS", "collection")
  link <- Sys.readlink(collection)
  if (!is.na(link) && nzchar(link)) {
    detach_link(collection)
    dir.create(collection)
  }
  normalize_dim4_1_companions(root, end_date = end_date)
  root
}

companion_stems <- names(dim4_1_workbook_specs())

# --- Step inputs ---------------------------------------------------------------
old_raw <- link_raw(c("1.5_DUIO", "4.2_SOAD", "4.1_SOCS"))
for (relative in c(
  "1.5_DUIO/PIP_comparability_latest.csv",
  "1.5_DUIO/Safely_Managed_Water_data.csv",
  "4.2_SOAD/SG_REG_BRTH90N.csv",
  "4.2_SOAD/SG_REG_DETH75N.csv",
  file.path("4.1_SOCS", paste0(companion_stems, "_NADA.csv"))
)) {
  use_reference_file(old_raw, relative)
}
step1 <- with_vintage(params, previous_end_date, old_raw, old_files)
step2 <- with_vintage(params, current_end_date, old_raw, old_files)
step3 <- with_vintage(params, current_end_date)

# A real folder inside `root` whose entries link to the real ones.
own_subdir <- function(root, relative) {
  path <- detach_link(file.path(root, relative))
  dir.create(path)
  for (entry in list.files(file.path(real_raw, relative), all.files = TRUE, no.. = TRUE)) {
    file.symlink(file.path(real_raw, relative, entry), file.path(path, entry))
  }
  path
}

d41_step1_raw <- normalize_into(old_raw, previous_end_date)
# Step 2: the 202511 workbooks (the 2024 derived files read as the 2025 ones)
# and catalogue companions, scored for 2025.
d41_window_raw <- link_raw(c("4.1_SOCS"))
for (stem in companion_stems) use_reference_file(d41_window_raw, file.path("4.1_SOCS", paste0(stem, "_NADA.csv")))
derived <- own_subdir(d41_window_raw, file.path("4.1_SOCS", "raw"))
for (stem in companion_stems) {
  destination <- detach_link(file.path(derived, sprintf("%s.%d.csv", stem, current_end_date)))
  file.copy(file.path(real_raw, "4.1_SOCS", "raw", sprintf("%s.%d.csv", stem, previous_end_date)), destination)
}
d41_window_raw <- normalize_into(d41_window_raw, current_end_date)
d41_step2_raw <- link_raw(c("4.1_SOCS"))
for (stem in companion_stems) use_reference_file(d41_step2_raw, file.path("4.1_SOCS", paste0(stem, "_NADA.csv")))
d41_step2_raw <- normalize_into(d41_step2_raw, current_end_date)
d41_step3_raw <- normalize_into(link_raw(c("4.1_SOCS")), current_end_date)

# --- Scores ----------------------------------------------------------------------
history <- function(data) data[data$date <= previous_end_date, , drop = FALSE]
score_d15 <- function(p) history(combine_dim1_5(p, build_country_grid(p)))
score_d42 <- function(p) history(score_crvs(read_wdi_metadata(p), p, build_country_grid(p)))
score_d41 <- function(p) history(combine_censuses_surveys(p, build_country_grid(p)))

message("Scoring D1.5 and D4.2 (three steps)")
d15 <- list(score_d15(step1), score_d15(step2), score_d15(step3))
d42 <- list(score_d42(step1), score_d42(step2), score_d42(step3))
message("Scoring D4.1 (four steps)")
d41 <- list(
  score_d41(with_vintage(params, previous_end_date, d41_step1_raw)),
  score_d41(with_vintage(params, current_end_date, d41_window_raw)),
  score_d41(with_vintage(params, current_end_date, d41_step2_raw)),
  score_d41(with_vintage(params, current_end_date, d41_step3_raw))
)

published <- readr::read_csv(
  file.path(real_raw, "previous_vintages", sprintf("SPI_data_%d.csv", previous_end_date)),
  show_col_types = FALSE, guess_max = Inf
)

stack_steps <- function(steps, indicators) {
  long <- function(data, label) {
    data %>%
      dplyr::select(iso3c, date, dplyr::any_of(indicators)) %>%
      tidyr::pivot_longer(-c(iso3c, date), names_to = "indicator", values_to = label)
  }
  labels <- c(if (length(steps) > 1L) paste0("value_step", seq_len(length(steps) - 1L)), "value_current")
  out <- long(history(published), "value_published")
  for (index in seq_along(steps)) {
    out <- dplyr::full_join(out, long(steps[[index]], labels[[index]]), by = c("iso3c", "date", "indicator"))
  }
  out
}
same <- function(x, y) (is.na(x) & is.na(y)) | (!is.na(x) & !is.na(y) & abs(x - y) <= 1e-9)

d15_indicators <- grep("^SPI[.]D1[.]5[.]", names(published), value = TRUE)
d42_indicators <- grep("^SPI[.]D4[.]2[.]", names(published), value = TRUE)
d41_indicators <- grep("^SPI[.]D4[.]1[.]", names(published), value = TRUE)

e5 <- readr::read_csv(file.path("tests", "fixtures", "exceptions", "E5_d41_name_normalization.csv"), show_col_types = FALSE)
e5 <- e5[e5$file == "SPI_data.csv", , drop = FALSE]
e5_keys <- paste(e5$column, e5$key)

# E6 is derived from the 202511 source labels rather than hard-coded country
# lists. The legacy IGME reader already patched the straight-apostrophe
# Côte d'Ivoire label, so that one is not an E6 pair.
iso_codes <- readr::read_csv(
  file.path(old_raw, "metadata", "iso_codes.csv"),
  col_types = readr::cols(.default = "c"),
  progress = FALSE
)
iso_country_names <- unique(iso_codes$country)
e6_igme <- readr::read_csv(
  file.path(old_raw, "1.5_DUIO", old_files$unigme_file),
  show_col_types = FALSE,
  guess_max = Inf
) %>%
  dplyr::distinct(REF_AREA, label = `Geographic area`) %>%
  dplyr::filter(
    !label %in% iso_country_names,
    !label %in% c("Côte d'Ivoire", "Côte d’Ivoire")
  ) %>%
  dplyr::mutate(
    iso3c = dplyr::if_else(REF_AREA == "RKS", "XKX", REF_AREA),
    source = "UN IGME REF_AREA"
  ) %>%
  dplyr::filter(iso3c %in% params$country_metadata$iso3c) %>%
  dplyr::transmute(indicator = "SPI.D1.5.CHLD.MORT", iso3c, source, label)

e6_ilo_lookup <- ilo_area_lookup(params)
e6_ilo <- dplyr::bind_rows(
  read_ilo_bulk_file(file.path(old_raw, "1.5_DUIO", old_files$ilo_modelled_file)) %>%
    dplyr::transmute(label = ref_area.label),
  read_ilo_bulk_file(file.path(old_raw, "1.5_DUIO", old_files$ilo_survey_file)) %>%
    dplyr::transmute(label = ref_area.label)
) %>%
  dplyr::distinct(label) %>%
  dplyr::mutate(label = ifelse(stringr::str_detect(label, "Tanzania"),
                               "United Republic of Tanzania", label)) %>%
  dplyr::filter(!label %in% iso_country_names) %>%
  dplyr::left_join(e6_ilo_lookup$codes, by = c("label" = "ilo_label")) %>%
  dplyr::filter(iso3c %in% params$country_metadata$iso3c) %>%
  dplyr::transmute(indicator = "SPI.D1.5.LFP", iso3c, source = "ILO area crosswalk", label)

e6_records <- dplyr::bind_rows(e6_igme, e6_ilo) %>%
  dplyr::distinct(indicator, iso3c, source, label)
e6_pair_keys <- paste(e6_records$indicator, e6_records$iso3c, sep = "|")
e6_match_evidence <- function(indicator, iso3c) {
  matched <- e6_records %>%
    dplyr::filter(indicator == !!indicator, iso3c == !!iso3c)
  if (nrow(matched) == 0L) {
    return("E6 country matching: no source-name mapping record")
  }
  paste0(
    "E6 country matching: ",
    paste(sprintf("%s '%s' -> %s", matched$source, matched$label, iso3c), collapse = "; ")
  )
}
lfp_window_span <- function(year) {
  if (year == current_end_date) 6L else if (year == current_end_date - 1L) 5L else 4L
}

cells <- dplyr::bind_rows(
  stack_steps(d15, d15_indicators) %>% dplyr::mutate(policy_group = "D1.5"),
  stack_steps(d42, d42_indicators) %>% dplyr::mutate(policy_group = "D4.2"),
  stack_steps(d41, d41_indicators) %>% dplyr::mutate(policy_group = "D4.1")
) %>%
  dplyr::filter(!same(value_published, value_current))

cause_of <- function(row) {
  causes <- character()
  step1_changed <- !same(row$value_published, row$value_step1)
  step2_changed <- !same(row$value_step1, row$value_step2)
  if (row$policy_group == "D4.1") {
    step3_changed <- !same(row$value_step2, row$value_step3)
    step4_changed <- !same(row$value_step3, row$value_current)
    if (step1_changed) {
      key <- sprintf("%s iso3c=%s;date=%d", row$indicator, row$iso3c, as.integer(row$date))
      causes <- c(causes, if (key %in% e5_keys) "E5 name normalization" else "inputs updated after the 202511 release (X1)")
    }
    if (step2_changed) causes <- c(causes, "window shift (new reference year)")
    if (step3_changed) causes <- c(causes, "2025 workbooks and review")
    if (step4_changed) causes <- c(causes, "catalogue refresh")
  } else {
    step3_changed <- !same(row$value_step2, row$value_current)
    if (step1_changed) {
      pair_key <- paste(row$indicator, row$iso3c, sep = "|")
      if (pair_key %in% e6_pair_keys) {
        causes <- c(causes, "E6 country matching")
      }
      if (row$indicator == "SPI.D1.5.LFP") {
        causes <- c(causes, "E4 LFP window correction")
      } else if (!(pair_key %in% e6_pair_keys)) {
        causes <- c(causes, "not reproduced from the 202511 inputs")
      }
    }
    if (step2_changed) causes <- c(causes, "window shift (new reference year)")
    if (step3_changed) causes <- c(causes, "source update")
  }
  if (length(causes) == 0L) "unexplained" else paste(causes, collapse = " + ")
}
cells$cause <- vapply(seq_len(nrow(cells)), function(index) cause_of(cells[index, ]), character(1))
unexplained <- sum(grepl("unexplained", cells$cause, fixed = TRUE))
if (unexplained > 0L) {
  stop(
    sprintf("REVISION ATTRIBUTION HAS %d UNEXPLAINED CELLS", unexplained),
    call. = FALSE
  )
}

# --- Per-cell evidence ------------------------------------------------------------
# For source updates, the source records of the country that differ between
# the 202511 and 202611 inputs within the scoring window; for the other
# causes, the reason in words.
keyed <- function(data, iso_column, year_column, key) {
  data <- data[!is.na(data[[iso_column]]), , drop = FALSE]
  split(
    data.frame(year = suppressWarnings(as.integer(data[[year_column]])), key = key(data), stringsAsFactors = FALSE),
    data[[iso_column]]
  )
}
window_keys <- function(sets, iso3c, limit, span) {
  rows <- sets[[iso3c]]
  if (is.null(rows)) return(character())
  unique(rows$key[!is.na(rows$year) & rows$year <= limit & rows$year >= limit - span])
}
describe_change <- function(sets, iso3c, limit, label, span = 12L) {
  before <- window_keys(sets$old, iso3c, limit, span)
  after <- window_keys(sets$new, iso3c, limit, span)
  added <- sort(setdiff(after, before))
  removed <- sort(setdiff(before, after))
  if (length(added) == 0L && length(removed) == 0L) {
    return(paste0(label, ": no change in the window"))
  }
  paste0(
    label, ":",
    if (length(added) > 0L) paste0(" added ", paste(added, collapse = ", ")) else "",
    if (length(removed) > 0L) paste0(if (length(added) > 0L) ";" else "", " removed ", paste(removed, collapse = ", ")) else ""
  )
}
pair <- function(read, step_old, step_new, iso_column, year_column, key) {
  lapply(list(old = read(step_old), new = read(step_new)), keyed, iso_column, year_column, key)
}
pip <- pair(read_pip_data, step2, step3, "country_code", "year", function(d) {
  sprintf("%s (spell %s%s)", d$year, d$survey_comparability, ifelse(d$survey_coverage == "national", "", paste0(", ", d$survey_coverage)))
})
mortality <- pair(read_child_mortality_data, step2, step3, "iso3c", "date", function(d) as.character(d$date))
water <- pair(read_safely_managed_water, step2, step3, "iso3c", "year", function(d) {
  sprintf("%s %s%s", d$year, d$geo, ifelse(d$data_quality == 1, "", " (not used)"))
})
labour <- pair(read_ilo_lfp, step2, step3, "iso3c", "date", function(d) {
  sprintf("%s %s", d$date, ifelse(d$lfs_source, "LFS", "other source"))
})
lfp_accuracy <- list(old = read_ilo_lfp(step2), new = read_ilo_lfp(step3))
describe_lfp_accuracy <- function(data, iso3c, limit, span) {
  values <- data %>%
    dplyr::filter(
      .data$iso3c == !!iso3c,
      .data$date >= limit - span,
      .data$date <= limit
    )
  if (nrow(values) == 0L || all(is.na(values$estimate_diff))) {
    return("no reported/modelled observations")
  }
  mean_gap <- mean(values$estimate_diff, na.rm = TRUE)
  lfs <- any(values$lfs_source %in% TRUE, na.rm = TRUE)
  sprintf(
    "mean reported-minus-modelled gap %.2f (<=10: %s; LFS source: %s)",
    mean_gap,
    ifelse(mean_gap <= 10, "yes", "no"),
    ifelse(lfs, "yes", "no")
  )
}
crvs_records <- function(root) {
  dplyr::bind_rows(lapply(c("SG_REG_BRTH90N", "SG_REG_DETH75N"), function(series) {
    readr::read_csv(file.path(root, "4.2_SOAD", paste0(series, ".csv")), show_col_types = FALSE, guess_max = Inf) %>%
      dplyr::transmute(iso3c, year = as.integer(TimePeriod), key = sprintf("%s %s=%s", TimePeriod, sub("^SG_REG_", "", series), Value))
  }))
}
crvs <- lapply(list(old = crvs_records(old_raw), new = crvs_records(real_raw)), function(d) split(d[c("year", "key")], d$iso3c))
workbook_columns <- c(
  D4.1.1.CEN.POPU = "POP.CENSUS", D4.1.2.CEN.AGRI = "AGRI.CENSUS", D4.1.3.CEN.BIZZ = "BIZZ.CENSUS",
  D4.1.4.SVY.HOUS = "HOUS.SURVEYS", D4.1.5.SVY.AGRI = "AGRI.SURVEYS", D4.1.6.SVY.LABR = "LABR.SURVEYS",
  D4.1.7.SVY.HLTH = "HLTH.SURVEYS", D4.1.8.SVY.BIZZ = "BIZZ.SURVEYS"
)
workbook_years <- function(stem, year) {
  data <- readr::read_csv(file.path(real_raw, "4.1_SOCS", "raw", sprintf("%s.%d.csv", stem, year)),
                          col_types = readr::cols(.default = "c"), progress = FALSE)
  years <- regmatches(data[[workbook_columns[[stem]]]], gregexpr("[0-9]{4}", data[[workbook_columns[[stem]]]]))
  rows <- data.frame(iso3c = rep(data$iso3c, lengths(years)), year = as.integer(unlist(years)), stringsAsFactors = FALSE)
  split(data.frame(year = rows$year, key = as.character(rows$year)), rows$iso3c)
}
workbooks <- stats::setNames(lapply(companion_stems, function(stem) {
  list(old = workbook_years(stem, previous_end_date), new = workbook_years(stem, current_end_date))
}), companion_stems)
companions <- function(root) {
  stats::setNames(lapply(companion_stems, function(stem) {
    data <- .read_d41_companion(root, stem, current_end_date)
    split(data.frame(year = as.integer(data$indicator_date), key = as.character(data$indicator_date)), data$iso3c)
  }), companion_stems)
}
catalogue_old <- companions(d41_step2_raw)
catalogue_new <- companions(d41_step3_raw)
stem_of <- function(indicator) {
  code <- sub("^SPI[.]D4[.]1[.]([0-9])[.].*$", "\\1", indicator)
  companion_stems[startsWith(companion_stems, paste0("D4.1.", code, "."))]
}

cells$evidence <- vapply(seq_len(nrow(cells)), function(index) {
  row <- cells[index, ]
  limit <- as.integer(row$date)
  notes <- character()
  if (grepl("source update", row$cause)) {
    notes <- c(notes, switch(
      row$indicator,
      SPI.D1.5.POV = describe_change(pip, row$iso3c, limit, "PIP surveys"),
      SPI.D1.5.CHLD.MORT = describe_change(mortality, row$iso3c, limit, "IGME series years included"),
      SPI.D1.5.SAFE.MAN.WATER = describe_change(water, row$iso3c, limit, "JMP source years"),
      SPI.D1.5.LFP = describe_change(
        labour,
        row$iso3c,
        limit,
        "ILO observations",
        span = lfp_window_span(limit)
      ),
      SPI.D4.2.3.CRVS = describe_change(crvs, row$iso3c, limit, "UN CRVS completeness flags"),
      NA_character_
    ))
  }
  if (grepl("window shift", row$cause)) {
    notes <- c(notes, "recency window for this year is shorter now that 2025 is the latest year")
  }
  if (grepl("E4", row$cause)) {
    notes <- c(notes, "corrected 5-year window replaces the legacy 6-year window (E4)")
  }
  stem <- if (row$policy_group == "D4.1") stem_of(row$indicator) else character()
  if (grepl("E5", row$cause)) {
    notes <- c(notes, "catalogue evidence previously lost to a country-name mismatch, now joined by ISO3 code (E5)")
  }
  if (grepl("E6", row$cause)) {
    notes <- c(notes, e6_match_evidence(row$indicator, row$iso3c))
  }
  if (row$indicator == "SPI.D1.5.LFP") {
    span <- lfp_window_span(limit)
    notes <- c(
      notes,
      paste0(
        "LFP scoring window: ",
        limit - span,
        "-",
        limit,
        "; 202511 ",
        describe_lfp_accuracy(lfp_accuracy$old, row$iso3c, limit, span),
        "; 202611 ",
        describe_lfp_accuracy(lfp_accuracy$new, row$iso3c, limit, span)
      )
    )
  }
  if (grepl("X1", row$cause)) {
    notes <- c(notes, "D4.1 input workbook changed after the 202511 release (accepted exception X1)")
  }
  if (grepl("2025 workbooks", row$cause) && length(stem) == 1L) {
    notes <- c(notes, describe_change(workbooks[[stem]], row$iso3c, limit, "workbook years"))
  }
  if (grepl("catalogue refresh", row$cause) && length(stem) == 1L) {
    notes <- c(notes, describe_change(list(old = catalogue_old[[stem]], new = catalogue_new[[stem]]), row$iso3c, limit, "catalogue study years"))
  }
  notes <- notes[!is.na(notes)]
  if (length(notes) == 0L) "" else paste(notes, collapse = "; ")
}, character(1))

cells <- cells %>%
  dplyr::mutate(dimension = vintage_diff_dimension(indicator)) %>%
  dplyr::select(indicator, dimension, iso3c, date, value_published, value_step1, value_step2, value_step3, value_current, cause, evidence) %>%
  dplyr::arrange(indicator, iso3c, date)

summary <- cells %>%
  dplyr::count(dimension, indicator, cause, name = "cells") %>%
  dplyr::arrange(dimension, indicator, dplyr::desc(cells))

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
readr::write_csv(cells, file.path(out_dir, "revision_attribution.csv"), na = "")
readr::write_csv(summary, file.path(out_dir, "revision_attribution_summary.csv"), na = "")
message(sprintf(
  "%d revised cells attributed; %d not reproduced or unexplained.",
  nrow(cells), sum(grepl("not reproduced|unexplained", cells$cause))
))

if (!is.null(current_dir)) {
  pipeline <- readr::read_csv(file.path(current_dir, "SPI_data.csv"), show_col_types = FALSE, guess_max = Inf)
  last_step <- dplyr::bind_rows(
    stack_steps(list(d15[[3]]), d15_indicators),
    stack_steps(list(d41[[4]]), d41_indicators),
    stack_steps(list(d42[[3]]), d42_indicators)
  )
  columns <- intersect(c(d15_indicators, d41_indicators, d42_indicators), names(pipeline))
  check <- last_step %>%
    dplyr::select(iso3c, date, indicator, value_current) %>%
    dplyr::full_join(
      tidyr::pivot_longer(
        history(pipeline)[c("iso3c", "date", columns)],
        -c(iso3c, date),
        names_to = "indicator",
        values_to = "value_pipeline"
      ),
      by = c("iso3c", "date", "indicator")
    )
  missing <- is.na(check$value_current) != is.na(check$value_pipeline)
  different <- !same(check$value_current, check$value_pipeline)
  differences <- sum(missing | different, na.rm = TRUE)
  message(sprintf(
    "Last step (D1.5 and D4.2 step 3, D4.1 step 4) vs the pipeline output: %d of %d cells differ.",
    differences, nrow(check)
  ))
  if (differences > 0L) {
    stop(
      sprintf("REVISION ATTRIBUTION DOES NOT MATCH THE PIPELINE: %d cells differ", differences),
      call. = FALSE
    )
  }
}

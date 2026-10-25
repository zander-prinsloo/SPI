# =============================================================================
# Agricultural catalogue evidence: effect of two legacy choices
# =============================================================================
# Quantifies, for the Working Group, two legacy choices of
# microdata_library_pull.Rmd that limit the agricultural evidence of D4.1.
# Neither is changed in 202611; this script measures what changing them
# would do.
#   1. The FAO studies are filtered with `created <= 2023`. `created` is text
#      ("2024/04/09 09:46:19"), so the comparison keeps only studies
#      catalogued in 2022 or earlier.
#   2. The script writes the FAO agricultural census list to
#      D4.1.2.CEN.AGRI_NADA_FAO.csv, which the estimation never reads; the
#      agricultural census score uses D4.1.2.CEN.AGRI_NADA.csv, unchanged
#      since February 2024.
# The script's own saver() is evaluated from the purled legacy code on the
# refreshed study lists, so the variants differ from the legacy run only in
# the choice under study; the legacy variant must reproduce the promoted
# companion exactly. Each variant is scored with combine_censuses_surveys().
#
# FAO names its studies with UN M49 country names. A name that neither
# CLASS.xlsx nor the D4.1 crosswalk resolves is, for this analysis only,
# resolved through the M49 table the pipeline uses for the UN SDG series
# (01_raw_data/metadata/iso_codes.csv) or one of the two current M49
# spellings in `m49_aliases`; names still unresolved (multi-country studies)
# are left out. The production crosswalk is not changed.
#
# Changed cells are counted as increased, decreased, added (no value in the
# legacy variant) or removed (no value in the variant): catalogue rows can
# score economies outside the 190 of the workbook base list, as in the legacy
# pipeline. The scoring warnings ("no non-missing arguments to max") are the
# legacy behaviour for economies without a census before the reference year,
# which score 0; the estimation emits the same warnings.
#
# Writes, next to this script:
#   agriculture_catalogue_evidence.csv   changed scores per variant and year
#   agriculture_catalogue_unmatched.csv  catalogue names CLASS.xlsx and the
#                                        crosswalk do not resolve, with how
#                                        the analysis resolved them
#
# Usage (repository root, after a catalogue refresh):
#   Rscript docs/revisions/202611/agriculture_catalogue_evidence.R
#
# Created: 2026-10-24
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
})
for (file in list.files("R", full.names = TRUE, pattern = "[.]R$")) source(file)

end_date <- 2025L
out_dir <- file.path("docs", "revisions", "202611")
params <- load_params(here::here("config", "params.R"), require_country_metadata = TRUE)
real_raw <- normalizePath(params$raw_dir, mustWork = TRUE)
socs <- file.path(real_raw, "4.1_SOCS")

# --- The legacy saver(), evaluated from the purled script ----------------------
code <- dim4_1_legacy_catalogue_code(dim4_1_catalogue_script_path())
expressions <- parse(text = code, keep.source = FALSE)
saver_expression <- Filter(function(expression) {
  is.call(expression) && identical(expression[[1]], as.name("<-")) && identical(expression[[2]], as.name("saver"))
}, as.list(expressions))
if (length(saver_expression) != 1L) stop("saver() NOT FOUND IN THE LEGACY SCRIPT", call. = FALSE)
legacy <- new.env(parent = globalenv())
legacy$write_excel_csv <- function(x, file, ...) readr::write_excel_csv(as.data.frame(x), file, ...)
eval(saver_expression[[1]], envir = legacy)

run_saver <- function(data, indicator) {
  out <- tempfile()
  dir.create(out)
  legacy$output_dir <- paste0(out, "/")
  legacy$study_data <- data
  suppressMessages(legacy$saver("study_data", indicator, "companion.csv"))
  readr::read_csv(file.path(out, "companion.csv"), col_types = readr::cols(.default = "c"), progress = FALSE)
}

read_text <- function(path) readr::read_csv(path, col_types = readr::cols(.default = "c"), progress = FALSE)
fao_all <- suppressMessages(readr::read_csv(file.path(socs, "fao_library_public_studies.csv"), show_col_types = FALSE, progress = FALSE)) %>%
  dplyr::filter(!(grepl("Good Growth Plan", title) | grepl("COVID", title)))
fao_legacy <- fao_all %>% dplyr::filter(created <= 2023)
internal <- suppressMessages(readr::read_csv(file.path(socs, "microdata_library_surveys.csv"), show_col_types = FALSE, progress = FALSE)) %>%
  dplyr::filter(!title %in% c("COVID19 Refugee Household Monitoring 2020")) %>%
  dplyr::filter(!(grepl("Good Growth Plan", title)))

survey_internal <- run_saver(internal, "ag/oth|Agricultural Survey")
survey_legacy <- dplyr::bind_rows(survey_internal, run_saver(fao_legacy, "ag/oth|Agricultural Survey|hh/oth"))
survey_all <- dplyr::bind_rows(survey_internal, run_saver(fao_all, "ag/oth|Agricultural Survey|hh/oth"))
census_static <- read_text(file.path(socs, "D4.1.2.CEN.AGRI_NADA.csv"))
census_fao_legacy <- run_saver(fao_legacy, "ag/census|Agricultural Census")
census_fao_all <- run_saver(fao_all, "ag/census|Agricultural Census")

promoted_survey <- read_text(file.path(socs, "D4.1.5.SVY.AGRI_NADA.csv"))
key <- function(data) sort(paste(data$country, data$indicator_date, data$nada_dates, sep = "|"))
if (!identical(key(promoted_survey), key(survey_legacy))) {
  stop("THE LEGACY VARIANT DOES NOT REPRODUCE THE PROMOTED D4.1.5.SVY.AGRI_NADA.csv", call. = FALSE)
}
message("Legacy variant reproduces the promoted agricultural survey companion.")

# --- Score each variant -----------------------------------------------------------
naming <- dim4_1_naming_files(real_raw)
lookup <- dim4_1_country_lookup(naming)
rules <- dim4_1_companion_exclusion_rules(naming)
m49 <- readr::read_csv(file.path(real_raw, "metadata", "iso_codes.csv"), col_types = readr::cols(.default = "c"), progress = FALSE)
m49_aliases <- c("Netherlands (Kingdom of the)" = "NLD", "Palestine" = "PSE")
unmatched <- list()
resolvable <- function(data, stem, variant) {
  name <- trimws(data$country)
  known <- name %in% lookup$catalogue_name | name %in% rules$catalogue_name[rules$companion %in% c("*", stem)]
  code <- ifelse(name %in% names(m49_aliases), m49_aliases[name], m49$iso3c[match(name, m49$country)])
  class_name <- lookup$country[match(code, lookup$iso3c)]
  via_m49 <- !known & !is.na(class_name)
  if (any(!known)) {
    resolution <- ifelse(
      via_m49,
      ifelse(name %in% names(m49_aliases), "M49 alias", "M49 table (iso_codes.csv)"),
      "unresolved, left out"
    )
    unmatched[[length(unmatched) + 1L]] <<- dplyr::distinct(data.frame(
      variant = variant, companion = stem, catalogue_name = name[!known],
      iso3c = ifelse(via_m49, code, NA_character_)[!known], resolution = resolution[!known],
      stringsAsFactors = FALSE
    ))
  }
  data$country[via_m49] <- class_name[via_m49]
  data[known | via_m49, , drop = FALSE]
}

score_variant <- function(survey, census, variant) {
  root <- tempfile("agriculture-raw-")
  dir.create(root)
  for (child in list.files(real_raw, no.. = TRUE)) {
    if (child == "4.1_SOCS") {
      dir.create(file.path(root, child))
      for (entry in list.files(socs, all.files = TRUE, no.. = TRUE)) {
        if (entry %in% c("collection", "D4.1.5.SVY.AGRI_NADA.csv", "D4.1.2.CEN.AGRI_NADA.csv")) next
        file.symlink(file.path(socs, entry), file.path(root, child, entry))
      }
      dir.create(file.path(root, child, "collection"))
    } else {
      file.symlink(file.path(real_raw, child), file.path(root, child))
    }
  }
  readr::write_csv(resolvable(survey, "D4.1.5.SVY.AGRI", variant), file.path(root, "4.1_SOCS", "D4.1.5.SVY.AGRI_NADA.csv"), na = "")
  readr::write_csv(resolvable(census, "D4.1.2.CEN.AGRI", variant), file.path(root, "4.1_SOCS", "D4.1.2.CEN.AGRI_NADA.csv"), na = "")
  normalize_dim4_1_companions(root, end_date = end_date)
  p <- params
  p$raw_dir <- root
  combine_censuses_surveys(p, build_country_grid(p)) %>%
    dplyr::select(iso3c, date, SPI.D4.1.2.AGRI, SPI.D4.1.5.AGSVY) %>%
    dplyr::mutate(variant = variant)
}

variants <- list(
  legacy = list(survey_legacy, census_static),
  fao_surveys_all_years = list(survey_all, census_static),
  fao_census_list = list(survey_legacy, census_fao_legacy),
  fao_census_list_all_years = list(survey_legacy, census_fao_all),
  both_all_years = list(survey_all, dplyr::bind_rows(census_static, census_fao_all))
)
scores <- lapply(names(variants), function(name) score_variant(variants[[name]][[1]], variants[[name]][[2]], name))
names(scores) <- names(variants)

baseline <- scores$legacy
evidence <- dplyr::bind_rows(lapply(setdiff(names(scores), "legacy"), function(name) {
  joined <- dplyr::inner_join(baseline, scores[[name]], by = c("iso3c", "date"), suffix = c(".legacy", ".variant"))
  dplyr::bind_rows(lapply(c("SPI.D4.1.2.AGRI", "SPI.D4.1.5.AGSVY"), function(indicator) {
    before <- joined[[paste0(indicator, ".legacy")]]
    after <- joined[[paste0(indicator, ".variant")]]
    changed <- !((is.na(before) & is.na(after)) | (!is.na(before) & !is.na(after) & abs(before - after) < 1e-9))
    data.frame(variant = name, indicator = indicator, date = joined$date, iso3c = joined$iso3c,
               legacy = before, variant_value = after, changed = changed, stringsAsFactors = FALSE)
  })) %>%
    dplyr::filter(changed) %>%
    dplyr::group_by(variant, indicator, date) %>%
    dplyr::summarise(
      countries = dplyr::n(),
      increased = sum(variant_value > legacy, na.rm = TRUE),
      decreased = sum(variant_value < legacy, na.rm = TRUE),
      added = sum(is.na(legacy) & !is.na(variant_value)),
      removed = sum(!is.na(legacy) & is.na(variant_value)),
      mean_change = round(mean(variant_value - legacy, na.rm = TRUE), 3),
      country_codes = paste(sort(iso3c), collapse = " "),
      .groups = "drop"
    )
}))

readr::write_csv(evidence, file.path(out_dir, "agriculture_catalogue_evidence.csv"), na = "")
readr::write_csv(
  if (length(unmatched) > 0L) {
    dplyr::arrange(dplyr::distinct(dplyr::bind_rows(unmatched)), variant, companion, catalogue_name)
  } else {
    data.frame(variant = character(), companion = character(), catalogue_name = character(), iso3c = character(), resolution = character())
  },
  file.path(out_dir, "agriculture_catalogue_unmatched.csv"),
  na = ""
)
message(sprintf(
  "FAO studies: %d (legacy filter keeps %d); variants scored: %d; changed country-years: %d",
  nrow(fao_all), nrow(fao_legacy), length(scores) - 1L, sum(evidence$countries)
))

# =============================================================================
# Sandbox-only legacy E6 readers
# =============================================================================
# These functions reproduce the pre-E6 country-name joins while retaining the
# current score rules. They are used only to isolate E6 impact evidence.
#
# Created: 2026-10-24
# =============================================================================

legacy_e6_child_reader <- function(params) {
  file_path <- file.path(params$raw_dir, "1.5_DUIO", params$unigme_file)
  mortality_raw <- readr::read_csv(file_path, show_col_types = FALSE)
  date_column <- if ("REF_DATE" %in% names(mortality_raw)) "REF_DATE" else "TIME_PERIOD"
  if (!date_column %in% names(mortality_raw)) {
    stop("UN IGME input must contain REF_DATE or TIME_PERIOD.", call. = FALSE)
  }
  mortality_raw %>%
    tibble::as_tibble(.name_repair = "universal") %>%
    dplyr::filter(
      Indicator == "Under-five mortality rate",
      Sex == "Total",
      Wealth.Quintile == "Total",
      Observation.Status == "Included in IGME"
    ) %>%
    dplyr::mutate(
      date = as.numeric(stringr::str_extract(Series.Year, "^.{4}")),
      ind_date = as.numeric(stringr::str_extract(.data[[date_column]], "^.{4}")),
      country = Geographic.area,
      D3.CHLD.MORT = OBS_VALUE
    ) %>%
    dplyr::left_join(
      readr::read_csv(
        file.path(params$raw_dir, "metadata", "iso_codes.csv"),
        show_col_types = FALSE
      ),
      by = "country"
    ) %>%
    dplyr::mutate(iso3c = dplyr::if_else(country == "Côte d'Ivoire", "CIV", iso3c))
}

legacy_e6_ilo_reader <- function(params) {
  ilo_ref_area <- readr::read_csv(
    file.path(params$raw_dir, "metadata", "ILO_reference_area.csv"),
    show_col_types = FALSE
  ) %>%
    dplyr::transmute(iso3c = ref_area, country = ref_area.label)
  fn_modelled <- file.path(params$raw_dir, "1.5_DUIO", params$ilo_modelled_file)
  fn_survey <- file.path(params$raw_dir, "1.5_DUIO", params$ilo_survey_file)
  iso3c_lookup <- readr::read_csv(
    file.path(params$raw_dir, "metadata", "iso_codes.csv"),
    show_col_types = FALSE
  )
  lfp_estimated <- read_ilo_bulk_file(fn_modelled) %>%
    dplyr::filter(
      sex.label == "Total",
      classif1.label == "Age (Youth, adults): 15+"
    ) %>%
    dplyr::mutate(
      ref_area.label = ifelse(
        stringr::str_detect(ref_area.label, "Tanzania"),
        "United Republic of Tanzania",
        ref_area.label
      )
    ) %>%
    dplyr::left_join(
      iso3c_lookup %>% dplyr::select(country, iso3c),
      by = dplyr::join_by(ref_area.label == country)
    ) %>%
    dplyr::mutate(date = as.numeric(time), estimated_value = obs_value) %>%
    dplyr::left_join(ilo_ref_area, by = "iso3c") %>%
    dplyr::select(iso3c, date, estimated_value)
  lfp_reported <- read_ilo_bulk_file(fn_survey) %>%
    dplyr::filter(
      sex.label == "Total",
      classif1.label == "Age (Youth, adults): 15+"
    ) %>%
    dplyr::mutate(
      ref_area.label = ifelse(
        stringr::str_detect(ref_area.label, "Tanzania"),
        "United Republic of Tanzania",
        ref_area.label
      )
    ) %>%
    dplyr::left_join(
      iso3c_lookup %>% dplyr::select(country, iso3c),
      by = dplyr::join_by(ref_area.label == country)
    ) %>%
    dplyr::mutate(
      date = as.numeric(time),
      reported_value = obs_value,
      source = source.label
    ) %>%
    dplyr::select(iso3c, date, source, reported_value)
  lfp_reported %>%
    dplyr::left_join(lfp_estimated, by = c("iso3c", "date")) %>%
    dplyr::mutate(
      estimate_diff = dplyr::if_else(
        !is.na(estimated_value),
        reported_value - estimated_value,
        NA_real_
      ),
      lfs_source = stringr::str_detect(source, "LFS")
    ) %>%
    dplyr::filter(iso3c %in% params$country_metadata$iso3c)
}

write_legacy_e6_overrides <- function(sandbox) {
  lines <- c(
    "# Sandbox-only legacy E6 overrides.",
    "legacy_e6_child_reader <-",
    deparse(legacy_e6_child_reader),
    "read_child_mortality_data <- legacy_e6_child_reader",
    "legacy_e6_ilo_reader <-",
    deparse(legacy_e6_ilo_reader),
    "read_ilo_lfp <- legacy_e6_ilo_reader"
  )
  writeLines(lines, file.path(sandbox, "R", "zzz_legacy_e6_overrides.R"))
  invisible(sandbox)
}

# =============================================================================
# Dimension 1.5: Data use by international organizations
# =============================================================================
# Ported from the "3.1", "aki_3.3", "3.15_debt", "safely_managed_scored", and
# "lfp" chunks of 01-SPI_data_prep.Rmd.
#
# Five indicators measure how useful/reliable country-produced statistics are
# for international organizations:
#   1. SPI.D1.5.POV               -- poverty comparability (PIP/Povcalnet)
#   2. SPI.D1.5.CHLD.MORT         -- child mortality data quality (UN IGME)
#   3. SPI.D1.5.DT.TDS.DPPF.XP.ZS -- debt service reporting (WDI metadata)
#   4. SPI.D1.5.SAFE.MAN.WATER    -- safely managed water data (JMP)
#   5. SPI.D1.5.LFP               -- labor force participation (ILO)
#
# The scoring logic is preserved EXACTLY from the Rmd so that the new
# pipeline replicates the 202511 vintage within tolerance.
#
# Created: 2026-09-21
# =============================================================================

# The pipe operator (%>%) comes from magrittr (loaded via tidyverse in the
# original Rmds). We import it explicitly so this file is self-contained.
`%>%` <- magrittr::`%>%`

# dplyr functions (if_else, case_when, etc.) are used unqualified throughout
# this file, matching the tidyverse style of the original Rmds.
library(dplyr)

# =============================================================================
# 1. SPI.D1.5.POV -- Poverty comparability (PIP)
# =============================================================================
# Source: World Bank Povcalnet PIP comparability metadata.
# Scoring:
#   1 point  -- comparable data lasting at least 2 years within past 5 years
#   0.5 point -- comparable data lasting at least 2 years within past 10 years
#   0 points -- no comparable data within past 10 years
# Note: surveys are reported with a lag, so recent years get a longer window
# (5/6/7-year windows for the last 3 years).
# Manual overrides: JPN, AUS, NZL, SGP get 1 (reviewed methodology).

#' Read the PIP comparability data
#'
#' Reads PIP_comparability_latest.csv and excludes the CPHS/IND survey
#' (produced by a private firm, not the statistical system).
#'
#' @param params List of pipeline parameters.
#' @return A tibble of PIP comparability records.
#' @export
read_pip_data <- function(params) {
  file_path <- file.path(params$raw_dir, "1.5_DUIO", "PIP_comparability_latest.csv")

  read_csv_validated(
    file_path,
    schema = list(
      required_cols = c("survey_acronym", "country_code", "year", "survey_comparability", "survey_coverage")
    )
  ) %>%
    # Exclude surveys produced by a private firm (non-official source).
    # Change applies to India in particular.
    dplyr::filter(!(survey_acronym == "CPHS" & country_code == "IND"))
}

#' Score the poverty comparability indicator
#'
#' For each reference year, checks whether a country has at least two
#' comparable poverty estimates within a 5-year (or 10-year) window.
#'
#' @param pip_data Tibble from read_pip_data().
#' @param params   List of pipeline parameters.
#' @param grid     The country x year grid (spi_df_empty equivalent).
#' @return A tibble with iso3c, date, SPI.D1.5.POV.
#' @export
score_poverty_comparability <- function(pip_data, params, grid) {
  end_date <- params$end_date
  span <- params$span

  # Loop over each reference year, keeping data inside the window
  result <- purrr::map_dfr(span, function(reference_year) {
    # Extend the window for recent years (surveys reported with a lag)
    rec_window <- if (reference_year >= end_date) {
      7
    } else if (reference_year == end_date - 1) {
      6
    } else {
      5
    }

    # 5-year window: at least 2 comparable estimates
    temp_5 <- pip_data %>%
      dplyr::mutate(frequency = ((reference_year - as.numeric(year)) <= rec_window) &
        (reference_year >= as.numeric(year))) %>%
      dplyr::filter(frequency == TRUE) %>%
      dplyr::group_by(country_code, survey_comparability) %>%
      dplyr::summarise(SPI.D1.5.POV_5 = dplyr::n(), .groups = "drop") %>%
      dplyr::ungroup() %>%
      dplyr::group_by(country_code) %>%
      dplyr::summarise(SPI.D1.5.POV_5 = max(SPI.D1.5.POV_5, na.rm = TRUE), .groups = "drop") %>%
      dplyr::mutate(SPI.D1.5.POV_5 = if_else(SPI.D1.5.POV_5 >= 2, 1, 0)) %>%
      dplyr::mutate(date = reference_year, iso3c = country_code) %>%
      dplyr::select(iso3c, date, SPI.D1.5.POV_5)

    # 10-year window: at least 2 comparable estimates (national coverage only)
    temp_10 <- pip_data %>%
      dplyr::filter(survey_coverage %in% c("national")) %>%
      dplyr::mutate(frequency = ((reference_year - as.numeric(year)) <= 12) &
        (reference_year >= as.numeric(year))) %>%
      dplyr::filter(frequency == TRUE) %>%
      dplyr::group_by(country_code, survey_comparability) %>%
      dplyr::summarise(SPI.D1.5.POV_10 = dplyr::n(), .groups = "drop") %>%
      dplyr::ungroup() %>%
      dplyr::group_by(country_code) %>%
      dplyr::summarise(SPI.D1.5.POV_10 = max(SPI.D1.5.POV_10, na.rm = TRUE), .groups = "drop") %>%
      dplyr::mutate(SPI.D1.5.POV_10 = if_else(SPI.D1.5.POV_10 >= 2, 1, 0)) %>%
      dplyr::mutate(date = reference_year, iso3c = country_code) %>%
      dplyr::select(iso3c, date, SPI.D1.5.POV_10)

    # Combine: 5-year window wins, else 10-year, else 0
    temp_5 %>%
      dplyr::left_join(temp_10, by = c("iso3c", "date")) %>%
      dplyr::mutate(SPI.D1.5.POV = dplyr::case_when(
        SPI.D1.5.POV_5 == 1 ~ 1,
        SPI.D1.5.POV_10 == 1 ~ 0.5,
        TRUE ~ 0
      )) %>%
      dplyr::select(iso3c, date, SPI.D1.5.POV)
  })

  # Fix countries not included in PIP but with reviewed methodology
  result %>%
    dplyr::right_join(grid, by = c("iso3c", "date")) %>%
    dplyr::mutate(SPI.D1.5.POV = if_else(
      iso3c %in% c("JPN", "AUS", "NZL", "SGP"),
      1,
      SPI.D1.5.POV
    )) %>%
    dplyr::select(iso3c, date, SPI.D1.5.POV)
}

# =============================================================================
# 2. SPI.D1.5.CHLD.MORT -- Child mortality (UN IGME)
# =============================================================================
# Source: UN Inter-agency Group for Child Mortality Estimation.
# Scoring:
#   1 point  -- two indicators meeting IGME standards within past 5 years
#   0.5 point -- two indicators meeting IGME standards within past 10 years
#   0 points -- no qualifying data within past 10 years

#' Read the UN IGME child mortality data
#'
#' Reads UNICEF-CME_DF_2021_WQ-1.0-download.csv, keeping only under-5
#' mortality observations included in the IGME estimation model.
#'
#' @param params List of pipeline parameters.
#' @return A tibble of child mortality source records.
#' @export
read_child_mortality_data <- function(params) {
  file_path <- file.path(params$raw_dir, "1.5_DUIO", "UNICEF-CME_DF_2021_WQ-1.0-download.csv")

  # NOTE: the raw file uses column names with spaces (e.g. "Geographic area").
  # The Rmd applies as_tibble(.name_repair = "universal") which converts
  # spaces to dots. We validate against the RAW names, then repair.
  read_csv_validated(
    file_path,
    schema = list(
      required_cols = c("Indicator", "Sex", "Observation Status", "Series Year", "TIME_PERIOD", "Geographic area", "OBS_VALUE")
    )
  ) %>%
    tibble::as_tibble(.name_repair = "universal") %>%
    # Keep only under-5 mortality, both sexes, overall wealth quintile
    dplyr::filter(Indicator == "Under-five mortality rate" & Sex == "Total") %>%
    # Keep only surveys that met IGME criteria for inclusion
    dplyr::filter(Observation.Status == "Included in IGME") %>%
    dplyr::mutate(
      date     = as.numeric(stringr::str_extract(Series.Year, "^.{4}")),
      ind_date = as.numeric(stringr::str_extract(TIME_PERIOD, "^.{4}")),
      country  = Geographic.area,
      D3.CHLD.MORT = OBS_VALUE
    ) %>%
    dplyr::left_join(
      readr::read_csv(file.path(params$raw_dir, "metadata", "iso_codes.csv")),
      by = "country"
    ) %>%
    dplyr::mutate(iso3c = if_else(country == "Côte d'Ivoire", "CIV", iso3c))
}

#' Score the child mortality indicator
#'
#' For each reference year, checks whether a country has at least two
#' qualifying observations within a 5-year (or 10-year) window.
#'
#' @param mort_data Tibble from read_child_mortality_data().
#' @param params    List of pipeline parameters.
#' @return A tibble with iso3c, date, SPI.D1.5.CHLD.MORT.
#' @export
score_child_mortality <- function(mort_data, params) {
  end_date <- params$end_date
  span <- params$span

  purrr::map_dfr(span, function(reference_year) {
    # Extend the window for recent years (surveys reported with a lag)
    rec_window <- if (reference_year == end_date) {
      7
    } else if (reference_year == (end_date - 1)) {
      6
    } else {
      5
    }

    # 5-year window: use survey year OR indicator report year
    temp_5 <- mort_data %>%
      dplyr::mutate(frequency = (
        ((reference_year - as.numeric(date)) <= rec_window &
          (reference_year >= as.numeric(date))) |
          ((reference_year - as.numeric(ind_date)) <= rec_window &
            (reference_year >= as.numeric(ind_date)))
      )) %>%
      dplyr::mutate(SPI.FREQ.D1.5.CHLD.MORT = if_else(frequency == TRUE, 1, 0)) %>%
      dplyr::group_by(iso3c) %>%
      dplyr::summarise(SPI.FREQ.D1.5.CHLD.MORT = sum(SPI.FREQ.D1.5.CHLD.MORT, na.rm = TRUE), .groups = "drop") %>%
      dplyr::mutate(
        SPI.FREQ.D1.5.CHLD.MORT = dplyr::case_when(SPI.FREQ.D1.5.CHLD.MORT >= 2 ~ 1, TRUE ~ 0),
        SPI.D1.5.CHLD.MORT_5 = SPI.FREQ.D1.5.CHLD.MORT,
        date = reference_year
      ) %>%
      dplyr::select(iso3c, date, SPI.D1.5.CHLD.MORT_5)

    # 10-year window: use survey year only
    temp_10 <- mort_data %>%
      dplyr::mutate(frequency = ((reference_year - as.numeric(date)) <= rec_window) &
        (reference_year >= as.numeric(date))) %>%
      dplyr::mutate(SPI.FREQ.D1.5.CHLD.MORT = if_else(frequency == TRUE, 1, 0)) %>%
      dplyr::group_by(iso3c) %>%
      dplyr::summarise(SPI.FREQ.D1.5.CHLD.MORT = sum(SPI.FREQ.D1.5.CHLD.MORT, na.rm = TRUE), .groups = "drop") %>%
      dplyr::mutate(
        SPI.FREQ.D1.5.CHLD.MORT = dplyr::case_when(SPI.FREQ.D1.5.CHLD.MORT >= 2 ~ 1, TRUE ~ 0),
        SPI.D1.5.CHLD.MORT_10 = SPI.FREQ.D1.5.CHLD.MORT,
        date = reference_year
      ) %>%
      dplyr::select(iso3c, date, SPI.D1.5.CHLD.MORT_10)

    temp_5 %>%
      dplyr::left_join(temp_10, by = c("iso3c", "date")) %>%
      dplyr::mutate(SPI.D1.5.CHLD.MORT = dplyr::case_when(
        SPI.D1.5.CHLD.MORT_5 == 1 ~ 1,
        SPI.D1.5.CHLD.MORT_10 == 1 ~ 0.5,
        TRUE ~ 0
      )) %>%
      dplyr::select(iso3c, date, SPI.D1.5.CHLD.MORT)
  })
}

# =============================================================================
# 3. SPI.D1.5.DT.TDS.DPPF.XP.ZS -- Debt service reporting (WDI metadata)
# =============================================================================
# Source: WDI metadata "External debt Reporting status".
# Scoring:
#   1 point  -- Actual value
#   0.67 points -- Preliminary value
#   0.33 points -- Estimated value
#   0 points -- No value
# High-income countries and WBG/PSE get 1 even without reporting (they are
# not judged on debt reporting).

#' Read and combine the WDI metadata files
#'
#' Reads WDI_metadata_<year>.csv for 2016:(end_date+1) and binds them into
#' one table. Mirrors the "metadata_pull" chunk.
#'
#' NOTE: the WDI metadata files have inconsistent column names across years:
#'   - 2016-2018 and 2025 use "Country Code" (with space)
#'   - 2019-2024 use "Code"
#' The Rmd normalizes these with rename(Code = Country.Code) for the years
#' that need it. We replicate that here.
#'
#' @param params List of pipeline parameters.
#' @return A tibble of combined WDI metadata.
#' @export
read_wdi_metadata <- function(params) {
  end_date <- params$end_date
  years <- 2016:(end_date + 1)

  purrr::map_dfr(years, function(i) {
    file_path <- file.path(params$raw_dir, "metadata", sprintf("WDI_metadata_%d.csv", i))
    df <- readr::read_csv(file_path) %>%
      tibble::as_tibble(.name_repair = "universal") %>%
      dplyr::mutate(
        National.accounts.reference.year = as.numeric(National.accounts.reference.year),
        date = i
      )

    # Normalize the country code column name across vintages.
    # 2016-2018 and 2025 use "Country.Code"; 2019-2024 use "Code".
    if ("Country.Code" %in% names(df) && !"Code" %in% names(df)) {
      df <- df %>% dplyr::rename(Code = Country.Code)
    }

    df
  })
}

#' Score the debt service reporting indicator
#'
#' Maps the WDI external debt reporting status to a score.
#'
#' @param wdi_metadata Tibble from read_wdi_metadata().
#' @return A tibble with iso3c, date, SPI.D1.5.DT.TDS.DPPF.XP.ZS.
#' @export
score_debt_reporting <- function(wdi_metadata) {
  wdi_metadata %>%
    dplyr::transmute(
      iso3c = Code,
      date = date,
      External_debt_Reporting = External.debt.Reporting.status,
      Income.Group = Income.Group
    ) %>%
    dplyr::mutate(SPI.D1.5.DT.TDS.DPPF.XP.ZS = dplyr::case_when(
      External_debt_Reporting == "Actual" ~ 1,
      External_debt_Reporting == "Preliminary" ~ 0.67,
      External_debt_Reporting == "Estimate" ~ 0.33,
      TRUE ~ 0
    )) %>%
    # High-income countries and WBG/PSE are not judged on debt reporting
    dplyr::mutate(SPI.D1.5.DT.TDS.DPPF.XP.ZS = if_else(
      ((Income.Group == "High income" | iso3c %in% c("WBG", "PSE")) &
        is.na(External_debt_Reporting)),
      1,
      SPI.D1.5.DT.TDS.DPPF.XP.ZS
    )) %>%
    dplyr::ungroup() %>%
    dplyr::select(iso3c, date, SPI.D1.5.DT.TDS.DPPF.XP.ZS)
}

# =============================================================================
# 4. SPI.D1.5.SAFE.MAN.WATER -- Safely managed water (JMP)
# =============================================================================
# Source: WHO/UNICEF JMP country files (Safely_Managed_Water_data.csv).
# Scoring (8-year window):
#   1 point  -- at least two estimates with urban/rural breakdown
#   0.5 point -- at least two estimates without urban/rural breakdown
#   0 points -- otherwise

#' Read the safely managed water data
#'
#' Reads the pre-downloaded JMP data (Safely_Managed_Water_data.csv).
#'
#' @param params List of pipeline parameters.
#' @return A tibble of JMP water data records.
#' @export
read_safely_managed_water <- function(params) {
  file_path <- file.path(params$raw_dir, "1.5_DUIO", "Safely_Managed_Water_data.csv")

  read_csv_validated(
    file_path,
    schema = list(
      required_cols = c("iso3c", "geo", "year", "data_quality")
    )
  )
}

#' Score the safely managed water indicator
#'
#' For each reference year, checks whether a country has at least two
#' qualifying estimates within an 8-year window, with or without urban/rural
#' breakdown.
#'
#' @param water_data Tibble from read_safely_managed_water().
#' @param params     List of pipeline parameters.
#' @return A tibble with iso3c, date, SPI.D1.5.SAFE.MAN.WATER.
#' @export
score_safely_managed_water <- function(water_data, params) {
  end_date <- params$end_date

  # Helper: score one window
  window_fun <- function(date_start, date_end) {
    water_data %>%
      dplyr::filter(dplyr::between(year, date_start, date_end)) %>%
      dplyr::group_by(iso3c, geo) %>%
      dplyr::summarise(data_quality = sum(data_quality, na.rm = TRUE), .groups = "drop") %>%
      tidyr::pivot_wider(names_from = "geo", values_from = "data_quality") %>%
      dplyr::mutate(SPI.D1.5.SAFE.MAN.WATER = dplyr::case_when(
        (Rural >= 2 & Urban >= 2) ~ 1,          # urban/rural breakdown gets 1
        (Rural >= 2 | Urban >= 2 | National >= 2) ~ 0.5,  # partial gets 0.5
        TRUE ~ 0
      )) %>%
      dplyr::select(iso3c, SPI.D1.5.SAFE.MAN.WATER) %>%
      dplyr::mutate(date = date_end)
  }

  # 8-year window for each year from 2015 to end_date
  purrr::map_dfr(2015:end_date, function(i) {
    end <- i
    # Extend the window for recent years (surveys reported with a lag)
    start <- if (end == end_date) {
      i - 9
    } else if (end == (end_date - 1)) {
      i - 8
    } else {
      i - 7
    }
    window_fun(start, end)
  })
}

# =============================================================================
# 5. SPI.D1.5.LFP -- Labor force participation (ILO)
# =============================================================================
# Source: ILO ILOSTAT modelled estimates (EAP_2WAP) and reported survey data
# (EAP_DWAP).
# Scoring:
#   1 point  -- country has an LFS-based estimate in past 5 years AND the
#               ILO estimated value is within 10 percentage points
#   0.5 point -- either LFS source OR within 10 points, but not both
#   0 points -- otherwise

#' Read the ILO labor force participation data
#'
#' Reads the modelled estimates and reported survey data, merges them, and
#' computes the difference between reported and estimated values.
#'
#' @param params List of pipeline parameters.
#' @return A tibble with iso3c, date, estimate_diff, lfs_source.
#' @export
read_ilo_lfp <- function(params) {
  # ILO reference areas (for country name matching)
  ilo_ref_area <- readr::read_csv(file.path(params$raw_dir, "metadata", "ILO_reference_area.csv")) %>%
    dplyr::transmute(iso3c = ref_area, country = ref_area.label)

  # Modelled estimates (EAP_2WAP) and reported survey data (EAP_DWAP).
  # The filenames come from config/params.R (ilo_modelled_file,
  # ilo_survey_file) so a new vintage's files can be wired in without
  # touching this code.
  fn_modelled <- file.path(params$raw_dir, "1.5_DUIO", params$ilo_modelled_file)
  fn_survey <- file.path(params$raw_dir, "1.5_DUIO", params$ilo_survey_file)

  # iso3c lookup from the UN country codes
  iso3c_lookup <- readr::read_csv(file.path(params$raw_dir, "metadata", "iso_codes.csv"))

  lfp_estimated <- readr::read_csv(fn_modelled) %>%
    tibble::as_tibble(.name_repair = "universal") %>%
    dplyr::filter(sex.label == "Total", classif1.label == "Age (Youth, adults): 15+") %>%
    dplyr::mutate(ref_area.label = ifelse(stringr::str_detect(ref_area.label, "Tanzania"),
      "United Republic of Tanzania",
      ref_area.label
    )) %>%
    dplyr::left_join(iso3c_lookup %>% dplyr::select(country, iso3c),
      by = dplyr::join_by(ref_area.label == country)
    ) %>%
    dplyr::mutate(
      date = time,
      estimated_value = obs_value
    ) %>%
    dplyr::left_join(ilo_ref_area, by = "iso3c") %>%
    dplyr::select(iso3c, date, estimated_value)

  lfp_reported <- readr::read_csv(fn_survey) %>%
    tibble::as_tibble(.name_repair = "universal") %>%
    dplyr::filter(sex.label == "Total", classif1.label == "Age (Youth, adults): 15+") %>%
    dplyr::mutate(ref_area.label = ifelse(stringr::str_detect(ref_area.label, "Tanzania"),
      "United Republic of Tanzania",
      ref_area.label
    )) %>%
    dplyr::left_join(iso3c_lookup %>% dplyr::select(country, iso3c),
      by = dplyr::join_by(ref_area.label == country)
    ) %>%
    dplyr::mutate(
      date = time,
      reported_value = obs_value,
      source = source.label
    ) %>%
    dplyr::select(iso3c, date, source, reported_value)

  # Merge and compute the difference
  lfp_reported %>%
    dplyr::left_join(lfp_estimated, by = c("iso3c", "date")) %>%
    dplyr::mutate(
      estimate_diff = if_else(!is.na(estimated_value), reported_value - estimated_value, 0),
      lfs_source = (stringr::str_detect(source, "LFS"))
    ) %>%
    dplyr::filter(iso3c %in% params$country_metadata$iso3c)
}

#' Score the labor force participation indicator
#'
#' For each reference year, checks whether a country has an LFS source and
#' whether the reported value is within 10 percentage points of the ILO
#' estimate.
#'
#' @param lfp_data Tibble from read_ilo_lfp().
#' @param params   List of pipeline parameters.
#' @return A tibble with iso3c, date, SPI.D1.5.LFP.
#' @export
score_ilo_lfp <- function(lfp_data, params) {
  end_date <- params$end_date

  # Helper: score one window
  ilo_fun <- function(date_start, date_end) {
    lfp_data %>%
      dplyr::filter(dplyr::between(date, date_start, date_end)) %>%
      dplyr::group_by(iso3c) %>%
      dplyr::summarise(
        SPI.D1.5.LFP.ACC = as.numeric(mean(estimate_diff, na.rm = TRUE) <= 10),
        SPI.D1.5.LFP.SOURCE = max(lfs_source, na.rm = TRUE),
        SPI.D1.5.LFP = (SPI.D1.5.LFP.ACC + SPI.D1.5.LFP.SOURCE) / 2,
        .groups = "drop"
      ) %>%
      dplyr::select(iso3c, SPI.D1.5.LFP) %>%
      dplyr::mutate(date = date_end)
  }

  # 5-year window for each year from 2010 to end_date (i-4 to i inclusive).
  # The window extends for recent years (surveys reported with a lag):
  #   end == end_date     -> 7-year window (i-6 to i)
  #   end == end_date - 1 -> 6-year window (i-5 to i)
  #   otherwise           -> 5-year window (i-4 to i)
  # NOTE: the original Rmd had a bug here -- `else if (end_date - 1)` is
  # always TRUE, so the `i - 4` branch was unreachable. Fixed to
  # `else if (end == end_date - 1)` (user-approved methodology
  # correction; see docs/CHANGELOG.md).
  purrr::map_dfr(2010:end_date, function(i) {
    end <- i
    start <- if (end == end_date) {
      i - 6
    } else if (end == end_date - 1) {
      i - 5
    } else {
      i - 4
    }
    ilo_fun(start, end)
  })
}

# =============================================================================
# Combine all five D1.5 indicators
# =============================================================================

#' Combine the five D1.5 indicators into one table
#'
#' Mirrors the "aki_combine" chunk: joins all five indicators onto the
#' country grid and fills missing values with 0.
#'
#' @param params List of pipeline parameters.
#' @param grid   The country x year grid.
#' @return A tibble with iso3c, date, and the five SPI.D1.5.* columns.
#' @export
combine_dim1_5 <- function(params, grid) {
  # Read all source data
  pip_data <- read_pip_data(params)
  mort_data <- read_child_mortality_data(params)
  wdi_metadata <- read_wdi_metadata(params)
  water_data <- read_safely_managed_water(params)
  lfp_data <- read_ilo_lfp(params)

  # Score each indicator
  pov <- score_poverty_comparability(pip_data, params, grid)
  mort <- score_child_mortality(mort_data, params)
  debt <- score_debt_reporting(wdi_metadata)
  water <- score_safely_managed_water(water_data, params)
  lfp <- score_ilo_lfp(lfp_data, params)

  # Join all onto the grid and fill missing with 0
  grid %>%
    dplyr::left_join(pov, by = c("iso3c", "date")) %>%
    dplyr::left_join(mort, by = c("iso3c", "date")) %>%
    dplyr::left_join(debt, by = c("iso3c", "date")) %>%
    dplyr::left_join(water, by = c("iso3c", "date")) %>%
    dplyr::left_join(lfp, by = c("iso3c", "date")) %>%
    dplyr::right_join(grid, by = c("iso3c", "date")) %>%
    dplyr::mutate(
      SPI.D1.5.POV = if_else(is.na(SPI.D1.5.POV), 0, as.numeric(SPI.D1.5.POV)),
      SPI.D1.5.CHLD.MORT = if_else(is.na(SPI.D1.5.CHLD.MORT), 0, as.numeric(SPI.D1.5.CHLD.MORT)),
      SPI.D1.5.DT.TDS.DPPF.XP.ZS = if_else(is.na(SPI.D1.5.DT.TDS.DPPF.XP.ZS), 0, as.numeric(SPI.D1.5.DT.TDS.DPPF.XP.ZS)),
      SPI.D1.5.SAFE.MAN.WATER = if_else(is.na(SPI.D1.5.SAFE.MAN.WATER), 0, as.numeric(SPI.D1.5.SAFE.MAN.WATER)),
      SPI.D1.5.LFP = if_else(is.na(SPI.D1.5.LFP), 0, as.numeric(SPI.D1.5.LFP))
    )
}
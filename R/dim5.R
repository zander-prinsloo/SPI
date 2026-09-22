# =============================================================================
# Dimension 5: Data Infrastructure
# =============================================================================
# Ported from the "legislation_governance", "standards_meta", "snau", "naby",
# "cnin", "cpiby", "hous", "empl", "cgov", "fina", "mony", "gsbp", "msc",
# and "finance" chunks of 01-SPI_data_prep.Rmd.
#
# Indicators:
#   1. SPI.D5.1.DILG      -- statistical legislation (Paris21/UNSD)
#   2. SPI.D5.2.1.SNAU    -- System of National Accounts in use
#   3. SPI.D5.2.2.NABY    -- National Accounts base year
#   4. SPI.D5.2.3.CNIN    -- Classification of national industry
#   5. SPI.D5.2.4.CPIBY   -- CPI base year
#   6. SPI.D5.2.5.HOUS    -- Classification of household consumption
#   7. SPI.D5.2.6.EMPL    -- Classification of status of employment
#   8. SPI.D5.2.7.CGOV    -- Central government accounting status
#   9. SPI.D5.2.8.FINA    -- Compilation of government finance statistics
#  10. SPI.D5.2.9.MONY    -- Compilation of monetary and financial statistics
#  11. SPI.D5.2.10.GSBP   -- Generic Statistical Business Process Model
#  12. SPI.D5.5.DIFI      -- Statistical plan fully funded (Paris21/UNSD)
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
# Shared helpers
# =============================================================================

#' Read the previous vintage of SPI data (for D5.2 indicators)
#'
#' Several D5.2 indicators start from the previous vintage's values and
#' update them with newer data. This reads SPI_data_<year>.csv and keeps
#' only the D5 columns for 2016+.
#'
#' @param params List of pipeline parameters.
#' @return A tibble with iso3c, date, and the RAW.D5.* / SPI.D5.* columns.
#' @export
read_previous_vintage_d5 <- function(params) {
  vintage_year <- params$end_date - 1
  readr::read_csv(file.path(
    params$raw_dir, "previous_vintages", sprintf("SPI_data_%d.csv", vintage_year)
  )) %>%
    dplyr::select(iso3c, date, dplyr::starts_with("RAW.D5"), dplyr::starts_with("SPI.D5.")) %>%
    dplyr::filter(date >= 2016)
}

#' Read the IMF country codes mapping
#'
#' @param params List of pipeline parameters.
#' @return A tibble mapping IMF codes to iso3c.
#' @export
read_imf_codes <- function(params) {
  readr::read_csv(file.path(params$raw_dir, "metadata", "IMF_country_codes.csv"))
}

#' Read a base CSV plus per-year update CSVs
#'
#' Several D5.2 indicators follow the same pattern: a base CSV (no year
#' suffix, covers the earliest years with its own date column) plus
#' per-year update CSVs (D5.2.*.<YEAR>.csv). The per-year files' own date
#' columns are overwritten with the file's year, matching the original Rmd.
#'
#' Historical quirk preserved from the original Rmd: the 2022 file is used
#' for BOTH 2021 and 2022 (there is no D5.2.*.2021.csv). When a new vintage
#' is added, the technical lead saves the new year's file as
#' D5.2.*.<end_date>.csv and the loop picks it up automatically.
#'
#' @param params List of pipeline parameters.
#' @param stem   Character: the file stem (e.g. "D5.2.6.EMPL").
#' @return A list with two elements:
#'   - base: the base CSV (has its own date column)
#'   - yearly: a LIST of per-year tibbles, each with the date column set
#'     (the 2022 file appears twice: date = 2021 and date = 2022)
#' @noRd
.read_base_plus_yearly <- function(params, stem) {
  end_date <- params$end_date
  dim5_dir <- file.path(params$raw_dir, "5.2_DISM")

  # Base file (covers the earliest years, has its own date column).
  base <- readr::read_csv(file.path(dim5_dir, sprintf("%s.csv", stem)))

  # Per-year files. The per-year files' own date columns are overwritten
  # with the file's year (matching the original Rmd). The 2021-from-2022
  # quirk is preserved: when the 2022 file exists, it is bound twice
  # (date = 2021 and date = 2022).
  yearly <- list()
  for (y in 2020:end_date) {
    file_path <- file.path(dim5_dir, sprintf("%s.%d.csv", stem, y))
    if (!file.exists(file_path)) {
      # Historical years may be missing (e.g. there is no 2021 file -- the
      # 2022 file provides the 2021 values). But the CURRENT vintage file
      # is required -- fail loudly if it is missing (R8).
      if (y == end_date) {
        stop(
          sprintf("DIM5 FILE NOT FOUND: %s\n", file_path),
          "\nThe current vintage file is required. Save the new year's",
          sprintf("data as %s.%d.csv in 01_raw_data/5.2_DISM/.", stem, end_date),
          call. = FALSE
        )
      }
      next
    }
    file_y <- readr::read_csv(file_path)
    yearly[[length(yearly) + 1]] <- file_y %>% dplyr::mutate(date = y)
    # Historical quirk: the 2022 file also provides the 2021 values.
    if (y == 2022) {
      yearly[[length(yearly) + 1]] <- file_y %>% dplyr::mutate(date = 2021)
    }
  }

  list(base = base, yearly = yearly)
}

# =============================================================================
# 5.1 Legislation and governance
# =============================================================================
# Source: Paris21/UNSD SDG indicator 17.18.2 (national statistical legislation
# compliance with UN Fundamental Principles of Official Statistics).
# Score: 1 if compliant, 0 otherwise.

#' Score the legislation indicator
#'
#' Mirrors the "legislation_governance" chunk.
#'
#' @param params List of pipeline parameters.
#' @param grid   The country x year grid.
#' @return A tibble with iso3c, date, RAW.D5.1.DILG, SPI.D5.1.DILG.
#' @export
score_legislation <- function(params, grid) {
  readr::read_csv(file.path(params$raw_dir, "5.1_DILG", "SG_STT_FPOS.csv")) %>%
    dplyr::select(iso3c, date, Value) %>%
    dplyr::right_join(grid, by = c("iso3c", "date")) %>%
    dplyr::mutate(
      RAW.D5.1.DILG = dplyr::if_else((is.na(Value) | Value == "NaN"), as.numeric(NA), as.numeric(Value)),
      SPI.D5.1.DILG = dplyr::if_else((is.na(Value) | Value == "NaN"), as.numeric(NA), as.numeric(Value))
    ) %>%
    dplyr::select(-Value, -country)
}

# =============================================================================
# 5.2 Standards
# =============================================================================

# --- 5.2.1 System of National Accounts in use --------------------------------
# Source: WDI metadata "System of National Accounts".
# Score: 1 for SNA2008/ESA2010, 0.5 for SNA1993/ESA1995, 0 otherwise.

#' Score the SNA indicator
#'
#' Mirrors the "snau" chunk.
#'
#' @param wdi_metadata Tibble from read_wdi_metadata().
#' @return A tibble with iso3c, date, RAW.D5.2.1.SNAU, SPI.D5.2.1.SNAU.
#' @export
score_snau <- function(wdi_metadata) {
  wdi_metadata %>%
    dplyr::filter(!is.na(Income.Group)) %>%
    dplyr::mutate(
      iso3c = Code,
      country = Table.Name
    ) %>%
    dplyr::select(iso3c, date, System.of.National.Accounts) %>%
    dplyr::mutate(
      SNAU = System.of.National.Accounts,
      SNAU = stringr::str_extract(SNAU, "\\d{4}")
    ) %>%
    dplyr::mutate(
      SPI.D5.2.1.SNAU = dplyr::case_when(
        SNAU == "2008" ~ 1,
        SNAU == "1993" ~ 0.5,
        TRUE ~ 0
      ),
      RAW.D5.2.1.SNAU = System.of.National.Accounts
    ) %>%
    dplyr::arrange(date, iso3c) %>%
    dplyr::select(iso3c, date, RAW.D5.2.1.SNAU, SPI.D5.2.1.SNAU)
}

# --- 5.2.2 National Accounts base year ---------------------------------------
# Source: WDI metadata "National accounts base year".
# Score: 1 for chained price, 0.5 for reference period within past 10 years,
# 0 otherwise.

#' Score the NABY indicator
#'
#' Mirrors the "naby" chunk. Reads the pre-computed raw metadata file
#' (D5.2.2.NABY_raw_metadata.csv) which contains the NABY and NABY_dates
#' columns.
#'
#' @param params List of pipeline parameters.
#' @return A tibble with iso3c, date, RAW.D5.2.2.NABY, SPI.D5.2.2.NABY.
#' @export
score_naby <- function(params) {
  readr::read_csv(file.path(params$raw_dir, "5.2_DISM", "D5.2.2.NABY_raw_metadata.csv")) %>%
    dplyr::mutate(
      SPI.D5.2.2.NABY = dplyr::case_when(
        NABY == "Original chained constant price data are rescaled." ~ 1,
        (date - as.numeric(NABY_dates)) <= 10 ~ 0.5,
        TRUE ~ 0
      ),
      RAW.D5.2.2.NABY = NABY
    ) %>%
    dplyr::select(iso3c, date, RAW.D5.2.2.NABY, SPI.D5.2.2.NABY) %>%
    dplyr::arrange(date)
}

# --- 5.2.3 Classification of national industry -------------------------------
# Source: WDI metadata + manual review.
# Score: 1 for ISIC Rev4/NACE Rev2, 0.5 for ISIC Rev3/NACE Rev1, 0 otherwise.

#' Score the CNIN indicator
#'
#' Mirrors the "cnin" chunk. Reads the base CSV, pivots 2020-2024 columns,
#' applies the manual review corrections, and scores.
#'
#' @param params List of pipeline parameters.
#' @return A tibble with iso3c, date, RAW.D5.2.3.CNIN, SPI.D5.2.3.CNIN.
#' @export
score_cnin <- function(params) {
  end_date <- params$end_date

  # --- 1) Read in data -------------------------------------------------------
  # The CNIN file is versioned by vintage year (D5.2.3.CNIN.<YEAR>.csv) and
  # contains one column per year (2020:<end_date>). Fail loudly if the
  # current vintage file is missing (R8).
  cnin_path <- file.path(params$raw_dir, "5.2_DISM", sprintf("D5.2.3.CNIN.%d.csv", end_date))
  if (!file.exists(cnin_path)) {
    stop(
      sprintf("CNIN FILE NOT FOUND: %s\n", cnin_path),
      "\nThe current vintage file is required. Save the new year's data as",
      sprintf("D5.2.3.CNIN.%d.csv in 01_raw_data/5.2_DISM/.", end_date),
      call. = FALSE
    )
  }
  D5.2.3.CNIN <- readr::read_csv(cnin_path) %>%
    tidyr::pivot_longer(
      cols = dplyr::all_of(as.character(2020:end_date)),
      names_to = "date",
      values_to = "CNIN"
    ) %>%
    dplyr::mutate(
      iso3c = Code,
      date = as.numeric(date)
    ) %>%
    dplyr::bind_rows(readr::read_csv(file.path(params$raw_dir, "5.2_DISM", "D5.2.3.CNIN.csv")))

  # --- 2) Load manual review -------------------------------------------------
  manual_path <- file.path(params$raw_dir, "5.2_DISM", "D5.2.3.CNIN.Manual.Review.xlsx")
  manual_raw <- readxl::read_xlsx(manual_path)

  year_cols <- intersect(names(manual_raw), unique(as.character(D5.2.3.CNIN$date)))

  manual_long <- manual_raw %>%
    dplyr::select(iso3c, dplyr::any_of(year_cols)) %>%
    tidyr::pivot_longer(
      cols = dplyr::all_of(year_cols),
      names_to = "date",
      values_to = "CNIN_manual"
    ) %>%
    dplyr::mutate(
      date = as.numeric(.data$date),
      CNIN_manual = stringr::str_squish(as.character(.data$CNIN_manual)),
      CNIN_manual = dplyr::na_if(.data$CNIN_manual, "")
    ) %>%
    dplyr::filter(!is.na(.data$CNIN_manual))

  # --- 3) Update data with review inputs -------------------------------------
  D5.2.3.CNIN <- dplyr::left_join(
    D5.2.3.CNIN,
    manual_long,
    by = c("iso3c", "date")
  ) |>
    dplyr::mutate(CNIN = ifelse(!is.na(CNIN_manual), CNIN_manual, CNIN))
  D5.2.3.CNIN$CNIN_manual <- NULL

  # --- 4) Execute scoring ----------------------------------------------------
  D5.2.3.CNIN %>%
    dplyr::mutate(
      SPI.D5.2.3.CNIN = dplyr::case_when(
        stringr::str_to_lower(CNIN) == "nace rev2" | stringr::str_to_lower(CNIN) == "rev4" ~ 1,
        stringr::str_to_lower(CNIN) == "nace rev1" | stringr::str_to_lower(CNIN) == "rev3" ~ 0.5,
        TRUE ~ 0
      ),
      RAW.D5.2.3.CNIN = CNIN
    ) %>%
    dplyr::select(iso3c, date, RAW.D5.2.3.CNIN, SPI.D5.2.3.CNIN) %>%
    dplyr::arrange(date, iso3c)
}

# --- 5.2.4 CPI base year -----------------------------------------------------
# Source: previous vintage + IMF data.
# Score: 1 for annual chain linking, 0.5 for base year in last 10 years,
# 0 otherwise.

#' Score the CPIBY indicator
#'
#' Mirrors the "cpiby" chunk. Starts from the previous vintage, then updates
#' with IMF data on annual chain linking / CPI reference period.
#'
#' @param params List of pipeline parameters.
#' @param grid   The country x year grid.
#' @return A tibble with iso3c, date, RAW.D5.2.4.CPIBY, SPI.D5.2.4.CPIBY.
#' @export
score_cpiby <- function(params, grid) {
  imf_codes <- read_imf_codes(params)
  imf_file <- params$imf_file

  # Previous vintage as starting point
  D5.2.4.CPIBY <- read_previous_vintage_d5(params) %>%
    dplyr::select(iso3c, date, RAW.D5.2.4.CPIBY, SPI.D5.2.4.CPIBY) %>%
    dplyr::arrange(date, iso3c) %>%
    dplyr::right_join(grid, by = c("iso3c", "date"))

  # --- IMF data --------------------------------------------------------------
  # COICOP weights last change
  D5.2.4.COICOP.WGT <- readxl::read_excel(
    path = file.path(params$raw_dir, "5.2_DISM", imf_file),
    sheet = "3. COICOP Month_Last Change",
    skip = 3
  ) %>%
    tibble::as_tibble(.name_repair = "universal") %>%
    dplyr::rename(
      IMF_code = Code,
      IMF_country = Country
    ) %>%
    dplyr::mutate(IMF_code = as.numeric(IMF_code)) %>%
    dplyr::left_join(imf_codes, by = "IMF_code")

  # CPI reference period
  D5.2.4.CPI.REF <- readxl::read_excel(
    path = file.path(params$raw_dir, "5.2_DISM", imf_file),
    sheet = "1. CPI Reference Period",
    skip = 1
  ) %>%
    tibble::as_tibble(.name_repair = "universal") %>%
    dplyr::rename(IMF_country = Country) %>%
    dplyr::left_join(D5.2.4.COICOP.WGT, by = "IMF_country")

  # Calculate annual chain linking / base year
  D5.2.4.CPIBY.IMF.RAW <- D5.2.4.CPI.REF %>%
    dplyr::filter(!is.na(iso3c)) %>%
    dplyr::mutate(
      CPI_ref_period = stringr::str_sub(Common.Reference.Period, 1, 4),
      CPI_ref_period = as.numeric(CPI_ref_period),
      CPI_weight_change = stringr::str_sub(last_change, 1, 4),
      CPI_weight_change = as.numeric(CPI_weight_change),
      iso3c = dplyr::if_else(iso3c == "KOS", "XKX", iso3c)
    ) %>%
    dplyr::mutate(
      RAW.D5.2.4.CPIBY.IMF = dplyr::if_else(
        (CPI_weight_change >= 2024 & CPI_ref_period <= 2024),
        "annual chained",
        as.character(CPI_ref_period),
        as.character(CPI_ref_period)
      )
    ) %>%
    dplyr::mutate(
      RAW.D5.2.4.CPIBY.IMF = dplyr::if_else(
        (iso3c == "AUS" | iso3c == "NZL"),
        "annual chained",
        as.character(RAW.D5.2.4.CPIBY.IMF),
        as.character(RAW.D5.2.4.CPIBY.IMF)
      )
    )

  # Score 2015:end_date
  D5.2.4.CPIBY.IMF <- purrr::map_dfr(2015:params$end_date, function(i) {
    D5.2.4.CPIBY.IMF.RAW %>%
      dplyr::mutate(date = i) %>%
      dplyr::mutate(
        SPI.D5.2.4.CPIBY.IMF = dplyr::case_when(
          RAW.D5.2.4.CPIBY.IMF == "annual chained" ~ 1,
          (date - as.numeric(RAW.D5.2.4.CPIBY.IMF)) <= 10 ~ 0.5,
          TRUE ~ 0
        )
      ) %>%
      dplyr::select(iso3c, date, RAW.D5.2.4.CPIBY.IMF, SPI.D5.2.4.CPIBY.IMF) %>%
      dplyr::arrange(date, iso3c)
  })

  # Update with IMF data when previous vintage value is missing
  D5.2.4.CPIBY %>%
    dplyr::full_join(D5.2.4.CPIBY.IMF, by = c("iso3c", "date")) %>%
    dplyr::mutate(
      SPI.D5.2.4.CPIBY = dplyr::if_else(
        is.na(SPI.D5.2.4.CPIBY),
        SPI.D5.2.4.CPIBY.IMF,
        SPI.D5.2.4.CPIBY
      )
    ) %>%
    dplyr::select(-SPI.D5.2.4.CPIBY.IMF)
}

# --- 5.2.5 Classification of household consumption ---------------------------
# Source: previous vintage + IMF COICOP data.
# Score: 1 for COICOP, 0 otherwise.

#' Score the HOUS indicator
#'
#' Mirrors the "hous" chunk. Starts from the previous vintage, then updates
#' with IMF COICOP data for 2021-2024.
#'
#' @param params List of pipeline parameters.
#' @param grid   The country x year grid.
#' @return A tibble with iso3c, date, RAW.D5.2.5.HOUS, SPI.D5.2.5.HOUS.
#' @export
score_hous <- function(params, grid) {
  imf_codes <- read_imf_codes(params)

  # Previous vintage as starting point
  D5.2.5.HOUS <- read_previous_vintage_d5(params) %>%
    dplyr::select(iso3c, date, RAW.D5.2.5.HOUS, SPI.D5.2.5.HOUS) %>%
    dplyr::arrange(date, iso3c) %>%
    dplyr::right_join(grid, by = c("iso3c", "date"))

  # --- IMF data: 2022 --------------------------------------------------------
  D5.2.5.HOUS.IMF.2022 <- readxl::read_excel(
    path = file.path(params$raw_dir, "5.2_DISM", "2022.10_Compiled Data for World Bank.xlsx"),
    sheet = "3. Household Consump Class",
    skip = 0
  ) %>%
    tibble::as_tibble(.name_repair = "universal") %>%
    dplyr::rename(IMF_code = Code, IMF_country = Country) %>%
    dplyr::mutate(
      SPI.D5.2.5.HOUS.IMF = dplyr::case_when(
        Status..as.of.October.2022 == "COICOP" ~ 1,
        Status..as.of.October.2022 == "COICOP." ~ 1,
        Status..as.of.October.2022 == "COICOP 2018" ~ 1,
        TRUE ~ 0
      ),
      RAW.D5.2.5.HOUS.IMF = Status..as.of.October.2022
    ) %>%
    dplyr::mutate(IMF_code = as.numeric(IMF_code)) %>%
    dplyr::left_join(imf_codes, by = "IMF_code") %>%
    dplyr::mutate(iso3c = dplyr::if_else(iso3c == "KOS", "XKX", iso3c)) %>%
    dplyr::select(iso3c, RAW.D5.2.5.HOUS.IMF, SPI.D5.2.5.HOUS.IMF)

  # --- IMF data: 2023 --------------------------------------------------------
  D5.2.5.HOUS.IMF.2023 <- readxl::read_excel(
    path = file.path(params$raw_dir, "5.2_DISM", "2024.02_Compiled Data for World Bank.xlsx"),
    sheet = "3. Household Consump Class",
    skip = 0
  ) %>%
    tibble::as_tibble(.name_repair = "universal") %>%
    dplyr::rename(IMF_code = Code, IMF_country = Country) %>%
    dplyr::mutate(
      SPI.D5.2.5.HOUS.IMF = dplyr::case_when(
        Status..as.of.January.2024 == "COICOP" ~ 1,
        Status..as.of.January.2024 == "COICOP." ~ 1,
        Status..as.of.January.2024 == "COICOP 2018" ~ 1,
        TRUE ~ 0
      ),
      RAW.D5.2.5.HOUS.IMF = Status..as.of.January.2024
    ) %>%
    dplyr::mutate(IMF_code = as.numeric(IMF_code)) %>%
    dplyr::left_join(imf_codes, by = "IMF_code") %>%
    dplyr::mutate(iso3c = dplyr::if_else(iso3c == "KOS", "XKX", iso3c)) %>%
    dplyr::select(iso3c, RAW.D5.2.5.HOUS.IMF, SPI.D5.2.5.HOUS.IMF)

  # --- IMF data: 2024 --------------------------------------------------------
  # The current vintage file comes from params$imf_file (see config/params.R).
  D5.2.5.HOUS.IMF.2024 <- readxl::read_excel(
    path = file.path(params$raw_dir, "5.2_DISM", params$imf_file),
    sheet = "2. Household Consump Class",
    skip = 1
  ) %>%
    tibble::as_tibble(.name_repair = "universal") %>%
    dplyr::rename(IMF_code = Code, IMF_country = Country) %>%
    dplyr::mutate(
      SPI.D5.2.5.HOUS.IMF = dplyr::case_when(
        Status == "COICOP" ~ 1,
        Status == "COICOP." ~ 1,
        Status == "COICOP 2018" ~ 1,
        TRUE ~ 0
      ),
      RAW.D5.2.5.HOUS.IMF = Status
    ) %>%
    dplyr::mutate(IMF_code = as.numeric(IMF_code)) %>%
    dplyr::left_join(imf_codes, by = "IMF_code") %>%
    dplyr::mutate(iso3c = dplyr::if_else(iso3c == "KOS", "XKX", iso3c)) %>%
    dplyr::select(iso3c, RAW.D5.2.5.HOUS.IMF, SPI.D5.2.5.HOUS.IMF)

  # Combine IMF data
  D5.2.5.HOUS.IMF <- D5.2.5.HOUS.IMF.2022 %>%
    dplyr::bind_rows(D5.2.5.HOUS.IMF.2022 %>% dplyr::mutate(date = 2021)) %>%
    dplyr::mutate(date = dplyr::if_else(!is.na(date), 2022, 2021)) %>%
    dplyr::bind_rows(D5.2.5.HOUS.IMF.2023 %>% dplyr::mutate(date = 2023)) %>%
    dplyr::bind_rows(D5.2.5.HOUS.IMF.2024 %>% dplyr::mutate(date = 2024)) %>%
    dplyr::filter(!is.na(iso3c))

  # Update with IMF data when previous vintage value is missing
  D5.2.5.HOUS %>%
    dplyr::full_join(D5.2.5.HOUS.IMF, by = c("iso3c", "date")) %>%
    dplyr::mutate(
      SPI.D5.2.5.HOUS = dplyr::if_else(
        is.na(SPI.D5.2.5.HOUS),
        SPI.D5.2.5.HOUS.IMF,
        SPI.D5.2.5.HOUS
      )
    ) %>%
    dplyr::select(-country, -SPI.D5.2.5.HOUS.IMF) %>%
    dplyr::arrange(date, iso3c)
}

# --- 5.2.6 Classification of status of employment ----------------------------
# Source: ILO data files.
# Score: 1 for ICSE-93 or NAICS, 0 otherwise.

#' Score the EMPL indicator
#'
#' Mirrors the "empl" chunk. Reads the base CSV plus yearly updates.
#'
#' @param params List of pipeline parameters.
#' @return A tibble with iso3c, date, RAW.D5.2.6.EMPL, SPI.D5.2.6.EMPL.
#' @export
score_empl <- function(params) {
  parts <- .read_base_plus_yearly(params, "D5.2.6.EMPL")

  # The base + 2020 files use the EMPL column; 2022+ files use the ISCE
  # column (different schema -- see the original Rmd "empl" chunk). Split
  # the yearly files by schema so each is scored with the right column.
  has_empl <- purrr::map_lgl(parts$yearly, ~ "EMPL" %in% names(.x))
  empl_files <- parts$yearly[has_empl]
  isce_files <- parts$yearly[!has_empl]

  # Score the EMPL-schema files (base + 2020).
  out <- parts$base
  for (f in empl_files) {
    out <- out %>% dplyr::bind_rows(f)
  }
  out <- out %>%
    dplyr::mutate(
      SPI.D5.2.6.EMPL = dplyr::case_when(
        EMPL == "ICSE-93" | EMPL == "NAICS" ~ 1,
        TRUE ~ 0
      )
    )

  # Bind the ISCE-schema files (2022+), scoring from the ISCE column.
  for (f in isce_files) {
    out <- out %>%
      dplyr::bind_rows(f %>% dplyr::mutate(SPI.D5.2.6.EMPL = as.numeric(ISCE)))
  }

  out %>%
    dplyr::mutate(RAW.D5.2.6.EMPL = EMPL) %>%
    dplyr::select(iso3c, date, RAW.D5.2.6.EMPL, SPI.D5.2.6.EMPL) %>%
    dplyr::arrange(date, iso3c)
}

# --- 5.2.7 Central government accounting status ------------------------------
# Source: previous vintage + IMF data.
# Score: 1 for noncash recording basis (AC), 0.5 for cash (CA), 0 otherwise.

#' Score the CGOV indicator
#'
#' Mirrors the "cgov" chunk. Starts from the previous vintage, updates with
#' IMF data for 2021-2024, and carries forward missing values.
#'
#' @param params List of pipeline parameters.
#' @param grid   The country x year grid.
#' @return A tibble with iso3c, date, RAW.D5.2.7.CGOV, SPI.D5.2.7.CGOV.
#' @export
score_cgov <- function(params, grid) {
  imf_codes <- read_imf_codes(params)

  # Previous vintage as starting point
  D5.2.7.CGOV <- read_previous_vintage_d5(params) %>%
    dplyr::select(iso3c, date, RAW.D5.2.7.CGOV, SPI.D5.2.7.CGOV) %>%
    dplyr::arrange(date, iso3c) %>%
    dplyr::right_join(grid, by = c("iso3c", "date"))

  # --- IMF data: 2021 and 2022 (same file) -----------------------------------
  read_cgov_2021_2022 <- function(file, sheet, skip) {
    readxl::read_excel(path = file.path(params$raw_dir, "5.2_DISM", file), sheet = sheet, skip = skip) %>%
      tibble::as_tibble(.name_repair = "universal") %>%
      dplyr::rename(IMF_code = Code, IMF_country = Country) %>%
      dplyr::mutate(
        SPI.D5.2.7.CGOV.IMF = dplyr::case_when(
          General.Government..consolidated. == "AC" ~ 1,
          General.Government..consolidated. == "CA" ~ 0.5,
          General.Government..consolidated. == "NA" ~ as.numeric(NA),
          TRUE ~ 0
        ),
        RAW.D5.2.7.CGOV.IMF = General.Government..consolidated.
      ) %>%
      dplyr::mutate(IMF_code = as.numeric(IMF_code)) %>%
      dplyr::left_join(imf_codes, by = "IMF_code") %>%
      dplyr::mutate(iso3c = dplyr::if_else(iso3c == "KOS", "XKX", iso3c)) %>%
      dplyr::select(iso3c, RAW.D5.2.7.CGOV.IMF, SPI.D5.2.7.CGOV.IMF)
  }

  D5.2.7.CGOV.IMF.2021 <- read_cgov_2021_2022("2022.10_Compiled Data for World Bank.xlsx", "5. Cntrl Gct Acct Status", 9) %>%
    dplyr::mutate(date = 2021)
  D5.2.7.CGOV.IMF.2022 <- read_cgov_2021_2022("2022.10_Compiled Data for World Bank.xlsx", "5. Cntrl Gct Acct Status", 9) %>%
    dplyr::mutate(date = 2022)
  D5.2.7.CGOV.IMF.2023 <- read_cgov_2021_2022("2024.02_Compiled Data for World Bank.xlsx", "5. Cntrl Gct Acct Status", 9) %>%
    dplyr::mutate(date = 2023)
  # The current vintage file comes from params$imf_file (see config/params.R).
  D5.2.7.CGOV.IMF.2024 <- read_cgov_2021_2022(params$imf_file, "4. Cntrl Gct Acct Status", 9) %>%
    dplyr::mutate(date = 2024)

  D5.2.7.CGOV.IMF <- dplyr::bind_rows(
    D5.2.7.CGOV.IMF.2021,
    D5.2.7.CGOV.IMF.2022,
    D5.2.7.CGOV.IMF.2023,
    D5.2.7.CGOV.IMF.2024
  ) %>%
    dplyr::filter(!is.na(iso3c))

  # Update with IMF data when previous vintage value is missing, then carry forward
  D5.2.7.CGOV %>%
    dplyr::full_join(D5.2.7.CGOV.IMF, by = c("iso3c", "date")) %>%
    dplyr::mutate(
      SPI.D5.2.7.CGOV = dplyr::if_else(
        is.na(SPI.D5.2.7.CGOV),
        SPI.D5.2.7.CGOV.IMF,
        SPI.D5.2.7.CGOV
      )
    ) %>%
    dplyr::select(-SPI.D5.2.7.CGOV.IMF) %>%
    dplyr::arrange(date, iso3c) %>%
    dplyr::group_by(iso3c) %>%
    dplyr::mutate(SPI.D5.2.7.CGOV = zoo::na.locf(SPI.D5.2.7.CGOV, na.rm = FALSE)) %>%
    dplyr::ungroup() %>%
    dplyr::filter(!is.na(SPI.D5.2.7.CGOV))
}

# --- 5.2.8 Compilation of government finance statistics ----------------------
# Source: WDI metadata files.
# Score: 1 for GFSM2014/ESA2010, 0.5 for GFSM2001, 0 otherwise.

#' Score the FINA indicator
#'
#' Mirrors the "fina" chunk. Reads the base CSV plus yearly updates.
#'
#' @param params List of pipeline parameters.
#' @return A tibble with iso3c, date, RAW.D5.2.8.FINA, SPI.D5.2.8.FINA.
#' @export
score_fina <- function(params) {
  parts <- .read_base_plus_yearly(params, "D5.2.8.FINA")

  # The 2022+ files use "Code" instead of "iso3c" (different schema -- see
  # the original Rmd "fina" chunk). Bind incrementally (as the original
  # Rmd does) so vctrs can coerce the differing auxiliary column types.
  out <- parts$base
  for (f in parts$yearly) {
    if ("Code" %in% names(f)) {
      out <- out %>% dplyr::bind_rows(f %>% dplyr::mutate(iso3c = Code))
    } else {
      out <- out %>% dplyr::bind_rows(f)
    }
  }

  out %>%
    dplyr::mutate(
      SPI.D5.2.8.FINA = dplyr::case_when(
        FINA == "2014" | FINA == "ESA 2010" ~ 1,
        FINA == "2001" ~ 0.5,
        TRUE ~ 0
      ),
      RAW.D5.2.8.FINA = FINA
    ) %>%
    dplyr::select(iso3c, date, RAW.D5.2.8.FINA, SPI.D5.2.8.FINA) %>%
    dplyr::arrange(date, iso3c)
}

# --- 5.2.9 Compilation of monetary and financial statistics ------------------
# Source: previous vintage + IMF data.
# Score: 1 for MFSM 2000 / Compilation Guide 2008/2016, 0 otherwise.

#' Score the MONY indicator
#'
#' Mirrors the "mony" chunk. Starts from the previous vintage, updates with
#' IMF data for 2020-2024.
#'
#' @param params List of pipeline parameters.
#' @param grid   The country x year grid.
#' @return A tibble with iso3c, date, RAW.D5.2.9.MONY, SPI.D5.2.9.MONY.
#' @export
score_mony <- function(params, grid) {
  imf_codes <- read_imf_codes(params)

  # Previous vintage as starting point
  D5.2.9.MONY <- read_previous_vintage_d5(params) %>%
    dplyr::select(iso3c, date, RAW.D5.2.9.MONY, SPI.D5.2.9.MONY) %>%
    dplyr::arrange(date, iso3c) %>%
    dplyr::right_join(grid, by = c("iso3c", "date"))

  # --- IMF data: 2020 --------------------------------------------------------
  D5.2.9.MONY.IMF <- readxl::read_excel(
    path = file.path(params$raw_dir, "5.2_DISM", "2020.11.04_Compiled Data for World Bank.xlsx"),
    sheet = "7. MFS Compilation status",
    skip = 0
  ) %>%
    tibble::as_tibble(.name_repair = "universal") %>%
    dplyr::rename(IMF_code = Code, IMF_country = Country) %>%
    dplyr::mutate(
      SPI.D5.2.9.MONY.IMF = dplyr::case_when(
        grepl("MFSM 2000", Monetary.and.Financial.Statistics..MFS..Reporting.Status) ~ 1,
        TRUE ~ 0
      ),
      RAW.D5.2.9.MONY.IMF = Monetary.and.Financial.Statistics..MFS..Reporting.Status
    ) %>%
    dplyr::mutate(IMF_code = as.numeric(IMF_code)) %>%
    dplyr::left_join(imf_codes, by = "IMF_code") %>%
    dplyr::select(iso3c, RAW.D5.2.9.MONY.IMF, SPI.D5.2.9.MONY.IMF) %>%
    dplyr::mutate(date = 2020)

  # --- IMF data: 2022 --------------------------------------------------------
  D5.2.9.MONY.IMF.2022 <- readxl::read_excel(
    path = file.path(params$raw_dir, "5.2_DISM", "2022.10_Compiled Data for World Bank.xlsx"),
    sheet = "7. MFS Compilation status",
    skip = 0
  ) %>%
    tibble::as_tibble(.name_repair = "universal") %>%
    dplyr::rename(IMF_code = Code, IMF_country = Country) %>%
    dplyr::mutate(
      SPI.D5.2.9.MONY.IMF = dplyr::case_when(
        grepl("MFSM 2000", Monetary.and.Financial.Statistics..MFS..Reporting.Status..as.of.October.2022) ~ 1,
        TRUE ~ 0
      ),
      RAW.D5.2.9.MONY.IMF = Monetary.and.Financial.Statistics..MFS..Reporting.Status..as.of.October.2022,
      IMF_code = as.numeric(IMF_code)
    ) %>%
    dplyr::left_join(imf_codes, by = "IMF_code") %>%
    dplyr::select(iso3c, RAW.D5.2.9.MONY.IMF, SPI.D5.2.9.MONY.IMF)

  # --- IMF data: 2023 --------------------------------------------------------
  D5.2.9.MONY.IMF.2023 <- readxl::read_excel(
    path = file.path(params$raw_dir, "5.2_DISM", "2024.02_Compiled Data for World Bank.xlsx"),
    sheet = "7. MFS Compilation status",
    skip = 0
  ) %>%
    tibble::as_tibble(.name_repair = "universal") %>%
    dplyr::rename(IMF_code = Code, IMF_country = Country) %>%
    dplyr::mutate(
      SPI.D5.2.9.MONY.IMF = dplyr::case_when(
        grepl("MFSM 2000", Monetary.and.Financial.Statistics..MFS..Reporting.Status..as.of.January.2024) ~ 1,
        TRUE ~ 0
      ),
      RAW.D5.2.9.MONY.IMF = Monetary.and.Financial.Statistics..MFS..Reporting.Status..as.of.January.2024
    ) %>%
    dplyr::mutate(IMF_code = as.numeric(IMF_code)) %>%
    dplyr::left_join(imf_codes, by = "IMF_code") %>%
    dplyr::select(iso3c, RAW.D5.2.9.MONY.IMF, SPI.D5.2.9.MONY.IMF)

  # --- IMF data: 2024 --------------------------------------------------------
  # The current vintage file comes from params$imf_file (see config/params.R).
  D5.2.9.MONY.IMF.2024 <- readxl::read_excel(
    path = file.path(params$raw_dir, "5.2_DISM", params$imf_file),
    sheet = "6. MFS Compilation status",
    skip = 1
  ) %>%
    tibble::as_tibble(.name_repair = "universal") %>%
    dplyr::rename(IMF_code = Code, IMF_country = Country) %>%
    dplyr::mutate(
      SPI.D5.2.9.MONY.IMF = dplyr::case_when(
        grepl("MFSM 2000", Monetary.and.Financial.Statistics..MFS..Reporting.Status) ~ 1,
        TRUE ~ 0
      ),
      RAW.D5.2.9.MONY.IMF = Monetary.and.Financial.Statistics..MFS..Reporting.Status
    ) %>%
    dplyr::mutate(IMF_code = as.numeric(IMF_code)) %>%
    dplyr::left_join(imf_codes, by = "IMF_code") %>%
    dplyr::select(iso3c, RAW.D5.2.9.MONY.IMF, SPI.D5.2.9.MONY.IMF)

  # Combine IMF data
  D5.2.9.MONY.IMF <- D5.2.9.MONY.IMF %>%
    dplyr::bind_rows(D5.2.9.MONY.IMF.2022 %>% dplyr::mutate(date = 2021)) %>%
    dplyr::bind_rows(D5.2.9.MONY.IMF.2022 %>% dplyr::mutate(date = 2022)) %>%
    dplyr::bind_rows(D5.2.9.MONY.IMF.2023 %>% dplyr::mutate(date = 2023)) %>%
    dplyr::bind_rows(D5.2.9.MONY.IMF.2024 %>% dplyr::mutate(date = 2024)) %>%
    dplyr::filter(!is.na(iso3c))

  # Update with IMF data when previous vintage value is missing
  D5.2.9.MONY %>%
    dplyr::full_join(D5.2.9.MONY.IMF, by = c("iso3c", "date")) %>%
    dplyr::mutate(
      SPI.D5.2.9.MONY = dplyr::if_else(
        is.na(SPI.D5.2.9.MONY),
        SPI.D5.2.9.MONY.IMF,
        SPI.D5.2.9.MONY,
        0
      )
    ) %>%
    dplyr::mutate(
      SPI.D5.2.9.MONY = dplyr::if_else(
        iso3c == "SAU" & date == 2023,
        SPI.D5.2.9.MONY.IMF,
        SPI.D5.2.9.MONY,
        0
      )
    ) %>%
    dplyr::select(-SPI.D5.2.9.MONY.IMF) %>%
    dplyr::arrange(date, iso3c)
}

# --- 5.2.10 Business process -------------------------------------------------
# Source: GSBPM survey data.
# Score: 1 for GSBPM in use, 0 otherwise.

#' Score the GSBP indicator
#'
#' Mirrors the "gsbp" chunk. Reads the base CSV plus yearly updates.
#'
#' @param params List of pipeline parameters.
#' @return A tibble with iso3c, date, RAW.D5.2.10.GSBP, SPI.D5.2.10.GSBP.
#' @export
score_gsbp <- function(params) {
  parts <- .read_base_plus_yearly(params, "D5.2.10.GSBP")

  out <- parts$base
  for (f in parts$yearly) {
    out <- out %>% dplyr::bind_rows(f)
  }

  out %>%
    dplyr::mutate(
      SPI.D5.2.10.GSBP = dplyr::case_when(
        stringr::str_to_lower(GSBP) == "yes" ~ 1,
        TRUE ~ 0
      ),
      RAW.D5.2.10.GSBP = GSBP
    ) %>%
    dplyr::select(iso3c, date, RAW.D5.2.10.GSBP, SPI.D5.2.10.GSBP) %>%
    dplyr::arrange(date, iso3c)
}

# =============================================================================
# 5.5 Finance
# =============================================================================
# Source: Paris21/UNSD SDG indicator 17.18.3 (national statistical plan fully
# funded and under implementation).
# Score: 1 if fully funded, 0 otherwise.

#' Score the DIFI indicator
#'
#' Mirrors the "finance" chunk.
#'
#' @param params List of pipeline parameters.
#' @param grid   The country x year grid.
#' @return A tibble with iso3c, date, RAW.D5.5.DIFI, SPI.D5.5.DIFI.
#' @export
score_difi <- function(params, grid) {
  readr::read_csv(file.path(params$raw_dir, "5.5_DIFI", "SG_STT_NSDSFND.csv")) %>%
    dplyr::select(iso3c, date, Value) %>%
    dplyr::right_join(grid, by = c("iso3c", "date")) %>%
    dplyr::mutate(
      RAW.D5.5.DIFI = dplyr::if_else((is.na(Value) | Value == "NaN"), as.numeric(NA), as.numeric(Value)),
      SPI.D5.5.DIFI = dplyr::if_else((is.na(Value) | Value == "NaN"), as.numeric(NA), as.numeric(Value))
    ) %>%
    dplyr::select(-Value)
}

# =============================================================================
# Combine all D5 indicators
# =============================================================================

#' Combine all D5 indicators
#'
#' Joins legislation, standards (10), and finance onto the country grid.
#'
#' @param params List of pipeline parameters.
#' @param grid   The country x year grid.
#' @return A tibble with iso3c, date, and the D5 indicator columns.
#' @export
combine_dim5 <- function(params, grid) {
  wdi_metadata <- read_wdi_metadata(params)

  D5.1 <- score_legislation(params, grid)
  D5.2.1 <- score_snau(wdi_metadata)
  D5.2.2 <- score_naby(params)
  D5.2.3 <- score_cnin(params)
  D5.2.4 <- score_cpiby(params, grid)
  D5.2.5 <- score_hous(params, grid)
  D5.2.6 <- score_empl(params)
  D5.2.7 <- score_cgov(params, grid)
  D5.2.8 <- score_fina(params)
  D5.2.9 <- score_mony(params, grid)
  D5.2.10 <- score_gsbp(params)
  D5.5 <- score_difi(params, grid)

  # Join all onto the grid (default joins, matching the original Rmd)
  grid %>%
    dplyr::left_join(D5.1, by = c("iso3c", "date")) %>%
    dplyr::left_join(D5.2.1, by = c("iso3c", "date")) %>%
    dplyr::left_join(D5.2.2, by = c("iso3c", "date")) %>%
    dplyr::left_join(D5.2.3, by = c("iso3c", "date")) %>%
    dplyr::left_join(D5.2.4, by = c("iso3c", "date")) %>%
    dplyr::left_join(D5.2.5, by = c("iso3c", "date")) %>%
    dplyr::left_join(D5.2.6, by = c("iso3c", "date")) %>%
    dplyr::left_join(D5.2.7, by = c("iso3c", "date")) %>%
    dplyr::left_join(D5.2.8, by = c("iso3c", "date")) %>%
    dplyr::left_join(D5.2.9, by = c("iso3c", "date")) %>%
    dplyr::left_join(D5.2.10, by = c("iso3c", "date")) %>%
    dplyr::left_join(D5.5, by = c("iso3c", "date"))
}
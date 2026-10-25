# =============================================================================
# Dimension 2: Data Services
# =============================================================================
# Ported from the "idds", "online_access", and "nada" chunks of
# 01-SPI_data_prep.Rmd.
#
# Three indicators:
#   1. SPI.D2.1.GDDS -- SDDS/e-GDDS data dissemination standard (IMF/WDI)
#   2. SPI.D2.2.*     -- ODIN online access openness scores
#   3. SPI.D2.4.NADA  -- NADA microdata catalog availability
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
# 1. SPI.D2.1.GDDS -- SDDS/e-GDDS data dissemination standard
# =============================================================================
# Source: WDI metadata "IMF data dissemination standard" + archived SCI data.
# Scoring:
#   1 point  -- SDDS+ or SDDS subscription
#   0.5 point -- e-GDDS subscription
#   0 points -- otherwise

#' Score the SDDS/e-GDDS indicator
#'
#' Combines the WDI metadata dissemination standard with the archived SCI
#' data (for earlier years).
#'
#' @param wdi_metadata Tibble from read_wdi_metadata().
#' @param params       List of pipeline parameters.
#' @param grid         The country x year grid.
#' @return A tibble with iso3c, date, RAW.D2.1.GDDS, SPI.D2.1.GDDS.
#' @export
score_sdds <- function(wdi_metadata, params, grid) {
  # --- Archived SCI data (for years 2004-2015) -------------------------------
  # The SCI archived data has SDDS subscription info for earlier years.
  # NOTE: pivot only YR2004:YR2015 -- the SCI file also contains YR2016:YR2020
  # but the original pipeline deliberately stops at 2015 (the WDI metadata
  # covers 2016+). Pivoting the later years would create duplicate rows.
  sci_path <- file.path(params$raw_dir, "2.1_DSDR", "SCI_archived_data.csv")
  D2.1_DSDR_sci <- readr::read_csv(sci_path) %>%
    tidyr::pivot_longer(cols = YR2004:YR2015, names_to = "date", values_to = "value") %>%
    dplyr::filter(`Series Code` == "5.21.01.01.sdds") %>%
    dplyr::transmute(
      iso3c = `Country Code`,
      date = as.numeric(stringr::str_remove_all(date, "YR")),
      SDDS = if_else(is.na(value), 0, as.numeric(value))
    ) %>%
    dplyr::left_join(grid, by = c("iso3c", "date")) %>%
    dplyr::filter(!is.na(income_level)) %>%
    dplyr::select(iso3c, date, SDDS)

  # --- WDI metadata dissemination standard -----------------------------------
  df <- wdi_metadata %>%
    dplyr::filter(!is.na(Income.Group))  # keep just countries (drop aggregations)

  D2.1_DSDR <- df %>%
    dplyr::mutate(
      iso3c = Code,
      country = Table.Name
    ) %>%
    dplyr::select(iso3c, date, IMF.data.dissemination.standard) %>%
    dplyr::mutate(IDDS = IMF.data.dissemination.standard) %>%
    dplyr::mutate(SPI.D2.1.GDDS = dplyr::case_when(
      IDDS == "Special Data Dissemination Standard Plus (SDDS+)" |
        IDDS == "Special Data Dissemination Standard Plus (SDDS Plus)" |
        IDDS == "Special Data Dissemination Standard (SDDS)" ~ 1,
      IDDS == "Enhanced General Data Dissemination System (e-GDDS)" ~ 0.5,
      TRUE ~ 0
    ),
    SDDS = dplyr::case_when(
      IDDS == "Special Data Dissemination Standard (SDDS)" ~ 1,
      TRUE ~ 0
    )
    ) %>%
    dplyr::bind_rows(D2.1_DSDR_sci) %>%
    dplyr::rename(RAW.D2.1.GDDS = IDDS) %>%
    dplyr::select(iso3c, date, RAW.D2.1.GDDS, SPI.D2.1.GDDS) %>%
    dplyr::left_join(params$country_metadata, by = "iso3c")

  D2.1_DSDR
}

# =============================================================================
# 2. SPI.D2.2.* -- ODIN online access openness scores
# =============================================================================
# Source: Open Data Watch ODIN. The Openness subscore (0-100) is divided by
# 100 to get a 0-1 score. Five components: Machine.readable, Non.proprietary,
# Download.options, Metadata.available, Terms.of.use.

# ODIN columns read by SPI.D2.2 (score_odin) and SPI.D4.3 (score_geospatial),
# named as after readr's universal name repair.
odin_required_columns <- c(
  "Year", "Country.Code", "Data.categories",
  "Indicator.coverage.and.disaggregation", "Data.available.last.5.years",
  "Data.available.last.10.years", "First.administrative.level",
  "Second.administrative.level", "Coverage.subscore", "Machine.readable",
  "Non.proprietary", "Download.options", "Metadata.available",
  "Terms.of.use", "Openness.subscore", "Overall.score"
)

#' List the ODIN files read for 2015 to the reference year
#'
#' The paths are a file target in the estimation pipeline, so replacing
#' ODIN_<end_date>.csv (the December swap) invalidates only the ODIN targets
#' and their downstream outputs.
#'
#' @param params List of pipeline parameters.
#' @return Character vector of ODIN_<year>.csv paths.
#' @export
odin_file_paths <- function(params) {
  paths <- file.path(
    params$raw_dir,
    "2.2_DSOA",
    sprintf("ODIN_%d.csv", 2015:params$end_date)
  )
  missing <- paths[!file.exists(paths)]
  if (length(missing) > 0L) {
    stop("ODIN FILE NOT FOUND: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  paths
}

odin_country_exclusions <- function(params) {
  path <- params$odin_country_exclusions_file
  if (is.null(path) || is.na(path) || !nzchar(path)) {
    path <- here::here("config", "odin_country_exclusions.csv")
  }
  if (!file.exists(path)) {
    stop("ODIN COUNTRY EXCLUSIONS FILE NOT FOUND: ", path, call. = FALSE)
  }
  exclusions <- readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    progress = FALSE
  )
  required <- c("iso3c", "country", "category", "reason")
  missing <- setdiff(required, names(exclusions))
  if (length(missing) > 0L) {
    stop(
      "ODIN COUNTRY EXCLUSIONS SCHEMA MISMATCH: missing ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  exclusions <- exclusions[required]
  if (nrow(exclusions) == 0L ||
      anyNA(exclusions$iso3c) ||
      any(!nzchar(trimws(exclusions$iso3c))) ||
      anyDuplicated(exclusions$iso3c) > 0L ||
      any(exclusions$category != "outside_country_universe")) {
    stop("ODIN COUNTRY EXCLUSIONS ARE INVALID: ", path, call. = FALSE)
  }
  exclusions
}

odin_country_crosswalk <- function(params) {
  path <- params$odin_country_crosswalk_file
  if (is.null(path) || is.na(path) || !nzchar(path)) {
    path <- here::here("config", "odin_country_crosswalk.csv")
  }
  if (!file.exists(path)) {
    stop("ODIN COUNTRY CROSSWALK FILE NOT FOUND: ", path, call. = FALSE)
  }
  crosswalk <- readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    progress = FALSE
  )
  required <- c("source_code", "iso3c", "country", "reason")
  missing <- setdiff(required, names(crosswalk))
  if (length(missing) > 0L) {
    stop(
      "ODIN COUNTRY CROSSWALK SCHEMA MISMATCH: missing ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  crosswalk <- crosswalk[required]
  if (nrow(crosswalk) == 0L ||
      anyNA(crosswalk[c("source_code", "iso3c")]) ||
      any(!nzchar(trimws(crosswalk$source_code))) ||
      any(!nzchar(trimws(crosswalk$iso3c))) ||
      anyDuplicated(crosswalk$source_code) > 0L) {
    stop("ODIN COUNTRY CROSSWALK IS INVALID: ", path, call. = FALSE)
  }
  crosswalk
}

#' Read and combine the ODIN openness data
#'
#' Reads ODIN_<year>.csv for 2015:end_date, keeps the "All Categories" rows,
#' and binds them together. Every file must contain all the columns that
#' SPI.D2.2 and SPI.D4.3 read (`odin_required_columns`, names after readr's
#' universal repair). The same data feed score_odin() and score_geospatial().
#'
#' @param params List of pipeline parameters.
#' @param paths ODIN file paths (default: odin_file_paths(params)).
#' @return A tibble of ODIN openness scores.
#' @export
read_odin_data <- function(params, paths = odin_file_paths(params)) {
  exclusions <- odin_country_exclusions(params)
  crosswalk <- odin_country_crosswalk(params)
  numeric_columns <- c(
    "Indicator.coverage.and.disaggregation",
    "Data.available.last.5.years",
    "Data.available.last.10.years",
    "First.administrative.level",
    "Second.administrative.level",
    "Coverage.subscore",
    "Machine.readable",
    "Non.proprietary",
    "Download.options",
    "Metadata.available",
    "Terms.of.use",
    "Openness.subscore",
    "Overall.score"
  )
  purrr::map_dfr(paths, function(file_path) {
    i <- as.integer(sub("^ODIN_([0-9]{4})[.]csv$", "\\1", basename(file_path)))
    data <- readr::read_csv(file_path) %>%
      tibble::as_tibble(.name_repair = "universal")
    missing <- setdiff(odin_required_columns, names(data))
    if (length(missing) > 0L) {
      stop(
        sprintf(
          "ODIN SCHEMA MISMATCH in '%s': missing column(s) %s",
          basename(file_path),
          paste(missing, collapse = ", ")
        ),
        call. = FALSE
      )
    }
    data <- data %>%
      dplyr::mutate(date = i) %>%
      dplyr::filter(Data.categories %in% c("All Categories", "All categories"))
    data <- dplyr::filter(data, !Country.Code %in% exclusions$iso3c)
    mapped <- match(data$Country.Code, crosswalk$source_code)
    data$Country.Code[!is.na(mapped)] <- crosswalk$iso3c[mapped[!is.na(mapped)]]

    for (column in numeric_columns) {
      raw <- as.character(data[[column]])
      numeric <- suppressWarnings(as.numeric(raw))
      allowed_missing <- is.na(raw) | !nzchar(trimws(raw)) | trimws(raw) %in% c("-", "NA", "N/A")
      invalid <- !allowed_missing & is.na(numeric)
      if (any(invalid)) {
        stop(
          sprintf(
            "ODIN NUMERIC VALUE INVALID in '%s', column '%s': %s",
            basename(file_path),
            column,
            paste(utils::head(unique(raw[invalid]), 5), collapse = ", ")
          ),
          call. = FALSE
        )
      }
      data[[column]] <- numeric
    }

    if (anyDuplicated(data[c("Country.Code", "date")]) > 0L) {
      stop(
        sprintf("ODIN DUPLICATE COUNTRY-YEAR in '%s'", basename(file_path)),
        call. = FALSE
      )
    }
    if (!is.null(params$country_metadata) && nrow(params$country_metadata) > 0L) {
      unknown <- setdiff(unique(data$Country.Code), params$country_metadata$iso3c)
      if (length(unknown) > 0L) {
        stop(
          "ODIN UNKNOWN COUNTRY CODE(S): ",
          paste(sort(unknown), collapse = ", "),
          call. = FALSE
        )
      }
    }
    dplyr::select(data, -Year)
  })
}

#' Score the ODIN online access indicator
#'
#' Selects the openness components, joins onto the country grid, fills
#' missing with 0, and produces both RAW (0-100) and SPI (0-1) versions.
#'
#' @param odin_data Tibble from read_odin_data().
#' @param params    List of pipeline parameters.
#' @return A tibble with iso3c, date, RAW.D2.2.* and SPI.D2.2.* columns.
#' @export
score_odin <- function(odin_data, params) {
  openness_df <- odin_data %>%
    dplyr::select(
      Country.Code,
      date,
      Machine.readable,
      Non.proprietary,
      Download.options,
      Metadata.available,
      Terms.of.use,
      Openness.subscore
    ) %>%
    dplyr::rename(iso3c = Country.Code) %>%
    dplyr::group_by(iso3c) %>%
    dplyr::right_join(params$country_metadata, by = "iso3c") %>%
    dplyr::mutate(dplyr::across(
      c(
        "Machine.readable",
        "Non.proprietary",
        "Download.options",
        "Metadata.available",
        "Terms.of.use",
        "Openness.subscore"
      ),
      ~ if_else(is.na(.), 0, .)
    ))

  # RAW versions (0-100 scale)
  openness_df_temp1 <- openness_df %>%
    dplyr::rename_with(
      ~ paste("RAW.D2.2", ., sep = "."),
      .cols = c(
        "Machine.readable",
        "Non.proprietary",
        "Download.options",
        "Metadata.available",
        "Terms.of.use",
        "Openness.subscore"
      )
    )

  # SPI versions (0-1 scale, divide by 100)
  openness_df_temp2 <- openness_df %>%
    dplyr::mutate(dplyr::across(
      c(
        "Machine.readable",
        "Non.proprietary",
        "Download.options",
        "Metadata.available",
        "Terms.of.use",
        "Openness.subscore"
      ),
      ~ ./100
    )) %>%
    dplyr::rename_with(
      ~ paste("SPI.D2.2", ., sep = "."),
      .cols = c(
        "Machine.readable",
        "Non.proprietary",
        "Download.options",
        "Metadata.available",
        "Terms.of.use",
        "Openness.subscore"
      )
    )

  openness_df_temp1 %>%
    dplyr::left_join(openness_df_temp2, by = c("iso3c", "date"))
}

# =============================================================================
# 3. SPI.D2.4.NADA -- NADA microdata catalog availability
# =============================================================================
# Source: NSO websites (manually collected).
# Scoring:
#   1 point  -- NADA catalog available
#   0 points -- otherwise

#' Read and score the NADA indicator
#'
#' Reads the D2.4.NADA csv files for each year and combines them.
#'
#' The NADA files are versioned by vintage year:
#'   D2.4.NADA.csv        -- base file (covers the earliest years, has its
#'                            own date column)
#'   D2.4.NADA.<YEAR>.csv -- per-year files (e.g. D2.4.NADA.2024.csv)
#'
#' Historical quirk preserved from the original Rmd: the per-year files'
#' own date columns are IGNORED and overwritten with the loop year, and the
#' 2022 file is used for BOTH 2021 and 2022 (there is no
#' D2.4.NADA.2021.csv). When a new vintage is added, the technical lead
#' saves the new year's file as D2.4.NADA.<end_date>.csv and the loop picks
#' it up automatically.
#'
#' @param params List of pipeline parameters.
#' @return A tibble with iso3c, date, RAW.D2.4.NADA, RAW.D2.4.NADA_text,
#'   SPI.D2.4.NADA.
#' @export
score_nada <- function(params) {
  end_date <- params$end_date
  nada_dir <- file.path(params$raw_dir, "2.4_DSDS")

  # Base file (covers the earliest years, has its own date column).
  D2.4_NADA <- readr::read_csv(file.path(nada_dir, "D2.4.NADA.csv"))

  # Per-year files. The per-year files' own date columns are overwritten
  # with the loop year (matching the original Rmd). The 2021-from-2022
  # quirk is preserved: when the 2022 file exists, it is bound twice
  # (date = 2021 and date = 2022).
  for (y in 2020:end_date) {
    file_path <- file.path(nada_dir, sprintf("D2.4.NADA.%d.csv", y))
    if (!file.exists(file_path)) {
      # Historical years may be missing (e.g. there is no 2021 file -- the
      # 2022 file provides the 2021 values). But the CURRENT vintage file
      # is required -- fail loudly if it is missing (R8).
      if (y == end_date) {
        stop(
          sprintf("NADA FILE NOT FOUND: %s\n", file_path),
          "\nRun the NADA check script to collect the data:",
          "  02_programs/misc_scripts/nada_check.R",
          "This checks national statistical office websites for NADA",
          "installations. Save the result as D2.4.NADA.<YEAR>.csv in",
          "01_raw_data/2.4_DSDS/.",
          call. = FALSE
        )
      }
      next
    }
    nada_y <- readr::read_csv(file_path)
    D2.4_NADA <- D2.4_NADA %>%
      dplyr::bind_rows(nada_y %>% dplyr::mutate(date = y))
    # Historical quirk: the 2022 file also provides the 2021 values.
    if (y == 2022) {
      D2.4_NADA <- D2.4_NADA %>%
        dplyr::bind_rows(nada_y %>% dplyr::mutate(date = 2021))
    }
  }

  D2.4_NADA <- D2.4_NADA %>%
    dplyr::mutate(SPI.D2.4.NADA = dplyr::case_when(
      NADA == 1 ~ 1,
      NADA == 0 ~ 0,
      TRUE ~ 0
    )) %>%
    dplyr::rename(
      RAW.D2.4.NADA = NADA,
      RAW.D2.4.NADA_text = NADA_text
    ) %>%
    dplyr::select(iso3c, date, RAW.D2.4.NADA, RAW.D2.4.NADA_text, SPI.D2.4.NADA) %>%
    dplyr::arrange(date, iso3c)

  D2.4_NADA
}

# =============================================================================
# Combine all D2 indicators
# =============================================================================

#' Combine the D2 indicators into one table
#'
#' Joins SDDS, ODIN, and NADA onto the country grid.
#'
#' @param params List of pipeline parameters.
#' @param grid   The country x year grid.
#' @param odin_data Tibble from read_odin_data().
#' @return A tibble with iso3c, date, and the D2 indicator columns.
#' @export
combine_dim2 <- function(params, grid, odin_data = read_odin_data(params)) {
  combine_dim2_parts(
    combine_dim2_core(params, grid),
    score_odin(odin_data, params),
    grid
  )
}

#' Score the D2 indicators that do not use ODIN (SDDS and NADA)
#'
#' @param params List of pipeline parameters.
#' @param grid   The country x year grid.
#' @return A list with the `sdds` and `nada` score tables.
#' @export
combine_dim2_core <- function(params, grid) {
  wdi_metadata <- read_wdi_metadata(params)
  list(
    sdds = score_sdds(wdi_metadata, params, grid),
    nada = score_nada(params)
  )
}

#' Join the D2 parts onto the grid in the published column order
#'
#' @param core Result of combine_dim2_core().
#' @param odin Result of score_odin().
#' @param grid The country x year grid.
#' @return A tibble with iso3c, date, and the D2 indicator columns.
#' @export
combine_dim2_parts <- function(core, odin, grid) {
  grid %>%
    dplyr::left_join(core$sdds, by = c("iso3c", "date")) %>%
    dplyr::left_join(odin, by = c("iso3c", "date")) %>%
    dplyr::left_join(core$nada, by = c("iso3c", "date"))
}
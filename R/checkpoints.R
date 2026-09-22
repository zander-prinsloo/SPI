# =============================================================================
# Manual download checkpoints
# =============================================================================
# Several SPI sources have no reliable public API and must be downloaded
# manually by the technical lead. For each, this file defines a CHECKPOINT
# target that:
#   1. Verifies the expected raw file is present in 01_raw_data/.
#   2. Validates its schema (R8: fail loudly on format changes).
#   3. Fails with clear download instructions if the file is missing.
#
# These checkpoints RUN BY DEFAULT: they are in the default target list, so
# targets::tar_make() verifies every manual source and fails loudly (R8)
# with download instructions if a file is missing or schema-invalid. Only
# the API pulls (pull_jmp, pull_unsdg) are opt-in (run_downloads = TRUE).
# The technical lead can also run a single checkpoint explicitly:
#   targets::tar_make(checkpoint_odin)
#   targets::tar_make(checkpoint_nada)
#   targets::tar_make(checkpoint_microdata)
#   targets::tar_make(checkpoint_unigme)
#
# Created: 2026-09-22
# =============================================================================

# The pipe operator (%>%) comes from magrittr (loaded via tidyverse in the
# original Rmds). We import it explicitly so this file is self-contained.
`%>%` <- magrittr::`%>%`

# dplyr functions (if_else, case_when, etc.) are used unqualified throughout
# this file, matching the tidyverse style of the original Rmds.
library(dplyr)

#' Checkpoint: ODIN data present and schema-valid
#'
#' ODIN (Open Data Inventory) is downloaded manually from
#' https://odin.opendatawatch.com. The pipeline reads ODIN_<YEAR>.csv from
#' 01_raw_data/2.2_DSOA/ for SPI.D2.2 (online access) and SPI.D4.3
#' (geospatial data).
#'
#' @param params List of pipeline parameters.
#' @return Invisibly returns the path to the ODIN file.
#' @export
verify_odin_data <- function(params) {
  end_date <- params$end_date
  file_path <- file.path(params$raw_dir, "2.2_DSOA", sprintf("ODIN_%d.csv", end_date))

  if (!file.exists(file_path)) {
    stop(
      sprintf("ODIN FILE NOT FOUND: %s\n", file_path),
      "\nDownload the ODIN data from:",
      "  https://odin.opendatawatch.com",
      "Select the latest year and download the CSV.",
      "Save it as ODIN_<YEAR>.csv in 01_raw_data/2.2_DSOA/.",
      call. = FALSE
    )
  }

  df <- readr::read_csv(file_path, show_col_types = FALSE)
  # The ODIN file uses "Country Code" and "Year" (raw names); the pipeline
  # applies as_tibble(.name_repair = "universal") which converts spaces to
  # dots. Validate against the RAW names. The pipeline also reads the
  # "Open Data Inventory" score columns (see R/dim2.R score_odin()).
  required <- c("Country Code", "Year")
  missing <- setdiff(required, names(df))
  if (length(missing) > 0) {
    stop(
      sprintf(
        "ODIN SCHEMA MISMATCH in '%s':\n  Missing required column(s): %s\n  Found columns: %s\n\n",
        basename(file_path), paste(missing, collapse = ", "), paste(names(df), collapse = ", ")
      ),
      "The ODIN download format has changed. Investigate before proceeding.",
      call. = FALSE
    )
  }

  # The pipeline's score_odin() reads the "Openness subscore" column (raw
  # name "Openness subscore" -> "Openness.subscore" after name repair).
  # Fail loudly if it is missing so the checkpoint catches format changes
  # that would silently zero the ODIN scores.
  score_col <- "Openness subscore"
  if (!(score_col %in% names(df))) {
    stop(
      sprintf(
        "ODIN SCHEMA MISMATCH in '%s':\n  Missing score column: '%s'\n  Found columns: %s\n\n",
        basename(file_path), score_col, paste(names(df), collapse = ", ")
      ),
      "The ODIN download format has changed (score column missing).",
      "Investigate before proceeding.",
      call. = FALSE
    )
  }

  message(sprintf("ODIN checkpoint OK: %s (%d rows)", basename(file_path), nrow(df)))
  invisible(file_path)
}

#' Checkpoint: NADA data present and schema-valid
#'
#' NADA (National Data Archive) data is collected by checking national
#' statistical office websites (see 02_programs/misc_scripts/nada_check.R).
#' The pipeline reads D2.4.NADA.2024.csv from 01_raw_data/2.4_DSDS/ for
#' SPI.D2.4 (data services).
#'
#' @param params List of pipeline parameters.
#' @return Invisibly returns the path to the NADA file.
#' @export
verify_nada_data <- function(params) {
  end_date <- params$end_date
  file_path <- file.path(params$raw_dir, "2.4_DSDS", sprintf("D2.4.NADA.%d.csv", end_date))

  if (!file.exists(file_path)) {
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

  df <- readr::read_csv(file_path, show_col_types = FALSE)
  # The pipeline's score_nada() reads iso3c, NADA, and NADA_text (see
  # R/dim2.R). Require all three so a format change that would silently
  # zero the NADA scores is caught.
  required <- c("iso3c", "NADA", "NADA_text")
  missing <- setdiff(required, names(df))
  if (length(missing) > 0) {
    stop(
      sprintf(
        "NADA SCHEMA MISMATCH in '%s':\n  Missing required column(s): %s\n  Found columns: %s\n\n",
        basename(file_path), paste(missing, collapse = ", "), paste(names(df), collapse = ", ")
      ),
      "The NADA check output format has changed. Investigate before proceeding.",
      call. = FALSE
    )
  }

  message(sprintf("NADA checkpoint OK: %s (%d rows)", basename(file_path), nrow(df)))
  invisible(file_path)
}

#' Checkpoint: Microdata library pull present
#'
#' The microdata library pull (02_programs/misc_scripts/microdata_library_pull.Rmd)
#' downloads census/survey metadata from national microdata libraries. The
#' pipeline reads the resulting files from 01_raw_data/4.1_SOCS/raw/ for the
#' SPI.D4.1 censuses and surveys indicators.
#'
#' @param params List of pipeline parameters.
#' @return Invisibly returns TRUE if the census/survey files are present.
#' @export
verify_microdata_files <- function(params) {
  end_date <- params$end_date

  # The census/survey files the pipeline reads (see R/dim4.R census_fun()).
  # Naming: D4.1.<n>.<CEN|SVY>.<DATA>.<YEAR>.csv in 4.1_SOCS/raw/.
  expected <- c(
    file.path(params$raw_dir, "4.1_SOCS", "raw", sprintf("D4.1.1.CEN.POPU.%d.csv", end_date)),
    file.path(params$raw_dir, "4.1_SOCS", "raw", sprintf("D4.1.2.CEN.AGRI.%d.csv", end_date)),
    file.path(params$raw_dir, "4.1_SOCS", "raw", sprintf("D4.1.3.CEN.BIZZ.%d.csv", end_date)),
    file.path(params$raw_dir, "4.1_SOCS", "raw", sprintf("D4.1.4.SVY.HOUS.%d.csv", end_date)),
    file.path(params$raw_dir, "4.1_SOCS", "raw", sprintf("D4.1.5.SVY.AGRI.%d.csv", end_date)),
    file.path(params$raw_dir, "4.1_SOCS", "raw", sprintf("D4.1.6.SVY.LABR.%d.csv", end_date)),
    file.path(params$raw_dir, "4.1_SOCS", "raw", sprintf("D4.1.7.SVY.HLTH.%d.csv", end_date)),
    file.path(params$raw_dir, "4.1_SOCS", "raw", sprintf("D4.1.8.SVY.BIZZ.%d.csv", end_date)),
    # The manual review file for the current vintage is required (R8).
    file.path(params$raw_dir, "4.1_SOCS", "raw", sprintf("D4.1.Manual.Review.%d.xlsx", end_date))
  )

  missing <- expected[!file.exists(expected)]
  if (length(missing) > 0) {
    stop(
      sprintf("MICRODATA LIBRARY FILES NOT FOUND (%d missing):\n  %s\n",
        length(missing), paste(missing, collapse = "\n  ")
      ),
      "\nRun the microdata library pull:",
      "  02_programs/misc_scripts/microdata_library_pull.Rmd",
      "This downloads census/survey metadata from national microdata",
      "libraries into 01_raw_data/4.1_SOCS/raw/.",
      call. = FALSE
    )
  }

  message(sprintf("Microdata library checkpoint OK: %d census/survey files present", length(expected)))
  invisible(TRUE)
}

#' Checkpoint: UN IGME child mortality data present
#'
#' UN IGME child mortality estimates are downloaded manually from
#' https://childmortality.org. The pipeline reads the UNICEF-CME file from
#' 01_raw_data/1.5_DUIO/ for SPI.D1.5.CHLD.MORT.
#'
#' @param params List of pipeline parameters.
#' @return Invisibly returns the path to the IGME file.
#' @export
verify_unigme_data <- function(params) {
  file_path <- file.path(params$raw_dir, "1.5_DUIO", "UNICEF-CME_DF_2021_WQ-1.0-download.csv")

  if (!file.exists(file_path)) {
    stop(
      sprintf("UN IGME FILE NOT FOUND: %s\n", file_path),
      "\nDownload the child mortality data from:",
      "  https://childmortality.org",
      "Select the UNICEF CME data file (with wealth quintile breakdown)",
      "and save it as UNICEF-CME_DF_2021_WQ-1.0-download.csv in",
      "01_raw_data/1.5_DUIO/.",
      call. = FALSE
    )
  }

  df <- readr::read_csv(file_path, show_col_types = FALSE)
  required <- c("Indicator", "Sex", "Observation Status", "Series Year", "TIME_PERIOD", "Geographic area", "OBS_VALUE")
  missing <- setdiff(required, names(df))
  if (length(missing) > 0) {
    stop(
      sprintf(
        "UN IGME SCHEMA MISMATCH in '%s':\n  Missing required column(s): %s\n  Found columns: %s\n\n",
        basename(file_path), paste(missing, collapse = ", "), paste(names(df), collapse = ", ")
      ),
      "The UN IGME download format has changed. Investigate before proceeding.",
      call. = FALSE
    )
  }

  message(sprintf("UN IGME checkpoint OK: %s (%d rows)", basename(file_path), nrow(df)))
  invisible(file_path)
}
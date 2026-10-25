# =============================================================================
# Manual download checkpoints
# =============================================================================
# Several SPI sources have no reliable public API and must be downloaded
# manually by the technical lead. For each, this file defines a CHECKPOINT
# function that:
#   1. Verifies the expected raw file is present in 01_raw_data/.
#   2. Validates its schema (R8: fail loudly on format changes).
#   3. Fails with clear download instructions if the file is missing.
#
# The collection target `manual_checkpoints` (run_collection_checkpoints() in
# R/collection_checkpoints.R) runs the checks on every collection run:
#   targets::tar_make(names = "manual_checkpoints",
#                     script = "_targets_data.R", store = "_targets_data")
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
  # The ODIN file uses raw names such as "Country Code"; the readers apply
  # as_tibble(.name_repair = "universal"), which converts spaces to dots.
  # Validate the repaired names against every column SPI.D2.2 and SPI.D4.3
  # read (odin_required_columns in R/dim2.R), so a format change cannot
  # silently zero the ODIN scores.
  repaired <- names(tibble::as_tibble(df, .name_repair = "universal_quiet"))
  missing <- setdiff(odin_required_columns, repaired)
  if (length(missing) > 0) {
    stop(
      sprintf(
        "ODIN SCHEMA MISMATCH in '%s':\n  Missing required column(s): %s\n  Found columns: %s\n\n",
        basename(file_path), paste(missing, collapse = ", "), paste(repaired, collapse = ", ")
      ),
      "The ODIN download format has changed. Investigate before proceeding.",
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
  file_path <- file.path(params$raw_dir, "1.5_DUIO", params$unigme_file)

  if (!file.exists(file_path)) {
    stop(
      sprintf("UN IGME FILE NOT FOUND: %s\n", file_path),
      "\nDownload the child mortality data from:",
      "  https://childmortality.org",
      "Select the UNICEF CME data file (with wealth quintile breakdown)",
      "and save it as ", params$unigme_file, " in",
      "01_raw_data/1.5_DUIO/.",
      call. = FALSE
    )
  }

  df <- readr::read_csv(file_path, show_col_types = FALSE)
  required <- c("Indicator", "Sex", "Observation Status", "Series Year", "Geographic area", "OBS_VALUE")
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
  if (!("REF_DATE" %in% names(df) || "TIME_PERIOD" %in% names(df))) {
    stop(
      sprintf("UN IGME SCHEMA MISMATCH in '%s': expected REF_DATE or TIME_PERIOD", basename(file_path)),
      call. = FALSE
    )
  }

  message(sprintf("UN IGME checkpoint OK: %s (%d rows)", basename(file_path), nrow(df)))
  invisible(file_path)
}
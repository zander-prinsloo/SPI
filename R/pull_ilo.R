# =============================================================================
# ILO ILOSTAT download target
# =============================================================================
# Downloads the ILO labour force participation data used for
# SPI.D1.5.LFP (labor force participation).
#
# Two datasets are needed:
#   - EAP_2WAP_SEX_AGE_RT_A: ILO modelled estimates (complete coverage)
#   - EAP_DWAP_SEX_AGE_RT_A: ILO reported survey data (national sources)
#
# The original Rmd downloads these from the ILO bulk explorer:
#   https://www.ilo.org/shinyapps/bulkexplorer2/
# and saves them to 01_raw_data/1.5_DUIO/ with a timestamped filename
# (e.g. EAP_2WAP_SEX_AGE_RT_A-20250923T0014.csv).
#
# ILOSTAT also provides a public API (https://www.ilo.org/ilostat-api/),
# but the bulk explorer CSV is the format the pipeline reads. This target
# is a CHECKPOINT: it verifies that the expected ILO files are present and
# schema-valid, and fails loudly with download instructions if not.
#
# NOTE: this target is OPT-IN. Running tar_make() by default does NOT
# trigger it. The technical lead runs it explicitly when updating:
#   targets::tar_make(checkpoint_ilo)
#
# Created: 2026-09-22
# =============================================================================

# The pipe operator (%>%) comes from magrittr (loaded via tidyverse in the
# original Rmds). We import it explicitly so this file is self-contained.
`%>%` <- magrittr::`%>%`

# dplyr functions (if_else, case_when, etc.) are used unqualified throughout
# this file, matching the tidyverse style of the original Rmds.
library(dplyr)

#' Checkpoint: ILO LFP files present and schema-valid
#'
#' The ILO data is downloaded manually from the bulk explorer (the API
#' format differs from the CSV the pipeline reads). This checkpoint
#' verifies that the expected modelled and survey files are present in
#' 01_raw_data/1.5_DUIO/ and have the expected columns. If a file is
#' missing or the format changed, it fails loudly with download
#' instructions (R8).
#'
#' @param params List of pipeline parameters.
#' @return Invisibly returns the paths to the ILO files.
#' @export
checkpoint_ilo_lfp <- function(params) {
  # The 202511 vintage files (see R/dim1_5.R read_ilo_lfp()).
  files <- c(
    modelled = file.path(params$raw_dir, "1.5_DUIO", "EAP_2WAP_SEX_AGE_RT_A-20250923T0014.csv"),
    survey = file.path(params$raw_dir, "1.5_DUIO", "EAP_DWAP_SEX_AGE_RT_A-20250923T0014.csv")
  )

  for (nm in names(files)) {
    fp <- files[[nm]]
    if (!file.exists(fp)) {
      stop(
        sprintf("ILO %s FILE NOT FOUND: %s\n", nm, fp),
        "\nDownload the ILO labour force data from the bulk explorer:",
        "  https://www.ilo.org/shinyapps/bulkexplorer2/",
        "Indicator: EAP_2WAP_SEX_AGE_RT_A (modelled) and",
        "           EAP_DWAP_SEX_AGE_RT_A (survey)",
        "Filter: sex = Total, classif1 = Age (Youth, adults): 15+",
        "Save to 01_raw_data/1.5_DUIO/ with a timestamped filename and",
        "update the filename in R/dim1_5.R (read_ilo_lfp).",
        call. = FALSE
      )
    }

    df <- readr::read_csv(fp, show_col_types = FALSE)
    required <- c("sex.label", "classif1.label", "ref_area.label", "time", "obs_value")
    missing <- setdiff(required, names(df))
    if (length(missing) > 0) {
      stop(
        sprintf(
          "ILO %s SCHEMA MISMATCH in '%s':\n  Missing required column(s): %s\n  Found columns: %s\n\n",
          nm, basename(fp), paste(missing, collapse = ", "), paste(names(df), collapse = ", ")
        ),
        "The ILO download format has changed. Investigate before proceeding.",
        call. = FALSE
      )
    }

    message(sprintf("ILO %s checkpoint OK: %s (%d rows)", nm, basename(fp), nrow(df)))
  }

  invisible(files)
}
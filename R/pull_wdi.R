# =============================================================================
# WDI metadata download target
# =============================================================================
# Downloads the World Development Indicators (WDI) metadata used by the
# pipeline:
#   - SPI.D1.5.DT.TDS.DPPF.XP.ZS (debt service reporting) -- from the WDI
#     metadata CSV (manual download from the WDI catalog)
#   - D5.2 standards indicators (SNA, base years, classifications) -- from
#     the WDI metadata CSV
#
# The WDI metadata is a MANUAL download from the World Bank data catalog:
#   https://datacatalog.worldbank.org/int/search/dataset/0037712
# There is no stable public API for the full metadata file, so this target
# is a CHECKPOINT: it verifies that the expected metadata file is present
# and schema-valid, and fails loudly with download instructions if not.
#
# The debt service indicator itself (SPI.D1.5.DT.TDS.DPPF.XP.ZS) is scored
# from the WDI metadata CSV in R/dim1_5.R (read_wdi_metadata()).
#
# Created: 2026-09-22
# =============================================================================

# The pipe operator (%>%) comes from magrittr (loaded via tidyverse in the
# original Rmds). We import it explicitly so this file is self-contained.
`%>%` <- magrittr::`%>%`

# dplyr functions (if_else, case_when, etc.) are used unqualified throughout
# this file, matching the tidyverse style of the original Rmds.
library(dplyr)

#' Checkpoint: WDI metadata file present and schema-valid
#'
#' The WDI metadata is a manual download (no stable public API). This
#' checkpoint verifies that the expected file for the reference year is
#' present in 01_raw_data/metadata/ and has the expected columns. If the
#' file is missing or the format changed, it fails loudly with download
#' instructions (R8).
#'
#' @param params List of pipeline parameters.
#' @return Invisibly returns the path to the WDI metadata file.
#' @export
checkpoint_wdi_metadata <- function(params) {
  end_date <- params$end_date

  # The pipeline reads WDI metadata for years 2016:(end_date + 1).
  # The most recent file is the one the technical lead must update.
  file_path <- file.path(params$raw_dir, "metadata", sprintf("WDI_metadata_%d.csv", end_date + 1))

  if (!file.exists(file_path)) {
    stop(
      sprintf("WDI METADATA NOT FOUND: %s\n", file_path),
      "\nDownload the WDI metadata from the World Bank data catalog:",
      "  https://datacatalog.worldbank.org/int/search/dataset/0037712",
      "Rename the file to WDI_metadata_<YEAR>.csv and place it in",
      "01_raw_data/metadata/ (see docs/user-guide.md section 4.2).",
      call. = FALSE
    )
  }

  df <- readr::read_csv(file_path, show_col_types = FALSE)

  # The metadata file has many columns; the pipeline needs these. The raw
  # file uses column names with spaces (e.g. "Country Code"); the pipeline
  # applies as_tibble(.name_repair = "universal") which converts spaces to
  # dots (e.g. "Country.Code"). Validate against the RAW names.
  required <- c("Country Code", "Income Group", "External debt Reporting status")
  missing <- setdiff(required, names(df))
  if (length(missing) > 0) {
    stop(
      sprintf(
        "WDI METADATA SCHEMA MISMATCH in '%s':\n  Missing required column(s): %s\n  Found columns: %s\n\n",
        basename(file_path),
        paste(missing, collapse = ", "),
        paste(names(df), collapse = ", ")
      ),
      "The WDI metadata format has changed. Investigate the download before",
      "proceeding (see docs/user-guide.md section 4.2).",
      call. = FALSE
    )
  }

  message(sprintf(
    "WDI metadata checkpoint OK: %s (%d rows, %d columns)",
    basename(file_path), nrow(df), ncol(df)
  ))

  invisible(file_path)
}
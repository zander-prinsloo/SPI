# =============================================================================
# IMF compiled workbook checkpoint
# =============================================================================
# Created: 2026-10-21
# =============================================================================

imf_workbook_specs <- function() {
  list(
    cpi_reference = list(
      sheet = "2. CPI Reference Period",
      skip = 2,
      required = c("code", "Country", "...3")
    ),
    household_classification = list(
      sheet = "2. Household Consump Class",
      skip = 0,
      required = c("Code", "Country"),
      pattern = "^As[.]of[.]"
    ),
    coicop_change = list(
      sheet = "3. COICOP Month_Last Change",
      skip = 3,
      required = c("Code", "Country"),
      pattern = "^As[.]of[.]"
    ),
    government_accounting = list(
      sheet = "4. Cntrl Gct Acct Status",
      skip = 9,
      required = c("Code", "Country", "General.Government..consolidated."),
      pattern = "Reference[.]Year"
    ),
    monetary_statistics = list(
      sheet = "6. MFS Compilation status",
      skip = 0,
      required = c(
        "Code", "Country",
        "Monetary.and.Financial.Statistics..MFS..Reporting.Status"
      ),
      pattern = "^As[.]of[.]"
    )
  )
}

imf_historical_workbook_specs <- function() {
  list(
    cpi_reference = list(
      sheet = "1. CPI Reference Period",
      skip = 1,
      required = c("Code", "Country", "Common.Reference.Period")
    ),
    household_classification = list(
      sheet = "2. Household Consump Class",
      skip = 1,
      required = c("Code", "Country", "Status")
    ),
    coicop_change = list(
      sheet = "3. COICOP Month_Last Change",
      skip = 3,
      required = c("Code", "Country", "last_change")
    ),
    government_accounting = list(
      sheet = "4. Cntrl Gct Acct Status",
      skip = 9,
      required = c("Code", "Country", "General.Government..consolidated.")
    ),
    monetary_statistics = list(
      sheet = "6. MFS Compilation status",
      skip = 1,
      required = c(
        "Code", "Country",
        "Monetary.and.Financial.Statistics..MFS..Reporting.Status"
      )
    )
  )
}

validate_imf_workbook <- function(file_path, specs, vintage_label) {
  if (!file.exists(file_path)) {
    stop(
      sprintf("IMF WORKBOOK NOT FOUND (%s): %s", vintage_label, file_path),
      "Place the required IMF Compiled Data for World Bank workbook in",
      "01_raw_data/5.2_DISM/ and set its parameter in config/params.R.",
      call. = FALSE
    )
  }

  sheets <- readxl::excel_sheets(file_path)
  for (spec in specs) {
    if (!(spec$sheet %in% sheets)) {
      stop(
        sprintf(
          "IMF WORKBOOK SHEET NOT FOUND (%s) in '%s': '%s'",
          vintage_label,
          basename(file_path),
          spec$sheet
        ),
        call. = FALSE
      )
    }
    header <- suppressWarnings(suppressMessages(readxl::read_excel(
      file_path,
      sheet = spec$sheet,
      skip = spec$skip,
      n_max = 0,
      .name_repair = "universal"
    )))
    missing <- setdiff(spec$required, names(header))
    if (length(missing) > 0L) {
      stop(
        sprintf(
          "IMF WORKBOOK SCHEMA MISMATCH (%s) in '%s' sheet '%s': %s",
          vintage_label,
          basename(file_path),
          spec$sheet,
          paste(missing, collapse = ", ")
        ),
        call. = FALSE
      )
    }
    if (!is.null(spec$pattern) &&
        !any(grepl(spec$pattern, names(header)))) {
      stop(
        sprintf(
          "IMF WORKBOOK HEADER MISMATCH (%s) in '%s' sheet '%s': pattern '%s' not found",
          vintage_label,
          basename(file_path),
          spec$sheet,
          spec$pattern
        ),
        call. = FALSE
      )
    }
  }
  invisible(file_path)
}

#' Check the configured IMF compiled workbook.
#'
#' @param params Pipeline parameters containing `raw_dir`, `imf_file`, and
#'   `imf_file_2024`.
#' @return The validated workbook path.
#' @export
checkpoint_imf_workbook <- function(params) {
  current_path <- file.path(params$raw_dir, "5.2_DISM", params$imf_file)
  historical_path <- file.path(params$raw_dir, "5.2_DISM", params$imf_file_2024)
  validate_imf_workbook(current_path, imf_workbook_specs(), "current 2025")
  validate_imf_workbook(
    historical_path,
    imf_historical_workbook_specs(),
    "historical 2024"
  )
  message(
    sprintf(
      "IMF workbook checkpoint OK: current=%s; historical=%s",
      basename(current_path),
      basename(historical_path)
    )
  )
  invisible(current_path)
}

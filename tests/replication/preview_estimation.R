# =============================================================================
# Preview estimation in a sandbox
# =============================================================================
# Runs the reference-year estimation on the current collection artifacts
# before the collection gate passes (attestations and reviews pending), for
# draft revision evidence and review packages. Nothing is written to the
# repository:
#   - the sandbox holds the working-tree code and a raw-data symlink farm
#     (`_collection` is a sandbox folder whose existing files are symlinks);
#   - the collection gate and the vintage-diff enforcement are neutralized in
#     the sandbox only, so blocking findings are reported, not enforced;
#   - the promoted outputs (including vintage-diff, revision evidence and the
#     provisional ODIN marker) are copied to <dir>, then the sandbox is
#     removed.
# The copied outputs are a preview: they carry the provisional ODIN marker
# and precede the attestations and manual reviews.
#
# Usage (repository root):
#   Rscript tests/replication/preview_estimation.R --out <dir> [--keep-sandbox]
#   Add --legacy-e6 to reproduce the same current-score run with the pre-E6
#   country-name joins, for E6-only impact evidence.
#
# Created: 2026-10-24
# =============================================================================

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag) {
  hit <- which(args == flag)
  if (length(hit) == 0L) NULL else args[[hit[[1]] + 1L]]
}
repo_root <- normalizePath(".", mustWork = TRUE)
source(file.path(repo_root, "tests", "replication", "replicate_vintage.R"))
out <- arg_value("--out")
if (is.null(out)) stop("--out IS REQUIRED.", call. = FALSE)
keep <- "--keep-sandbox" %in% args
legacy_e6 <- "--legacy-e6" %in% args
dir.create(out, recursive = TRUE, showWarnings = FALSE)

sandbox <- tempfile("spi-preview-", tmpdir = dirname(tempdir()))
dir.create(sandbox, recursive = TRUE)
cat("Preview sandbox:", sandbox, "\n")

preview <- function() {
  copy_replication_code(repo_root, sandbox, "worktree")
  real_raw <- file.path(repo_root, "01_raw_data")
  farm <- file.path(sandbox, "01_raw_data")
  dir.create(farm)
  for (child in list.files(real_raw, no.. = TRUE)) {
    if (child == "_collection") {
      dir.create(file.path(farm, child))
      for (grandchild in list.files(file.path(real_raw, child), no.. = TRUE)) {
        file.symlink(file.path(real_raw, child, grandchild), file.path(farm, child, grandchild))
      }
    } else {
      file.symlink(file.path(real_raw, child), file.path(farm, child))
    }
  }
  legacy_child <- function(params) {
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
        readr::read_csv(file.path(params$raw_dir, "metadata", "iso_codes.csv"),
                        show_col_types = FALSE),
        by = "country"
      ) %>%
      dplyr::mutate(iso3c = dplyr::if_else(country == "Côte d'Ivoire", "CIV", iso3c))
  }
  legacy_ilo <- function(params) {
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
  overrides <- c(
    "# Sandbox-only preview overrides (never part of the repository code).",
    "validate_collection_status <- function(...) TRUE",
    "enforce_vintage_diff <- function(...) invisible(TRUE)"
  )
  if (legacy_e6) {
    overrides <- c(
      overrides,
      c("legacy_child <-", deparse(legacy_child)),
      "read_child_mortality_data <- legacy_child",
      c("legacy_ilo <-", deparse(legacy_ilo)),
      "read_ilo_lfp <- legacy_ilo"
    )
  }
  writeLines(overrides, file.path(sandbox, "R", "zzz_preview_overrides.R"))
  script <- file.path(sandbox, "_preview_run.R")
  writeLines(c(
    "suppressPackageStartupMessages(library(targets))",
    "result <- tryCatch({ tar_make(script = '_targets.R', store = '_targets', reporter = 'silent'); 'completed' }, error = function(e) paste('FAILED:', conditionMessage(e)))",
    "cat('RESULT:', result, '\\n')"
  ), script)
  log <- file.path(out, "_preview_run.log")
  old <- setwd(sandbox)
  on.exit(setwd(old), add = TRUE)
  system2(
    "Rscript",
    c("--vanilla", "-e", shQuote("source('renv/activate.R'); source('_preview_run.R')")),
    stdout = log,
    stderr = log
  )
  result <- grep("^RESULT:", readLines(log, warn = FALSE), value = TRUE)
  cat(result, "\n")
  if (length(result) == 0L || !grepl("completed", result[[length(result)]])) {
    stop("PREVIEW ESTIMATION FAILED; see ", log, call. = FALSE)
  }
  outputs <- list.files(file.path(sandbox, "03_output_data"), all.files = TRUE, no.. = TRUE)
  outputs <- outputs[!outputs %in% c(".candidate", "releases") & !dir.exists(file.path(sandbox, "03_output_data", outputs))]
  file.copy(file.path(sandbox, "03_output_data", outputs), out, overwrite = TRUE)
  cat("Copied", length(outputs), "output files to", out, "\n")
}

tryCatch(
  preview(),
  finally = {
    if (keep) cat("Sandbox kept at:", sandbox, "\n") else unlink(sandbox, recursive = TRUE, force = TRUE)
  }
)

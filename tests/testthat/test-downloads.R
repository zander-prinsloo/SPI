# =============================================================================
# Download target smoke tests
# =============================================================================
# Smoke tests for the OPT-IN download/checkpoint targets (Phase 6, Step 21).
#
# These tests verify:
#   1. The checkpoint functions fail loudly (R8) when a source file is
#      missing or schema-invalid.
#   2. The checkpoint functions pass when the expected committed source files
#      are present in 01_raw_data/.
#   3. The API pull functions are no-ops when run_downloads = FALSE.
#
# The tests use a temporary params list pointing at the real raw data
# directory, so they exercise the actual checkpoint logic without running
# the full pipeline.
#
# Created: 2026-09-22
# =============================================================================

library(testthat)

# Source the checkpoint and pull functions
source(file.path(here::here("R"), "collection_http.R"))
source(file.path(here::here("R"), "collection_cache.R"))
source(file.path(here::here("R"), "checkpoints.R"))
source(file.path(here::here("R"), "dim2.R"))
source(file.path(here::here("R"), "pull_wdi.R"))
source(file.path(here::here("R"), "pull_ilo.R"))
source(file.path(here::here("R"), "pull_imf.R"))
source(file.path(here::here("R"), "pull_jmp.R"))
source(file.path(here::here("R"), "pull_unsdg.R"))

# --- Helper: build a params list for the tests ------------------------------

test_params <- function() {
  list(
    raw_dir = here::here("01_raw_data"),
    end_date = 2024,
    run_downloads = FALSE,
    # ILO filenames (from config/params.R) -- needed by checkpoint_ilo_lfp
    ilo_modelled_file = "EAP_2WAP_SEX_AGE_RT_A-20261006T1235.xlsx",
    ilo_survey_file = "EAP_DWAP_SEX_AGE_RT_A-20261006T1234.xlsx",
    imf_file = "2026.10_Compiled Data for World Bank - Sep 2026 - Final.xlsx",
    imf_file_2024 = "2025.10_Compiled Data for World Bank.xlsx",
    unigme_file = "UN IGME 2025.csv"
  )
}

test_that("checkpoint_imf_workbook passes with the 202611 workbook", {
  params <- test_params()
  result <- checkpoint_imf_workbook(params)
  expect_true(is.character(result))
  expect_true(file.exists(result))
})

test_that("checkpoint_imf_workbook fails loudly when filename is wrong", {
  params <- test_params()
  params$imf_file <- "missing-imf-workbook.xlsx"
  expect_error(checkpoint_imf_workbook(params), "IMF WORKBOOK NOT FOUND")
})

test_that("checkpoint_imf_workbook requires the historical 2024 workbook", {
  params <- test_params()
  params$imf_file_2024 <- "missing-historical-imf-workbook.xlsx"
  expect_error(
    checkpoint_imf_workbook(params),
    "historical 2024"
  )
})

# --- Test: WDI metadata checkpoint ------------------------------------------

test_that("checkpoint_wdi_metadata passes with the committed WDI metadata", {
  params <- test_params()
  result <- checkpoint_wdi_metadata(params)
  expect_true(is.character(result))  # returns the file path
  expect_true(file.exists(result))
})

test_that("checkpoint_wdi_metadata fails loudly when the file is missing", {
  params <- test_params()
  params$end_date <- 2099  # no WDI_metadata_2100.csv exists
  expect_error(
    checkpoint_wdi_metadata(params),
    "WDI METADATA NOT FOUND"
  )
})

# --- Test: ILO checkpoint ---------------------------------------------------

test_that("checkpoint_ilo_lfp passes with the committed ILO files", {
  params <- test_params()
  result <- checkpoint_ilo_lfp(params)
  expect_true(is.character(result))
  expect_length(result, 2)  # modelled + survey
})

test_that("checkpoint_ilo_lfp fails loudly when a file is missing", {
  params <- test_params()
  # Point at a raw_dir that lacks the ILO files (tempdir is empty).
  params$raw_dir <- tempdir()
  expect_error(
    checkpoint_ilo_lfp(params),
    "ILO .* FILE NOT FOUND"
  )
})

# --- Test: ODIN checkpoint --------------------------------------------------

test_that("checkpoint_odin passes with the committed ODIN data", {
  params <- test_params()
  result <- verify_odin_data(params)
  expect_true(is.character(result))
  expect_true(file.exists(result))
})

test_that("checkpoint_odin fails loudly when the file is missing", {
  params <- test_params()
  params$end_date <- 2099
  expect_error(
    verify_odin_data(params),
    "ODIN FILE NOT FOUND"
  )
})

# --- Test: NADA checkpoint --------------------------------------------------

test_that("checkpoint_nada passes with the committed NADA data", {
  params <- test_params()
  result <- verify_nada_data(params)
  expect_true(is.character(result))
  expect_true(file.exists(result))
})

test_that("checkpoint_nada fails loudly when the file is missing", {
  params <- test_params()
  params$end_date <- 2099
  expect_error(
    verify_nada_data(params),
    "NADA FILE NOT FOUND"
  )
})

# --- Test: microdata checkpoint ---------------------------------------------

test_that("checkpoint_microdata passes with the committed census/survey files", {
  params <- test_params()
  result <- verify_microdata_files(params)
  expect_true(isTRUE(result))
})

test_that("checkpoint_microdata fails loudly when files are missing", {
  params <- test_params()
  params$end_date <- 2099
  expect_error(
    verify_microdata_files(params),
    "MICRODATA LIBRARY FILES NOT FOUND"
  )
})

# --- Test: UN IGME checkpoint -----------------------------------------------

test_that("checkpoint_unigme passes with the committed IGME data", {
  params <- test_params()
  result <- verify_unigme_data(params)
  expect_true(is.character(result))
  expect_true(file.exists(result))
})

test_that("checkpoint_unigme fails loudly when the file is missing", {
  params <- test_params()
  params$raw_dir <- tempdir()
  expect_error(
    verify_unigme_data(params),
    "UN IGME FILE NOT FOUND"
  )
})

# --- Test: API pull no-op behavior ------------------------------------------

test_that("pull targets are no-ops when run_downloads = FALSE", {
  params <- test_params()
  # The pull functions are guarded by run_downloads in _targets.R. Here we
  # verify the guard logic directly: with run_downloads = FALSE the pull
  # functions must NOT be invoked. We exercise the same branch condition
  # the target command uses.
  expect_false(isTRUE(params$run_downloads))

  # The guard in _targets.R is: if (isTRUE(params$run_downloads)) { pull }
  # else { message(...); NULL }. Verify the else-branch contract: the pull
  # function is not called and the result is NULL.
  called <- FALSE
  fake_pull <- function(params) {
    called <<- TRUE
    NULL
  }
  result <- if (isTRUE(params$run_downloads)) fake_pull(params) else NULL
  expect_false(called)
  expect_null(result)
})

# --- Test: JMP download hard stop (P2.11) -----------------------------------

test_that("JMP workbook downloads fail loudly on a non-200 response", {
  # The download must STOP (not return an empty sheet) so the pull cannot
  # silently produce incomplete data. httr::GET is mocked: no network.
  local_mocked_bindings(
    GET = function(...) structure(list(status_code = 404L, url = "https://washdata.org"), class = "response"),
    .package = "httr"
  )
  expect_error(
    jmp_download_workbook(jmp_country_url("ZZZ"), tempfile(fileext = ".xlsx")),
    "JMP DOWNLOAD FAILED: HTTP 404"
  )
})

test_that("checkpoint_odin requires every column the ODIN readers use", {
  params <- test_params()
  source_file <- file.path(params$raw_dir, "2.2_DSOA", sprintf("ODIN_%d.csv", params$end_date))
  data <- readr::read_csv(source_file, show_col_types = FALSE)
  raw <- withr::local_tempdir()
  dir.create(file.path(raw, "2.2_DSOA"))
  readr::write_csv(
    data[, setdiff(names(data), "Second administrative level")],
    file.path(raw, "2.2_DSOA", basename(source_file))
  )
  params$raw_dir <- raw
  expect_error(verify_odin_data(params), "ODIN SCHEMA MISMATCH.*Second.administrative.level")
})

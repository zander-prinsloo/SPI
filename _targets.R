# =============================================================================
# SPI Estimation Pipeline -- targets orchestration
# =============================================================================
# This file defines the {targets} pipeline for the Statistical Performance
# Indicators (SPI). It mirrors the estimation logic of the original Rmd
# pipeline (01-SPI_data_prep.Rmd, 02-SPI_index.Rmd, 03_SPI_data_validation.Rmd)
# so that the new pipeline produces IDENTICAL results.
#
# HOW TO RUN
# ----------
#   From R (in the project root):
#       targets::tar_make()
#
#   From the terminal:
#       Rscript -e "targets::tar_make()"
#
#   To see the pipeline graph:
#       targets::tar_manifest()
#       targets::tar_visnetwork()
#
# DESIGN PRINCIPLES
# -----------------
# 1. Readability over efficiency (R9): functions are simple and heavily
#    commented so the technical lead can read and understand them.
# 2. Fail loudly (R8): source reads are schema-validated; any format change
#    stops the pipeline with a clear report.
# 3. Collection validation must pass before final outputs are written.
# 4. Estimation only (R12): visualization chunks and commented-out blocks
#    from the Rmds are NOT ported.
#
# Created: 2026-09-21
# =============================================================================

# --- Load the targets package ------------------------------------------------
library(targets)
library(tarchetypes)

# --- Global targets options --------------------------------------------------
tar_option_set(
  # Reproducibility: fixed seed for targets' stochastic steps (tar_rep and
  # similar). NOTE: this does NOT seed rnorm() inside ordinary target
  # commands -- the jitter columns in SPI_quantiles_2024.csv use unseeded
  # rnorm() and are the documented exception E2 (see docs/CHANGELOG.md).
  seed = 2024,
  # Fail loudly: stop the pipeline on the first error (R8). A failing
  # target halts the run so the technical lead sees the error immediately.
  error = "stop"
)

# --- Load pipeline functions -------------------------------------------------
# All functions live in R/ and are sourced here so targets can call them.
# (targets also supports tar_source() for this purpose.)
for (f in list.files("R", pattern = "[.]R$", full.names = TRUE)) {
  source(f)
}

# =============================================================================
# PIPELINE STAGES
# =============================================================================
# The pipeline mirrors the Rmd structure:
#   Stage A (data prep, from 01-SPI_data_prep.Rmd):
#     grid -> per-dimension indicators -> append -> SPI_data.csv/.dta
#   Stage B (index, from 02-SPI_index.Rmd):
#     SPI_data.csv -> nested index -> SPI_index.csv
#   Stage C (validation, from 03_SPI_data_validation.Rmd):
#     staged outputs vs vintage fixtures + expectation checks
#   Stage D (misc outputs, from misc_scripts/):
#     quantiles, treemap, databank files
#
# Phases 3-6 of the plan populate the indicator targets below. The skeleton
# currently defines the foundational targets (params, grid, iso codes).
# =============================================================================

# The targets are defined inside a function so that the target objects do not
# pollute the global environment (this avoids the "Targets and globals must
# have unique names" warning).
pipeline_targets <- function() {

  # --- Load pipeline parameters ----------------------------------------------
  # Parameters are a target themselves so that changing config/params.R
  # invalidates downstream targets. The config file is a file target that
  # `params` depends on, so targets rebuilds params (and everything
  # downstream) when the configuration changes (e.g. end_date, imf_file,
  # ilo filenames).
  params_file <- tar_target(
    name = "params_file",
    command = "config/params.R",
    format = "file"
  )
  params <- tar_target(
    name = "params",
    command = load_params(params_file),
    format = "rds"
  )

  collection_status_file <- tar_target(
    name = "collection_status_file",
    command = params$collection_status_file,
    format = "file"
  )
  collection_run_file <- tar_target(
    name = "collection_run_file",
    command = params$collection_run_file,
    format = "file"
  )
  source_registry_file <- tar_target(
    name = "estimation_source_registry_file",
    command = params$source_registry_file,
    format = "file"
  )
  estimation_source_registry <- tar_target(
    name = "estimation_source_registry",
    command = load_source_registry(source_registry_file),
    format = "rds"
  )
  collection_gate <- tar_target(
    name = "collection_gate",
    command = validate_collection_status(
      collection_status_file,
      expected_source_ids = estimation_source_registry$source_id,
      run_path = collection_run_file,
      parameters_hash = collection_parameters_hash(params)
    ),
    format = "rds"
  )
  output_prepare <- tar_target(
    name = "output_prepare",
    command = {
      collection_gate
      prepare_output_candidate(params$estimation_write_dir)
    },
    format = "rds",
    cue = tar_cue(mode = "always")
  )

  # --- Stage A: Data prep ----------------------------------------------------

  # Country x year grid (from the "spi_df" chunk of 01-SPI_data_prep.Rmd)
  iso_codes <- tar_target(
    name = "iso_codes",
    command = {
      collection_gate
      read_iso_codes(params)
    },
    format = "rds"
  )

  country_grid <- tar_target(
    name = "country_grid",
    command = {
      collection_gate
      build_country_grid(params)
    },
    format = "rds"
  )

  # --- Dimension 1.5: Data use by international organizations ----------------
  # (from the "3.1", "aki_3.3", "3.15_debt", "safely_managed_scored", "lfp",
  # and "aki_combine" chunks of 01-SPI_data_prep.Rmd)
  dim1_5 <- tar_target(
    name = "dim1_5",
    command = {
      collection_gate
      combine_dim1_5(params, country_grid)
    },
    format = "rds"
  )

  # --- Dimension 2: Data services --------------------------------------------
  # (from the "idds", "online_access", and "nada" chunks)
  dim2 <- tar_target(
    name = "dim2",
    command = {
      collection_gate
      combine_dim2(params, country_grid)
    },
    format = "rds"
  )

  # --- Dimension 3: Data products (UN SDG) -----------------------------------
  # (from the "unstats" chunk)
  dim3 <- tar_target(
    name = "dim3",
    command = {
      collection_gate
      combine_dim3(params)
    },
    format = "rds"
  )

  # --- Dimension 4: Data sources ---------------------------------------------
  # (from the "cs", "crvs", and "geo" chunks)
  dim4 <- tar_target(
    name = "dim4",
    command = {
      collection_gate
      combine_dim4(params, country_grid)
    },
    format = "rds"
  )

  # --- Dimension 5: Data infrastructure --------------------------------------
  # (from the "legislation_governance", "standards_meta", "snau", "naby",
  # "cnin", "cpiby", "hous", "empl", "cgov", "fina", "mony", "gsbp", "msc",
  # and "finance" chunks)
  dim5 <- tar_target(
    name = "dim5",
    command = {
      collection_gate
      combine_dim5(params, country_grid)
    },
    format = "rds"
  )

  # --- Append + save: final SPI data -----------------------------------------
  # (from the "append" and "save" chunks of 01-SPI_data_prep.Rmd)
  # Combines all dimensions, adds population, carries forward SPI values,
  # applies the OECD high-income adjustment, and writes SPI_data.csv/.dta
  # to 03_output_data/ after collection validation.
  spi_data <- tar_target(
    name = "spi_data",
    command = {
      output_prepare
      dims <- list(dim1_5, dim2, dim3, dim4, dim5)
      final <- append_spi(dims, params, country_grid)
      save_spi(final, params)
      final
    },
    format = "rds"
  )

  # --- Stage B: Index --------------------------------------------------------
  # (from the "data", "index_weights", "index", and "saver" chunks of
  # 02-SPI_index.Rmd)
  # Builds the nested index (dimension -> pillar -> overall) and writes
  # SPI_index.csv to 03_output_data/ after collection validation.
  spi_index <- tar_target(
    name = "spi_index",
    command = {
      idx <- build_index(spi_data, params)
      save_index(idx, params)
      idx
    },
    format = "rds"
  )

  # --- Stage D: Misc outputs -------------------------------------------------
  # (from misc_scripts/SPI_quantiles.R, SPI_treemap.R, databank.R, and the
  # "aspire" chunk of 01-SPI_data_prep.Rmd)

  # Quantiles and indicators (SPI_quantiles.csv, SPI_quantiles_2024.csv,
  # SPI_indicators_2024.csv)
  quantiles <- tar_target(
    name = "quantiles",
    command = {
      q <- build_quantiles(spi_index, params)
      q24 <- build_quantiles_2024(spi_index, q, params)
      save_quantiles(q, q24$quantiles_2024, q24$indicators_2024, params)
      q
    },
    format = "rds"
  )

  # Treemap (SPI_treemap.csv)
  treemap <- tar_target(
    name = "treemap",
    command = {
      t <- build_treemap(spi_index, params)
      save_treemap(t, params)
      t
    },
    format = "rds"
  )

  # Databank outputs (SPI_databank_country_and_aggregates*.csv, footnotes)
  databank <- tar_target(
    name = "databank",
    command = {
      d <- build_databank(spi_index, spi_data, params)
      save_databank(d, params)
      d
    },
    format = "rds"
  )

  # SPL admin data availability (SPL_admin_data_availability.csv)
  spl_admin <- tar_target(
    name = "spl_admin",
    command = {
      output_prepare
      s <- build_spl_admin(params)
      save_spl_admin(s, params)
      s
    },
    format = "rds"
  )

  output_manifest <- tar_target(
    name = "output_manifest",
    command = {
      spi_data
      spi_index
      quantiles
      treemap
      databank
      spl_admin
      validate_output_manifest(params$estimation_write_dir, params$end_date)
      promote_output_set(
        params$estimation_write_dir,
        params$output_dir,
        params$end_date
      )
    },
    format = "rds"
  )

  # ===========================================================================
  # TARGET LIST
  # ===========================================================================
  # The order here defines the pipeline graph. Add new targets as phases
  # complete.
  list(
    params_file,
    params,
    collection_status_file,
    collection_run_file,
    source_registry_file,
    estimation_source_registry,
    collection_gate,
    output_prepare,
    iso_codes,
    country_grid,
    dim1_5,
    dim2,
    dim3,
    dim4,
    dim5,
    spi_data,
    spi_index,
    quantiles,
    treemap,
    databank,
    spl_admin,
    output_manifest
    # Collection-stage API and manual checkpoints are defined in
    # `_targets_data.R`; estimation consumes their validated artifacts.
  )
}

# =============================================================================
# OPT-IN DOWNLOAD TARGETS
# =============================================================================
# These targets download or verify external data sources.
#
# The CHECKPOINT targets (checkpoint_*) verify that manually-downloaded
# source files are present and schema-valid. They run by default and fail
# loudly (R8) with download instructions when a file is missing or the
# format changed.
#
# API extraction targets live in `_targets_data.R` and are not part of
# estimation.
download_targets <- function() {
  list(
    # --- Manual download checkpoints (fail loudly with instructions) --------
    tar_target(
      name = "checkpoint_wdi",
      command = checkpoint_wdi_metadata(params),
      format = "rds"
    ),
    tar_target(
      name = "checkpoint_ilo",
      command = checkpoint_ilo_lfp(params),
      format = "rds"
    ),
    tar_target(
      name = "checkpoint_odin",
      command = verify_odin_data(params),
      format = "rds"
    ),
    tar_target(
      name = "checkpoint_nada",
      command = verify_nada_data(params),
      format = "rds"
    ),
    tar_target(
      name = "checkpoint_microdata",
      command = verify_microdata_files(params),
      format = "rds"
    ),
    tar_target(
      name = "checkpoint_unigme",
      command = verify_unigme_data(params),
      format = "rds"
    )
  )
}

# Return the target list to targets
pipeline_targets()
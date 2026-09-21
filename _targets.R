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
# 3. Historical outputs are never overwritten (C7): the pipeline writes to
#    staging/ only.
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
  # Reproducibility: fixed seed so any stochastic step is deterministic
  seed = 2024,
  # Tidyverse-style: errors surface immediately instead of being swallowed
  error = "continue"
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
  # invalidates downstream targets (targets tracks file hashes).
  params <- tar_target(
    name = "params",
    command = load_params(),
    format = "rds"
  )

  # --- Stage A: Data prep ----------------------------------------------------

  # Country x year grid (from the "spi_df" chunk of 01-SPI_data_prep.Rmd)
  iso_codes <- tar_target(
    name = "iso_codes",
    command = read_iso_codes(params),
    format = "rds"
  )

  country_grid <- tar_target(
    name = "country_grid",
    command = build_country_grid(params),
    format = "rds"
  )

  # --- Dimension 1.5: Data use by international organizations ----------------
  # (from the "3.1", "aki_3.3", "3.15_debt", "safely_managed_scored", "lfp",
  # and "aki_combine" chunks of 01-SPI_data_prep.Rmd)
  dim1_5 <- tar_target(
    name = "dim1_5",
    command = combine_dim1_5(params, country_grid),
    format = "rds"
  )

  # --- Dimension 2: Data services --------------------------------------------
  # (from the "idds", "online_access", and "nada" chunks)
  dim2 <- tar_target(
    name = "dim2",
    command = combine_dim2(params, country_grid),
    format = "rds"
  )

  # --- Dimension 3: Data products (UN SDG) -----------------------------------
  # (from the "unstats" chunk)
  dim3 <- tar_target(
    name = "dim3",
    command = combine_dim3(params),
    format = "rds"
  )

  # --- Dimension 4: Data sources ---------------------------------------------
  # (from the "cs", "crvs", and "geo" chunks)
  dim4 <- tar_target(
    name = "dim4",
    command = combine_dim4(params, country_grid),
    format = "rds"
  )

  # --- Dimension 5: Data infrastructure --------------------------------------
  # (from the "legislation_governance", "standards_meta", "snau", "naby",
  # "cnin", "cpiby", "hous", "empl", "cgov", "fina", "mony", "gsbp", "msc",
  # and "finance" chunks)
  dim5 <- tar_target(
    name = "dim5",
    command = combine_dim5(params, country_grid),
    format = "rds"
  )

  # --- Append + save: final SPI data -----------------------------------------
  # (from the "append" and "save" chunks of 01-SPI_data_prep.Rmd)
  # Combines all dimensions, adds population, carries forward SPI values,
  # applies the OECD high-income adjustment, and writes SPI_data.csv/.dta
  # to the staging directory (constraint C7).
  spi_data <- tar_target(
    name = "spi_data",
    command = {
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
  # SPI_index.csv to the staging directory (constraint C7).
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
      s <- build_spl_admin(params)
      save_spl_admin(s, params)
      s
    },
    format = "rds"
  )

  # ===========================================================================
  # TARGET LIST
  # ===========================================================================
  # The order here defines the pipeline graph. Add new targets as phases
  # complete.
  list(
    params,
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
    # Download/checkpoint targets (see download_targets() below)
    download_targets()
  )
}

# =============================================================================
# OPT-IN DOWNLOAD TARGETS
# =============================================================================
# These targets download or verify external data sources.
#
# The API PULL targets (pull_jmp, pull_unsdg) write fresh data to
# 01_raw_data/ and are OPT-IN: they only run when the technical lead sets
# run_downloads = TRUE in config/params.R (or passes it explicitly). By
# default they are no-ops, so tar_make() keeps the replication gate
# deterministic (the committed raw files are the source of truth for the
# 202511 vintage).
#
# The CHECKPOINT targets (checkpoint_*) verify that manually-downloaded
# source files are present and schema-valid. They run by default and fail
# loudly (R8) with download instructions when a file is missing or the
# format changed.
#
# To run the API pulls for a new vintage:
#   config/params.R: run_downloads <- TRUE
#   targets::tar_make(pull_jmp, pull_unsdg)
download_targets <- function() {
  list(
    # --- API pulls (write fresh data to 01_raw_data/; opt-in) ----------------
    tar_target(
      name = "pull_jmp",
      command = {
        if (isTRUE(params$run_downloads)) {
          pull_jmp_water(params)
        } else {
          message("pull_jmp skipped (run_downloads = FALSE). Set run_downloads = TRUE in config/params.R to download fresh JMP data.")
          NULL
        }
      },
      format = "rds"
    ),
    tar_target(
      name = "pull_unsdg",
      command = {
        if (isTRUE(params$run_downloads)) {
          download_unsdg_series(params)
        } else {
          message("pull_unsdg skipped (run_downloads = FALSE). Set run_downloads = TRUE in config/params.R to download fresh UN SDG data.")
          NULL
        }
      },
      format = "rds"
    ),
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
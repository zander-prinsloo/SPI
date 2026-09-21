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

  # --- Stage B: Index --------------------------------------------------------
  # (Populated in Phase 4)

  # --- Stage C: Validation ---------------------------------------------------
  # (Populated in Phase 5)

  # --- Stage D: Misc outputs -------------------------------------------------
  # (Populated in Phase 6)

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
    dim2
  )
}

# Return the target list to targets
pipeline_targets()
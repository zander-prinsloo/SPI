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
  # Reproducibility: {targets} derives a deterministic, target-specific seed
  # from this value, so random draws inside target commands (for example the
  # jitter columns in SPI_quantiles_<year>.csv) reproduce exactly on rebuild.
  # The original Rmd jitter was unseeded, so those columns still differ from
  # the published vintage (documented exception E2, see docs/CHANGELOG.md).
  seed = 2024,
  # Fail loudly: stop the pipeline on the first error (R8). A failing
  # target halts the run so the technical lead sees the error immediately.
  error = "stop"
)

# --- Load pipeline functions -------------------------------------------------
# All functions live in R/ and are sourced here so targets can call them.
# (targets also supports tar_source() for this purpose.)
tar_source(here::here("R"))

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
  # `odin_status` is read separately and removed from `params`, so switching
  # it to "official" in December reruns only the output manifest.
  params <- tar_target(
    name = "params",
    command = {
      loaded <- load_params(params_file, require_country_metadata = TRUE)
      loaded$odin_status <- NULL
      loaded
    },
    format = "rds"
  )
  odin_status <- tar_target(
    name = "odin_status",
    command = read_odin_status(params_file),
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
  d41_manifest_file <- tar_target(
    name = "d41_manifest_file",
    command = params$dim4_1_manifest_file,
    format = "file"
  )
  source_registry_file <- tar_target(
    name = "estimation_source_registry_file",
    command = params$source_registry_file,
    format = "file"
  )
  estimation_source_registry <- tar_target(
    name = "estimation_source_registry",
    command = load_source_registry(estimation_source_registry_file),
    format = "rds"
  )
  collection_input_files <- tar_target(
    name = "collection_input_files",
    command = release_lock_artifacts(
      params,
      registry = estimation_source_registry,
      substitutions = collection_artifact_substitutions(params)
    )$path,
    format = "file"
  )
  collection_gate <- tar_target(
    name = "collection_gate",
    command = {
      collection_input_files
      validate_collection_status(
        collection_status_file,
        expected_source_ids = estimation_source_registry$source_id,
        run_path = collection_run_file,
        parameters_hash = collection_parameters_hash(params)
      )
    },
    format = "rds"
  )
  # The candidate folder is created when missing but never wiped: each writer
  # target below owns its files and {targets} reruns a writer whose file is
  # missing or changed, so partial rebuilds still produce a complete set.
  # With a release lock (written at approval of the provisional outputs),
  # every non-ODIN collection artifact must still match it before outputs
  # are written. Checked on every run; the value is constant, so a passing
  # check never invalidates downstream targets.
  release_lock_verification <- tar_target(
    name = "release_lock_verification",
    command = {
      collection_gate
      verify_release_lock(
        params,
        registry = estimation_source_registry,
        substitutions = collection_artifact_substitutions(params)
      )
      TRUE
    },
    format = "rds",
    cue = tar_cue(mode = "always")
  )
  output_prepare <- tar_target(
    name = "output_prepare",
    command = {
      collection_gate
      release_lock_verification
      ensure_output_candidate(params$estimation_write_dir)
    },
    format = "rds"
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
  # and "aki_combine" chunks of 01-SPI_data_prep.Rmd). The ILO area-name
  # config (correction E6) is a file target, so editing it reruns D1.5.
  ilo_area_names_files <- tar_target(
    name = "ilo_area_names_files",
    command = c(params$ilo_area_crosswalk_file, params$ilo_area_exclusions_file),
    format = "file"
  )
  dim1_5 <- tar_target(
    name = "dim1_5",
    command = {
      collection_gate
      ilo_area_names_files
      combine_dim1_5(params, country_grid)
    },
    format = "rds"
  )

  # --- Dimension 2: Data services --------------------------------------------
  # (from the "idds", "online_access", and "nada" chunks). The ODIN files are
  # file targets read once (`odin_data`) for D2.2 and D4.3, so replacing
  # ODIN_<end_date>.csv (the December swap) reruns only the ODIN targets and
  # their downstream outputs.
  odin_files <- tar_target(
    name = "odin_files",
    command = odin_file_paths(params),
    format = "file"
  )

  odin_data <- tar_target(
    name = "odin_data",
    command = {
      collection_gate
      read_odin_data(params, odin_files)
    },
    format = "rds"
  )

  dim2_core <- tar_target(
    name = "dim2_core",
    command = {
      collection_gate
      combine_dim2_core(params, country_grid)
    },
    format = "rds"
  )

  dim2_odin <- tar_target(
    name = "dim2_odin",
    command = score_odin(odin_data, params),
    format = "rds"
  )

  dim2 <- tar_target(
    name = "dim2",
    command = combine_dim2_parts(dim2_core, dim2_odin, country_grid),
    format = "rds"
  )

  # --- Dimension 3: Data products (UN SDG) -----------------------------------
  # (from the "unstats" chunk). Every per-year score file is a file target so
  # a new or replaced year file invalidates dim3.
  d3_year_files <- tar_target(
    name = "d3_year_files",
    command = d3_year_file_paths(params),
    format = "file"
  )

  dim3 <- tar_target(
    name = "dim3",
    command = {
      collection_gate
      d3_year_files
      combine_dim3(params)
    },
    format = "rds"
  )

  # --- Dimension 4: Data sources ---------------------------------------------
  # (from the "cs", "crvs", and "geo" chunks). D4.3 uses the shared ODIN data.
  dim4_core <- tar_target(
    name = "dim4_core",
    command = {
      collection_gate
      manifest <- jsonlite::read_json(d41_manifest_file, simplifyVector = FALSE)
      validate_dim4_1_manifest(
        d41_manifest_file,
        raw_dir = params$raw_dir,
        end_date = params$end_date,
        valid_iso3c = params$country_metadata$iso3c
      )
      combine_dim4_core(params, country_grid, d41_manifest = manifest)
    },
    format = "rds"
  )

  dim4_geo <- tar_target(
    name = "dim4_geo",
    command = score_geospatial(params, odin_data),
    format = "rds"
  )

  dim4 <- tar_target(
    name = "dim4",
    command = combine_dim4_parts(dim4_core, dim4_geo, country_grid),
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
  # and applies the OECD high-income adjustment. `spi_data_files` writes
  # SPI_data.csv/.dta to the candidate folder after collection validation.
  spi_data <- tar_target(
    name = "spi_data",
    command = {
      output_prepare
      dims <- list(dim1_5, dim2, dim3, dim4, dim5)
      append_spi(dims, params, country_grid)
    },
    format = "rds"
  )
  spi_data_files <- tar_target(
    name = "spi_data_files",
    command = unlist(save_spi(spi_data, params), use.names = FALSE),
    format = "file"
  )

  # --- Stage B: Index --------------------------------------------------------
  # (from the "data", "index_weights", "index", and "saver" chunks of
  # 02-SPI_index.Rmd)
  # Builds the nested index (dimension -> pillar -> overall) from the written
  # SPI_data.csv (the Rmd's round trip); `spi_index_file` writes SPI_index.csv.
  spi_index <- tar_target(
    name = "spi_index",
    command = {
      spi_data_files
      build_index(spi_data, params)
    },
    format = "rds"
  )
  spi_index_file <- tar_target(
    name = "spi_index_file",
    command = save_index(spi_index, params),
    format = "file"
  )

  # --- Stage D: Misc outputs -------------------------------------------------
  # (from misc_scripts/SPI_quantiles.R, SPI_treemap.R, databank.R, and the
  # "aspire" chunk of 01-SPI_data_prep.Rmd). These builders read the written
  # SPI_index.csv / SPI_data.csv, so they depend on the writer file targets.

  # Quantiles and indicators (SPI_quantiles.csv, SPI_quantiles_<year>.csv,
  # SPI_indicators_<year>.csv)
  quantiles <- tar_target(
    name = "quantiles",
    command = {
      spi_index_file
      q <- build_quantiles(spi_index, params)
      q24 <- build_quantiles_2024(spi_index, q, params)
      list(
        quantiles = q,
        quantiles_latest = q24$quantiles_2024,
        indicators_latest = q24$indicators_2024
      )
    },
    format = "rds"
  )
  quantiles_files <- tar_target(
    name = "quantiles_files",
    command = save_quantiles(
      quantiles$quantiles,
      quantiles$quantiles_latest,
      quantiles$indicators_latest,
      params
    ),
    format = "file"
  )

  # Treemap (SPI_treemap.csv)
  treemap <- tar_target(
    name = "treemap",
    command = {
      spi_index_file
      build_treemap(spi_index, params)
    },
    format = "rds"
  )
  treemap_file <- tar_target(
    name = "treemap_file",
    command = save_treemap(treemap, params),
    format = "file"
  )

  # Databank outputs (SPI_databank_country_and_aggregates*.csv, footnotes)
  databank <- tar_target(
    name = "databank",
    command = {
      spi_index_file
      spi_data_files
      build_databank(spi_index, spi_data, params)
    },
    format = "rds"
  )
  databank_files <- tar_target(
    name = "databank_files",
    command = unlist(save_databank(databank, params), use.names = FALSE),
    format = "file"
  )

  # SPL admin data availability (SPL_admin_data_availability.csv)
  spl_admin <- tar_target(
    name = "spl_admin",
    command = {
      output_prepare
      build_spl_admin(params)
    },
    format = "rds"
  )
  spl_admin_file <- tar_target(
    name = "spl_admin_file",
    command = save_spl_admin(spl_admin, params),
    format = "file"
  )

  # Validate the complete candidate set and promote it. Returning the promoted
  # paths as a file target means a missing or edited final file is re-promoted.
  # --- Vintage-diff policy report -------------------------------------------
  # Compares the candidate SPI_data.csv with the previous published vintage
  # for 2004 to end_date - 1. Changes in frozen dimensions (D2, D3, D4.3, D5)
  # block promotion unless approved in the approvals file; refresh-dimension
  # changes (D1.5, D4.1, D4.2) are reported.
  previous_vintage_file <- tar_target(
    name = "previous_vintage_file",
    command = vintage_diff_previous_path(params),
    format = "file"
  )
  vintage_diff_approvals_file <- tar_target(
    name = "vintage_diff_approvals_file",
    command = ensure_vintage_diff_approvals(vintage_diff_approvals_path(params)),
    format = "file"
  )
  vintage_diff <- tar_target(
    name = "vintage_diff",
    command = {
      spi_data_files
      write_vintage_diff(
        params$estimation_write_dir,
        previous_vintage_file,
        vintage_diff_approvals_file,
        params$end_date
      )
    },
    format = "file"
  )

  # Revision evidence for the Working Group (R/revision_report.R): indicator
  # revisions from the vintage diff, index score/rank/quintile revisions
  # against the previous published SPI_index, and reference-year coverage.
  previous_index_file <- tar_target(
    name = "previous_index_file",
    command = revision_previous_index_path(params),
    format = "file"
  )
  revision_report <- tar_target(
    name = "revision_report",
    command = {
      spi_data_files
      spi_index_file
      vintage_diff
      write_revision_report(
        params$estimation_write_dir,
        previous_index_file,
        params$end_date,
        odin_status = odin_status,
        provisional_columns = odin_dependent_columns(params$estimation_write_dir)
      )
    },
    format = "file"
  )

  # --- Provisional-to-final release diff ------------------------------------
  # With a release lock, compares every candidate output with the archived
  # provisional outputs; only ODIN-dependent values may change. Without a lock
  # it does nothing.
  release_diff <- tar_target(
    name = "release_diff",
    command = {
      release_lock_verification
      spi_data_files
      spi_index_file
      quantiles_files
      treemap_file
      databank_files
      spl_admin_file
      write_release_diff(params)
    },
    format = "rds",
    cue = tar_cue(mode = "always")
  )

  output_manifest <- tar_target(
    name = "output_manifest",
    command = {
      release_diff
      vintage_diff
      revision_report
      spi_data_files
      spi_index_file
      quantiles_files
      treemap_file
      databank_files
      spl_admin_file
      validate_output_manifest(
        params$estimation_write_dir,
        params$end_date,
        odin = list(status = odin_status, files = odin_files)
      )
      promote_output_set(
        params$estimation_write_dir,
        params$output_dir,
        params$end_date
      )
    },
    format = "file"
  )

  # ===========================================================================
  # TARGET LIST
  # ===========================================================================
  # The order here defines the pipeline graph. Add new targets as phases
  # complete.
  list(
    params_file,
    params,
    odin_status,
    collection_status_file,
    collection_run_file,
    d41_manifest_file,
    source_registry_file,
    estimation_source_registry,
    collection_input_files,
    collection_gate,
    release_lock_verification,
    output_prepare,
    iso_codes,
    country_grid,
    ilo_area_names_files,
    dim1_5,
    odin_files,
    odin_data,
    dim2_core,
    dim2_odin,
    dim2,
    d3_year_files,
    dim3,
    dim4_core,
    dim4_geo,
    dim4,
    dim5,
    spi_data,
    spi_data_files,
    spi_index,
    spi_index_file,
    quantiles,
    quantiles_files,
    treemap,
    treemap_file,
    databank,
    databank_files,
    spl_admin,
    spl_admin_file,
    previous_vintage_file,
    vintage_diff_approvals_file,
    vintage_diff,
    previous_index_file,
    revision_report,
    release_diff,
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

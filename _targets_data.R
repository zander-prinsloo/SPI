# =============================================================================
# SPI data collection pipeline
# =============================================================================
# This pipeline refreshes and validates source artifacts before estimation.
# Run from the project root with:
#   targets::tar_make(script = "_targets_data.R", store = "_targets_data")
#
# Created: 2026-10-05
# =============================================================================

library(targets)
library(tarchetypes)

tar_option_set(
  seed = 2024,
  error = "stop"
)

tar_source(here::here("R"))

collection_targets <- function() {
  params_file <- tar_target(
    name = "collection_params_file",
    command = "config/params.R",
    format = "file"
  )

  params <- tar_target(
    name = "collection_params",
    command = load_params(collection_params_file),
    format = "rds"
  )

  d41_input_files <- tar_target(
    name = "d41_input_files",
    command = unname(
      dim4_1_artifact_paths(
        collection_params$raw_dir,
        collection_params$end_date
      )$input_files
    ),
    format = "file"
  )

  d41_manual_review_file <- tar_target(
    name = "d41_manual_review_file",
    command = dim4_1_artifact_paths(
      collection_params$raw_dir,
      collection_params$end_date
    )$review_file,
    format = "file"
  )

  d41_manual_validation <- tar_target(
    name = "d41_manual_validation",
    command = {
      d41_input_files
      d41_manual_review_file
      validate_dim4_1_workbooks(
        raw_dir = collection_params$raw_dir,
        end_date = collection_params$end_date
      )
    },
    format = "rds"
  )

  collection_run_start <- tar_target(
    name = "collection_run_start",
    command = start_collection_run(collection_params),
    format = "rds",
    cue = tar_cue(mode = "always")
  )

  registry_file <- tar_target(
    name = "source_registry_file",
    command = "config/source_registry.R",
    format = "file"
  )

  source_registry <- tar_target(
    name = "source_registry",
    command = load_source_registry(source_registry_file),
    format = "rds"
  )

  pip_collection <- tar_target(
    name = "pip_collection",
    command = {
      collection_run_start
      collect_pip_comparability(
        raw_dir = collection_params$raw_dir,
        vintage = collection_params$end_date,
        max_age_days = collection_params$collection_age_warning_days
      )
    },
    format = "rds"
  )

  world_bank_inputs <- tar_target(
    name = "world_bank_inputs",
    command = {
      collection_run_start
      collect_world_bank_inputs(collection_params)
    },
    format = "rds"
  )

  nada_previous_file <- tar_target(
    name = "nada_previous_file",
    command = nada_artifact_paths(
      collection_params$raw_dir,
      collection_params$end_date
    )$previous,
    format = "file"
  )

  nada_review_file <- tar_target(
    name = "nada_review_file",
    command = nada_artifact_paths(
      collection_params$raw_dir,
      collection_params$end_date
    )$review,
    format = "file"
  )

  nada_url_evidence <- tar_target(
    name = "nada_url_evidence",
    command = {
      nada_previous_file
      nada_review_file
      wb <- world_bank_inputs
      country_metadata <- readRDS(wb$countries)
      collect_nada_url_evidence(
        collection_params,
        valid_iso3c = country_metadata$iso3c
      )
    },
    format = "file"
  )

  nada_output <- tar_target(
    name = "nada_output",
    command = {
      nada_previous_file
      nada_review_file
      nada_url_evidence
      wb <- world_bank_inputs
      country_metadata <- readRDS(wb$countries)
      paths <- nada_artifact_paths(
        collection_params$raw_dir,
        collection_params$end_date
      )
      previous <- .read_nada_file(paths$previous, "NADA PREVIOUS VINTAGE")
      review <- read_manual_review(paths$review, nada_review_spec())
      evidence <- readr::read_csv(paths$evidence, show_col_types = FALSE)
      result <- build_nada_vintage(
        previous = previous,
        evidence = evidence,
        review = review,
        end_date = collection_params$end_date,
        first_collected_vintage = collection_params$first_collected_vintage,
        valid_iso3c = country_metadata$iso3c
      )
      written <- write_nada_vintage(
        result = result,
        paths = paths,
        end_date = collection_params$end_date,
        first_collected_vintage = collection_params$first_collected_vintage
      )
      written$output
    },
    format = "file"
  )

  d41_preprocess <- tar_target(
    name = "d41_preprocess",
    command = {
      d41_manual_validation
      wb <- world_bank_inputs
      country_metadata <- readRDS(wb$countries)
      preprocess_dim4_1(
        raw_dir = collection_params$raw_dir,
        end_date = collection_params$end_date,
        country_metadata = country_metadata
      )
    },
    format = "file"
  )

  d41_catalogue_collection <- tar_target(
    name = "d41_catalogue_collection",
    command = {
      d41_preprocess
      d41_manual_review_file
      wb <- world_bank_inputs
      collection_params$country_metadata <- readRDS(wb$countries)
      collect_dim4_1_catalogue(collection_params)
    },
    format = "rds",
    cue = tar_cue(mode = "always")
  )

  d41_manifest <- tar_target(
    name = "d41_manifest",
    command = {
      collection_run_start
      d41_preprocess
      catalogue <- d41_catalogue_collection
      wb <- world_bank_inputs
      country_metadata <- readRDS(wb$countries)
      manifest <- dim4_1_build_manifest(
        raw_dir = collection_params$raw_dir,
        end_date = collection_params$end_date,
        country_metadata = country_metadata
      )
      manifest$catalogue <- catalogue
      write_dim4_1_manifest(
        manifest,
        collection_params$dim4_1_manifest_file
      )
      manifest
    },
    format = "rds",
    cue = tar_cue(mode = "always")
  )

  d41_manifest_file <- tar_target(
    name = "d41_manifest_file",
    command = {
      d41_manifest
      collection_params$dim4_1_manifest_file
    },
    format = "file",
    cue = tar_cue(mode = "always")
  )

  manual_checkpoints <- tar_target(
    name = "manual_checkpoints",
    command = {
      collection_run_start
      run_collection_checkpoints(collection_params)
    },
    format = "rds",
    cue = tar_cue(mode = "always")
  )

  jmp_collection <- tar_target(
    name = "jmp_collection",
    command = {
      collection_run_start
      world_bank_inputs
      pull_jmp_water(collection_params)
    },
    format = "rds"
  )

  unsdg_collection <- tar_target(
    name = "unsdg_collection",
    command = {
      collection_run_start
      download_unsdg_series(collection_params)
    },
    format = "rds"
  )

  sdg_collection <- tar_target(
    name = "sdg_collection",
    command = {
      collection_run_start
      collect_sdg_pipeline(collection_params)
    },
    format = "rds"
  )

  collection_status <- tar_target(
    name = "collection_status",
    command = {
      run <- collection_run_start
      d41_manifest
      d41_manifest_file
      pip_collection
      wb <- world_bank_inputs
      nada_output
      validate_nada_collection_artifact(
        collection_params,
        valid_iso3c = readRDS(wb$countries)$iso3c
      )
      nada_paths <- nada_artifact_paths(
        collection_params$raw_dir,
        collection_params$end_date
      )
      nada_warnings <- read_nada_manifest_warnings(nada_paths$manifest)
      manual_checkpoints
      jmp_collection
      unsdg_collection
      sdg_collection
      status <- evaluate_collection_status(
        registry = source_registry,
        collection_root = collection_params$raw_dir,
        end_date = collection_params$end_date,
        run_id = run$run_id,
        parameters_hash = run$parameters_hash
      )
      write_collection_status_report(
        status,
        csv_path = collection_params$collection_status_file,
        markdown_path = file.path(collection_params$collection_dir, "collection_status.md"),
        warnings = nada_warnings
      )
      complete_collection_run(collection_params, run)
      status
    },
    format = "rds",
    cue = tar_cue(mode = "always")
  )

  list(
    params_file,
    params,
    d41_input_files,
    d41_manual_review_file,
    d41_manual_validation,
    collection_run_start,
    registry_file,
    source_registry,
    pip_collection,
    world_bank_inputs,
    nada_previous_file,
    nada_review_file,
    nada_url_evidence,
    nada_output,
    d41_preprocess,
    d41_catalogue_collection,
    d41_manifest,
    d41_manifest_file,
    manual_checkpoints,
    jmp_collection,
    unsdg_collection,
    sdg_collection,
    collection_status
  )
}

collection_targets()

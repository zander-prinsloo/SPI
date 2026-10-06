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

for (f in list.files("R", pattern = "[.]R$", full.names = TRUE)) {
  source(f)
}

collection_targets <- function() {
  params_file <- tar_target(
    name = "collection_params_file",
    command = "config/params.R",
    format = "file"
  )

  params <- tar_target(
    name = "collection_params",
    command = load_params(params_file),
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
    command = load_source_registry(registry_file),
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
      pip_collection
      world_bank_inputs
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
        markdown_path = file.path(collection_params$collection_dir, "collection_status.md")
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
    collection_run_start,
    registry_file,
    source_registry,
    pip_collection,
    world_bank_inputs,
    manual_checkpoints,
    jmp_collection,
    unsdg_collection,
    sdg_collection,
    collection_status
  )
}

collection_targets()

# =============================================================================
# SPI data collection pipeline
# =============================================================================
# This pipeline refreshes and validates source artifacts before estimation.
# Completion of reporting does not imply source acceptance: inspect both the
# matching run marker and all blocking status rows. See docs/user-guide.md.
# run_downloads controls the D4.1 catalogue refresh only; other collectors may
# fetch missing/stale responses through their caches.
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
        max_age_days = collection_params$collection_age_warning_days,
        ppp_version = collection_params$pip_ppp_version,
        release_lock = pip_locked_release(collection_params)
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

  # Validates (or, with run_downloads, refreshes) the raw catalogue companions
  # and normalizes them to CLASS.xlsx names plus ISO3 codes in
  # 4.1_SOCS/collection/ (config/d41_country_crosswalk.csv and
  # config/d41_companion_exclusions.csv).
  d41_catalogue_collection <- tar_target(
    name = "d41_catalogue_collection",
    command = {
      d41_preprocess
      d41_manual_review_file
      wb <- world_bank_inputs
      collect_dim4_1_catalogue(
        collection_params,
        valid_iso3c = readRDS(wb$countries)$iso3c
      )
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
      d41_preprocess
      run_collection_checkpoints(collection_params)
    },
    format = "rds",
    cue = tar_cue(mode = "always")
  )

  jmp_collection <- tar_target(
    name = "jmp_collection",
    command = {
      collection_run_start
      wb <- world_bank_inputs
      pull_jmp_water(
        collection_params,
        country_metadata = readRDS(wb$countries)
      )
    },
    format = "rds"
  )

  d5_2_empl <- tar_target(
    name = "d5_2_empl",
    command = {
      collection_run_start
      collect_empl_vintage(collection_params)
    },
    format = "rds"
  )

  d5_2_cnin <- tar_target(
    name = "d5_2_cnin",
    command = {
      collection_run_start
      collect_cnin_vintage(collection_params)
    },
    format = "rds"
  )

  d5_2_fina <- tar_target(
    name = "d5_2_fina",
    command = {
      collection_run_start
      collect_fina_vintage(collection_params)
    },
    format = "rds"
  )

  gsbp_previous_file <- tar_target(
    name = "gsbp_previous_file",
    command = gsbp_artifact_paths(collection_params$raw_dir, collection_params$end_date)$previous,
    format = "file"
  )

  gsbp_desk_review_file <- tar_target(
    name = "gsbp_desk_review_file",
    command = gsbp_artifact_paths(collection_params$raw_dir, collection_params$end_date)$desk_review,
    format = "file"
  )

  gsbp_review_file <- tar_target(
    name = "gsbp_review_file",
    command = gsbp_artifact_paths(collection_params$raw_dir, collection_params$end_date)$review,
    format = "file"
  )

  gsbp_output <- tar_target(
    name = "gsbp_output",
    command = {
      collection_run_start
      gsbp_previous_file
      gsbp_desk_review_file
      gsbp_review_file
      wb <- world_bank_inputs
      collect_gsbp_vintage(
        collection_params,
        country_metadata = readRDS(wb$countries)
      )
    },
    format = "rds"
  )

  review_candidates <- tar_target(
    name = "review_candidates",
    command = {
      d41_manifest
      assemble_review_candidates(
        list(
          d5_2_empl$candidates,
          d5_2_cnin$candidates,
          d5_2_fina$candidates,
          gsbp_output$candidates,
          d41_review_candidates(collection_params)
        ),
        file.path(
          collection_params$collection_dir,
          sprintf("review_candidates_%d.csv", as.integer(collection_params$end_date))
        )
      )
    },
    format = "file"
  )

  oecd_collection <- tar_target(
    name = "oecd_collection",
    command = {
      collection_run_start
      collect_oecd_sdg(collection_params)
    },
    format = "rds"
  )

  unsdg_collection <- tar_target(
    name = "unsdg_collection",
    command = {
      collection_run_start
      wb <- world_bank_inputs
      download_unsdg_series(
        collection_params,
        country_metadata = readRDS(wb$countries)
      )
    },
    format = "rds"
  )

  sdg_collection <- tar_target(
    name = "sdg_collection",
    command = {
      collection_run_start
      oecd_collection
      wb <- world_bank_inputs
      collect_d3_scores(
        collection_params,
        country_metadata = readRDS(wb$countries)
      )
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
      empl_warnings <- if (length(d5_2_empl$unmatched) > 0L) {
        data.frame(
          source_id = "d5_2_empl",
          message = paste0(
            "ILO catalogue countries without an ISO3 code were dropped (as in the notebook): ",
            paste(d5_2_empl$unmatched, collapse = "; ")
          ),
          stringsAsFactors = FALSE
        )
      } else {
        NULL
      }
      collection_warnings <- rbind(nada_warnings, gsbp_output$warnings, empl_warnings)
      manual_checkpoints
      jmp_collection
      d5_2_empl
      d5_2_cnin
      d5_2_fina
      oecd_collection
      unsdg_collection
      sdg_collection
      status <- evaluate_collection_status(
        registry = source_registry,
        collection_root = collection_params$raw_dir,
        end_date = collection_params$end_date,
        run_id = run$run_id,
        parameters_hash = run$parameters_hash,
        substitutions = collection_artifact_substitutions(collection_params),
        attestations = read_collection_attestations(
          collection_attestation_path(collection_params)
        )
      )
      write_collection_status_report(
        status,
        csv_path = collection_params$collection_status_file,
        markdown_path = file.path(collection_params$collection_dir, "collection_status.md"),
        warnings = collection_warnings,
        candidates = readr::read_csv(review_candidates, show_col_types = FALSE)
      )
      # With a release lock (written at approval of the provisional
      # outputs), every non-ODIN artifact must still match it.
      verify_release_lock(
        collection_params,
        registry = source_registry,
        substitutions = collection_artifact_substitutions(collection_params)
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
    d5_2_empl,
    d5_2_cnin,
    d5_2_fina,
    gsbp_previous_file,
    gsbp_desk_review_file,
    gsbp_review_file,
    gsbp_output,
    review_candidates,
    oecd_collection,
    unsdg_collection,
    sdg_collection,
    collection_status
  )
}

collection_targets()

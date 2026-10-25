# =============================================================================
# Collection and estimation pipeline contract tests
# =============================================================================
# Created: 2026-10-05
# =============================================================================

library(testthat)

project_root <- here::here()

# The collection script must expose a separate target list and the estimation
# script must validate the collection manifest before producing final outputs.
test_that("collection pipeline exposes a separate target graph", {
  expect_true(file.exists(file.path(project_root, "_targets_data.R")))

  collection_env <- new.env(parent = globalenv())
  sys.source(file.path(project_root, "_targets_data.R"), envir = collection_env)

  expect_true(exists("collection_targets", envir = collection_env, inherits = FALSE))
  expect_type(collection_env$collection_targets(), "list")

  manifest <- targets::tar_manifest(
    script = file.path(project_root, "_targets_data.R")
  )
  expect_true(all(c(
    "d41_input_files",
    "d41_manual_review_file",
    "d41_manual_validation",
    "d41_preprocess",
    "d41_catalogue_collection",
    "d41_manifest",
    "d41_manifest_file",
    "nada_previous_file",
    "nada_review_file",
    "nada_url_evidence",
    "nada_output"
  ) %in% manifest$name))

  estimation_manifest <- targets::tar_manifest(
    script = file.path(project_root, "_targets.R")
  )
  expect_true("d41_manifest_file" %in% estimation_manifest$name)
})

test_that("estimation pipeline exposes a collection status gate", {
  expect_true(file.exists(file.path(project_root, "R", "collection_status.R")))

  source(file.path(project_root, "R", "collection_status.R"))

  expect_true(exists("validate_collection_status", mode = "function"))
  expect_error(
    validate_collection_status(file.path(tempdir(), "missing-collection-status.csv")),
    "COLLECTION STATUS FILE NOT FOUND"
  )
})

test_that("estimation registry target depends on its declared file target", {
  network <- targets::tar_network(
    script = file.path(project_root, "_targets.R"),
    targets_only = TRUE
  )
  edges <- network$edges
  expect_true(any(
    edges$from == "estimation_source_registry_file" &
      edges$to == "estimation_source_registry"
  ))
})

test_that("estimation outputs are written by file targets and promoted incrementally", {
  manifest <- targets::tar_manifest(
    script = file.path(project_root, "_targets.R"),
    fields = c("name", "format", "cue_mode")
  )
  writers <- c(
    "spi_data_files", "spi_index_file", "quantiles_files",
    "treemap_file", "databank_files", "spl_admin_file"
  )
  expect_true(all(writers %in% manifest$name))
  expect_true(all(manifest$format[manifest$name %in% writers] == "file"))
  expect_equal(manifest$format[manifest$name == "output_manifest"], "file")
  expect_false(manifest$cue_mode[manifest$name == "output_prepare"] == "always")

  network <- targets::tar_network(
    script = file.path(project_root, "_targets.R"),
    targets_only = TRUE
  )
  upstream <- network$edges$from[network$edges$to == "output_manifest"]
  expect_true(all(writers %in% upstream))
})

test_that("collection checkpoints run after D4.1 preprocessing without modifying parameters", {
  network <- targets::tar_network(
    script = file.path(project_root, "_targets_data.R"),
    targets_only = TRUE
  )
  expect_true(any(network$edges$from == "d41_preprocess" & network$edges$to == "manual_checkpoints"))

  manifest <- targets::tar_manifest(script = file.path(project_root, "_targets_data.R"))
  catalogue_command <- manifest$command[manifest$name == "d41_catalogue_collection"]
  expect_false(grepl("collection_params$country_metadata <-", catalogue_command, fixed = TRUE))

  source(file.path(project_root, "R", "collection_checkpoints.R"))
  expect_false(grepl("verify_microdata_files", paste(deparse(run_collection_checkpoints), collapse = "\n")))
})

test_that("UN SDG series collection joins the saved country snapshot", {
  network <- targets::tar_network(
    script = file.path(project_root, "_targets_data.R"),
    targets_only = TRUE
  )
  expect_true(any(network$edges$from == "world_bank_inputs" & network$edges$to == "unsdg_collection"))
})

test_that("OECD SDG collection feeds the collection status", {
  network <- targets::tar_network(
    script = file.path(project_root, "_targets_data.R"),
    targets_only = TRUE
  )
  expect_true(any(network$edges$from == "oecd_collection" & network$edges$to == "collection_status"))
})

test_that("the D3 scorer runs after the OECD collection and country snapshot", {
  network <- targets::tar_network(
    script = file.path(project_root, "_targets_data.R"),
    targets_only = TRUE
  )
  upstream <- network$edges$from[network$edges$to == "sdg_collection"]
  expect_true(all(c("oecd_collection", "world_bank_inputs") %in% upstream))
})

# --- ODIN as tracked inputs (202611 plan, Step 19) ----------------------------

downstream_targets <- function(edges, start) {
  seen <- character()
  frontier <- start
  while (length(frontier) > 0L) {
    following <- setdiff(edges$to[edges$from %in% frontier], seen)
    seen <- c(seen, following)
    frontier <- following
  }
  seen
}

test_that("replacing an ODIN file invalidates only ODIN targets and their outputs", {
  script <- file.path(project_root, "_targets.R")
  edges <- targets::tar_network(script = script, targets_only = TRUE)$edges
  affected <- downstream_targets(edges, "odin_files")
  expect_true(all(c(
    "odin_data", "dim2_odin", "dim4_geo", "dim2", "dim4", "spi_data",
    "spi_data_files", "spi_index", "quantiles", "treemap"
  ) %in% affected))
  expect_false(any(c(
    "params", "collection_gate", "country_grid", "dim1_5", "dim2_core",
    "dim3", "dim4_core", "dim5"
  ) %in% affected))

  manifest <- targets::tar_manifest(script = script)
  reads_odin <- manifest$name[grepl(
    "ODIN_|read_odin_data|score_odin|score_geospatial|odin_file_paths",
    manifest$command
  )]
  expect_setequal(reads_odin, c("odin_files", "odin_data", "dim2_odin", "dim4_geo"))
  expect_identical(
    manifest$command[manifest$name == "dim2"],
    "combine_dim2_parts(dim2_core, dim2_odin, country_grid)"
  )
  expect_identical(
    manifest$command[manifest$name == "dim4"],
    "combine_dim4_parts(dim4_core, dim4_geo, country_grid)"
  )
})

test_that("editing the ILO area-name config reruns D1.5 (E6)", {
  script <- file.path(project_root, "_targets.R")
  manifest <- targets::tar_manifest(script = script)
  expect_match(manifest$command[manifest$name == "ilo_area_names_files"], "ilo_area_crosswalk_file", fixed = TRUE)
  expect_match(manifest$command[manifest$name == "ilo_area_names_files"], "ilo_area_exclusions_file", fixed = TRUE)
  edges <- targets::tar_network(script = script, targets_only = TRUE)$edges
  expect_true(any(edges$from == "ilo_area_names_files" & edges$to == "dim1_5"))
})

test_that("the ODIN status reaches only the labelling outputs", {
  # Switching to "official" relabels the outputs (manifest, provisional
  # marker, revision evidence); no estimation target reruns.
  script <- file.path(project_root, "_targets.R")
  edges <- targets::tar_network(script = script, targets_only = TRUE)$edges
  expect_setequal(downstream_targets(edges, "odin_status"), c("revision_report", "output_manifest"))
  manifest <- targets::tar_manifest(script = script)
  expect_match(manifest$command[manifest$name == "params"], "odin_status <- NULL", fixed = TRUE)
})

test_that("read_odin_status accepts only provisional or official", {
  source(file.path(project_root, "R", "setup.R"))
  path <- withr::local_tempfile(fileext = ".R")
  writeLines('odin_status <- "official"', path)
  expect_identical(read_odin_status(path), "official")
  writeLines('odin_status <- "draft"', path)
  expect_error(read_odin_status(path), "ODIN STATUS MUST BE 'provisional' OR 'official'")
  writeLines("end_date <- 2025", path)
  expect_error(read_odin_status(path), "ODIN STATUS MUST BE")
})

test_that("promotion waits for the vintage-diff policy report", {
  edges <- targets::tar_network(script = file.path(project_root, "_targets.R"), targets_only = TRUE)$edges
  expect_true(any(edges$from == "vintage_diff" & edges$to == "output_manifest"))
  expect_true(any(edges$from == "spi_data_files" & edges$to == "vintage_diff"))
  expect_true(any(edges$from == "vintage_diff_approvals_file" & edges$to == "vintage_diff"))
})

test_that("the revision report is built from the vintage diff and the outputs before promotion", {
  edges <- targets::tar_network(script = file.path(project_root, "_targets.R"), targets_only = TRUE)$edges
  expect_true(any(edges$from == "vintage_diff" & edges$to == "revision_report"))
  expect_true(any(edges$from == "spi_index_file" & edges$to == "revision_report"))
  expect_true(any(edges$from == "previous_index_file" & edges$to == "revision_report"))
  expect_true(any(edges$from == "odin_status" & edges$to == "revision_report"))
  expect_true(any(edges$from == "revision_report" & edges$to == "output_manifest"))
})

test_that("the release lock is verified before promotion and pins the PIP release", {
  estimation <- targets::tar_manifest(script = file.path(project_root, "_targets.R"))
  edges <- targets::tar_network(script = file.path(project_root, "_targets.R"), targets_only = TRUE)$edges
  expect_true(any(edges$from == "release_lock_verification" & edges$to == "output_prepare"))
  expect_match(estimation$command[estimation$name == "release_lock_verification"], "verify_release_lock", fixed = TRUE)
  collection <- targets::tar_manifest(script = file.path(project_root, "_targets_data.R"))
  expect_match(collection$command[collection$name == "pip_collection"], "release_lock = pip_locked_release(collection_params)", fixed = TRUE)
  status_command <- collection$command[collection$name == "collection_status"]
  expect_match(status_command, "verify_release_lock", fixed = TRUE)
  expect_lt(regexpr("verify_release_lock", status_command, fixed = TRUE), regexpr("complete_collection_run", status_command, fixed = TRUE))
})

test_that("collection artifacts are content dependencies of estimation", {
  script <- file.path(project_root, "_targets.R")
  edges <- targets::tar_network(script = script, targets_only = TRUE)$edges
  expect_true(any(edges$from == "collection_input_files" & edges$to == "collection_gate"))
  expect_match(
    targets::tar_manifest(script = script)$command[
      targets::tar_manifest(script = script)$name == "collection_input_files"
    ],
    "release_lock_artifacts",
    fixed = TRUE
  )
})

test_that("promotion waits for the provisional-to-final release diff", {
  edges <- targets::tar_network(script = file.path(project_root, "_targets.R"), targets_only = TRUE)$edges
  expect_true(any(edges$from == "release_diff" & edges$to == "output_manifest"))
  for (writer in c("spi_data_files", "spi_index_file", "quantiles_files", "treemap_file", "databank_files", "spl_admin_file")) {
    expect_true(any(edges$from == writer & edges$to == "release_diff"), info = writer)
  }
})

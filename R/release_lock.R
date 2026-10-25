# =============================================================================
# Release lock for the provisional-to-final (ODIN) update
# =============================================================================
# At approval of the provisional outputs, write_release_lock() records the
# SHA-256 of every non-ODIN collection artifact (resolved through the source
# registry, plus the World Bank snapshot), the PIP release, and the approved
# outputs, which it archives under 03_output_data/releases/<label>/. While
# the lock exists, collection uses the locked PIP release and both pipelines
# stop when any non-ODIN artifact differs from the lock.
#
# Created: 2026-10-24
# =============================================================================

.release_lock_excluded_sources <- c("d2_2_odin", "d4_3_odin")

#' Path of the release lock for the reference year.
#'
#' @param params Pipeline parameters.
#' @return `<collection_dir>/release_lock_<end_date>.json`.
#' @export
release_lock_path <- function(params) {
  file.path(params$collection_dir, sprintf("release_lock_%d.json", as.integer(params$end_date)))
}

#' Read the release lock, or NULL when none exists.
#'
#' @param params Pipeline parameters.
#' @return The lock list or NULL.
#' @export
read_release_lock <- function(params) {
  path <- release_lock_path(params)
  if (!file.exists(path)) {
    return(NULL)
  }
  lock <- jsonlite::read_json(path, simplifyVector = FALSE)
  .release_lock_validate(lock, path)
  if (!identical(as.integer(lock$end_date), as.integer(params$end_date))) {
    stop("RELEASE LOCK VINTAGE MISMATCH: ", path, call. = FALSE)
  }
  lock
}

.release_lock_digest <- function(lock) {
  candidate <- lock
  candidate$lock_sha256 <- NULL
  digest::digest(
    as.character(jsonlite::toJSON(
      candidate,
      auto_unbox = TRUE,
      digits = NA,
      null = "null",
      pretty = FALSE
    )),
    algo = "sha256",
    serialize = FALSE
  )
}

.release_lock_validate <- function(lock, path) {
  required <- c(
    "schema_version", "end_date", "approved_by", "approved_at",
    "odin_status", "pip_release", "excluded_sources", "artifacts",
    "archive", "outputs", "controls", "lock_sha256"
  )
  missing <- setdiff(required, names(lock))
  if (length(missing) > 0L) {
    stop(
      "RELEASE LOCK SCHEMA INVALID: missing ",
      paste(missing, collapse = ", "), " in ", path,
      call. = FALSE
    )
  }
  if (!identical(lock$schema_version, "spi-release-lock-v2")) {
    stop("RELEASE LOCK SCHEMA VERSION UNSUPPORTED in ", path, call. = FALSE)
  }
  if (!identical(as.character(lock$lock_sha256), .release_lock_digest(lock))) {
    stop("RELEASE LOCK SELF-HASH MISMATCH: ", path, call. = FALSE)
  }
  invisible(TRUE)
}

#' Locked PIP release identifier, or NULL without a lock.
#'
#' @param params Pipeline parameters.
#' @return Character release identifier or NULL.
#' @export
pip_locked_release <- function(params) {
  lock <- read_release_lock(params)
  if (is.null(lock)) NULL else lock$pip_release
}

# Registry paths may name a folder (for example 4.1_SOCS/raw/): lock every
# file in it, except hidden files (.DS_Store) and Excel lock files (~$...),
# which appear and change without any data change.
.release_lock_expand <- function(paths) {
  unlist(lapply(paths, function(path) {
    if (!dir.exists(path)) {
      return(path)
    }
    files <- list.files(sub("/+$", "", path), recursive = TRUE, full.names = TRUE, all.files = FALSE)
    files[!grepl("^~[$]", basename(files))]
  }), use.names = FALSE)
}

.release_lock_relative <- function(path, raw_dir) {
  path <- gsub("/{2,}", "/", path)
  prefix <- paste0(sub("/+$", "", raw_dir), "/")
  if (startsWith(path, prefix)) {
    return(substring(path, nchar(prefix) + 1L))
  }
  root <- normalizePath(raw_dir, winslash = "/", mustWork = TRUE)
  parent <- normalizePath(dirname(path), winslash = "/", mustWork = FALSE)
  absolute <- file.path(parent, basename(path))
  if (!startsWith(absolute, paste0(root, "/"))) {
    stop("RELEASE LOCK ARTIFACT OUTSIDE raw_dir: ", path, call. = FALSE)
  }
  substring(absolute, nchar(root) + 2L)
}

#' Non-ODIN collection artifacts covered by the release lock.
#'
#' @param params Pipeline parameters.
#' @param registry Source registry.
#' @param substitutions Placeholder values for registry paths.
#' @return A data frame with `source_id` and `path` (relative to raw_dir).
#' @export
release_lock_artifacts <- function(params,
                                   registry = load_source_registry(params$source_registry_file),
                                   substitutions = collection_artifact_substitutions(params),
                                   include_sidecars = FALSE) {
  rows <- lapply(seq_len(nrow(registry)), function(index) {
    source <- registry[index, , drop = FALSE]
    if (source$source_type[[1]] == "unavailable" ||
        source$source_id[[1]] %in% .release_lock_excluded_sources) {
      return(NULL)
    }
    relative <- source$normalized_path[[1]]
    if (is.na(relative) || !nzchar(relative)) {
      relative <- if ("input_path" %in% names(source)) source$input_path[[1]] else NA_character_
    }
    if (is.na(relative) || !nzchar(relative)) {
      return(NULL)
    }
    paths <- resolve_collection_artifact_paths(relative, params$raw_dir, params$end_date, substitutions)
    paths <- .release_lock_expand(paths)
    if (length(paths) == 0L) {
      return(NULL)
    }
    data.frame(source_id = source$source_id[[1]], path = paths, stringsAsFactors = FALSE)
  })
  world_bank <- list.files(
    file.path(params$collection_dir, "world_bank"),
    pattern = "[.]rds$",
    full.names = TRUE
  )
  rows <- c(rows, list(data.frame(source_id = rep("world_bank_snapshot", length(world_bank)), path = world_bank, stringsAsFactors = FALSE)))
  artifacts <- do.call(rbind, rows)
  artifacts$relative <- vapply(artifacts$path, .release_lock_relative, character(1), raw_dir = params$raw_dir)
  artifacts <- artifacts[!duplicated(artifacts$relative), , drop = FALSE]
  if (isTRUE(include_sidecars)) {
    sidecars <- lapply(seq_len(nrow(artifacts)), function(index) {
      sidecar <- artifact_provenance_path(artifacts$path[[index]])
      if (!file.exists(sidecar)) {
        return(NULL)
      }
      data.frame(
        source_id = paste0(artifacts$source_id[[index]], "__provenance"),
        relative = .release_lock_relative(sidecar, params$raw_dir),
        path = sidecar,
        stringsAsFactors = FALSE
      )
    })
    sidecars <- sidecars[!vapply(sidecars, is.null, logical(1))]
    if (length(sidecars) > 0L) {
      artifacts <- rbind(artifacts, do.call(rbind, sidecars))
    }
  }
  artifacts[order(artifacts$relative, method = "radix"), c("source_id", "relative", "path"), drop = FALSE]
}

.release_lock_strip_volatile <- function(value) {
  if (is.list(value)) {
    keep <- if (is.null(names(value))) rep(TRUE, length(value)) else !grepl("(_at|_seconds)$", names(value))
    lapply(value[keep], .release_lock_strip_volatile)
  } else {
    value
  }
}

#' SHA-256 of an artifact; JSON files without their timestamp fields.
#'
#' Collection manifests are rewritten on every run with new `*_at` and
#' `*_seconds` values; hashing their remaining content keeps a rerun with
#' unchanged data equal to the lock.
#'
#' @param path Artifact path.
#' @return Hex SHA-256 string.
#' @export
release_lock_hash <- function(path) {
  if (grepl("[.]json$", path, ignore.case = TRUE)) {
    content <- .release_lock_strip_volatile(jsonlite::read_json(path, simplifyVector = FALSE))
    return(digest::digest(
      as.character(jsonlite::toJSON(content, auto_unbox = TRUE, digits = NA, null = "null")),
      algo = "sha256",
      serialize = FALSE
    ))
  }
  digest::digest(path, algo = "sha256", file = TRUE)
}

#' Lock the approved release.
#'
#' Archives the promoted outputs and records the hashes of every non-ODIN
#' collection artifact, the PIP release and the outputs. Never overwrites an
#' existing lock or archive.
#'
#' @param params Pipeline parameters.
#' @param approved_by Name of the approver.
#' @param registry Source registry.
#' @param substitutions Placeholder values for registry paths.
#' @param release_label Archive folder name (default "<end_date + 1>11-<odin_status>").
#' @return The lock path.
#' @export
write_release_lock <- function(params, approved_by,
                               registry = load_source_registry(params$source_registry_file),
                               substitutions = collection_artifact_substitutions(params),
                               release_label = NULL) {
  if (missing(approved_by) || !nzchar(trimws(approved_by))) {
    stop("RELEASE LOCK REQUIRES approved_by.", call. = FALSE)
  }
  lock_path <- release_lock_path(params)
  if (file.exists(lock_path)) {
    stop("RELEASE LOCK ALREADY EXISTS: ", lock_path, call. = FALSE)
  }
  manifest_path <- file.path(params$output_dir, "_estimation_manifest.json")
  if (!file.exists(manifest_path)) {
    stop("RELEASE LOCK REQUIRES THE PROMOTED OUTPUTS: ", manifest_path, call. = FALSE)
  }
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
  if (!identical(as.integer(manifest$end_date), as.integer(params$end_date))) {
    stop("RELEASE LOCK: OUTPUT MANIFEST VINTAGE MISMATCH", call. = FALSE)
  }
  odin_status <- if (is.null(manifest$odin_status)) NA_character_ else manifest$odin_status
  files <- c(manifest$files, "_estimation_manifest.json", if (identical(odin_status, "provisional")) odin_marker_file)
  missing <- files[!file.exists(file.path(params$output_dir, files))]
  if (length(missing) > 0L) {
    stop("RELEASE LOCK REQUIRES THE PROMOTED OUTPUTS: missing ", paste(missing, collapse = ", "), call. = FALSE)
  }

  artifacts <- release_lock_artifacts(
    params,
    registry,
    substitutions,
    include_sidecars = TRUE
  )
  absent <- artifacts$relative[!file.exists(artifacts$path)]
  if (length(absent) > 0L) {
    stop("RELEASE LOCK: COLLECTION ARTIFACT(S) MISSING: ", paste(absent, collapse = ", "), call. = FALSE)
  }
  pip <- artifacts$path[artifacts$source_id == "d1_5_pip"]
  pip_release <- if (length(pip) == 1L) read_artifact_provenance(pip)$release_identifier else NULL
  if (is.null(pip_release) || is.na(pip_release) || !nzchar(pip_release)) {
    stop("RELEASE LOCK: PIP RELEASE NOT RECORDED in the PIP artifact provenance.", call. = FALSE)
  }
  controls <- c(
    params$collection_status_file,
    params$collection_run_file,
    collection_attestation_path(params)
  )
  controls <- unique(controls[!is.na(controls) & nzchar(controls)])
  missing_controls <- controls[!file.exists(controls)]
  if (length(missing_controls) > 0L) {
    stop(
      "RELEASE LOCK: CONTROL FILE(S) MISSING: ",
      paste(missing_controls, collapse = ", "),
      call. = FALSE
    )
  }

  if (is.null(release_label)) {
    release_label <- sprintf("%d11-%s", as.integer(params$end_date) + 1L, odin_status)
  }
  archive <- file.path(params$output_dir, "releases", release_label)
  if (dir.exists(archive)) {
    stop("RELEASE ARCHIVE ALREADY EXISTS: ", archive, call. = FALSE)
  }
  dir.create(archive, recursive = TRUE)
  if (!all(file.copy(file.path(params$output_dir, files), archive, copy.date = TRUE))) {
    unlink(archive, recursive = TRUE)
    stop("RELEASE ARCHIVE COULD NOT BE WRITTEN: ", archive, call. = FALSE)
  }
  outputs <- lapply(files, function(file) {
    list(file = file, sha256 = digest::digest(file.path(archive, file), algo = "sha256", file = TRUE))
  })

  lock <- list(
    schema_version = "spi-release-lock-v2",
    end_date = as.integer(params$end_date),
    approved_by = approved_by,
    approved_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    odin_status = odin_status,
    pip_release = pip_release,
    excluded_sources = .release_lock_excluded_sources,
    artifacts = lapply(seq_len(nrow(artifacts)), function(index) {
      list(
        source_id = artifacts$source_id[[index]],
        path = artifacts$relative[[index]],
        sha256 = release_lock_hash(artifacts$path[[index]])
      )
    }),
    controls = lapply(controls, function(path) {
      list(
        path = .release_lock_relative(path, params$raw_dir),
        sha256 = digest::digest(path, algo = "sha256", file = TRUE)
      )
    }),
    archive = file.path(basename(params$output_dir), "releases", release_label),
    outputs = outputs
  )
  lock$lock_sha256 <- .release_lock_digest(lock)
  dir.create(dirname(lock_path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(lock, lock_path, auto_unbox = TRUE, pretty = TRUE)
  lock_path
}

#' Verify the release lock; stop when a non-ODIN artifact changed.
#'
#' @param params Pipeline parameters.
#' @param registry Source registry.
#' @param substitutions Placeholder values for registry paths.
#' @return The lock invisibly, or NULL when no lock exists.
#' @export
verify_release_lock <- function(params,
                                registry = load_source_registry(params$source_registry_file),
                                substitutions = collection_artifact_substitutions(params)) {
  lock <- read_release_lock(params)
  if (is.null(lock)) {
    return(NULL)
  }
  locked <- vapply(lock$artifacts, `[[`, character(1), "path")
  expected <- stats::setNames(vapply(lock$artifacts, `[[`, character(1), "sha256"), locked)
  current <- release_lock_artifacts(
    params,
    registry,
    substitutions,
    include_sidecars = TRUE
  )
  problems <- character()
  for (relative in locked) {
    path <- file.path(params$raw_dir, relative)
    if (!file.exists(path)) {
      problems <- c(problems, paste0(relative, " (missing)"))
    } else if (!identical(release_lock_hash(path), expected[[relative]])) {
      problems <- c(problems, paste0(relative, " (changed)"))
    }
  }
  added <- setdiff(current$relative, locked)
  if (length(added) > 0L) {
    problems <- c(problems, paste0(added, " (not in the lock)"))
  }
  if (!is.null(lock$controls)) {
    for (control in lock$controls) {
      path <- file.path(params$raw_dir, control$path)
      if (!file.exists(path)) {
        problems <- c(problems, paste0(control$path, " (missing)"))
      } else if (!identical(
        digest::digest(path, algo = "sha256", file = TRUE),
        control$sha256
      )) {
        problems <- c(problems, paste0(control$path, " (changed)"))
      }
    }
  }
  if (length(problems) > 0L) {
    stop(
      sprintf(
        "RELEASE LOCK MISMATCH: %d non-ODIN artifact(s) differ from %s: %s",
        length(problems),
        basename(release_lock_path(params)),
        paste(problems, collapse = "; ")
      ),
      call. = FALSE
    )
  }
  invisible(lock)
}

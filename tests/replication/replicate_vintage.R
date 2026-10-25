# =============================================================================
# Sandboxed vintage replication harness
# =============================================================================
# Rebuilds an SPI vintage with a chosen code version in a throwaway sandbox so
# replication evidence can be produced without writing into the repository.
#
# The sandbox contains a copy of the pipeline code (from the working tree or a
# git ref), the renv activation files, and an `01_raw_data/` "symlink farm":
# every raw-data folder is a read-only symlink to the repository, except the
# folders the estimation run must write into (`3_DP/collection`,
# `4.1_SOCS/collection`, `_collection/world_bank`).
#
# Usage (from the repository root):
#   Rscript --vanilla tests/replication/run_replication.R \
#     --code <worktree|git-ref> --vintage 2024 --out <dir>
#
# Created: 2026-10-23
# =============================================================================

source(file.path("tests", "replication", "legacy_e6_overrides.R"))

# Parameters of the published 2024 vintage (202511), recovered from commit
# d7b368f. Only the vintage-specific values differ from config/params.R.
#
# IMF exception: since commit 8cb21c8 the D5.2 IMF readers expect the 2026.10
# workbook layout for `imf_file` and the 2025.10 layout for `imf_file_2024`,
# so the published 2024 IMF pairing cannot be read by current code. The
# harness therefore uses the 2025 pairing; D5.2.4/5.2.5/5.2.7/5.2.9 values for
# 2024 are comparable differentially (code version A vs B) but not against the
# published fixture.
replication_vintage_params <- function(vintage) {
  if (!identical(as.integer(vintage), 2024L)) {
    stop("REPLICATION PARAMETERS ARE DEFINED ONLY FOR THE 2024 VINTAGE.", call. = FALSE)
  }
  list(
    end_date = 2024,
    imf_file = "2026.10_Compiled Data for World Bank - Sep 2026 - Final.xlsx",
    imf_file_2024 = "2025.10_Compiled Data for World Bank.xlsx",
    ilo_modelled_file = "EAP_2WAP_SEX_AGE_RT_A-20250923T0014.csv",
    ilo_survey_file = "EAP_DWAP_SEX_AGE_RT_A-20250923T0014.csv",
    unigme_file = "UNICEF-CME_DF_2021_WQ-1.0-download.csv"
  )
}

.run_command <- function(command, args, wd = NULL) {
  old <- if (!is.null(wd)) setwd(wd) else NULL
  on.exit(if (!is.null(old)) setwd(old), add = TRUE)
  status <- system2(command, args)
  if (!identical(as.integer(status), 0L)) {
    stop(
      sprintf("REPLICATION COMMAND FAILED (%s): %s %s", status, command, paste(args, collapse = " ")),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

# Commit whose tracked raw files replications read (see
# pin_tracked_raw_files()); the raw data of the E5 enumeration.
replication_raw_ref <- "8df2865"

.run_git_lines <- function(repo_root, args) {
  out <- system2("git", c("-C", shQuote(repo_root), args), stdout = TRUE)
  status <- attr(out, "status")
  if (!is.null(status) && !identical(as.integer(status), 0L)) {
    stop("GIT COMMAND FAILED: git ", paste(args, collapse = " "), call. = FALSE)
  }
  out
}

.is_symlink <- function(path) {
  link <- Sys.readlink(path)
  !is.na(link) && nzchar(link)
}

# Replace a farm symlink to a directory with a real sandbox directory whose
# children are symlinks, so single files below it can be replaced.
.materialize_farm_dir <- function(farm_dir, real_dir) {
  if (.is_symlink(farm_dir)) {
    if (system2("rm", shQuote(farm_dir)) != 0L) {
      stop("COULD NOT REPLACE FARM SYMLINK ", farm_dir, call. = FALSE)
    }
    dir.create(farm_dir)
    for (child in list.files(real_dir, all.files = TRUE, no.. = TRUE)) {
      file.symlink(file.path(real_dir, child), file.path(farm_dir, child))
    }
  } else if (!dir.exists(farm_dir)) {
    dir.create(farm_dir)
  }
  invisible(farm_dir)
}

#' Restore tracked raw files that differ from `ref` inside the sandbox farm.
#'
#' Never writes through a symlink: every ancestor of a restored file is a
#' real sandbox directory, and the write is refused otherwise.
pin_tracked_raw_files <- function(repo_root, farm, ref) {
  in_ref <- .run_git_lines(repo_root, c("ls-tree", "-r", "--name-only", ref, "--", "01_raw_data"))
  changed <- .run_git_lines(repo_root, c("diff", "--name-only", ref, "--", "01_raw_data"))
  changed <- intersect(changed, in_ref)
  changed <- changed[!startsWith(changed, "01_raw_data/_collection/") & changed != "01_raw_data/README.md"]
  farm_root <- normalizePath(farm, winslash = "/")
  for (path in changed) {
    parts <- strsplit(sub("^01_raw_data/", "", path), "/", fixed = TRUE)[[1]]
    farm_dir <- farm
    real_dir <- file.path(repo_root, "01_raw_data")
    for (part in head(parts, -1L)) {
      farm_dir <- file.path(farm_dir, part)
      real_dir <- file.path(real_dir, part)
      .materialize_farm_dir(farm_dir, real_dir)
    }
    target <- file.path(farm_dir, parts[[length(parts)]])
    if (!startsWith(normalizePath(farm_dir, winslash = "/"), farm_root)) {
      stop("REFUSING TO WRITE OUTSIDE THE SANDBOX: ", target, call. = FALSE)
    }
    if (.is_symlink(target) || file.exists(target)) {
      if (system2("rm", shQuote(target)) != 0L) stop("COULD NOT REPLACE ", target, call. = FALSE)
    }
    status <- system2(
      "git",
      c("-C", shQuote(repo_root), "show", shQuote(paste0(ref, ":", path))),
      stdout = target
    )
    if (!identical(as.integer(status), 0L)) {
      stop("COULD NOT RESTORE ", path, " FROM ", ref, call. = FALSE)
    }
  }
  invisible(changed)
}

#' Copy pipeline code into the sandbox from the working tree or a git ref.
copy_replication_code <- function(repo_root, sandbox, code = "worktree") {
  code_paths <- c("R", "config", "_targets.R", "_targets_data.R")
  if (identical(code, "worktree")) {
    for (path in code_paths) {
      .run_command("rsync", c("-a", shQuote(file.path(repo_root, path)), shQuote(sandbox)))
    }
  } else {
    archive <- tempfile(fileext = ".tar")
    .run_command(
      "git",
      c("-C", shQuote(repo_root), "archive", "--format=tar", "-o", shQuote(archive), shQuote(code), code_paths)
    )
    .run_command("tar", c("-xf", shQuote(archive), "-C", shQuote(sandbox)))
    unlink(archive)
  }
  for (path in c("SPI.Rproj", ".Rprofile", "renv.lock")) {
    file.copy(file.path(repo_root, path), sandbox, overwrite = TRUE)
  }
  .run_command("rsync", c("-a", shQuote(file.path(repo_root, "renv")), shQuote(sandbox)))
  invisible(sandbox)
}

#' Build the read-only raw-data symlink farm with writable exceptions.
build_raw_data_farm <- function(repo_root, sandbox, vintage) {
  real_raw <- file.path(repo_root, "01_raw_data")
  farm <- file.path(sandbox, "01_raw_data")
  dir.create(farm, recursive = TRUE, showWarnings = FALSE)

  copied <- c("4.1_SOCS")
  mixed <- c("3_DP", "_collection")
  for (child in list.files(real_raw, all.files = FALSE, no.. = TRUE)) {
    source <- file.path(real_raw, child)
    target <- file.path(farm, child)
    if (child %in% copied) {
      # The catalogue response cache and refresh staging folders are
      # collection-only and large; estimation never reads them.
      .run_command("rsync", c("-a", "--exclude=catalogue_cache/", "--exclude=staging-*/", shQuote(source), shQuote(farm)))
    } else if (child %in% mixed) {
      dir.create(target, showWarnings = FALSE)
      for (grandchild in list.files(source, no.. = TRUE)) {
        if (child == "_collection" && grandchild == "world_bank") next
        if (child == "3_DP" && grandchild == "collection") next
        file.symlink(file.path(source, grandchild), file.path(target, grandchild))
      }
    } else {
      file.symlink(source, target)
    }
  }

  # The 2024 derived D4.1 CSVs predate the edited 2025 input workbooks; in the
  # sandbox copy only, refresh their timestamps so the stale-artifact check
  # reflects the replication scenario rather than later edits.
  derived <- list.files(
    file.path(farm, "4.1_SOCS", "raw"),
    pattern = sprintf("^D4[.]1[.][0-9][.].*[.]%d[.]csv$", vintage),
    full.names = TRUE
  )
  Sys.setFileTime(derived, Sys.time())

  # Live collection rewrites tracked raw files in place (PIP, UN SDG series,
  # JMP, D4.1 catalogue companions). Replications read every tracked raw file
  # as of the reference commit, so they isolate code changes from data
  # refreshes.
  pin_tracked_raw_files(repo_root, farm, replication_raw_ref)

  # World Bank snapshots for the vintage are derived from the frozen 2025
  # retrieval in tests/replication/world_bank_snapshot (the snapshot every
  # replication since the 8df2865 baseline used), filtered to the vintage
  # span, so a later live collection cannot change replicated metadata.
  wb_real <- file.path(repo_root, "tests", "replication", "world_bank_snapshot")
  wb_farm <- file.path(farm, "_collection", "world_bank")
  dir.create(wb_farm, recursive = TRUE, showWarnings = FALSE)
  for (file in c("country_metadata.rds", "oecd_countries.rds")) {
    file.symlink(file.path(wb_real, file), file.path(wb_farm, file))
  }
  for (stem in c("population", "gdp")) {
    latest <- readRDS(file.path(wb_real, sprintf("%s_2025.rds", stem)))
    latest$date <- as.numeric(latest$date)
    saveRDS(
      latest[latest$date <= vintage, , drop = FALSE],
      file.path(wb_farm, sprintf("%s_%d.rds", stem, vintage))
    )
  }
  invisible(farm)
}

#' Rewrite vintage-specific assignments in the sandbox params file.
write_replication_params <- function(sandbox, values) {
  path <- file.path(sandbox, "config", "params.R")
  text <- readLines(path, warn = FALSE)
  for (name in names(values)) {
    value <- values[[name]]
    literal <- if (is.character(value)) sprintf('"%s"', value) else as.character(value)
    pattern <- sprintf("^%s[[:space:]]*<-.*$", name)
    hits <- grep(pattern, text)
    replacement <- sprintf("%s <- %s", name, literal)
    if (length(hits) == 0L) {
      text <- c(text, replacement)
    } else {
      text[hits] <- replacement
    }
  }
  writeLines(text, path)
  invisible(path)
}

#' Sandbox-only overrides: bypass the collection gate (collection is not part
#' of an estimation replication) and provide the global used by an older
#' registry target definition. No published index is kept for the vintage
#' before a replicated one, so the revision report gets an empty placeholder
#' and states that index revisions are unavailable.
write_replication_overrides <- function(sandbox, legacy_e6 = FALSE) {
  writeLines("country,iso3c,date,SPI.INDEX", file.path(sandbox, "_replication_previous_index.csv"))
  writeLines(
    c(
      "# Sandbox-only replication overrides (never part of the repository code).",
      "validate_collection_status <- function(...) TRUE",
      "# The vintage-diff report is still written; its 2025 promotion policy is not",
      "# applied to a replicated vintage.",
      "enforce_vintage_diff <- function(...) invisible(TRUE)",
      "revision_previous_index_path <- function(params) here::here(\"_replication_previous_index.csv\")",
      "source_registry_file <- here::here(\"config\", \"source_registry.R\")"
    ),
    file.path(sandbox, "R", "zzz_replication_overrides.R")
  )
  if (isTRUE(legacy_e6)) {
    write_legacy_e6_overrides(sandbox)
  }
}

#' Prepare vintage artifacts inside the sandbox and run the estimation graph.
run_replication_estimation <- function(sandbox, vintage) {
  script <- file.path(sandbox, "_replication_prepare_and_run.R")
  writeLines(
    c(
      "suppressPackageStartupMessages(library(dplyr))",
      "for (f in list.files('R', full.names = TRUE, pattern = '[.]R$')) source(f)",
      "params <- load_params('config/params.R')",
      sprintf("vintage <- %d", vintage),
      "notes <- character()",
      "# The catalogue companions are newer than the replicated vintage (they list",
      "# surveys dated after it). Normalize them without the end_date ceiling;",
      "# scoring ignores catalogue years after each scored year.",
      "new_d41 <- exists('normalize_dim4_1_companions', mode = 'function')",
      "if (new_d41) {",
      "  normalize_dim4_1_companions(params$raw_dir, end_date = NULL)",
      "  notes <- c(notes, 'D4.1 companions normalized without the end_date ceiling')",
      "}",
      "manifest <- tryCatch(",
      "  dim4_1_build_manifest(params$raw_dir, vintage, country_metadata = NULL),",
      "  error = function(e) {",
      "    if (new_d41 && !grepl('EXCEEDS END_DATE', conditionMessage(e))) stop(e)",
      "    notes <<- c(notes, paste('D4.1 companion validation relaxed in sandbox:', conditionMessage(e)))",
      "    if (new_d41) {",
      "      strict_validate <- validate_dim4_1_companions",
      "      validate_dim4_1_companions <<- function(raw_dir, end_date = NULL, naming = dim4_1_naming_files(raw_dir)) {",
      "        strict_validate(raw_dir, end_date = NULL, naming = naming)",
      "      }",
      "    } else {",
      "      validate_dim4_1_companions <<- function(raw_dir, country_metadata = NULL, end_date = NULL) {",
      "        paths <- dim4_1_artifact_paths(raw_dir, end_date = 2000)$companion_files",
      "        list(files = lapply(paths, function(p) list(path = p, rows = 0L)), exclusions = list())",
      "      }",
      "    }",
      "    dim4_1_build_manifest(params$raw_dir, vintage, country_metadata = NULL)",
      "  }",
      ")",
      "write_dim4_1_manifest(manifest, params$dim4_1_manifest_file)",
      "dir.create('03_output_data', showWarnings = FALSE)",
      "writeLines(if (length(notes)) notes else 'no sandbox bypasses', '03_output_data/_sandbox_notes.txt')",
      "d3_dir <- file.path(params$raw_dir, '3_DP', 'collection')",
      "dir.create(d3_dir, recursive = TRUE, showWarnings = FALSE)",
      "d3 <- purrr::map_dfr(2004:vintage, un_sdg_data_read, params = params)",
      "readr::write_csv(d3, file.path(d3_dir, 'SPI_D3_UNSD_data_5yr.csv'))",
      "status <- tryCatch({ targets::tar_make(script = '_targets.R', store = '_targets', reporter = 'summary'); 0L }, error = function(e) 1L)",
      "if (status != 0L) {",
      "  meta <- targets::tar_meta(store = '_targets', fields = c(name, error))",
      "  meta <- meta[!is.na(meta$error), ]",
      "  for (i in seq_len(nrow(meta))) cat(sprintf('TARGET ERROR [%s]: %s\\n', meta$name[i], meta$error[i]))",
      "  quit(status = 1L)",
      "}",
      "# Partial-rebuild check (plan V2): invalidate one output target (forcing the",
      "# final manifest to rerun), delete another writer's candidate file, rebuild,",
      "# and require both a successful run and a complete candidate set.",
      "targets::tar_invalidate(names = 'treemap', store = '_targets')",
      "unlink(file.path('03_output_data', '.candidate', 'SPI_quantiles.csv'))",
      "rebuild <- tryCatch({ targets::tar_make(script = '_targets.R', store = '_targets', reporter = 'summary'); 'completed' }, error = function(e) paste('FAILED:', conditionMessage(e)))",
      "if (startsWith(rebuild, 'completed')) {",
      "  complete <- tryCatch({ validate_output_manifest(file.path('03_output_data', '.candidate'), vintage); TRUE }, error = function(e) conditionMessage(e))",
      "  rebuild <- if (isTRUE(complete)) 'completed; candidate set complete and promoted' else paste('FAILED: run completed but candidate incomplete:', complete)",
      "} else {",
      "  meta <- targets::tar_meta(store = '_targets', fields = c(name, error))",
      "  meta <- meta[!is.na(meta$error), ]",
      "  rebuild <- c(rebuild, sprintf('TARGET ERROR [%s]: %s', meta$name, meta$error))",
      "}",
      "writeLines(c('partial rebuild (treemap invalidated, SPI_quantiles.csv deleted from candidate):', rebuild), '03_output_data/_partial_rebuild_check.txt')"
    ),
    script
  )
  .run_command(
    "Rscript",
    c("--vanilla", "-e", shQuote("source('renv/activate.R'); source('_replication_prepare_and_run.R')")),
    wd = sandbox
  )
  invisible(file.path(sandbox, "03_output_data"))
}

#' Run the repository's replication test files against the sandbox outputs.
run_replication_tests <- function(repo_root, sandbox, out,
                                  test_files = c("test-stage-compare.R", "test-validation.R", "test-vintage-compare.R")) {
  dir.create(file.path(sandbox, "tests"), showWarnings = FALSE)
  file.symlink(file.path(repo_root, "tests", "fixtures"), file.path(sandbox, "tests", "fixtures"))
  .run_command("rsync", c("-a", shQuote(file.path(repo_root, "tests", "testthat")), shQuote(file.path(sandbox, "tests"))))
  script <- file.path(sandbox, "_replication_tests.R")
  writeLines(
    c(
      "results <- list(); failures <- character()",
      sprintf("for (f in c(%s)) {", paste(sprintf("'%s'", test_files), collapse = ", ")),
      "  r <- testthat::test_file(file.path('tests', 'testthat', f), reporter = testthat::ListReporter$new(), stop_on_failure = FALSE)",
      "  df <- as.data.frame(r); df$file <- f; results[[f]] <- df[, c('file', 'test', 'nb', 'failed', 'skipped', 'error', 'passed')]",
      "  for (t in r) for (res in t$results) if (inherits(res, c('expectation_failure', 'expectation_error'))) failures <- c(failures, paste0('[', f, '] ', t$test, ': ', conditionMessage(res)))",
      "}",
      sprintf("utils::write.csv(do.call(rbind, results), '%s', row.names = FALSE)", file.path(out, "_replication_tests.csv")),
      sprintf("writeLines(if (length(failures)) failures else 'no failures', '%s')", file.path(out, "_replication_test_failures.txt"))
    ),
    script
  )
  .run_command(
    "Rscript",
    c("--vanilla", "-e", shQuote("source('renv/activate.R'); source('_replication_tests.R')")),
    wd = sandbox
  )
  invisible(file.path(out, "_replication_tests.csv"))
}

#' Build a sandbox, run the vintage, and copy promoted outputs to `out`.
replicate_vintage <- function(repo_root, out, code = "worktree", vintage = 2024,
                              keep_sandbox = FALSE, legacy_e6 = FALSE) {
  sandbox <- tempfile("spi-replication-", tmpdir = dirname(tempdir()))
  dir.create(sandbox, recursive = TRUE)
  cat("Replication sandbox:", sandbox, "\n")
  if (!keep_sandbox) on.exit(unlink(sandbox, recursive = TRUE, force = TRUE), add = TRUE)

  copy_replication_code(repo_root, sandbox, code)
  build_raw_data_farm(repo_root, sandbox, vintage)
  write_replication_params(sandbox, replication_vintage_params(vintage))
  write_replication_overrides(sandbox, legacy_e6 = legacy_e6)
  outputs <- run_replication_estimation(sandbox, vintage)

  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  files <- list.files(outputs, pattern = "[.](csv|dta|json|txt)$", full.names = TRUE)
  if (length(files) == 0L) {
    stop("REPLICATION PRODUCED NO PROMOTED OUTPUTS: ", outputs, call. = FALSE)
  }
  file.copy(files, out, overwrite = TRUE)
  run_replication_tests(repo_root, sandbox, out)
  invisible(list(out = out, sandbox = sandbox, files = basename(files)))
}

#' Compare two promoted output sets file by file and column by column.
compare_output_sets <- function(dir_a, dir_b, files = NULL, tolerance = 1e-9) {
  if (is.null(files)) {
    files <- intersect(
      list.files(dir_a, pattern = "[.]csv$"),
      list.files(dir_b, pattern = "[.]csv$")
    )
  }
  rows <- lapply(files, function(file) {
    a <- readr::read_csv(file.path(dir_a, file), show_col_types = FALSE, guess_max = 1e6)
    b <- readr::read_csv(file.path(dir_b, file), show_col_types = FALSE, guess_max = 1e6)
    if (!identical(sort(names(a)), sort(names(b)))) {
      return(data.frame(
        file = file, column = "<columns>", differing_cells = NA_integer_,
        note = paste(
          "only in A:", paste(setdiff(names(a), names(b)), collapse = ","),
          "| only in B:", paste(setdiff(names(b), names(a)), collapse = ",")
        )
      ))
    }
    if (nrow(a) != nrow(b)) {
      return(data.frame(
        file = file, column = "<rows>", differing_cells = abs(nrow(a) - nrow(b)),
        note = sprintf("rows A=%d B=%d", nrow(a), nrow(b))
      ))
    }
    b <- b[, names(a), drop = FALSE]
    sort_key <- function(df) do.call(order, unname(lapply(df, function(x) as.character(x))))
    a <- a[sort_key(a), , drop = FALSE]
    b <- b[sort_key(b), , drop = FALSE]
    diffs <- vapply(names(a), function(column) {
      x <- a[[column]]
      y <- b[[column]]
      if (is.numeric(x) && is.numeric(y)) {
        both_na <- is.na(x) & is.na(y)
        one_na <- xor(is.na(x), is.na(y))
        close <- abs(x - y) <= tolerance * pmax(1, abs(x), abs(y))
        as.integer(sum(one_na | (!both_na & !one_na & !close), na.rm = TRUE))
      } else {
        x <- as.character(x)
        y <- as.character(y)
        as.integer(sum(xor(is.na(x), is.na(y)) | (!is.na(x) & !is.na(y) & x != y)))
      }
    }, integer(1))
    diffs <- diffs[diffs > 0]
    if (length(diffs) == 0L) {
      return(data.frame(file = file, column = "<identical>", differing_cells = 0L, note = ""))
    }
    data.frame(file = file, column = names(diffs), differing_cells = unname(diffs), note = "")
  })
  do.call(rbind, rows)
}

# =============================================================================
# ODIN-swap rehearsal in a sandbox
# =============================================================================
# Rehearses the December ODIN update without writing to the repository:
#   1. Builds a sandbox with the working-tree code and a raw-data symlink farm
#      (the ODIN folder is copied so it can be changed; `_collection` is a
#      sandbox folder whose existing files are symlinks).
#   2. Runs the reference-year estimation with odin_status "provisional"
#      (collection gate and vintage-diff enforcement neutralized in the
#      sandbox only) and writes a release lock in the sandbox. When the
#      repository already has a lock, its archive is used instead.
#   3. Reruns without changes (the release diff must be empty).
#   4. Perturbs the sandbox ODIN_<end_date>.csv, sets odin_status to
#      "official", reruns, and checks that only ODIN targets were rebuilt,
#      the release diff stays within the ODIN-dependent outputs, and the
#      provisional marker is removed.
#   5. Changes one non-ODIN artifact (a sandbox copy) and checks that the
#      release lock blocks the run.
#
# Usage (from the repository root):
#   Rscript tests/replication/rehearse_odin_swap.R --out <dir> [--keep-sandbox]
# (without --vanilla, so the project .Rprofile activates renv).
#
# <dir> receives the step logs, `_rehearsal_summary.txt`, and copies of the
# release and vintage diff reports (`candidate_*` for unpromoted reports).
#
# Created: 2026-10-24
# =============================================================================

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default = NULL) {
  hit <- which(args == flag)
  if (length(hit) == 0L) return(default)
  args[[hit[[1]] + 1L]]
}
repo_root <- normalizePath(".", mustWork = TRUE)
source(file.path(repo_root, "tests", "replication", "replicate_vintage.R"))
out <- arg_value("--out")
if (is.null(out)) stop("--out IS REQUIRED.", call. = FALSE)
keep <- "--keep-sandbox" %in% args
dir.create(out, recursive = TRUE, showWarnings = FALSE)

sandbox <- tempfile("spi-odin-rehearsal-", tmpdir = dirname(tempdir()))
dir.create(sandbox, recursive = TRUE)
cat("Rehearsal sandbox:", sandbox, "\n")

rehearse <- function() {

copy_replication_code(repo_root, sandbox, "worktree")
real_raw <- file.path(repo_root, "01_raw_data")
farm <- file.path(sandbox, "01_raw_data")
dir.create(farm)
for (child in list.files(real_raw, no.. = TRUE)) {
  if (child == "2.2_DSOA") {
    .run_command("rsync", c("-a", shQuote(file.path(real_raw, child)), shQuote(farm)))
  } else if (child == "_collection") {
    dir.create(file.path(farm, child))
    for (grandchild in list.files(file.path(real_raw, child), no.. = TRUE)) {
      file.symlink(file.path(real_raw, child, grandchild), file.path(farm, child, grandchild))
    }
  } else {
    file.symlink(file.path(real_raw, child), file.path(farm, child))
  }
}
writeLines(
  c(
    "# Sandbox-only rehearsal overrides (never part of the repository code).",
    "validate_collection_status <- function(...) TRUE",
    "enforce_vintage_diff <- function(...) invisible(TRUE)"
  ),
  file.path(sandbox, "R", "zzz_rehearsal_overrides.R")
)

run_in_sandbox <- function(lines, label) {
  script <- file.path(sandbox, sprintf("_rehearsal_%s.R", label))
  writeLines(c("suppressPackageStartupMessages(library(targets))", lines), script)
  log <- file.path(out, sprintf("%s.log", label))
  old <- setwd(sandbox)
  on.exit(setwd(old), add = TRUE)
  status <- system2(
    "Rscript",
    c("--vanilla", "-e", shQuote(sprintf("source('renv/activate.R'); source('%s')", basename(script)))),
    stdout = log,
    stderr = log
  )
  list(status = status, log = log)
}

make_lines <- c(
  "started <- Sys.time()",
  "result <- tryCatch({ tar_make(script = '_targets.R', store = '_targets', reporter = 'silent'); 'completed' }, error = function(e) paste('FAILED:', conditionMessage(e)))",
  "meta <- tar_meta(store = '_targets', fields = c(name, time, error))",
  "built <- sort(meta$name[!is.na(meta$time) & meta$time >= started])",
  "errors <- meta[!is.na(meta$error), c('name', 'error')]",
  "cat('RESULT:', result, '\\n')",
  "cat('BUILT:', paste(built, collapse = ', '), '\\n')",
  "for (i in seq_len(nrow(errors))) cat(sprintf('ERROR [%s]: %s\\n', errors$name[i], errors$error[i]))"
)
note <- function(...) {
  line <- paste0(...)
  cat(line, "\n", file = summary_file, append = TRUE)
  cat(line, "\n")
}
read_log <- function(run) readLines(run$log, warn = FALSE)
require_completed <- function(run, label) {
  result <- grab(run, "RESULT:")
  if (!identical(result, "completed")) {
    stop("REHEARSAL STEP FAILED (", label, "): ", result, "; see ", run$log, call. = FALSE)
  }
  invisible(TRUE)
}
grab <- function(run, prefix) {
  hit <- grep(paste0("^", prefix), read_log(run), value = TRUE)
  if (length(hit) == 0L) NA_character_ else trimws(sub(paste0("^", prefix), "", hit[[length(hit)]]))
}

# 1-2. Provisional run and lock --------------------------------------------
run1 <- run_in_sandbox(make_lines, "1_provisional")
note("1 provisional run: ", grab(run1, "RESULT:"))
require_completed(run1, "provisional run")
marker <- file.path(sandbox, "03_output_data", "PROVISIONAL_ODIN.md")
note("  marker present: ", file.exists(marker))
manifest <- jsonlite::read_json(file.path(sandbox, "03_output_data", "_estimation_manifest.json"))
note("  odin_status: ", manifest$odin_status)

params_lines <- c(
  "for (f in list.files('R', full.names = TRUE, pattern = '[.]R$')) source(f)",
  "params <- load_params('config/params.R')"
)
real_lock <- file.path(real_raw, "_collection", sprintf("release_lock_%d.json", manifest$end_date))
if (file.exists(real_lock)) {
  lock <- jsonlite::read_json(real_lock)
  archive_name <- basename(lock$archive)
  .run_command("rsync", c("-a", shQuote(file.path(repo_root, "03_output_data", "releases", archive_name)), shQuote(file.path(sandbox, "03_output_data", "releases"))))
  note("2 lock: using the repository lock ", basename(real_lock))
} else {
  run2 <- run_in_sandbox(c(params_lines, "cat('LOCK:', write_release_lock(params, approved_by = 'ODIN-swap rehearsal'), '\\n')"), "2_lock")
  lock_file <- grab(run2, "LOCK:")
  note("2 lock written in the sandbox: ", lock_file)
  if (is.na(lock_file) || !file.exists(lock_file)) {
    stop("REHEARSAL STEP FAILED (lock); see ", run2$log, call. = FALSE)
  }
  lock <- jsonlite::read_json(lock_file)
  note("  locked artifacts: ", length(lock$artifacts), "; PIP release: ", lock$pip_release)
}

# 3. Rerun without changes ----------------------------------------------------
run3 <- run_in_sandbox(make_lines, "3_unchanged")
note("3 unchanged rerun: ", grab(run3, "RESULT:"))
require_completed(run3, "unchanged rerun")
note("  rebuilt: ", grab(run3, "BUILT:"))
diff3 <- file.path(sandbox, "03_output_data", sprintf("release_diff_%d.md", manifest$end_date))
note("  release diff: ", if (file.exists(diff3)) readLines(diff3)[[3]] else "missing")

# 4. Official ODIN swap -------------------------------------------------------
sandbox_root <- normalizePath(sandbox, winslash = "/")
inside_sandbox <- function(path) {
  directory <- dirname(path)
  !.is_symlink(directory) && startsWith(normalizePath(directory, winslash = "/"), sandbox_root)
}
odin_path <- file.path(farm, "2.2_DSOA", sprintf("ODIN_%d.csv", manifest$end_date))
if (!inside_sandbox(odin_path) || .is_symlink(odin_path)) {
  stop("REHEARSAL REFUSES TO CHANGE A FILE OUTSIDE THE SANDBOX: ", odin_path, call. = FALSE)
}
odin <- readr::read_csv(odin_path, show_col_types = FALSE, name_repair = "minimal")
rows <- which(odin[["Data categories"]] %in% c("All Categories", "All categories"))
if (length(rows) == 0L) {
  stop("REHEARSAL FOUND NO ODIN ALL-CATEGORY ROWS TO PERTURB", call. = FALSE)
}
for (column in c("Openness subscore", "Machine readable", "First administrative level", "Second administrative level")) {
  original <- odin[[column]][rows]
  numeric <- suppressWarnings(as.numeric(original))
  unparseable <- !is.na(original) & is.na(numeric)
  if (any(unparseable)) {
    if (!all(original[unparseable] == "-")) {
      stop(
        "REHEARSAL FOUND UNPARSEABLE ODIN VALUES in ",
        column,
        ": ",
        paste(unique(original[unparseable]), collapse = ", "),
        call. = FALSE
      )
    }
    numeric[unparseable] <- NA_real_
  }
  updated <- ifelse(is.na(numeric), original, pmin(100, numeric + 5))
  odin[[column]][rows] <- updated
}
readr::write_csv(odin, odin_path, na = "")
params_file <- file.path(sandbox, "config", "params.R")
text <- readLines(params_file, warn = FALSE)
text <- sub('^odin_status <- "provisional"$', 'odin_status <- "official"', text)
writeLines(text, params_file)
run4 <- run_in_sandbox(make_lines, "4_official")
note("4 official run after the ODIN change: ", grab(run4, "RESULT:"))
require_completed(run4, "official run")
note("  rebuilt: ", grab(run4, "BUILT:"))
diff4 <- file.path(sandbox, "03_output_data", sprintf("release_diff_%d.csv", manifest$end_date))
if (file.exists(diff4)) {
  report <- readr::read_csv(diff4, show_col_types = FALSE)
  note("  release diff: ", nrow(report), " changed cells, ", sum(!report$allowed), " outside the ODIN-dependent outputs")
  note("  changed columns: ", paste(sort(unique(paste(report$file, report$column, sep = ":"))), collapse = ", "))
} else {
  note("  release diff: missing")
}
note("  marker removed: ", !file.exists(marker))
note("  odin_status: ", jsonlite::read_json(file.path(sandbox, "03_output_data", "_estimation_manifest.json"))$odin_status)

# 5. A non-ODIN change must block ---------------------------------------------
.materialize_farm_dir(file.path(farm, "1.5_DUIO"), file.path(real_raw, "1.5_DUIO"))
pip_path <- file.path(farm, "1.5_DUIO", "PIP_comparability_latest.csv")
pip <- readLines(pip_path)
if (!inside_sandbox(pip_path)) {
  stop("REHEARSAL REFUSES TO CHANGE A FILE OUTSIDE THE SANDBOX: ", pip_path, call. = FALSE)
}
if (.is_symlink(pip_path)) system2("rm", shQuote(pip_path))
if (.is_symlink(pip_path) || file.exists(pip_path)) {
  stop("REHEARSAL COULD NOT DETACH ", pip_path, call. = FALSE)
}
writeLines(c(pip, pip[[length(pip)]]), pip_path)
run5 <- run_in_sandbox(make_lines, "5_non_odin_change")
note("5 non-ODIN change: ", grab(run5, "RESULT:"))
blocked <- grep("RELEASE LOCK MISMATCH", read_log(run5), value = TRUE)
note("  blocked by the lock: ", length(blocked) > 0L)
if (length(blocked) == 0L) {
  stop("REHEARSAL STEP FAILED (non-ODIN change was not blocked); see ", run5$log, call. = FALSE)
}
note("REHEARSAL PASSED")
}

# Copies the diff reports (promoted and candidate) out of the sandbox so a
# failed step can be diagnosed after the sandbox is removed.
preserve_reports <- function() {
  outputs <- file.path(sandbox, "03_output_data")
  for (prefix in c("", "candidate_")) {
    folder <- if (nzchar(prefix)) file.path(outputs, ".candidate") else outputs
    reports <- Sys.glob(file.path(folder, c("release_diff_*", "vintage_diff_*")))
    if (length(reports) > 0L) {
      file.copy(reports, file.path(out, paste0(prefix, basename(reports))), overwrite = TRUE)
    }
  }
}

summary_file <- file.path(out, "_rehearsal_summary.txt")
unlink(c(summary_file, Sys.glob(file.path(out, c("release_diff_*", "vintage_diff_*", "candidate_*")))))
tryCatch(
  rehearse(),
  finally = {
    preserve_reports()
    if (keep) cat("Sandbox kept at:", sandbox, "\n") else unlink(sandbox, recursive = TRUE, force = TRUE)
  }
)

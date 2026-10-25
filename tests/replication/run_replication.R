# =============================================================================
# Command-line entry point for the sandboxed vintage replication harness
# =============================================================================
# Examples (run from the repository root):
#   Rscript --vanilla tests/replication/run_replication.R \
#     --code 25b534706ff6 --vintage 2024 --out replication/spi-rep/baseline
#   Rscript --vanilla tests/replication/run_replication.R \
#     --code worktree --vintage 2024 --out replication/spi-rep/worktree \
#     --compare replication/spi-rep/baseline
#   Add --allow-skips only for an explicitly accepted exception run.
#
# Created: 2026-10-23
# =============================================================================

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default = NULL) {
  hit <- which(args == flag)
  if (length(hit) == 0L) return(default)
  if (hit[[1]] == length(args)) stop("MISSING VALUE FOR ", flag, call. = FALSE)
  args[[hit[[1]] + 1L]]
}

repo_root <- normalizePath(".", mustWork = TRUE)
source(file.path(repo_root, "tests", "replication", "replicate_vintage.R"))

code <- arg_value("--code", "worktree")
vintage <- as.integer(arg_value("--vintage", "2024"))
out <- arg_value("--out")
if (is.null(out)) stop("--out IS REQUIRED.", call. = FALSE)
compare_with <- arg_value("--compare")
keep <- "--keep-sandbox" %in% args
allow_skips <- "--allow-skips" %in% args

result <- replicate_vintage(repo_root, out, code = code, vintage = vintage, keep_sandbox = keep)
cat("Promoted outputs copied to:", result$out, "\n")
if (keep) cat("Sandbox kept at:", result$sandbox, "\n")

if (!is.null(compare_with)) {
  comparison <- compare_output_sets(compare_with, out)
  readr::write_csv(comparison, file.path(out, "_comparison_vs_reference.csv"))
  print(comparison, row.names = FALSE)
} else {
  comparison <- NULL
}

tests <- utils::read.csv(file.path(out, "_replication_tests.csv"))
summary <- replication_result_status(tests, comparison = comparison, allow_skips = allow_skips)
cat(sprintf(
  "\nReplication tests: %d expectations, %d failed, %d skipped, %d errors\n",
  sum(tests$nb, na.rm = TRUE), summary$failed, summary$skipped, summary$errors
))
if (summary$comparison_failures > 0L) {
  cat("Comparison differences:", summary$comparison_failures, "\n")
}
if (summary$skips_accepted) {
  cat("Skipped expectations accepted by --allow-skips.\n")
}
cat(readLines(file.path(out, "_replication_test_failures.txt")), sep = "\n")
if (summary$status != 0L) {
  quit(status = summary$status)
}

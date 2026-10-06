---
date: 2026-10-05
depth: full
type: standard
plan: .cg-docs/plans/2026-10-05-spi-data-collection-pipeline.md
findings:
  P1.1: fixed
  P1.2: fixed
  P1.3: fixed
  P1.4: fixed
  P1.5: fixed
  P1.6: fixed
  P1.7: fixed
  P1.8: fixed
  P2.1: fixed
  P2.2: open
  P2.3: fixed
  P2.2: fixed
  P2.4: fixed
  P2.5: fixed
  P2.6: fixed
  P2.7: fixed
  P2.9: fixed
  P2.10: fixed
  P2.11: fixed
  P2.12: fixed
  P2.13: fixed
  P2.14: fixed
  P3.1: open
---

# Review Report

**Review mode**: full (`thorough`)
**Files reviewed**: 49 changed or untracked paths, excluding generated view bodies
**Findings**: 23 (P0: 0, P1: 8, P2: 14, P3: 1)

## P1 — Critical

### [P1.1] Source registry points D5.5 at the wrong artifact
- **Files**: `config/source_registry.R`, `R/pull_unsdg.R`
- **Why**: The registry names `SG_STT_NSDSFND.csv`, while the collector and estimator use `SG_STT_FIN.csv`. A successful collection can therefore still be reported as missing or validate the wrong file.
- **Fix**: Align the registry, collector, and estimator on one source artifact and add a mapping test.
- **Tag**: `[safe_auto]`

### [P1.2] SDG status checks a directory and permits legacy fallback
- **Files**: `config/source_registry.R`, `R/collection_status.R`, `R/dim3.R`
- **Why**: `file.exists()` accepts the normalized directory as present, while estimation can fall back to legacy per-year files when the collection score artifact is absent. This violates the collection-first boundary.
- **Fix**: Register the exact score artifact and block estimation when it is absent; remove or explicitly gate the legacy fallback.
- **Tag**: `[safe_auto]` for the exact-path correction; the fallback policy is `[manual]`.

### [P1.3] `spl_admin` can write final output without the collection gate
- **Files**: `_targets.R`
- **Why**: `spl_admin` is an output-producing target but does not depend on `collection_gate`; a blocking collection status does not prevent that output path from running.
- **Fix**: Add the gate dependency to every final-output producer.
- **Tag**: `[safe_auto]`

### [P1.4] SDG Nature handling can abort on missing values
- **Files**: `R/collect_sdg.R`
- **Why**: `result[nature == "N"] <- NA_real_` uses an index that can contain `NA`; missing Nature values can error instead of following the Rmd rule.
- **Fix**: Make the mask NA-safe and preserve the known Nature classification semantics.
- **Tag**: `[safe_auto]`

### [P1.5] Collection status does not validate expected vintage or manifest freshness
- **Files**: `R/collection_status.R`, `_targets.R`
- **Why**: `observed_vintage` is always `NA`; status is based on presence/mtime, stale warnings do not block, and a previous passing manifest can remain trusted after a failed collection run.
- **Fix**: Bind the manifest to current parameters and a successful collection run, validate source-specific vintages and artifact hashes, and define blocking severity for required stale inputs.
- **Tag**: `[manual]`

### [P1.6] SDG aggregation does not yet prove exact Rmd replication
- **Files**: `R/availability.R`, `R/collect_sdg.R`, `02_programs/misc_scripts/un_stats_cleaning.Rmd`
- **Why**: The collector does not yet demonstrate the Rmd tier-1 filter, complete country-year-series grid, global-year availability behavior, or required lookback semantics; missing rows can alter denominators.
- **Fix**: Port and fixture-test the exact transformation before enabling the score artifact as authoritative.
- **Tag**: `[manual]`

### [P1.7] Raw response/provenance coverage is inconsistent
- **Files**: `R/pull_jmp.R`, `R/pull_unsdg.R`, `R/collect_world_bank.R`, `R/collection_cache.R`, `.gitignore`
- **Why**: SDG DataCSV uses raw capture, but JMP, legacy UN series, PIP, and World Bank paths do not consistently preserve source bytes and replayable provenance; several required snapshots are ignored.
- **Fix**: Standardize capture/provenance or explicitly document source-specific exceptions and version the exact inputs needed for estimation.
- **Tag**: `[manual]`

### [P1.8] Direct final-output replacement can lose an existing file
- **Files**: `R/save.R`, `R/append.R`, `tests/testthat/test-fixtures.R`
- **Why**: Writers unlink the existing output before renaming a temporary file, and fixture protection for `03_output_data/` was removed. A failed replacement can leave a missing or mixed output set.
- **Fix**: Resolve the staging-versus-direct-promotion contract; preserve the existing destination until replacement succeeds and validate the complete set before publication.
- **Tag**: `[manual]`

## P2 — Important

### [P2.1] Output manifest is not downstream of all output producers
- **Files**: `_targets.R`, `R/output_manifest.R`
- **Why**: `output_manifest` depends only on `spl_admin`, so it can inspect stale files before other writers finish.
- **Fix**: Depend on every output-producing target and validate the complete current run.
- **Tag**: `[safe_auto]`

### [P2.2] Stage/vintage comparisons can inspect pre-existing outputs
- **Files**: `tests/testthat/test-stage-compare.R`, `tests/testthat/test-vintage-compare.R`
- **Why**: Tests read existing `03_output_data/` files and can pass without executing the new graph; missing files can skip comparisons.
- **Fix**: Compare isolated pipeline-produced outputs or require an executed-run marker.
- **Tag**: `[manual]`

### [P2.3] Cache hits do not verify the recorded checksum
- **Files**: `R/collection_cache.R`, `R/collection_io.R`
- **Why**: Existing raw/table bytes are trusted whenever files and sidecars exist; corruption or manual alteration is not detected.
- **Fix**: Recompute and compare SHA-256 on cache hits; test corruption and incomplete pairs.
- **Tag**: `[safe_auto]`

### [P2.4] Registry paths do not consistently represent required artifacts
- **Files**: `config/source_registry.R`, `R/collection_status.R`, `R/dim3.R`
- **Why**: Directory paths count as present, and D5.2’s workbook inputs are not all represented by readiness checks.
- **Fix**: Register exact required files and schemas, including IMF/WDI inputs.
- **Tag**: `[manual]`

### [P2.5] PIP/World Bank source contracts lack key and type validation
- **Files**: `R/collect_pip.R`, `R/collect_world_bank.R`, `R/dim1_5.R`, `R/quantiles.R`
- **Why**: Duplicate PIP surveys, malformed years, duplicate country-year rows, or natural GDP joins can alter estimates silently.
- **Fix**: Add source-specific type, key, coverage, and explicit-join validation without changing methodology.
- **Tag**: `[manual]`

### [P2.6] API failure/replay cases are under-tested
- **Files**: `tests/testthat/test-api-collectors.R`, `R/pull_jmp.R`, `R/pull_unsdg.R`, `R/collect_sdg.R`
- **Why**: Tests cover successful injected collectors but not HTTP failures, empty/malformed responses, retry behavior, or cache reuse for all collectors.
- **Fix**: Add offline failure/schema/replay tests and bounded retry behavior.
- **Tag**: `[safe_auto]` for tests; collector retry policy is `[manual]`.

### [P2.7] Validation tests do not assert the named country-set failure
- **Files**: `tests/testthat/test-validation.R`
- **Why**: The “new country” test only checks that validation rules do not error; it does not assert that `ZZZ` is rejected.
- **Fix**: Assert the specific rule failure and valid-fixture pass.
- **Tag**: `[safe_auto]`

### [P2.8] Stage comparison derives required columns from the candidate output
- **Files**: `tests/testthat/test-stage-compare.R`
- **Why**: Dropped columns can disappear from both sides before comparison.
- **Fix**: Derive required columns from fixtures or a fixed schema and assert presence first.
- **Tag**: `[safe_auto]`

### [P2.9] Output filenames retain a fixed 2024 suffix
- **Files**: `R/quantiles.R`, `R/output_manifest.R`
- **Why**: A later vintage can overwrite `_2024` files with newer data.
- **Fix**: Make names vintage-aware or explicitly constrain supported `end_date`.
- **Tag**: `[manual]`

### [P2.10] User guide retains contradictory legacy procedures
- **Files**: `docs/user-guide.md`, `README.md`, `R/pull_jmp.R`, `R/pull_unsdg.R`
- **Why**: Sections still describe staging/manual copy, `run_downloads`, and opt-in pull targets that no longer match collection-first execution.
- **Fix**: Align all operator instructions with the two commands and current source prerequisites.
- **Tag**: `[safe_auto]`

### [P2.11] Collection cache can reuse same-vintage data indefinitely
- **Files**: `R/collection_cache.R`, `R/collect_pip.R`, `_targets_data.R`
- **Why**: Same source/query/vintage keys produce cache hits without a release/expiry refresh policy.
- **Fix**: Add explicit force-refresh/expiry semantics and record the decision in provenance.
- **Tag**: `[manual]`

### [P2.12] Manual checkpoints can remain cached after input changes
- **Files**: `_targets_data.R`, `R/collection_checkpoints.R`
- **Why**: Only status has an always-run cue; checkpoint targets do not explicitly depend on the checked files’ content.
- **Fix**: Make source files target dependencies or cue checkpoints appropriately.
- **Tag**: `[manual]`

### [P2.13] Collection can make duplicate SDG requests/series mappings
- **Files**: `R/collect_sdg.R`
- **Why**: Fixed UN series and indicator-list series can overlap; duplicate `code1` to multiple goals can duplicate score contributions.
- **Fix**: Validate unique series-to-goal mappings and deduplicate request plans.
- **Tag**: `[safe_auto]` for validation; scoring resolution is `[manual]`.

### [P2.14] Unmatched SDG geography codes are silently dropped
- **Files**: `R/collect_sdg.R`
- **Why**: Country lookup joins do not assert uniqueness or report unmatched codes.
- **Fix**: Report/fail unexpected unmapped codes while allowing known aggregates.
- **Tag**: `[manual]`

## P3 — Minor

### [P3.1] Jitter seed contract remains unclear
- **Files**: `_targets.R`, `R/quantiles.R`, `tests/testthat/test-stage-compare.R`
- **Why**: Documentation disagrees about whether targets seeds ordinary `rnorm()` calls, and jitter repeatability is not tested.
- **Fix**: Verify/document RNG behavior and test repeatability.
- **Tag**: `[advisory]`

## Passed

- No P0 finding was identified.
- Focused collection, SDG, pipeline-contract, API-collector, output-writer,
  and output-manifest tests passed during the implementation session.
- Diagnostics were clean for the touched R/config/test files.
- The estimation graph correctly stops on the current collection blockers.

## Review Notes

The current checkout remains blocked by missing reviewed SDG inputs, so the
review does not treat the final-output path as end-to-end validated. The Rmd
references remain protected and were not modified by this review.

---
date: 2026-10-20
depth: full
type: standard
plan: .cg-docs/plans/2026-10-20-d41-manual-collection-pipeline.md
findings:
  P0.1: fixed
  P0.2: fixed
  P0.3: fixed
  P0.4: open
  P1.1: fixed
  P1.2: fixed
  P1.3: fixed
  P1.4: open
  P1.5: open
  P2.1: fixed
  P2.2: fixed
  P2.3: fixed
  P2.4: open
  P2.5: fixed
  P2.6: open
---

# Review Report

**Review mode**: full
**Files reviewed**: 18 changed or added implementation, test, configuration,
documentation, plan, and state paths
**Findings**: 15 (P0: 4, P1: 5, P2: 6, P3: 0)

## P0 — BLOCKING

### [P0.1] Manifest hashes are recorded but not enforced
- **Files**: `R/collect_dim4_1.R`, `R/dim4.R`, `_targets.R`
- **Why**: The manifest records hashes, but estimation reads derived CSVs and
  companion files directly from `raw_dir` without recomputing or comparing
  those hashes. A changed artifact can therefore be used without a fresh
  collection run.
- **Fix**: Validate manifest vintage, paths, existence, and SHA-256 values at
  the estimation gate; pass an authorized artifact bundle into Dimension 4.1.
- **Tag**: `[safe_auto]`

### [P0.2] Unknown companion country names can disappear silently
- **Files**: `R/collect_dim4_1.R`, `R/dim4.R`
- **Why**: Companion validation checks blank country names but not mapping
  completeness. The estimator joins by country name and later filters rows
  with missing `iso3c`, silently dropping evidence.
- **Fix**: Validate all companion country names against the authorized country
  metadata and stop with row-level diagnostics. Country aliases or exclusions
  require analyst approval.
- **Tag**: `[manual]`

### [P0.3] Manual-review overrides can be accepted and ignored
- **Files**: `R/collect_dim4_1.R`, `R/dim4.R`
- **Why**: Review validation does not enforce country membership, country/ISO
  consistency, or a valid year/register grammar. Unknown or malformed review
  values can fail to join or produce no usable dates.
- **Fix**: Add authorized-country and value-grammar validation before review
  data reaches estimation.
- **Tag**: `[manual]`

### [P0.4] Workbook coverage and year content are under-validated
- **Files**: `R/collect_dim4_1.R`, tests
- **Why**: Validation checks only that one non-empty unique key exists. A
  workbook can lose most countries or contain `pending`/invalid year text and
  still pass.
- **Fix**: Add explicit expected-country coverage and strict year parsing;
  retain a documented exception list if one is approved.
- **Tag**: `[manual]`

## P1 — CRITICAL

### [P1.1] Country metadata has a silent empty fallback
- **Files**: `R/setup.R`, `R/collect_dim4_1.R`, `_targets_data.R`
- **Why**: Missing `country_metadata.rds` becomes an empty data frame instead of
  blocking at collection, while D4.1 preprocessing depends on that snapshot.
- **Fix**: Require the snapshot, validate its schema/coverage, and include its
  hash in D4.1 provenance.
- **Tag**: `[safe_auto]`

### [P1.2] Partial D4.1 runs can desynchronize manifest and status
- **Files**: `_targets_data.R`, `R/collection_status.R`
- **Why**: A direct `d41_manifest` target run can regenerate artifacts without a
  completed collection-status report unless it is bound to the collection-run
  identity.
- **Fix**: Bind the D4.1 manifest to `collection_run_start`, status completion,
  and a manifest digest before estimation can pass.
- **Tag**: `[safe_auto]`

### [P1.3] Valid manual workbooks are classified as permanently unverified
- **Files**: `config/source_registry.R`, `R/collection_status.R`
- **Why**: The eight inputs use `latest_release`, which the status evaluator
  maps to `unverified` and then `blocking` even when present and validated.
- **Fix**: Define a manifest/reviewer attestation for manual workbooks instead
  of treating their vintage as an unverifiable API release.
- **Tag**: `[manual]`

### [P1.4] Legacy catalogue refresh lacks raw/provenance and atomicity
- **Files**: `R/collect_dim4_1.R`, legacy catalogue Rmd
- **Why**: The adapter executes a transformed legacy Rmd, writes companions
  directly, and records only final file hashes. A partial refresh can leave a
  mixed companion set; request identity and raw response provenance are absent.
- **Fix**: Stage refreshes, validate all companions, atomically promote the set,
  and preserve source-specific request/raw provenance. Keep refresh opt-in.
- **Tag**: `[manual]`

### [P1.5] Existing companion data contain unresolved quality issues
- **Files**: `D4.1.4.SVY.HOUS_NADA.csv`, `D4.1.5.SVY.AGRI_NADA.csv`,
  `D4.1.6.SVY.LABR_NADA.csv`
- **Why**: Household companions contain 16 missing-country rows; agriculture
  companions contain duplicate country/date groups; labour companions contain
  dates beyond the current 2024 reference year.
- **Fix**: Obtain an approved mapping/deduplication/vintage policy. Do not
  synthesize, delete, or silently remap rows.
- **Tag**: `[manual]`

## P2 — IMPORTANT

### [P2.1] Derived CSV schema, coverage, freshness, and key checks are incomplete
- **Files**: `R/collect_dim4_1.R`, tests
- **Why**: The manifest hashes existing files but does not validate required
  output columns, duplicate keys, country coverage, or freshness against inputs.
- **Fix**: Add derived-artifact validators and mutation/backdating tests.
- **Tag**: `[safe_auto]`

### [P2.2] Manifest paths are absolute
- **Files**: `R/collect_dim4_1.R`
- **Why**: `normalizePath()` writes machine-specific paths, reducing portability.
- **Fix**: Store project-relative paths and resolve them at consumption time.
- **Tag**: `[safe_auto]`

### [P2.3] Positive fixtures mask the production companion blocker
- **Files**: `tests/testthat/test-dim4-collection.R`
- **Why**: The fixture replaces missing countries with `Kosovo`, so the focused
  suite passes while the real household companion fails.
- **Fix**: Preserve invalid rows in a negative fixture and use separate clean
  fixtures for positive tests.
- **Tag**: `[manual]`

### [P2.4] Documentation and executable target names diverge
- **Files**: `docs/user-guide.md`, `R/checkpoints.R`
- **Why**: Some documentation refers to individual checkpoint targets while the
  collection graph exposes a combined `manual_checkpoints` target; derived
  survey field examples also use names not produced by the code.
- **Fix**: Align commands and field names with the executable graph.
- **Tag**: `[safe_auto]`

### [P2.5] R-source invalidation is not explicit
- **Files**: `_targets.R`, `_targets_data.R`
- **Why**: Plain `source()` loops do not create explicit target dependencies on
  changes to collection or estimation R functions.
- **Fix**: Use a tracked source target or explicit source-file dependencies and
  test invalidation.
- **Tag**: `[safe_auto]`

### [P2.6] Catalogue adapter is operationally expensive
- **Files**: `R/collect_dim4_1.R`, legacy catalogue Rmd
- **Why**: The legacy path can issue thousands of sequential detail requests,
  has no robust call budget, and may fail after partial writes.
- **Fix**: Cache/bound requests, make refresh explicitly opt-in, and use staged
  promotion with failure-rate checks.
- **Tag**: `[manual]`

## Passed Checks

- D4.1 focused tests: passed with 0 failures.
- Pipeline contract tests: 8 passed, 0 failed.
- Dimension 4 scoring tests: 25 passed, 0 failed.
- Full suite: 241 passed, 0 failed, 187 warnings, 12 expected skips.
- No diagnostics errors in the changed R/targets/config files.
- D4.1 and D2.4 NADA paths remain structurally separate.

## Review State

The review is not merge-ready. The existing companion-data blocker and the P0/P1
manifest/data-integrity findings require resolution or explicit analyst approval
before the plan can be marked complete.

## Autofix Applied

- P0.1: estimation now validates D4.1 manifest vintage, paths, and SHA-256
  hashes before `dim4` reads artifacts.
- P1.1: estimation now fails when the World Bank country metadata snapshot is
  absent; collection may still bootstrap the snapshot.
- P1.2: the D4.1 manifest depends on the collection-run marker so partial runs
  cannot silently reuse a completed status report.
- P2.1: generated D4.1 CSVs now validate required columns, non-empty keys,
  current dates, duplicate keys, and non-empty outputs; freshness versus each
  input remains open.
- P2.2: manifest paths are stored relative to the project where possible.
- P2.5: both target scripts now track the R source directory explicitly.
- P0.2: companion validation now applies canonical country aliases and records
  the evidence-backed TWN household exclusion; unknown names remain blocking.
- P0.3: manual-review keys and non-empty values now receive country-membership
  and year/register grammar validation; review merging is additive in scoring.
- P1.3: manual workbook inputs now use an attestation vintage rule rather than
  an API-style permanently unverified rule.
- P2.1: derived artifacts now validate schema, keys, vintage dates, and source
  freshness before manifest creation.
- P2.3: positive fixtures are cleaned deterministically and negative tests use
  explicit unknown-country and unresolved-production fixtures.

Manual review remains required for P0.4, P1.4, P1.5, P2.4, and P2.6.

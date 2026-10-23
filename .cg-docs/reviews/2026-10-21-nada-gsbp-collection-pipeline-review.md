---
date: 2026-10-21
depth: data-risk
type: standard
plan: .cg-docs/plans/2026-10-21-nada-gsbp-collection-pipeline.md
findings:
  P0.1: fixed
  P0.2: fixed
  P1.1: open
  P1.2: fixed
  P1.3: fixed
  P1.4: fixed
  P2.1: fixed
  P2.2: fixed
  P2.3: fixed
  P2.4: fixed
  P2.5: fixed
---

# Review Report

**Review mode**: data-risk

**Files reviewed**: NADA collection code, target wiring, configuration,
registry, tests, generated NADA artifacts, status artifacts, and current user
-guide sections.

**Findings**: 11 (P0: 0 open, P1: 1 open, P2: 0 open, P3: 0)

## P0 — Blocking (resolved)

### [P0.1] Technical HTTP failures are converted into methodological zeros

**Files**: `R/collect_nada.R` (`check_nada_urls()`,
`collect_nada_url_evidence()`, `build_nada_vintage()`).

Only HTTP 200 is marked working. HTTP 403, 404, 410, 418, 500, and 503 are
marked `NADA_working = FALSE`, and positive prior values are automatically
changed to `NADA = 0`. The network guard counts only missing status codes, so a
large wave of terminal HTTP errors is not treated as a collection failure.

The generated 2025 evidence has 98 HTTP 200 responses, 14 HTTP 403, 21 HTTP
404, 1 HTTP 410, 1 HTTP 418, 3 HTTP 500, 3 HTTP 503, and 26 missing statuses.
The output has 93 zeros and 97 ones, compared with 154 positive values in the
2024 source. Technical reachability failures are not evidence that a NADA
catalogue is absent.

the current 2025 output for estimation or publication until resolved.
**Resolution**: Technical failures are now preserved as unresolved and require
an explicit manual-review value. They are no longer silently auto-zeroed.

### [P0.2] Positive values can survive without URL evidence

**Files**: `R/collect_nada.R`, `01_raw_data/2.4_DSDS/D2.4.NADA.2025.csv`.

URL checks omit blank `NADA_text` values. Evidence matching compares only the
non-blank `(iso3c, url)` pairs, and the builder uses `match()` without requiring
one unique evidence row for every output country. As a result, a positive NADA
value can retain `NADA_working = NA` and still be scored as 1. The generated
2025 output contains one positive row with a blank URL.

**Resolution**: Evidence now requires exact one-to-one country/URL coverage,
including explicit rows for blank URLs and transport errors. Positive unresolved
values block the current-vintage builder.

## P1 — Critical

### [P1.1] The current collection run is incomplete and its status is stale

**Files**: `01_raw_data/_collection/collection_run.json`,
`01_raw_data/_collection/collection_status.csv`,
`01_raw_data/_collection/collection_status.md`.

The live command ran only `nada_output`. The run marker remains
`collection_state: "started"`, and the status report still describes the 2024
NADA artifact from the earlier collection run. The 2025 CSV, evidence, and
manifest therefore exist but are not certified by a completed collection run.

a current status report whose source IDs, run marker, parameters, and artifact
**Status**: open. The 2025 manual review workbook now contains 65 explicit
decisions and the NADA output rebuild succeeds. The complete collection target
still stops at the unrelated missing 2025 D4.1 microdata inputs, so the
estimation gate does not yet have a current completed status report.

### [P1.2] Provenance hashes are written but not enforced by the status gate

**Files**: `R/collect_nada.R`, `R/collection_status.R`, `_targets_data.R`.

The NADA manifest records hashes, but collection status checks only file
presence and age. It does not consume the manifest or recompute the output and
evidence hashes. `nada_output` also writes CSV/JSON side effects from an RDS
target. A later replacement of the CSV could therefore remain present and pass
status checks while changing estimates.

The collection parameter hash also hashes the registry path rather than the
registry contents and omits review/evidence identities.

**Resolution**: Current NADA output, evidence, previous vintage, and review
hashes are now validated from the manifest. Registry content and collection
input identities are included in the collection-run hash.

### [P1.3] Fresh URL-cache validation is incomplete

**Files**: `R/collect_nada.R` (`.nada_evidence_matches_sites()`,
`collect_nada_url_evidence()`).

A fresh cache is reused when its `(iso3c, url)` pairs match. Required columns,
unique keys, complete coverage, valid status types, and cached error rates are
not validated before `NADA_working` is consumed. A malformed or unhealthy
cache can bypass the network guard and feed incomplete evidence into the
builder.

**Resolution**: Fresh cache hits now validate schema, unique keys, exact
coverage, and status consistency before reuse.

### [P1.4] Always-run target cues undermine incremental collection

**Files**: `_targets_data.R`.

`collection_run_start`, `nada_url_evidence`, `nada_output`, and
`collection_status` are always-run. The evidence cache prevents repeated HTTP
requests when fresh, but the target still rebuilds local outputs and rewrites a
timestamped manifest on every invocation.

**Resolution**: URL evidence and NADA output now use dependency-aware targets;
the generated CSV is a `format = "file"` target, and URL refresh remains an
explicit parameter.

## P2 — Important

### [P2.1] Review keys are not constrained to the canonical country universe

**Files**: `R/collect_manual_review.R`, `R/collect_nada.R`.

`valid_iso3c` is optional, and the NADA builder does not pass a canonical key
set. Unmatched review keys are treated as new countries and appended to the
output. A mistyped ISO3C can therefore create a synthetic row or fail to update
the intended country.

**Resolution**: Production targets pass the saved World Bank ISO3C universe to
review validation; unmatched review keys fail loudly.

### [P2.2] The 2024 regression fixture is circular

**File**: `tests/testthat/test-nada-collection.R`.

The test derives the TJK and FJI review values from the committed expected 2024
output and then compares the rebuild to that same output. It tests plumbing but
not independent reproduction of the historical decisions, and it does not
assert the final `score_nada()`/dimension result despite the plan's contract.

**Resolution**: The regression uses independent literal TJK/FJI review values
and verifies both indicator values and `score_nada()` output.

### [P2.3] User documentation still describes the legacy NADA workflow

**File**: `docs/user-guide.md`.

The guide still tells users to run `02_programs/misc_scripts/nada_check.R` and
lists only `iso3c`, `NADA`, and `NADA_text`. It does not document the current
review workbook and `Evidence` field, URL-evidence cache, refresh parameters,
2025+ auto-zero rule, manifest, warning behavior, or the legacy script's
reference-only status.

**Resolution**: The NADA section now documents the target workflow, review
schema, cache, evidence, fail-closed behavior, manifest, and legacy-script
boundary. GSBP documentation remains part of Phase 2.

### [P2.4] Duplicate manual-review headers are now rejected

**Status**: fixed automatically.

`validate_manual_review()` now fails loudly on duplicate workbook column names,
and a regression test covers the condition.

### [P2.5] NADA manifest paths are now repository-relative

**Status**: fixed automatically.

The manifest writer now normalizes project paths before recording them. The
2025 manifest was regenerated and no longer exposes the local absolute path.

## Fix Summary

autofixed.
Applied the requested fixes in the manual-review helper, NADA collector,
collection status, target graph, registry, tests, and user guide. The
technical-failure policy was changed to fail closed as a conservative
data-integrity decision; this is recorded as a deviation from the original
auto-zero plan.

## Incomplete Reviews

- `@cg-testing` did not produce usable output because its dispatch hit a
  transient network error. The focused and full local test commands were run
  independently.

## Validation

- Manual-review tests: 21 passed.
- NADA collection tests: 23 passed.
- Manual-review tests: 22 passed.
- Collection-status tests: 15 passed.
- Final full test suite: 299 passed, 0 failed, 200 warnings, 12 skips.
- Manifest hash/tamper validation: passed.
- Manifest path refresh: passed; paths are repository-relative.
- 2025 NADA review workbook: 65 explicit decisions; output rebuilt with 190
  rows, 160 positives, 30 negatives, and zero auto-zeros.
- NADA manifest validator: passed.
- Full collection-status target: blocked by 8 missing 2025 D4.1 microdata files.
- Live collection status: not complete; the run marker remains `started`.

## Passed

- No credentials or secrets were found in the added implementation.
- No changes to `R/dim2.R` or `R/dim5.R` were made.
- No legacy Rmd or `02_programs/misc_scripts/*` file was changed by the NADA
  implementation.
- No material memory/performance issue was found for the 190-country data size;
  the primary performance risk is sequential HTTP runtime.

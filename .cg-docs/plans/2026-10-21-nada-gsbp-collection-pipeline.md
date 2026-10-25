---
date: 2026-10-21
title: "Integrate D2.4 NADA and D5.2.10 GSBP into the SPI Collection Pipeline"
status: active
scope: "Standard"
brainstorm: ".cg-docs/brainstorms/2026-10-21-nada-gsbp-collection-pipeline.md"
execution-report: ".cg-docs/work-reports/2026-10-21-nada-gsbp-collection-pipeline.md"
language: "R"
estimated-effort: "medium"
deviation-policy: "ask"
artifact-schema-version: 1
phases: 2  # convenience hint -- may be stale; always recount from ## Phase headers
tags: [nada, gsbp, dimension-2.4, dimension-5.2, manual-review, collection, targets, regression]
superseded-by: ".cg-docs/plans/2026-10-23-spi-202611-source-readiness.md"
---

# Plan: Integrate D2.4 NADA and D5.2.10 GSBP into the SPI Collection Pipeline

## Objective

Produce `D2.4.NADA.<end_date>.csv` and `D5.2.10.GSBP.<end_date>.csv` inside the
`{targets}` collection pipeline (`_targets_data.R`) from (1) the previous
vintage, (2) automated evidence, and (3) a validated per-vintage manual review
workbook, with provenance manifests, loud failures, and a 2024 regression test.

## Context

- Both indicators are scored by estimation (`score_nada()` in `R/dim2.R`,
  `score_gsbp()` in `R/dim5.R`) but produced by legacy scripts that must not be
  edited: `02_programs/misc_scripts/nada_check.R` (hardcoded 2023 input,
  personal Windows output path) and the GSBP section of
  `02_programs/misc_scripts/preprocess-manual-data-4.1-and-5.2.10.R`
  (hardcoded `date = 2024`, live `wb_countries()`).
- The collection pipeline currently only runs `verify_nada_data()` (presence
  and schema) inside `manual_checkpoints`; GSBP has no collection presence.
- Verified data facts (2026-10-21):
  - NADA 2023 -> 2024: 1 value change (TJK 0 -> 1); 2 `NADA_text` changes (FJI,
    TJK); 20 countries kept `NADA = 1` despite `NADA_working = FALSE`.
  - `01_raw_data/2.4_DSDS/Nada2024.csv` (the `nada_check.R` output) differs from
    the committed `D2.4.NADA.2024.csv` on `NADA`/`NADA_text`/`NADA_working`; it
    was hand-edited afterwards. It is usable only as URL evidence.
  - GSBP 2024 equals the desk review `01_raw_data/5.2_DISM/raw/D1.12.MSC.csv`
    (`Business Process (GSBPM)`) for 190/190 countries; the desk review is a
    cumulative sheet (all 65 2023 "Yes" plus 12 new). The union rule
    (previous "Yes" OR desk review "Yes") reproduces 2024 exactly.
  - `D1.12.MSC.csv` last changed in `95b3959` (2025-05-10) and is edited in
    place, so the 2024 regression needs a frozen fixture copy.
- `config/params.R` already has `end_date <- 2025`.
- Reusable patterns: `validate_dim4_1_review()` / `read_dim4_1_review()` /
  `dim4_1_review_metadata()` in `R/collect_dim4_1.R`; `with_http_retry()` in
  `R/collection_http.R`; cache-age logic in `R/collection_cache.R`;
  `world_bank_inputs$countries` snapshot from `R/collect_world_bank.R`.
- Packages already locked: `httr`, `digest`, `writexl`, `readxl`, `jsonlite`.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Collection pipeline writes `01_raw_data/2.4_DSDS/D2.4.NADA.<end_date>.csv`; no hardcoded years or personal paths | Brainstorm |
| R2 | Collection pipeline writes `01_raw_data/5.2_DISM/D5.2.10.GSBP.<end_date>.csv`; country metadata from the saved `world_bank_inputs` snapshot | Brainstorm |
| R3 | Values = previous vintage carried forward, plus automated evidence, plus per-vintage manual review overrides | Brainstorm |
| R4 | NADA URL check is a cached collection step: reused unless older than `nada_url_max_age_days` or `refresh_nada_urls = TRUE` | Brainstorm |
| R5 | Auto-zero: only when `end_date >= first_collected_vintage` (2025), URL still fails after retries, previous `NADA = 1`, and no review row sets `NADA`; every auto-zero is listed as a warning | Brainstorm |
| R6 | Historical vintages (< `first_collected_vintage`) are never written to `01_raw_data/` | Brainstorm |
| R7 | 2024 regression: rebuilt `iso3c`/`NADA`/`NADA_text` and `iso3c`/`GSBP` equal committed 2024 files; `score_nada()`/`score_gsbp()` 2024 scores identical | Brainstorm |
| R8 | Block on: missing review file for `end_date`; review with unknown/duplicate/missing `iso3c` or invalid values; override without `Evidence`; country in previous vintage or metadata scope without a matching row in the other and no review row | Brainstorm |
| R9 | Warn when the GSBP desk review hash equals the previous vintage's recorded hash | Brainstorm |
| R10 | No edits to Rmd files or `02_programs/misc_scripts/*` | Brainstorm / user |
| R11 | Scoring functions `score_nada()` and `score_gsbp()` unchanged | Brainstorm |
| R12 | Shared, reusable review helper (designed for later CNIN/EMPL/FINA use) | Brainstorm |
| R13 | Registry entries and collection status for NADA/GSBP outputs and review files; NADA presence check moves from `manual_checkpoints` to post-build validation | Brainstorm |
| R14 | `docs/user-guide.md`: NADA section rewritten, GSBP section added, run order and review roles documented | Brainstorm |

## Phase 1: Shared review layer and NADA

### 1. Shared manual-review helper

- **Requirements**: R3, R8, R12
- **Files**: `R/collect_manual_review.R` (new), `tests/testthat/test-manual-review.R` (new)
- **Details**:
  - `manual_review_spec(indicator, value_columns, validators, evidence_column = "Evidence")`:
    a list describing review columns; each validator is a function returning a
    logical vector of valid non-blank values.
  - `read_manual_review(path, spec)`: fail loudly if the file is missing
    (`"<INDICATOR> MANUAL REVIEW FILE NOT FOUND: <path>"`); read with
    `readxl::read_xlsx(.name_repair = "minimal")`; call
    `validate_manual_review()`.
  - `validate_manual_review(data, spec, valid_iso3c = NULL)`: required columns
    `iso3c`, `country`, value columns, `Evidence`; no missing, blank, or duplicate
    `iso3c`; unknown `iso3c` blocks when `valid_iso3c` is given; non-blank
    values must pass validators; any row with a non-blank value must have
    non-blank `Evidence`.
  - `apply_manual_review(base, review, spec)`: left-join on `iso3c`; for each
    value column, non-blank review value replaces base; returns the data plus a
    tidy `overrides` table (`iso3c`, column, old, new, Evidence).
  - `manual_review_metadata(path, review, overrides)`: relative path, sha256,
    rows, override count (for manifests).
  - Header-only review workbook (no rows) is valid and means "no overrides".
- **Test Scenarios**: happy path with two overrides; blank cells ignored;
  missing file; missing column; duplicate iso3c; unknown iso3c; invalid value;
  override without Evidence; header-only file.
- **Tests**: `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-manual-review.R")'`
- **Acceptance criteria**: all scenarios pass using temp `.xlsx` fixtures written
  with `writexl`.

### 2. NADA URL evidence (cached)

- **Requirements**: R4, R5
- **Files**: `R/collect_nada.R` (new), `config/params.R`, `tests/testthat/test-nada-collection.R` (new)
- **Details**:
  - Params: `first_collected_vintage <- 2025`, `nada_url_max_age_days <- 30`,
    `refresh_nada_urls <- FALSE`, `nada_url_delay_seconds <- 5`.
  - `nada_artifact_paths(raw_dir, end_date)`: previous file
    (`D2.4.NADA.<end_date-1>.csv`), review
    (`D2.4.NADA.Manual.Review.<end_date>.xlsx`), evidence
    (`2.4_DSDS/collection/D2.4.NADA.url_evidence.<end_date>.csv`), output
    (`D2.4.NADA.<end_date>.csv`), manifest
    (`2.4_DSDS/collection/D2.4.NADA_manifest_<end_date>.json`).
  - `check_nada_urls(sites, request_fn = httr::GET, delay_fn = Sys.sleep, attempts = 3)`:
    for each non-blank `NADA_text`, call `with_http_retry()`; record `iso3c`,
    `url`, `status_code` (NA on error), `NADA_working` (status 200),
    `error_message`, `checked_at` (UTC), `attempts`.
  - `collect_nada_url_evidence(params, request_fn = NULL, delay_fn = NULL)`:
    reuse the evidence CSV when it exists, is younger than
    `nada_url_max_age_days`, covers the same `iso3c`/URL set as the
    to-be-checked sites, and `refresh_nada_urls` is FALSE; otherwise run
    `check_nada_urls()` and write it. URL set = previous `NADA_text` with any
    review `NADA_text` overrides applied. Returns the evidence path.
  - Network-wide failure guard: if more than 50% of checked URLs end in
    error (no HTTP status), stop with
    `"NADA URL CHECK FAILED FOR MOST SITES; check network access before auto-zeroing."`
- **Test Scenarios**: fake `request_fn` returning 200/404/error; retry on 503
  then 200; cache reused when fresh; refreshed when stale or flag set; cache
  invalidated when URL set changes; >50% errors stops.
- **Tests**: `test_file("tests/testthat/test-nada-collection.R")` (no network;
  `delay_fn = function(...) NULL`).
- **Acceptance criteria**: evidence CSV schema stable; no real HTTP in tests.

### 3. NADA vintage builder

- **Requirements**: R1, R3, R5, R6, R8, R11
- **Files**: `R/collect_nada.R`, `tests/testthat/test-nada-collection.R`, `tests/testthat/fixtures/nada/` (new)
- **Details**:
  - `build_nada_vintage(previous, evidence, review, end_date, first_collected_vintage)`:
    1. Start from the previous vintage (keep its columns and order; set
       `date = end_date`).
    2. Apply review overrides (`NADA` in {0, 1}; `NADA_text` must start with
       `http://` or `https://`).
    3. Join evidence -> `NADA_working`.
    4. If `end_date >= first_collected_vintage`: rows with `NADA == 1`,
       `NADA_working` FALSE or NA-with-error, and no review `NADA` override ->
       `NADA = 0`; record them in `auto_zero`.
    5. Return the data plus `overrides` and `auto_zero`.
  - `write_nada_vintage(result, paths, end_date, first_collected_vintage, allow_historical = FALSE)`:
    refuse `end_date < first_collected_vintage` unless `allow_historical`
    (tests only, temp dirs); write CSV with `readr::write_csv`; write a manifest
    JSON (inputs with sha256, review metadata, evidence path and age,
    `auto_zero`, `overrides`, row count, created_at); then run
    `verify_nada_data()` on the written file.
  - New-country block: `iso3c` in the review not in previous -> block unless the
    review supplies both `NADA` and `NADA_text`; previous rows are never
    dropped.
  - Regression fixture `tests/testthat/fixtures/nada/D2.4.NADA.Manual.Review.2024.xlsx`
    with TJK (`NADA = 1`, new `NADA_text`) and FJI (new `NADA_text`), Evidence
    `"Backfilled 2026-10-21 from committed D2.4.NADA.2024.csv for regression"`;
    evidence replayed from `Nada2024.csv` (`NADA_working`).
  - Regression test: build 2024 from `D2.4.NADA.2023.csv` + fixtures in a temp
    dir; compare `iso3c`, `NADA`, `NADA_text` to committed
    `D2.4.NADA.2024.csv`; run `score_nada()` with `raw_dir` pointed at a temp
    copy and compare `SPI.D2.4.NADA` for `date == 2024`.
- **Test Scenarios**: carry-forward unchanged; override applied; auto-zero
  only for 2025+; review `NADA = 1` suppresses auto-zero; historical write
  refused; new country without full review row blocks; 2024 regression.
- **Tests**: `test_file("tests/testthat/test-nada-collection.R")`
- **Acceptance criteria**: regression equal; all scenarios pass.

### 4. NADA targets, registry, status

- **Requirements**: R1, R4, R13
- **Files**: `_targets_data.R`, `config/source_registry.R`, `R/collection_checkpoints.R`, `R/collection_report.R`, `01_raw_data/2.4_DSDS/D2.4.NADA.Manual.Review.2025.xlsx` (new template)
- **Details**:
  - Targets: `nada_previous_file` (format file), `nada_review_file` (format
    file), `nada_url_evidence` (format file, `tar_cue(mode = "always")`; caching
    lives in the function), `nada_output` (builds, writes, returns output and
    manifest paths). `collection_status` depends on `nada_output`.
  - Remove `nada = verify_nada_data(params)` from `run_collection_checkpoints()`
    (now run inside `write_nada_vintage()`); keep `verify_nada_data()` itself.
  - Registry: update `d2_4_nada` `input_path` to include the review file; add
    `d2_4_nada_review` (manual, `2.4_DSDS/D2.4.NADA.Manual.Review.<END_DATE>.xlsx`,
    `end_date`, blocking) and `d2_4_nada_url_evidence` (external,
    `2.4_DSDS/collection/D2.4.NADA.url_evidence.<END_DATE>.csv`, warning).
    Confirm the placeholder token style used by `resolve_collection_artifact_path()`.
  - `write_collection_status_report()`: add optional `warnings` argument
    (data frame `source_id`, `message`) rendered as a "Collection warnings"
    section in the markdown only; CSV schema and
    `validate_collection_status()` unchanged.
  - Template: all `iso3c` and `country` rows from the 2024 file; blank `NADA`,
    `NADA_text`, `Evidence`; header comment cell not added (schema stays
    plain).
- **Test Scenarios**: registry validator accepts new rows; status report renders
  warnings; pipeline-contract test still passes.
- **Tests**: `test_file("tests/testthat/test-source-registry.R")`,
  `test_file("tests/testthat/test-collection-status.R")`,
  `test_file("tests/testthat/test-pipeline-contract.R")`
- **Acceptance criteria**: `tar_manifest(script = "_targets_data.R")` lists the
  new targets; existing tests unchanged in outcome.

## Phase 2: GSBP, regression, live run, documentation

### 5. GSBP vintage builder

- **Requirements**: R2, R3, R6, R8, R9, R11
- **Files**: `R/collect_gsbp.R` (new), `tests/testthat/test-gsbp-collection.R` (new), `tests/testthat/fixtures/gsbp/D1.12.MSC.2024.csv` (new frozen copy)
- **Details**:
  - `gsbp_artifact_paths(raw_dir, end_date)`: previous
    (`D5.2.10.GSBP.<end_date-1>.csv`), desk review (`5.2_DISM/raw/D1.12.MSC.csv`),
    review (`D5.2.10.GSBP.Manual.Review.<end_date>.xlsx`), output, manifest
    (`5.2_DISM/collection/D5.2.10.GSBP_manifest_<end_date>.json`).
  - `read_gsbp_desk_review(path)`: require `Code`, `Country`,
    `Business Process (GSBPM)`; values blank or "Yes" (case-insensitive) else
    block; unique `Code`.
  - `build_gsbp_vintage(previous, desk_review, review, country_metadata, end_date)`:
    `GSBP = "Yes"` if previous is "Yes" or desk review is "Yes", else NA; apply
    review (`GSBP` in {"Yes", "No"}; "No" written as NA so the stored
    vocabulary stays {"Yes", NA}); join `country_metadata` (snapshot) and keep
    the 2024 column order (`colnames(country_metadata)`, then `date`, `GSBP`).
  - Stale warning: compare desk-review sha256 with the previous manifest's
    recorded hash; add a warning when equal. Baseline:
    `01_raw_data/5.2_DISM/collection/D5.2.10.GSBP_manifest_2024.json`
    recording the sha256 of `D1.12.MSC.csv` at commit `95b3959` and marked
    `"baseline": true`.
  - `write_gsbp_vintage()`: same historical guard and manifest pattern as NADA.
  - Regression: build 2024 from `D5.2.10.GSBP.2023.csv` + fixture desk review +
    empty review; compare `iso3c`, `GSBP` to committed 2024; compare
    `score_gsbp()` 2024 scores.
- **Test Scenarios**: union rule; review "No" removes a "Yes"; invalid desk
  value blocks; stale hash warns; missing review blocks; historical write
  refused; 2024 regression.
- **Tests**: `test_file("tests/testthat/test-gsbp-collection.R")`
- **Acceptance criteria**: regression equal; all scenarios pass.

### 6. GSBP targets and registry

- **Requirements**: R2, R13
- **Files**: `_targets_data.R`, `config/source_registry.R`, `01_raw_data/5.2_DISM/D5.2.10.GSBP.Manual.Review.2025.xlsx` (new template)
- **Details**: targets `gsbp_previous_file`, `gsbp_desk_review_file`,
  `gsbp_review_file` (format file) and `gsbp_output` (uses
  `world_bank_inputs$countries`); `collection_status` depends on `gsbp_output`
  and passes NADA auto-zeros and GSBP stale warnings to the report. Registry
  rows `d5_2_10_gsbp` (output, `end_date`, blocking), `d5_2_10_gsbp_desk_review`
  (manual, `age_warning_days = 365`, warning), `d5_2_10_gsbp_review` (manual,
  `end_date`, blocking). Template with all 2024 `iso3c`/`country` rows and blank
  `GSBP`/`Evidence`.
- **Test Scenarios**: registry validation; status includes the new source IDs.
- **Tests**: `test_file("tests/testthat/test-source-registry.R")`,
  `test_file("tests/testthat/test-collection-status.R")`
- **Acceptance criteria**: `tar_manifest()` lists the GSBP targets.

### 7. Full suite and live collection run

- **Requirements**: R1, R2, R4, R5, R7, R10, R11
- **Files**: none new
- **Details**: run the full suite; then
  `targets::tar_make(names = c("nada_output", "gsbp_output", "collection_status"), script = "_targets_data.R", store = "_targets_data")`
  with the 2025 review templates in place (empty review = no overrides). Check
  the output files, manifests, evidence CSV, and the warnings in
  `collection_status.md`. Confirm `git diff --stat -- 02_programs/ R/dim2.R R/dim5.R`
  is empty.
- **Test Scenarios**: full suite; live run; stop if >50% URL errors.
- **Tests**: `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'`
- **Acceptance criteria**: `FAIL 0`; 2025 files exist; warnings listed.

### 8. Documentation

- **Requirements**: R14
- **Files**: `docs/user-guide.md`, `docs/CHANGELOG.md`
- **Details**: rewrite the 2.4 NADA section: inputs, review workbook schema,
  URL evidence cache and refresh params, auto-zero rule (2025+, after
  retries, reported), outputs, failure meanings, and the legacy
  `nada_check.R` as reference only. Add a 5.2.10 GSBP section: desk-review
  sheet (edited in place; stale warning), union rule, review workbook ("Yes" /
  "No"), outputs. Add both rows to the collection-run order. Preserve the
  user's 2026-10-21 edits in the D4.1 section.
- **Test Scenarios**: n/a (docs).
- **Tests**: manual read-through plus link check of paths cited.
- **Acceptance criteria**: every file, parameter, and target named in the docs
  exists.

## Testing Strategy

- Unit tests per helper with temp-dir fixtures; no network (injected
  `request_fn` and `delay_fn`).
- Regression tests for 2024 in the NADA and GSBP test files, writing only to
  `tempdir()` with `allow_historical = TRUE`.
- Contract tests: registry, status, pipeline contract.
- Full suite once per phase; baseline `FAIL 0 | SKIP 12`.

## Documentation Checklist

- [ ] `docs/user-guide.md` NADA section rewritten
- [ ] `docs/user-guide.md` GSBP section added
- [ ] `docs/CHANGELOG.md` entry
- [ ] Creation-date headers in all new R, test, and fixture-generating files
- [ ] roxygen headers on exported functions

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| World Bank network blocks many NSO sites, causing mass false auto-zeros | Medium | High | >50% error guard stops; retries; every auto-zero reported; review row can restore `NADA = 1` |
| Some NSO sites block automated requests (403) but work in a browser | Medium | Medium | Auto-zeros listed for review; review overrides take precedence |
| `D1.12.MSC.csv` edited in place breaks the 2024 regression later | High | Medium | Frozen fixture copy in `tests/testthat/fixtures/gsbp/` |
| Status-report change affects estimation gating | Low | High | Warnings added only to markdown; CSV and `validate_collection_status()` unchanged |
| Registry placeholder token mismatch (`<END_DATE>` vs `<YEAR>`) makes status miss files | Medium | Medium | Confirm with `resolve_collection_artifact_path()` and a status test |
| URL check runtime (~15-20 min) slows collection | High | Low | Cached evidence with max-age and refresh flag |
| Header-only review files accidentally treated as missing | Low | Medium | Explicit unit test |

## Out of Scope

- CNIN, EMPL, FINA collection (IMF DSBB scraper indicators).
- Changes to NADA or GSBP scoring rules.
- Any edit to Rmd files or `02_programs/misc_scripts/*`.
- Automating GSBPM evidence discovery.
- Wiring `download_targets()` / `checkpoint_nada` in `_targets.R`.
- Filling in 2025 review values (technical lead's manual review).

## Completion Contract

### Outcome

Running the collection pipeline with `end_date = 2025` produces validated
`D2.4.NADA.2025.csv` and `D5.2.10.GSBP.2025.csv` from the previous vintage,
automated evidence, and 2025 review workbooks, with manifests recording
provenance, overrides, and auto-zeros; rebuilding 2024 reproduces the committed
indicator columns and scores.

### Verification Surface

| ID | Evidence Required | Command/Artifact | Required |
|----|-------------------|------------------|----------|
| V1 | Shared review helper tests pass | `testthat::test_file("tests/testthat/test-manual-review.R")` | yes |
| V2 | NADA tests pass (carry-forward, cached evidence, retries, auto-zero 2025+, overrides, new-country block) | `testthat::test_file("tests/testthat/test-nada-collection.R")` | yes |
| V3 | GSBP tests pass (union, overrides incl. "No", stale-hash warning, new-country block) | `testthat::test_file("tests/testthat/test-gsbp-collection.R")` | yes |
| V4 | 2024 regression: indicator columns and `score_nada()`/`score_gsbp()` 2024 scores identical | regression blocks in V2/V3 files | yes |
| V5 | Full suite has no new failures | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` | yes |
| V6 | Live collection writes 2025 outputs, manifests, and evidence CSV | `tar_make(names = c("nada_output","gsbp_output"), script = "_targets_data.R", store = "_targets_data")` | yes |
| V7 | Status report lists both indicators and shows auto-zero/stale warnings | `01_raw_data/_collection/collection_status.md` | yes |
| V8 | Legacy files untouched | `git diff --stat -- 02_programs/` | yes |
| V9 | User guide updated for NADA and GSBP | `docs/user-guide.md` diff | yes |

### Constraints

| ID | Constraint | Check |
|----|------------|-------|
| C1 | No edits to Rmd files or `02_programs/misc_scripts/*` | V8 |
| C2 | `score_nada()` / `score_gsbp()` unchanged | `git diff R/dim2.R R/dim5.R` empty |
| C3 | No writes of vintages < 2025 to `01_raw_data/` | unit test + `git status` on historical files |
| C4 | Fail loudly on missing/invalid review and unreviewed new countries | V1-V3 |
| C5 | No network in tests | V2 (injected `request_fn`) |
| C6 | No new package dependencies | `renv.lock` unchanged |
| C7 | Creation-date header in every new file | review of new files |

### Boundaries

- Allowed: new `R/collect_manual_review.R`, `R/collect_nada.R`,
  `R/collect_gsbp.R`; edits to `_targets_data.R`, `config/params.R`,
  `config/source_registry.R`, `R/collection_checkpoints.R`,
  `R/collection_report.R`; new tests and fixtures under `tests/testthat/`;
  2025 review templates; 2024 GSBP baseline manifest; `docs/user-guide.md`,
  `docs/CHANGELOG.md`.
- Out of scope: CNIN/EMPL/FINA; scoring rules; legacy Rmd and scripts;
  automating the GSBPM desk review; `download_targets()` wiring; filling 2025
  review values.

### Iteration Policy

1. Build and test the shared review helper before indicator code.
2. NADA before GSBP.
3. On regression mismatch, diagnose per country; adjust only fixtures that
   encode documented 2024 manual decisions, never the rule.
4. Single test files during development; full suite once per phase.
5. Live URL check (V6) only after all unit tests pass.

### Blocked-Stop Conditions

- The 2024 regression cannot be met without changing the auto-zero or union
  rule.
- A step requires editing a legacy Rmd/script or `score_nada()`/`score_gsbp()`.
- Showing warnings requires changing `validate_collection_status()` semantics
  that estimation depends on.
- The live URL check errors for more than 50% of sites; stop and report.

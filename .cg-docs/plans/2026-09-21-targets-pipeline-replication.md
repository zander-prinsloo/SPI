---
date: 2026-09-21
title: "Targets-based SPI estimation pipeline with exact replication of the 2024 vintage"
status: active
scope: "Deep"
brainstorm: ".cg-docs/brainstorms/2026-09-21-targets-pipeline-replication.md"
language: "R"
estimated-effort: "large"
deviation-policy: "ask"
execution-report: ".cg-docs/work-reports/2026-09-21-targets-pipeline-replication.md"
completed-phases: [1, 2, 3, 4]
current-phase: 5
artifact-schema-version: 1
tags: [targets, pipeline, replication, testing, user-guide, spi]
---

# Plan: Targets-based SPI Estimation Pipeline

## Objective

Build a `{targets}`-based SPI estimation pipeline that exactly replicates the
202511 vintage outputs (the committed `03_output_data/` files) within a 1e-9
relative tolerance, with a comprehensive test suite, schema-validation on
source reads, and a user guide for the technical lead — while the original Rmd
files remain untouched and historical output files are never overwritten.

## Context

The SPI data product is produced by R Markdown pipelines. The three most
important files are `01-SPI_data_prep.Rmd` (5,142 lines), `02-SPI_index.Rmd`
(3,384 lines), and `03_SPI_data_validation.Rmd` (166 lines). These have worked
for several vintages and contain valuable comments and documentation, but Rmd
files are not well suited to reliable estimation and pipeline workflows. The
new pipeline uses R's `{targets}` package, remains readable by the SPI
technical lead (clarity over efficiency), is well documented, and is
accompanied by a user guide covering the step-by-step SPI update approach,
including where to get sources.

Phase 1 of the work is designing comprehensive tests to ensure the new pipeline
works as expected, run against the 2024 data to verify it produces the same
results as the 202511 vintage.

Key mechanics of the existing pipeline (from research):
- `01-SPI_data_prep.Rmd`: reads raw data from `01_raw_data/` (per-dimension
  folders), builds a country×year grid (`spi_df_empty`, 2004–2024 via
  `wbstats::wb_countries()`), processes each indicator (PIP poverty, UN IGME
  child mortality, WDI metadata debt, JMP water, ILO LFP, IMF SDDS, ODIN,
  NADA, UN SDG, censuses/surveys, CRVS, geospatial, legislation, standards,
  finance), applies `na.locf` forward-fill and OECD high-income adjustments,
  then writes `SPI_data.csv` and `SPI_data.dta`.
- `02-SPI_index.Rmd`: reads `SPI_data.csv`, adds population weights, builds
  the nested index (dimension → pillar → overall) with explicit weights
  (`wgt <- 1` unity weights), writes `SPI_index.csv`.
- `03_SPI_data_validation.Rmd`: compares against the published vintage via
  `dataCompareR::rCompare()` and runs `validate::validator()` expectation
  checks (min/max ranges, country/year coverage) plus correlation checks.
- `misc_scripts/`: `SPI_quantiles.R`, `SPI_treemap.R`, `databank.R`,
  `databank_aggregates.R`, `SPL_admin_data_availability` (via
  `microdata_library_pull.Rmd`), `nada_check.R`, `sdg_indicators_for_SPI.R`.
- Update steps (from `SPI updates.xlsx`): per-indicator source instructions —
  WDI metadata download, UN IGME child mortality, JMP washdata API, ILO
  ilostat, ODIN, NADA check script, UNSDG data, microdata library pull,
  previous-vintage copy for 5.2. Next steps: 01 → 02 → 03.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | New pipeline replicates 202511 vintage outputs within 1e-9 relative tolerance | Brainstorm Q&A |
| R2 | Pipeline covers core 3 Rmds (data prep, index, validation) | Brainstorm Q&A |
| R3 | Pipeline covers misc_scripts outputs (quantiles, treemap, databank, SPL admin) | Brainstorm Q&A |
| R4 | Pipeline includes data pulls where APIs allow; manual steps as documented checkpoints | Brainstorm Q&A |
| R5 | Rmd files remain untouched as reference source of truth | Brainstorm Q&A |
| R6 | Extend existing renv with `{targets}`, `{tarchetypes}`, `{testthat}` | Brainstorm Q&A |
| R7 | Standard `targets::tar_make()` entry point (CLI documented as alternative) | Brainstorm Q&A |
| R8 | Fail loudly: schema validation on source reads; source format changes reported, never silently adapted | Brainstorm Q&A |
| R9 | Readability over efficiency; functions simple and well-commented for the technical lead | Brainstorm Q&A |
| R10 | User guide for the technical lead: step-by-step SPI update approach, source locations, manual checkpoints | Brainstorm Q&A |
| R11 | Existing historical output files must never be overwritten | User constraint (contract C7) |
| R12 | Estimation only: visualization chunks and commented-out blocks excluded from porting surface | Brainstorm Q&A |
| R13 | Edge cases handled: source format changes, missing/partial country coverage, new countries/code changes, reproducibility across machines, long run times / partial re-runs | Brainstorm Q&A |

## Implementation Steps

phases: 8  # convenience hint -- may be stale; always recount from ## Phase headers

## Phase 1: Scaffolding

### 1. Extend renv with pipeline packages
- **Requirements**: R6
- **Files**: `renv.lock`, `renv/`
- **Details**: Add `{targets}`, `{tarchetypes}`, `{testthat}` (and any
  transitive deps) to the existing renv lockfile via `renv::install()` +
  `renv::snapshot()`. Do not create a separate environment. Verify
  `renv::restore()` works from a clean state.
- **Test Scenarios**: happy path — packages install and load; edge case —
  version conflicts with existing pinned packages; error path — restore fails
  on a missing package.
- **Tests**: `renv::status()` clean; `library(targets)` loads.
- **Acceptance criteria**: `renv.lock` diff shows only the new packages;
  `renv::restore()` completes.

### 2. Create pipeline skeleton
- **Requirements**: R1, R2, R5, R7, R9, R12
- **Files**: `_targets.R`, `R/` (function library), `config/` (pipeline
  parameters), `data-raw/` or `staging/` (new-output staging area)
- **Details**: Create `_targets.R` with `tar_option_set()` (seed, tidyverse
  style), a `list()` of targets mirroring the pipeline stages, and a
  `config/params.yml` (or R file) holding `end_date`, `window`, `span`,
  `output_dir`, `staging_dir`, `vintage` parameters. Create `R/` with
  per-indicator function files (one file per dimension or indicator group,
  matching the Rmd chunk structure). Functions must be simple, readable, and
  heavily commented, drawing on the Rmd comments. Exclude visualization
  chunks and commented-out blocks (R12).
- **Test Scenarios**: happy path — `tar_manifest()` lists all targets; edge
  case — parameter changes propagate; error path — missing config file fails
  loudly.
- **Tests**: `targets::tar_manifest()`; `targets::tar_visnetwork()` renders.
- **Acceptance criteria**: pipeline graph builds; every estimation chunk from
  the Rmds has a corresponding function/target; visualization chunks do not.

### 3. Create user guide skeleton
- **Requirements**: R10
- **Files**: `docs/user-guide.md`
- **Details**: Create the user guide skeleton with sections: overview,
  prerequisites (renv, R version), how to run the pipeline, how to update each
  indicator (from `SPI updates.xlsx` Update steps tab), where to get sources,
  manual checkpoints, troubleshooting. Populate incrementally as phases
  complete (per brainstorm decision).
- **Test Scenarios**: n/a (documentation).
- **Tests**: n/a.
- **Acceptance criteria**: skeleton exists with all planned sections.

## Phase 2: Test Harness and Fixtures

### 4. Build comparison utilities
- **Requirements**: R1, R8, R13
- **Files**: `R/compare.R`, `tests/testthat/helper-compare.R`
- **Details**: Build tolerance-based comparison utilities (1e-9 relative
  tolerance) that compare two data frames column-by-column, reporting exact
  locations of differences. Handle: column order differences (report, don't
  fail silently), type differences, NA vs 0 differences, row-set differences.
  All comparisons must fail loudly with a clear report.
- **Test Scenarios**: happy path — identical frames pass; edge case —
  floating-point noise within tolerance passes; error path — real difference
  fails with a precise report.
- **Tests**: `testthat::test_file("tests/testthat/test-compare.R")`.
- **Acceptance criteria**: comparison utilities tested and working.

### 5. Snapshot 202511 vintage outputs as fixtures
- **Requirements**: R1, R11
- **Files**: `tests/fixtures/` (copies of `03_output_data/SPI_data.csv`,
  `SPI_index.csv`, quantiles, treemap, databank files, etc.)
- **Details**: Copy the committed 202511 vintage outputs into
  `tests/fixtures/` as immutable reference fixtures. Record SHA-256 hashes of
  the originals in a manifest (`tests/fixtures/manifest.json`) to verify the
  originals are never modified (R11). Fixtures are read-only reference data —
  never modified by tests or the pipeline.
- **Test Scenarios**: happy path — fixtures match originals; edge case —
  fixture file missing; error path — original output file hash changed.
- **Tests**: hash-verification test.
- **Acceptance criteria**: fixtures in place; manifest hashes verified.

### 6. Establish old-vs-new comparison at each stage
- **Requirements**: R1, R13
- **Files**: `tests/testthat/test-stage-compare.R`
- **Details**: Wire the comparison utilities into a test that compares each
  pipeline stage's output (indicator-level, dimension-level, final files)
  against the fixtures. This is the "tests first" harness that drives the
  porting in Phases 3–6.
- **Test Scenarios**: happy path — stage outputs match; edge case — partial
  stage output; error path — mismatch reported with location.
- **Tests**: `testthat::test_file("tests/testthat/test-stage-compare.R")`.
- **Acceptance criteria**: harness runs and reports per-stage comparison.

## Phase 3: Port Data Prep (01)

### 7. Port setup, parameters, and country grid
- **Requirements**: R2, R9, R13
- **Files**: `R/setup.R`, `R/grid.R`
- **Details**: Port the `set-parameters` and `spi_df` chunks: directory
  setup, `window`, `end_date`, `span`, iso3c codes from
  `01_raw_data/metadata/iso_codes.csv`, and the country×year grid from
  `wbstats::wb_countries()` (filtering out aggregates). Add schema validation
  on the iso_codes read (R8).
- **Test Scenarios**: happy path — grid matches vintage dimensions; edge case
  — new country in wb_countries; error path — iso_codes schema change.
- **Tests**: stage-compare test for grid.
- **Acceptance criteria**: grid target matches vintage grid.

### 8. Port Dimension 1.5 indicators
- **Requirements**: R2, R9, R13
- **Files**: `R/dim1_5.R`
- **Details**: Port the five Dimension 1.5 indicators: PIP poverty
  comparability (`pipr`/`PIP_comparability_latest.csv`), UN IGME child
  mortality (`UNICEF-CME_DF_2021_WQ-1.0-download.csv`), debt service from WDI
  metadata, safely managed water (JMP `Safely_Managed_Water_data.csv`), and
  ILO labor force participation. Preserve the exact scoring logic (5/6/7-year
  windows, 0.5/1 point rules, manual country overrides like JPN/AUS/NZL/SGP).
- **Test Scenarios**: happy path — each indicator matches vintage; edge case —
  missing country coverage; error path — source schema change fails loudly.
- **Tests**: stage-compare tests per indicator.
- **Acceptance criteria**: all five D1.5 indicators match vintage.

### 9. Port Dimension 2 indicators
- **Requirements**: R2, R9, R13
- **Files**: `R/dim2.R`
- **Details**: Port SDDS/e-GDDS (from WDI metadata `IMF.data.dissemination.standard`),
  ODIN online access (openness subscore + components), and NADA data access
  services. Preserve exact scoring and the `spi_mapper`-equivalent join logic.
- **Test Scenarios**: happy path — indicators match; edge case — ODIN format
  shift; error path — schema mismatch.
- **Tests**: stage-compare tests.
- **Acceptance criteria**: D2 indicators match vintage.

### 10. Port Dimension 3 (UN SDG)
- **Requirements**: R2, R9, R13
- **Files**: `R/dim3.R`
- **Details**: Port the UN SDG data read (`un_sdg_data_read`), the 5-year
  window availability logic, and the 16 SDG goal indicators (D3.1–D3.17,
  excluding D3.14). Preserve the OECD supplement logic if active.
- **Test Scenarios**: happy path — SDG indicators match; edge case — missing
  goal data; error path — API/source change.
- **Tests**: stage-compare tests.
- **Acceptance criteria**: D3 indicators match vintage.

### 11. Port Dimension 4 indicators
- **Requirements**: R2, R9, R13
- **Files**: `R/dim4.R`
- **Details**: Port censuses and surveys (`census_fun`, `survey_fun`,
  `cs_df`), CRVS (UN SDG data + WDI metadata matching), and geospatial (ODIN
  admin-level data). Preserve the exact combine-years logic and the
  first/second admin level handling.
- **Test Scenarios**: happy path — indicators match; edge case — survey
  classification changes; error path — microdata library schema change.
- **Tests**: stage-compare tests.
- **Acceptance criteria**: D4 indicators match vintage.

### 12. Port Dimension 5 indicators
- **Requirements**: R2, R9, R13
- **Files**: `R/dim5.R`
- **Details**: Port legislation (PARIS21/UN SDG), standards and methods
  (SNAU, NABY, CNIN, CPIBY, HOUS, EMPL, CGOV, FINA, MONY, GSBP from WDI
  metadata and IMF), and finance (UN SDG). Preserve exact scoring and the
  high-income/OECD adjustments.
- **Test Scenarios**: happy path — indicators match; edge case — IMF data
  format change; error path — schema mismatch.
- **Tests**: stage-compare tests.
- **Acceptance criteria**: D5 indicators match vintage.

### 13. Port append and save logic
- **Requirements**: R2, R9, R11
- **Files**: `R/append.R`, `R/save.R`
- **Details**: Port the `append` chunk (population join, `na.locf`
  forward-fill, OECD high-income adjustments) and the `save` chunk
  (`SPI_data.csv` via `write_excel_csv`, `SPI_data.dta` via `write_dta` with
  labels). **Critical (R11)**: writes go to a staging directory
  (`staging/`), never directly to `03_output_data/`. Overwrite protection:
  refuse to write if the target path exists and is a tracked historical file.
- **Test Scenarios**: happy path — staged outputs match vintage; edge case —
  target path exists; error path — write blocked.
- **Tests**: stage-compare test; overwrite-protection test.
- **Acceptance criteria**: `SPI_data.csv`/`.dta` staged and matching vintage;
  historical files untouched.

## Phase 4: Port Index (02)

### 14. Port index weights and nested index construction
- **Requirements**: R2, R9, R13
- **Files**: `R/index.R`
- **Details**: Port the `index_weights` chunk (pillar/dimension weights,
  `wgt <- 1`) and the `index` chunk (na.locf, dimension indices, pillar
  indices, overall SPI.INDEX, ×100 scaling). Preserve exact arithmetic order
  to match floating-point results within tolerance.
- **Test Scenarios**: happy path — index matches vintage; edge case — missing
  indicator; error path — weight misconfiguration.
- **Tests**: stage-compare test for index.
- **Acceptance criteria**: index targets match vintage.

### 15. Port SPI_index.csv output
- **Requirements**: R2, R11
- **Files**: `R/save.R`
- **Details**: Port the `saver` chunk writing `SPI_index.csv` to the staging
  directory with overwrite protection (R11).
- **Test Scenarios**: happy path — staged file matches vintage; error path —
  write blocked.
- **Tests**: stage-compare test; overwrite-protection test.
- **Acceptance criteria**: `SPI_index.csv` staged and matching vintage.

## Phase 5: Port Validation (03)

### 16. Convert validation expectations into automated tests
- **Requirements**: R2, R8, R13
- **Files**: `tests/testthat/test-validation.R`
- **Details**: Convert the `validate::validator()` rules from
  `03_SPI_data_validation.Rmd` (min/max ranges for every SPI indicator,
  country/year coverage, dates by country) into automated testthat tests.
  Keep the exact rule set.
- **Test Scenarios**: happy path — all rules pass; edge case — new country;
  error path — out-of-range value fails.
- **Tests**: `testthat::test_file("tests/testthat/test-validation.R")`.
- **Acceptance criteria**: all validation rules pass on staged outputs.

### 17. Keep vintage comparison and correlation checks
- **Requirements**: R1, R13
- **Files**: `tests/testthat/test-vintage-compare.R`
- **Details**: Port the `dataCompareR::rCompare()` vintage comparison and the
  correlation matrix check into automated tests against the fixtures.
- **Test Scenarios**: happy path — comparison passes; edge case — expected
  vintage drift; error path — unexpected drift fails.
- **Tests**: `testthat::test_file("tests/testthat/test-vintage-compare.R")`.
- **Acceptance criteria**: vintage comparison and correlation checks pass.

## Phase 6: misc_scripts and Data Pulls

### 18. Port quantiles and treemap outputs
- **Requirements**: R3, R11
- **Files**: `R/quantiles.R`, `R/treemap.R`
- **Details**: Port `SPI_quantiles.R` and `SPI_treemap.R` logic as targets,
  writing to staging with overwrite protection (R11).
- **Test Scenarios**: happy path — outputs match vintage; error path — write
  blocked.
- **Tests**: stage-compare tests.
- **Acceptance criteria**: quantiles and treemap staged and matching.

### 19. Port databank outputs
- **Requirements**: R3, R11
- **Files**: `R/databank.R`
- **Details**: Port `databank.R` and `databank_aggregates.R` logic
  (`SPI_databank_country_and_aggregates*.csv`, footnotes) as targets, writing
  to staging with overwrite protection (R11).
- **Test Scenarios**: happy path — outputs match vintage; error path — write
  blocked.
- **Tests**: stage-compare tests.
- **Acceptance criteria**: databank files staged and matching.

### 20. Port SPL admin data output
- **Requirements**: R3, R11
- **Files**: `R/spl_admin.R`
- **Details**: Port the `SPL_admin_data_availability.csv` production logic
  (from `microdata_library_pull.Rmd` outputs) as a target, writing to staging
  with overwrite protection (R11).
- **Test Scenarios**: happy path — output matches vintage; error path — write
  blocked.
- **Tests**: stage-compare test.
- **Acceptance criteria**: SPL admin file staged and matching.

### 21. Add download targets and manual checkpoints
- **Requirements**: R4, R8, R13
- **Files**: `R/pull_*.R`, `_targets.R`
- **Details**: Add download targets where reliable APIs exist (UN SDG API,
  JMP washdata API, WDI metadata, ILO ilostat where feasible). For manual
  downloads (ODIN, NADA check, microdata library, UN IGME), create
  documented checkpoint targets that fail loudly with instructions when the
  expected raw file is missing or schema-invalid (R8). Document each in the
  user guide.
- **Test Scenarios**: happy path — API pull succeeds; edge case — API
  unavailable; error path — manual file missing fails loudly with guidance.
- **Tests**: pull-target smoke tests.
- **Acceptance criteria**: download targets present; manual checkpoints
  documented and failing loudly.

## Phase 7: User Guide Completion

### 22. Finalize the step-by-step update guide
- **Requirements**: R10
- **Files**: `docs/user-guide.md`
- **Details**: Complete the user guide: full step-by-step SPI update approach
  (from `SPI updates.xlsx` Update steps tab), where to get each source
  (WDI metadata, UN IGME, JMP, ILO, ODIN, NADA, UNSDG, microdata library),
  manual checkpoints, how to run the pipeline (`targets::tar_make()`), how to
  interpret test results, and troubleshooting. Include the "Next steps"
  sequence (01 → 02 → 03) mapped to pipeline targets.
- **Test Scenarios**: n/a (documentation).
- **Tests**: n/a.
- **Acceptance criteria**: guide complete and accurate against the pipeline.

## Phase 8: Full Replication Gate

### 23. Run full pipeline and confirm replication
- **Requirements**: R1, R11, R13
- **Files**: `_targets.R`, `tests/`
- **Details**: Run the complete pipeline on 2024 data via
  `targets::tar_make()`. Run the full test suite. Confirm zero (or
  documented, approved) differences vs the 202511 vintage within 1e-9
  relative tolerance. Verify historical output files are unchanged (hash
  manifest). Any difference beyond tolerance escalates to the user under
  `ask` policy.
- **Test Scenarios**: happy path — full suite passes; edge case — partial
  re-run after a source change; error path — any mismatch fails loudly.
- **Tests**: full `testthat` suite; hash-verification test.
- **Acceptance criteria**: full pipeline reproduces vintage; all tests pass;
  historical files untouched.

## Testing Strategy

- **Framework**: `testthat` (3e), run via `targets::tar_make()` test targets
  and standalone `testthat::test_local()`.
- **Comparison harness**: tolerance-based (1e-9 relative) utilities in
  `R/compare.R`, used by all stage-compare tests.
- **Fixtures**: immutable 202511 vintage outputs in `tests/fixtures/` with a
  SHA-256 manifest.
- **Per-stage tests**: each ported indicator/dimension has a stage-compare
  test, enabling fast iteration during porting.
- **Full gate**: complete pipeline run + full suite + hash verification.
- **Fail loudly**: any schema mismatch, missing file, or out-of-tolerance
  difference fails with a precise report.

## Documentation Checklist

- [ ] `docs/user-guide.md` — step-by-step update guide (R10)
- [ ] Roxygen2-style comments on all pipeline functions (R9)
- [ ] `_targets.R` header explaining pipeline structure and how to run it
- [ ] Source-schema registry documentation (expected columns/types per source)
- [ ] README section pointing to the new pipeline and user guide
- [ ] Changelog/notes on what was ported and what was excluded (R12)

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Porting drift — subtle behavior differences vs Rmds | High | High | Tests-first harness; per-indicator stage-compare tests; fixtures as ground truth |
| Source format changes (ILO columns, ODIN format) | Medium | Medium | Schema validation on reads; fail loudly with report (R8) |
| Floating-point differences in index arithmetic | Medium | Low | 1e-9 relative tolerance; preserve arithmetic order |
| `wbstats`/API changes (wb_countries, UN SDG API) | Medium | Medium | Pin via renv; schema validation; documented checkpoints |
| renv version conflicts with new packages | Low | Medium | `renv::install()` + snapshot; verify restore from clean state |
| Long run times (microdata pulls, API calls) | Medium | Low | targets incremental re-runs; manual checkpoints for slow pulls |
| Accidental overwrite of historical outputs | Low | High | Staging directory + overwrite protection + hash manifest (R11) |
| Scope creep into visualization/methodology | Medium | Medium | Explicit out-of-scope list; roadmap ideas tracked separately |

## Out of Scope

- Changing the SPI methodology itself (indicators, weights, scoring)
- The Shiny dashboard (`SPI_data_viz/`)
- The technical methodology document (bookdown)
- Country reports
- Visualization chunks (maps, charts) — tracked as roadmap idea
- Modifying the existing Rmd files (they remain the reference)
- Overwriting or migrating historical output files

## Completion Contract

### Outcome

A `{targets}`-based SPI estimation pipeline that reproduces the 202511 vintage
outputs (committed `03_output_data/` files) within a 1e-9 relative tolerance,
with a comprehensive test suite, schema-validation on source reads, and a user
guide for the technical lead — while the original Rmd files remain untouched
and historical output files are never overwritten.

### Verification Surface

| ID | Phase | Evidence Required | Command/Artifact | Required |
|----|-------|-------------------|------------------|----------|
| V1 | 1 | `renv.lock` updated with `{targets}`, `{tarchetypes}`, `{testthat}` | `git diff renv.lock` | yes |
| V2 | 1 | `_targets.R` parses and pipeline graph builds | `targets::tar_manifest()` | yes |
| V3 | 2 | Comparison harness compares old vs new outputs with 1e-9 tolerance | `testthat::test_file("tests/testthat/test-compare.R")` | yes |
| V4 | 2 | Vintage fixtures snapshot the 202511 outputs with hash manifest | `tests/fixtures/` populated + `manifest.json` | yes |
| V5 | 3 | `SPI_data.csv` from new pipeline matches vintage within tolerance | `testthat::test_file("tests/testthat/test-data-prep.R")` | yes |
| V6 | 3 | `SPI_data.dta` matches vintage | comparison test | yes |
| V7 | 4 | `SPI_index.csv` matches vintage within tolerance | `testthat::test_file("tests/testthat/test-index.R")` | yes |
| V8 | 5 | Validation expectations converted to automated tests, all pass | `testthat::test_file("tests/testthat/test-validation.R")` | yes |
| V9 | 6 | misc_scripts outputs (quantiles, treemap, databank, SPL admin) match vintage | comparison tests | yes |
| V10 | 6 | Download targets present where APIs allow; manual checkpoints documented | `_targets.R` + user guide | yes |
| V11 | 7 | User guide complete: step-by-step update, source locations, manual steps | `docs/user-guide.md` | yes |
| V12 | final | Full pipeline run on 2024 data; zero (or documented, approved) differences vs 202511 | `targets::tar_make()` + full test suite | yes |
| V13 | final | Historical output files unchanged (hash manifest verified) | hash-verification test | yes |

### Constraints

| ID | Phase | Constraint | Check |
|----|-------|------------|-------|
| C1 | all | Rmd files remain untouched | `git diff 02_programs/*.Rmd` empty |
| C2 | all | Fail loudly: schema validation on source reads; no silent adaptation | schema registry + tests |
| C3 | all | Readability over efficiency: functions simple, well-commented | code review |
| C4 | all | Estimation only: visualization chunks and commented-out blocks excluded | pipeline file inventory |
| C5 | all | Reproducibility: `renv::restore()` works; relative paths only | clean-env test |
| C6 | final | Outputs match 202511 vintage within 1e-9 relative tolerance | full test suite |
| C7 | all | Existing historical output files must never be overwritten | pipeline writes to staging paths; hash-verification test confirms tracked historical files unchanged |

### Boundaries

- Allowed:
  - New files under `R/`, `tests/`, `_targets.R`, `docs/`, `config/`, `staging/`
  - Extending `renv.lock` with pipeline packages
  - New `targets`-specific config files
  - User guide under `docs/`
- Out of scope:
  - Changing SPI methodology (indicators, weights, scoring)
  - The Shiny dashboard (`SPI_data_viz/`)
  - The technical methodology document (bookdown)
  - Country reports
  - Visualization chunks (maps, charts) — roadmap idea only
  - Modifying the existing Rmd files
  - Overwriting or migrating historical output files

### Iteration Policy

1. Port indicator-by-indicator, running comparison tests after each port.
2. On test failure: fix the ported function, re-run tests; do not modify the vintage fixtures.
3. On source schema mismatch: fail loudly, report to tech lead, record deviation.
4. On floating-point differences within 1e-9: accept, document.
5. On differences beyond tolerance: investigate; if a genuine methodology difference is found, escalate to user under `ask` policy.
6. On any attempt to write to a historical output path: block, report, and route to staging.

### Blocked-Stop Conditions

- Any required verification cannot be run through the safe runner.
- Any required evidence item fails after allowed recovery attempts.
- A required deviation is discovered under policy `ask` and user approval is unavailable.
- A required deviation is discovered under policy `strict`.
- A protected boundary must be crossed to continue (e.g., modifying Rmds or overwriting historical outputs).
- `/cg-work` cannot durably create or update the execution report.
- A selected plan lacks `## Completion Contract` or `deviation-policy` and the user has not approved a compatibility contract.
- Completion would require marking evidence as passed from static inspection alone rather than an executed check.
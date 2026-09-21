---
plan: ".cg-docs/plans/2026-09-21-targets-pipeline-replication.md"
created: "2026-09-21"
status: active
---

# Execution Report: Targets-based SPI Estimation Pipeline

## Plan Reference

- Plan: `.cg-docs/plans/2026-09-21-targets-pipeline-replication.md`
- Active deviation policy: `ask` (no runtime override)

## Deviations

### D1: renv bootstrap (Phase 1, Step 1) — 2026-09-21
- **Policy active**: `ask`
- **Decision**: User approved Option 1 — bootstrap renv properly via
  `renv::init()` (create `.Rprofile`, `renv/settings.json`, complete lockfile
  from system library), then add `{targets}` and `{tarchetypes}`.
- **Rationale**: The renv environment was not bootstrapped (no `.Rprofile`,
  no `renv/library`, no `renv/settings.json`); `renv.lock` was stale/partial
  (v3.0, missing core packages `tidyverse`, `dplyr`, `wbstats`, `haven`,
  `httr`, `readr`). C5 (`renv::restore()` works) requires a working renv
  environment.
- **Impact**: `renv.lock` diff will be larger than "only the new packages"
  (V1 acceptance criterion needs documented exception). R version pinned in
  lockfile will update from 4.3.0 to 4.6.1.

## Completed Steps/Phases

- Phase 1, Step 1 (renv): COMPLETE. renv bootstrapped (`.Rprofile`,
  `renv/settings.json`, `renv/activate.R` 1.2.3). Project library hydrated
  with modern packages via `renv::hydrate()`. `targets` 1.12.0,
  `tarchetypes` 0.14.1, `testthat` 3.3.2, `validate` 1.1.7 installed.
  Lockfile updated to R 4.6.1 with 140 packages (implicit snapshot).
  `dataCompareR` deferred (archived on CRAN; custom comparison utilities
  replace it per plan Phase 2).
- Phase 1, Step 2 (pipeline skeleton): COMPLETE. `_targets.R` created with
  `pipeline_targets()` function pattern (3 targets: params, iso_codes,
  country_grid). `R/schema.R` (schema validation), `R/save.R` (overwrite
  protection), `R/setup.R` (params + grid) created. `config/params.R` holds
  pipeline parameters. Pipeline graph builds and executes cleanly.
  Country grid verified: 217 countries x 2004-2024 = 4,557 rows, matching
  the vintage SPI_data.csv exactly.
- Phase 1, Step 3 (user guide skeleton): COMPLETE. `docs/user-guide.md`
  created with overview, prerequisites, how-to-run, step-by-step update
  (from SPI updates.xlsx), manual checkpoints, troubleshooting sections.
- Phase 1 evidence: V1 (lockfile has targets/tarchetypes/testthat) PASSED
  (with documented exception for large diff per D1). V2 (pipeline graph
  builds) PASSED.
- Phase 2, Step 4 (comparison utilities): COMPLETE. `R/compare.R` created
  with `compare_frames()` (1e-9 relative tolerance, column/type/NA/row-set
  difference reporting with key-value row labels) and
  `expect_frames_match()`. `tests/testthat/test-compare.R` has 14 tests,
  all passing. Red-phase confirmed (test failed before implementation).
- Phase 2, Step 5 (vintage fixtures): COMPLETE. 12 vintage output files
  copied to `tests/fixtures/` with SHA-256 manifest
  (`tests/fixtures/manifest.json`). `tests/testthat/test-fixtures.R` has 36
  tests (fixture integrity + C7 historical-output protection), all passing.
- Phase 2, Step 6 (stage-compare harness): COMPLETE.
  `tests/testthat/test-stage-compare.R` wires comparison utilities against
  fixtures for SPI_data, SPI_index, quantiles, treemap, SPL admin, and
  databank files. 6 tests, all skipping until Phases 3-6 produce staged
  outputs (expected).
- Phase 2 evidence: V3 (comparison harness with 1e-9 tolerance) PASSED.
  V4 (vintage fixtures + hash manifest) PASSED.
- Full suite: 50 passed, 0 failed, 6 skipped (skips = stage-compare for
  not-yet-produced outputs).
- Phase 3, Step 7 (setup/grid): COMPLETE (done in Phase 1). Country grid
  verified: 217 countries x 2004-2024 = 4,557 rows.
- Phase 3, Step 8 (D1.5): COMPLETE. `R/dim1_5.R` with 5 indicators
  (poverty comparability, child mortality, debt reporting, safely managed
  water, labor force participation). All 5 SPI columns verified with 0
  differences vs vintage.
- Phase 3, Step 9 (D2): COMPLETE. `R/dim2.R` with 3 indicators (SDDS,
  ODIN, NADA). **Fix applied**: SCI pivot restricted to YR2004:YR2015
  (original code pivots only those years; pivoting YR2016:YR2020 created
  duplicate rows overlapping WDI metadata). After fix, all 8 D2 columns
  verified; remaining diffs (AUS 2004-2015 GDDS, NZL 2016 GDDS, AFG 2016
  D2.2, SMR 2019 NADA) are all EXPECTED to resolve in the append step
  (na.locf carry-forward + OECD high-income adjustment).
- Phase 3, Step 10 (D3): COMPLETE. `R/dim3.R` with 16 UN SDG indicators.
  All 16 SPI columns verified with 0 differences vs vintage.
- Phase 3, Step 11 (D4): COMPLETE. `R/dim4.R` with censuses/surveys (8),
  CRVS (1), geospatial (2). **Fixes applied**: (1) NADA join uses
  `by = "country"` (NADA files key on country name, not iso3c); (2) joins
  use default (all-common-column) keys to avoid `.x`/`.y` suffix columns,
  matching the original Rmd; (3) `zoo` package installed (was missing from
  renv). All 8 census/survey + CRVS columns verified with 0 differences;
  GEO has 2 diffs (AFG 2016) EXPECTED to resolve in the append step's
  na.locf carry-forward.
- Phase 3 evidence so far: D1.5, D2, D3, D4 all ported and verified at the
  dimension level. V5/V6 (full SPI_data.csv/.dta) pending the append/save
  port (Step 13).

## Evidence Table

| ID | Phase | Evidence Required | Status |
|----|-------|-------------------|--------|
| V1 | 1 | `renv.lock` updated with `{targets}`, `{tarchetypes}`, `{testthat}` | PASSED (exception: larger diff due to D1) |
| V2 | 1 | `_targets.R` parses and pipeline graph builds | PASSED |
| V3 | 2 | Comparison harness with 1e-9 tolerance | PASSED |
| V4 | 2 | Vintage fixtures + hash manifest | PASSED |
| V5 | 3 | `SPI_data.csv` matches vintage | pending |
| V6 | 3 | `SPI_data.dta` matches vintage | pending |
| V7 | 4 | `SPI_index.csv` matches vintage | pending |
| V8 | 5 | Validation expectations as automated tests | pending |
| V9 | 6 | misc_scripts outputs match vintage | pending |
| V10 | 6 | Download targets + manual checkpoints | pending |
| V11 | 7 | User guide complete | pending |
| V12 | final | Full pipeline reproduces vintage | pending |
| V13 | final | Historical outputs unchanged | pending |

## Accepted Exceptions

- (none yet)
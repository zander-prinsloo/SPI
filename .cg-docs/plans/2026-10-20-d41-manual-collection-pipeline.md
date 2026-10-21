---
date: 2026-10-20
title: "Integrate Dimension 4.1 Manual Collection into the SPI Collection Pipeline"
status: active
scope: "Deep"
brainstorm: ".cg-docs/brainstorms/2026-10-20-d41-manual-collection-integration.md"
language: "R"
estimated-effort: "large"
deviation-policy: "ask"
execution-report: ".cg-docs/work-reports/2026-10-20-d41-manual-collection-pipeline.md"
completed-phases: [1, 2]
current-phase: 3
failing-steps: [5, 6, 7]
phases: 5
artifact-schema-version: 1
tags: [spi, dimension-4.1, manual-collection, microdata, targets, preprocessing, provenance]
---

# Plan: Integrate Dimension 4.1 Manual Collection into the SPI Collection Pipeline

## Objective

Make Dimension 4.1 a complete collection-stage dependency. The collection
pipeline will track the eight manually maintained source workbooks, the
vintage-specific manual review workbook, the D4.1 catalogue/API companion
artifacts, and the parameterized preprocessing outputs. It will validate the
complete artifact set, fail loudly on input or derivation problems, and expose a
blocking manifest to the estimation pipeline.

The implementation will preserve the existing Excel structure and legacy Rmd
and preprocessing workflows as reference artifacts. The new collection path
will use tested R functions and explicit `{targets}` dependencies.

## Context

The prior registry-driven collection plan established two separate stages:
collection first, estimation second. Dimension 4.1 remains incomplete in that
architecture. `microdata_library_pull.Rmd` performs programmatic catalogue
pulls, while eight manually curated workbooks under
`01_raw_data/4.1_SOCS/raw/input/` contain the core evidence. The legacy
preprocessing script reads those workbooks and writes eight derived
`D4.1.*.<YEAR>.csv` files, but it hard-codes 2024 and is not a collection target.

`R/dim4.R` consumes the derived current-vintage CSVs, D4.1-specific
`D4.1.*_NADA.csv` companion files, and `D4.1.Manual.Review.<YEAR>.xlsx`. The
Dimension 2.4 `D2.4.NADA.<YEAR>.csv` workflow is a separate source and is not
part of this plan.

The technical lead owns the run. Country economists review the evidence and
provide adjustments through the manual review workbook. The review workbook is
the authoritative additive-evidence layer; review values are merged with source
evidence without silently replacing it. Provenance and approval state are recorded
in a separate manifest because the workbook structure must remain unchanged.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Track all eight `raw/input/*.xlsx` files as explicit collection inputs. | Approved brainstorm |
| R2 | Track `D4.1.Manual.Review.<end_date>.xlsx` as an explicit collection input. | Approved brainstorm |
| R3 | Preserve the existing Excel workbook structures. | User decision |
| R4 | Treat the manual review workbook as the authoritative additive-evidence layer; merge review values with source evidence without silently replacing it. | User decision |
| R5 | Parameterize preprocessing so `end_date` controls filenames, embedded dates, and expected outputs. | User decision |
| R6 | Generate and validate all eight `D4.1.*.<end_date>.csv` artifacts before estimation. | Existing estimator contract |
| R7 | Collect or validate D4.1-specific catalogue/API companion files without invoking Dimension 2.4 NADA. | Scope clarification |
| R8 | Fail loudly on missing files, schema errors, duplicate country keys, incomplete coverage, stale outputs, or invalid review inputs. | User decision / charter |
| R9 | Add unit tests for workbook structure, keys, dates, preprocessing, manual review, and derived artifacts. | User decision |
| R10 | Make the D4.1 collection manifest a blocking dependency of estimation. | Prior collection architecture |
| R11 | Preserve exact 2024/202511 replication and leave the original Rmd workflow untouched. | Charter / prior plans |
| R12 | Document the manual and programmatic workflow, roles, files, and failure recovery. | User decision |

## Phase 1: Collection Contract and Input Validation

### 1. Define the D4.1 artifact contract
- **Requirements**: R1, R2, R6, R7, R10
- **Files**: `config/source_registry.R`, `_targets_data.R`, new D4.1 collection R files, `tests/testthat/`
- **Details**: Define source records for the eight manual workbooks, the
  manual-review workbook, D4.1 catalogue inputs, D4.1 companion artifacts, and
  the eight derived current-vintage CSVs. Define a manifest containing
  `end_date`, source IDs, input hashes, output hashes, review status, generated
  paths, validation results, and collection-run identity. Keep D2.4 NADA in its
  existing separate registry record.
- **Test Scenarios**: all expected source records present; duplicate source IDs;
  missing artifact path; manifest vintage mismatch.
- **Tests**: source-registry coverage tests and manifest-schema tests.
- **Acceptance criteria**: every file consumed by `combine_censuses_surveys()`
  has an explicit collection record and an unambiguous artifact role.

### 2. Validate the eight workbooks and manual review workbook
- **Requirements**: R1, R2, R3, R4, R8, R9
- **Files**: new D4.1 validation functions under `R/`,
  `01_raw_data/4.1_SOCS/raw/input/`,
  `01_raw_data/4.1_SOCS/raw/D4.1.Manual.Review.<YEAR>.xlsx`,
  `tests/testthat/`
- **Details**: Validate workbook existence, expected sheets, required source
  columns, country/code keys, duplicate rows, expected year fields, and review
  columns. Validate that the review workbook has the expected eight indicator
  columns and `iso3c`; store validation results outside the workbook. Do not
  alter workbook layout.
- **Test Scenarios**: missing workbook; missing sheet; renamed required column;
  duplicate country code; malformed year field; missing review column; review
  workbook with an unknown country code; valid workbook with sparse overrides.
- **Tests**: focused workbook fixture tests with temporary copies.
- **Acceptance criteria**: invalid input stops the collection target with an
  actionable technical-lead error; valid sparse review data passes.

## Phase 2: Parameterized Preprocessing and Derived Artifacts

### 3. Extract parameterized 4.1 preprocessing functions
- **Requirements**: R3, R5, R6, R11
- **Files**: new `R/collect_dim4_1.R` or equivalent collection module,
  `02_programs/misc_scripts/preprocess-manual-data-4.1-and-5.2.10.R`,
  `02_programs/01-SPI_data_prep.Rmd`
- **Details**: Extract the eight 4.1 transformations into ordinary R functions
  that accept `end_date`, input paths, output directory, and country metadata.
  Preserve the current skip rules, column mappings, source provenance, and
  output semantics. Leave the legacy script and Rmd untouched as references;
  compare the extracted functions against their behavior before using them in
  collection.
- **Test Scenarios**: `end_date = 2024` produces the approved 2024 filenames;
  `end_date = 2025` produces only 2025 current-vintage filenames; no output
  retains a hard-coded 2024 date; missing workbook fails before writing.
- **Tests**: transformation fixtures for all eight indicators and filename/date
  assertions.
- **Acceptance criteria**: preprocessing is reusable from targets and does not
  silently write a different vintage than the configured `end_date`.

### 4. Generate and validate the eight current-vintage CSVs
- **Requirements**: R4, R5, R6, R8, R9
- **Files**: new D4.1 collection module, `R/dim4.R`, `R/checkpoints.R`,
  `tests/testthat/`
- **Details**: Write the eight derived files to
  `01_raw_data/4.1_SOCS/raw/` using `D4.1.*.<end_date>.csv` names. Validate
  required `iso3c` and indicator-specific fields, unique country keys, expected
  current-vintage coverage, and output freshness relative to every input file.
  Apply the manual review workbook in the estimation-compatible layer and
  preserve raw versus overridden values in the manifest or derived artifact
  metadata without changing the workbook.
- **Test Scenarios**: one input changed; output missing; output older than input;
  duplicate output key; missing current-year output; manual override applied;
  manual override absent and valid sparse review accepted.
- **Tests**: derived-artifact schema/freshness tests and review-application tests.
- **Acceptance criteria**: all eight outputs are present, current, schema-valid,
  keyed correctly, and traceable to the input/review hashes.

## Phase 3: D4.1 Programmatic Companions

### 5. Integrate catalogue collection and D4.1 companion artifacts
- **Requirements**: R7, R8, R10, R12
- **Files**: new D4.1 catalogue collector module, selected logic from
  `02_programs/misc_scripts/microdata_library_pull.Rmd`,
  `01_raw_data/4.1_SOCS/`, `config/source_registry.R`, `tests/testthat/`
- **Details**: Port the reproducible World Bank, FAO, ILO, and PIP catalogue
  requests into collection functions or wrap them behind tested collector
  contracts. Preserve raw responses, normalized catalogue tables, request
  identity, timestamps, and hashes. Generate or validate only the D4.1
  companion files such as `D4.1.*_NADA.csv`; do not call or modify the separate
  `D2.4.NADA.<YEAR>.csv` process. Classify unavailable or unreliable catalogue
  sources explicitly rather than silently treating them as complete.
- **Test Scenarios**: injected API response; HTTP failure; empty catalogue;
  schema change; country-name mismatch; duplicate catalogue record; valid
  companion output; missing companion output.
- **Tests**: collector unit tests with fixtures and companion-file schema tests.
- **Acceptance criteria**: D4.1 companion artifacts have reproducible source
  provenance and are visible in the collection status/manifest.

## Phase 4: Target Graph and Estimation Gate

### 6. Add explicit D4.1 collection targets
- **Requirements**: R1, R2, R5, R6, R7, R10
- **Files**: `_targets_data.R`, new D4.1 collection module,
  `config/source_registry.R`
- **Details**: Add explicit file targets for the eight input workbooks and
  current manual-review workbook. Add targets for catalogue collection,
  preprocessing, D4.1 companion generation/validation, derived CSV validation,
  manifest writing, and collection status. Make the preprocessing target depend
  on every input file, the preprocessing code, `end_date`, and country metadata.
  Ensure a changed workbook invalidates preprocessing and all downstream D4.1
  artifacts.
- **Test Scenarios**: unchanged inputs reuse cached targets; one workbook change
  rebuilds preprocessing; review workbook change rebuilds review application;
  `end_date` change rebuilds all current-vintage outputs; missing file blocks
  collection.
- **Tests**: target manifest/dependency tests and temporary-store integration
  tests.
- **Acceptance criteria**: `targets::tar_make(script = "_targets_data.R", store = "_targets_data")`
  executes the complete D4.1 collection path before status completion.

### 7. Connect D4.1 artifacts to estimation
- **Requirements**: R4, R8, R10, R11
- **Files**: `_targets.R`, `R/dim4.R`, `R/append.R`,
  `tests/testthat/test-collection-integration.R`,
  `tests/testthat/test-stage-compare.R`
- **Details**: Make the estimation gate require the D4.1 manifest and all
  validated derived artifacts. Pass validated artifact paths or objects into
  Dimension 4.1 functions instead of allowing invisible file discovery. Ensure
  `dim4`, `spi_data`, index, and output targets are downstream of the gate.
- **Test Scenarios**: no manifest; blocking D4.1 status; missing derived CSV;
  successful validated run; changed input followed by estimation; exact 2024
  fixture run.
- **Tests**: collection-to-estimation integration tests and stage comparison.
- **Acceptance criteria**: estimation cannot use a stale or unvalidated D4.1
  input and the approved 2024/202511 result remains within tolerance.

## Phase 5: Tests, Documentation, and Handoff

### 8. Add end-to-end and regression tests
- **Requirements**: R8, R9, R10, R11
- **Files**: `tests/testthat/test-dim4-collection.R` (new),
  `tests/testthat/test-collection-integration.R` (new),
  `tests/testthat/test-stage-compare.R`, `tests/fixtures/`
- **Details**: Use deterministic temporary fixtures for valid and invalid
  workbooks, manual review, catalogue companions, and generated outputs. Keep
  network calls out of default tests. Test cache reuse, changed-query/source
  invalidation, schema failures, review overrides, stale output detection,
  blocking status, and complete estimation output.
- **Test Scenarios**: happy path, missing workbook, bad sheet, duplicate key,
  invalid year, incomplete country coverage, stale CSV, invalid review input,
  catalogue failure, and full 2024 replication.
- **Tests**: focused test files followed by `testthat::test_local()`.
- **Acceptance criteria**: tests prove both manual and programmatic inputs flow
  into the final Dimension 4.1 and SPI outputs.

### 9. Update user documentation and source inventory
- **Requirements**: R3, R4, R7, R8, R12
- **Files**: `docs/user-guide.md`, `README.md`, `config/source_registry.R`
- **Details**: Document the technical lead's run order, country-economist review
  role, eight workbook locations, manual-review workbook location, D4.1
  companion files, preprocessing, validation failures, manifest/status review,
  and the separate D2.4 NADA process. State how manual and programmatic updates
  are run together for 202611 and future vintages.
- **Test Scenarios**: a new technical lead can identify every input, run the
  collection command, interpret a blocking error, and proceed to estimation
  only after the gate passes.
- **Tests**: documentation path/command checks and a manual walkthrough.
- **Acceptance criteria**: documentation exactly matches target names, paths,
  filenames, failure behavior, and output ownership.

## Testing Strategy

- Run focused workbook and preprocessing tests first.
- Run D4.1 catalogue/companion tests with injected deterministic responses.
- Run collection-to-estimation integration tests in temporary raw and target
  stores.
- Run the 2024/202511 stage comparison before enabling the 202611 path.
- Keep live network tests opt-in; default tests must not require external APIs.
- Run the complete suite with `testthat::test_local()` after focused tests pass.

## Documentation Checklist

- Explain the two-stage collection/estimation workflow.
- Identify the eight unchanged manual input workbooks.
- Identify `D4.1.Manual.Review.<YEAR>.xlsx` and its override role.
- Distinguish D4.1 companion files from Dimension 2.4 NADA.
- Explain `end_date`-driven filenames and preprocessing outputs.
- Document technical-lead and country-economist responsibilities.
- Document blocking errors, manifest/status review, and recovery steps.
- Include the 202611 reference-year example (`end_date <- 2025`).

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Workbooks change structure upstream | Validate sheets/columns and fail before preprocessing |
| Excel changes do not invalidate derived CSVs | Track every workbook as an explicit file dependency |
| Manual overrides are not reproducible | Hash the review workbook and record manifest provenance |
| Country coverage is incomplete | Require country-key and coverage checks with actionable errors |
| D4.1 companion files are confused with D2.4 NADA | Use separate source IDs, paths, targets, and documentation |
| Refactoring changes 2024 scores | Fixture-based comparison against the 202511 output |
| Catalogue APIs are unavailable | Preserve cached raw responses and classify manual/external status explicitly |
| Collection succeeds but estimation reads stale paths | Make the D4.1 manifest a hard estimation-gate dependency |

## Out of Scope

- Changing the Excel workbook structure.
- Changing SPI scoring rules or methodology.
- Rewriting the original Rmd reference workflow.
- Integrating Dimension 2.4 NADA into Dimension 4.1.
- Automating country-economist judgments.
- Replacing the broader collection-pipeline plan's unrelated source work.

## Completion Contract

### Outcome

A collection run reads and validates the eight 4.1 workbooks, the current
manual-review workbook, and D4.1 programmatic companion artifacts; produces
current-vintage derived CSVs and a provenance manifest; and blocks estimation
when any required artifact is invalid, stale, missing, or unapproved.

### Verification Surface

| Phase | ID | Evidence Required | Command/Artifact | Required |
|---|---|---|---|---|
| 1 | V1 | All manual input and review files are explicit target dependencies | Target manifest and input tests | yes |
| 1 | V2 | Workbook schemas, keys, duplicate rows, dates, and coverage validate | Focused `testthat` tests | yes |
| 2 | V3 | `end_date` propagates to all eight output names and embedded dates | Preprocessing fixture tests | yes |
| 2 | V4 | Manual review overrides are applied and hashed in the manifest | Review/manifest tests | yes |
| 3 | V5 | D4.1 companion files have raw/normalized/provenance coverage | Companion artifact tests and status report | yes |
| 4 | V6 | Collection target runs preprocessing before status completion | `_targets_data.R` temporary-store test | yes |
| 4 | V7 | Estimation is blocked by invalid/missing D4.1 artifacts | Collection-gate integration test | yes |
| 4 | V8 | `dim4` consumes only validated collection artifacts | Target graph and code-contract test | yes |
| 5 | V9 | 2024/202511 output remains within established tolerance | Stage comparison tests | yes |
| 5 | V10 | Manual/programmatic run order is documented | `docs/user-guide.md` review | yes |

### Constraints

| ID | Constraint | Check |
|---|---|---|
| C1 | Preserve the eight Excel workbook structures | No workbook schema edits |
| C2 | Leave legacy Rmd/reference scripts untouched | Diff and replication checks |
| C3 | Fail loudly; no silent legacy fallback | Blocking/error-path tests |
| C4 | Keep D4.1 NADA separate from D2.4 NADA | Registry/path assertions |
| C5 | Use relative paths and reproducible hashes | Manifest/provenance tests |
| C6 | Do not change methodology implicitly | 2024/202511 comparison |

### Boundaries

- Allowed: new D4.1 collection functions, targets, validators, manifests, tests,
  and documentation.
- Allowed: parameterizing equivalent preprocessing behavior outside the legacy
  reference scripts.
- Out of scope: workbook redesign, scoring changes, country-economist judgment
  automation, and unrelated source collection work.

### Iteration Policy

1. Preserve 2024/202511 behavior as the first acceptance gate.
2. Fix failures within the current phase and rerun focused tests before widening
   scope.
3. Treat any methodology or workbook-format change as a deviation requiring
   explicit approval.
4. Do not replace the legacy reference path until the new path passes comparison.

### Blocked-Stop Conditions

- Required workbook or manual review schema cannot be validated.
- The preprocessing output cannot be traced to its input/review hashes.
- D4.1 companion artifacts cannot be separated from D2.4 NADA.
- The target graph cannot guarantee preprocessing before estimation.
- 2024/202511 outputs differ beyond the approved comparison tolerance.
- A required source or review decision is unavailable and no approved policy
  exists for handling it.

### Deviation Policy

`ask`

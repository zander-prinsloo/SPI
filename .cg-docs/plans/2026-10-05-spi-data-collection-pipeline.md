---
date: 2026-10-05
title: "Registry-driven SPI data collection pipeline before estimation"
status: active
scope: "Deep"
brainstorm: ".cg-docs/brainstorms/2026-10-05-api-data-collection-pipeline.md"
language: "R"
estimated-effort: "large"
deviation-policy: "ask"
completed-phases: [1, 2, 3, 4]
current-phase: 5
failing-steps: [9]
phases: 7
artifact-schema-version: 1
tags: [spi, targets, data-collection, api, caching, provenance, sdg, testing, reproducibility]
---

# Plan: Registry-Driven SPI Data Collection Pipeline Before Estimation

## Objective

Build a separate, reproducible data-collection pipeline that runs before the
existing SPI estimation pipeline. The collection pipeline will refresh and
validate `01_raw_data/`, preserve raw and normalized source artifacts, produce
availability and provenance outputs, and report API, manual, external, stale,
missing, or unavailable sources. The estimation pipeline will consume only
validated collection artifacts and write the complete final output set to
`03_output_data/`.

## Context

The completed estimation plan established a `{targets}` pipeline that mirrors
the existing Rmd estimation logic. The current implementation still mixes
responsibilities: it reads prepared files from `01_raw_data/`, has opt-in API
pulls that are not upstream dependencies, and performs live World Bank calls
inside estimation helpers for country metadata, population, OECD membership,
and GDP.

The legacy `02_programs/misc_scripts/un_stats_cleaning.Rmd` downloads raw UN SDG
series, creates normalized per-series files, fills country-year gaps, and then
creates scored five-year outputs. The current `R/dim3.R` consumes prepared
five-year files instead of owning that collection process. The legacy
`01-SPI_data_prep.Rmd` loads `pipr` but leaves the acquisition call commented
out; the current estimator reads `PIP_comparability_latest.csv`. The collection
plan must implement and test the missing acquisition or document why it remains
external.

The project charter prioritizes exact replication, open data, reproducibility,
and untouched Rmd reference files. The new collection-first architecture
expands the charter's current estimation-only focus and should be reflected in
charter and roadmap follow-up work, but this plan does not edit those files.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Provide two explicit commands: collection first, estimation second. | Brainstorm decision |
| R2 | Represent every source used by all indicators across all 22 dimensions in a machine-readable registry. | User request |
| R3 | Run every feasible public API or package-backed extraction in the collection pipeline, not during estimation. | User request |
| R4 | Preserve raw payloads, normalized source tables, and provenance metadata with hashes, timestamps, query/vintage identity, and paths. | User request / brainstorm |
| R5 | Produce country-indicator-year availability intermediates containing explicit `0`/`1` values before scoring where applicable. | User request |
| R6 | Port the intended behavior of `un_stats_cleaning.Rmd` into tested R functions and targets while leaving the Rmd untouched. | User attachment / charter |
| R7 | Use source-specific expected-vintage rules plus a configurable rough age threshold as a warning. | User decision |
| R8 | Report blocking, warning, and informational collection statuses for API, manual, external, stale, missing, and unavailable sources. | User decision |
| R9 | Prevent estimation from running when required collection artifacts have blocking issues. | User decision |
| R10 | Write the validated final estimation artifact set directly to `03_output_data/` with no partial output set. | User request / charter deliverable |
| R11 | Preserve exact Rmd scoring behavior and test against existing vintage fixtures; do not change methodology implicitly. | Charter / prior plan |
| R12 | Keep the SPI technical team workflow and source-specific analyst actions current in `docs/user-guide.md`. | User decision |

## Implementation Steps

## Phase 1: Collection Contract and Source Inventory

### 1. Define the collection-estimation interface
- **Requirements**: R1, R4, R8, R9, R10
- **Files**: `_targets_data.R` (new), `_targets.R`, `config/params.R`, `R/setup.R`, `docs/user-guide.md`
- **Details**: Define the two commands and separate target stores, for example:
  `targets::tar_make(script = "_targets_data.R", store = "_targets_data")`
  followed by `targets::tar_make(script = "_targets.R", store = "_targets")`.
  Define the collection artifact root under `01_raw_data/` and a stable
  machine-readable status manifest that the estimation pipeline can validate.
  Keep target stores separate so collection and estimation caches do not share
  ambiguous target names or invalidation state.
- **Test Scenarios**: command-level smoke test for each script; estimation gate
  fails when the collection status manifest is absent or blocking.
- **Tests**: new `tests/testthat/test-pipeline-contract.R`; target manifest checks.
- **Acceptance criteria**: Both commands are documented and independently
  discoverable; estimation has an explicit collection-status dependency.

### 2. Build the complete source registry and runtime-call audit
- **Requirements**: R2, R3, R7, R8, R12
- **Files**: `config/source_registry.R` (new), `config/params.R`, `R/append.R`,
  `R/quantiles.R`, `R/dim1_5.R`, `R/dim2.R`, `R/dim3.R`, `R/dim4.R`,
  `R/dim5.R`, `R/pull_*.R`, `02_programs/01-SPI_data_prep.Rmd`,
  `02_programs/02-SPI_index.Rmd`, `02_programs/misc_scripts/*.R`,
  `02_programs/misc_scripts/*.Rmd`
- **Details**: Create registry records for each source and indicator mapping,
  including source ID, dimensions/indicators, type (`api`, `manual`, `external`,
  `unavailable`), endpoint or input path, request parameters, raw and
  normalized paths, schema validator, expected vintage rule, age threshold,
  status severity, and analyst action. Audit confirmed runtime calls including
  `wbstats`, World Bank HTTP calls, UN SDG POST/GET calls, JMP, microdata
  library endpoints, NADA checks, and the legacy `pipr` block. Distinguish
  confirmed calls from comments or reference-only code; do not claim an API is
  automated without a tested extraction path.
- **Test Scenarios**: every registered source has a valid type, unique ID,
  indicator mapping, status policy, and path; no estimation runtime call is
  omitted from the audit inventory.
- **Tests**: new registry validation tests plus a reviewed static-audit report.
- **Acceptance criteria**: all 22 dimensions have registry coverage, including
  explicit manual/external records where automation is not reliable.

## Phase 2: Shared Collection Engine

### 3. Implement raw capture, cache, and provenance helpers
- **Requirements**: R3, R4, R7
- **Files**: `R/collection_io.R` (new), `R/collection_cache.R` (new),
  `R/collection_provenance.R` (new), `config/source_registry.R`
- **Details**: Implement dependency-injected request and write helpers that
  preserve exact raw response bytes or source files before normalization. Cache
  keys must include source ID, endpoint/query parameters, requested vintage or
  year range, and a schema/collector version. Write normalized artifacts only
  after raw capture succeeds. Record UTC retrieval time, source URL, request
  parameters, HTTP status, content type, observed vintage, byte/hash identity,
  raw path, normalized path, and collector version. Do not use `targets`
  caching as a substitute for remote freshness checks.
- **Test Scenarios**: cache hit avoids a second request; changed query or
  collector version invalidates the cache; failed response does not replace a
  prior valid raw artifact; hash and metadata are stable.
- **Tests**: new `test-collection-cache.R` and `test-collection-provenance.R`
  using local fixtures and injected fake requests.
- **Acceptance criteria**: every API collector can use the same capture and
  provenance contract without live network calls in unit tests.

### 4. Implement freshness, status, and analyst reports
- **Requirements**: R7, R8, R9
- **Files**: `R/collection_status.R` (new), `R/collection_report.R` (new),
  `R/collection_registry.R` (new), `01_raw_data/_collection/` (generated),
  `_targets_data.R` (new)
- **Details**: Implement source-specific vintage/update rules and a configurable
  rough age warning. Classify results as `blocking`, `warning`, or
  `informational`; include `manual` and `external` as source types rather than
  silently treating them as successful API collection. Produce a machine-readable
  CSV or RDS status manifest and a human-readable Markdown report with source,
  indicator, expected/observed vintage, age, artifact paths, status, reason,
  and analyst action. Make the status evaluation target run deliberately for
  every collection command, even when a raw download is served from cache.
- **Test Scenarios**: missing file is blocking; schema mismatch is blocking;
  source-specific vintage mismatch is blocking or warning according to registry;
  age threshold produces warning only; manual source present and valid is
  informational; unresolved external source is clearly reported.
- **Tests**: new `test-collection-status.R` and report snapshot/structure tests.
- **Acceptance criteria**: a technical analyst can identify every required
  action from the generated report, and estimation rejects blocking status.

## Phase 3: Pillar 3 SDG Collection and Availability

### 5. Port the SDG raw extraction and normalization functions
- **Requirements**: R3, R4, R6
- **Files**: `R/collect_sdg.R` (new), `R/pull_unsdg.R` (refactor or move to
  collection), `02_programs/misc_scripts/un_stats_cleaning.Rmd` (reference;
  unchanged), `01_raw_data/metadata/SDG_indicator_list.csv`,
  `01_raw_data/sdg_data/` (generated), `_targets_data.R`
- **Details**: Port the Rmd sequence into ordinary functions: load the fixed
  SDG indicator list, request each series through the `DataCSV` endpoint with
  the configured year range, preserve each raw response, normalize
  `TimePeriod`, `[Nature]`, `GeoAreaCode`, and values, join the ISO registry,
  and write per-series normalized artifacts. Preserve the Rmd's tier-1 and
  source classification rules as explicit functions. Add request failure,
  empty-series, and schema validation errors that stop collection rather than
  producing silent partial data.
- **Test Scenarios**: representative series with country, adjusted, estimated,
  global, modeled, missing, and non-country values; HTTP failure; empty
  response; changed column names; repeated collection with an unchanged cache.
- **Tests**: new `test-sdg-collection.R` with stored response fixtures and
  injected HTTP functions; no live UN API in automated tests.
- **Acceptance criteria**: collection writes raw and normalized artifacts for
  every requested series and records failures per source without silently
  completing a partial collection.

### 6. Produce and test SDG availability and estimation inputs
- **Requirements**: R5, R6, R11
- **Files**: `R/collect_sdg.R`, `R/availability.R` (new), `R/dim3.R`,
  `R/compare.R`, `tests/fixtures/` (new SDG fixtures), `_targets_data.R`,
  `_targets.R`
- **Details**: Create a complete country-indicator-year availability table with
  explicit `0`/`1` values before scoring, retaining indicator code, goal,
  country, year, source nature, and any not-applicable marker needed by the
  Rmd rules. Reproduce the filled country-year grid, five-year rolling inputs,
  and `SPI_D3_*` estimation inputs as separate artifacts. Refactor `R/dim3.R`
  to consume the collection outputs rather than an unexplained prepared file.
  Compare the resulting five-year inputs and scores to approved fixtures and
  document any deliberate difference.
- **Test Scenarios**: no value, country value, country-adjusted value, estimated
  or global value, modeled value, indicator unavailable for all countries in a
  year, and country-year gaps filled with zero.
- **Tests**: unit tests for availability and rolling transformations; fixture
  comparison for the 2024/202511 vintage; existing `test-scoring.R` and
  `test-stage-compare.R` updates.
- **Acceptance criteria**: the intermediate data can answer which countries
  have which SDG indicators in which years using only `0`/`1`, and the
  estimation output matches the approved Rmd behavior.

## Phase 4: Migrate API-Backed Sources and Register Non-API Sources

### 7. Move confirmed runtime acquisition into collection targets
- **Requirements**: R3, R4, R9, R11
- **Files**: `_targets_data.R`, `R/pull_jmp.R`, `R/pull_unsdg.R`,
  `R/collect_pip.R` (new), `R/collect_world_bank.R` (new), `R/append.R`,
  `R/quantiles.R`, `R/setup.R`, `R/dim1_5.R`, `config/params.R`
- **Details**: Convert existing opt-in pulls into real collection targets and
  make downstream source artifacts explicit dependencies. Implement the PIP
  acquisition needed to create `PIP_comparability_latest.csv` through a tested
  `pipr`-compatible function or a documented equivalent; retain the current
  prepared-file reader only as an estimation consumer. Move country metadata,
  population, OECD membership, and GDP retrieval out of estimation and save
  their raw/normalized artifacts under the collection contract. Ensure JMP,
  UN SDG CRVS/legislation/finance, and any other confirmed API sources are
  collected before estimation. Remove direct network calls from estimation
  functions.
- **Test Scenarios**: API source succeeds and is cached; API source fails and
  blocks its dependent indicator; PIP output schema changes; World Bank query
  changes; collection target is skipped only on a valid cache hit, while the
  status check still runs.
- **Tests**: collector unit tests with injected responses; target dependency
  tests; update `test-downloads.R` to test collection behavior rather than
  opt-in no-op behavior.
- **Acceptance criteria**: estimation functions read collection artifacts only,
  and all confirmed runtime source calls are reachable from `_targets_data.R`.

### 8. Register and validate manual, external, and unavailable sources
- **Requirements**: R2, R8, R12
- **Files**: `config/source_registry.R`, `R/collection_checkpoints.R` (new),
  `R/checkpoints.R`, `R/pull_ilo.R`, `R/pull_wdi.R`, `02_programs/misc_scripts/`,
  `docs/user-guide.md`
- **Details**: Keep reliable manual download and external preprocessing steps
  as explicit collection checkpoints. Cover WDI metadata, ILO bulk files or
  API feasibility, ODIN, NADA, IGME, microdata libraries, IMF workbooks,
  manual-review files, CLASS, ASPIRE, previous-vintage inputs, and any other
  source used by dimensions 1.5 through 5.5. Each record must state why it is
  manual/external, the expected file and vintage, the schema check, the
  analyst action, and whether absence blocks estimation. Do not label a source
  automated merely because an HTTP URL exists if its response cannot be
  reproduced or transformed reliably.
- **Test Scenarios**: required manual file present, missing, stale, and schema
  invalid; external artifact present but marked external; source intentionally
  unavailable and excluded from the current vintage.
- **Tests**: extend checkpoint tests and registry coverage tests; verify every
  estimation input has a collection status record.
- **Acceptance criteria**: no source is silently omitted from the collection
  report, and the technical team has actionable instructions for every manual
  item.

## Phase 5: Integrate the Estimation Pipeline and Final Outputs

### 9. Add the collection gate and migrate output ownership
- **Requirements**: R1, R9, R10, R11
- **Files**: `_targets.R`, `config/params.R`, `R/save.R`, `R/append.R`,
  `R/index.R`, `R/quantiles.R`, `R/treemap.R`, `R/databank.R`,
  `R/spl_admin.R`, `tests/testthat/test-fixtures.R`,
  `tests/testthat/test-stage-compare.R`, `tests/testthat/test-validation.R`
- **Details**: Add a first estimation target that reads and validates the
  collection status manifest and required artifact paths. Replace staging-only
  source reads with collection artifact paths. Update all final writers to
  write the complete CSV/DTA output set to `03_output_data/`. Use temporary
  files and a validated replacement step so a failed target cannot leave a
  partial output set. Retire or repurpose the old staging-only overwrite guard;
  preserve fixture hashes and make the new write policy explicit.
- **Test Scenarios**: absent collection manifest; blocking status; warning-only
  status; missing normalized artifact; successful full write; failure during
  one output write; existing output replacement after validation.
- **Tests**: integration tests with temporary output directories; fixture hash
  and historical-output protection tests updated for the new policy; final
  output manifest test.
- **Acceptance criteria**: estimation cannot run against an unvalidated
  collection, and a successful run leaves the complete expected output set in
  `03_output_data/`.

## Phase 6: End-to-End and Regression Testing

### 10. Add collection-to-estimation integration and replication tests
- **Requirements**: R5, R6, R9, R10, R11
- **Files**: `tests/testthat/test-collection-integration.R` (new),
  `tests/testthat/test-sdg-collection.R` (new),
  `tests/testthat/test-collection-status.R` (new),
  `tests/testthat/test-vintage-compare.R`, `tests/testthat/test-stage-compare.R`,
  `tests/fixtures/manifest.json`
- **Details**: Run a fixture-backed collection pipeline into a temporary raw
  root and verify the status report, raw hashes, normalized data,
  availability intermediates, and estimation gate. Run the estimation graph
  against the fixture-backed collection artifacts and compare the approved
  indicator/index outputs within the established tolerance. Keep network calls
  out of default tests; provide an explicitly opt-in live smoke test for the
  technical team if needed.
- **Test Scenarios**: complete fixture run, partial API failure, stale source,
  schema change, cache reuse, changed query, collection report with warning,
  and final output comparison.
- **Tests**: `testthat::test_local()` plus focused test files; target manifest
  and dry-run checks for both scripts.
- **Acceptance criteria**: tests demonstrate both pipeline boundaries,
  deterministic cache behavior, blocking semantics, SDG availability correctness,
  and final vintage replication.

## Phase 7: Documentation and Technical-Team Handoff

### 11. Update the operating guide and source inventory documentation
- **Requirements**: R1, R2, R7, R8, R12
- **Files**: `docs/user-guide.md`, `README.md`, `config/source_registry.R`,
  `01_raw_data/_collection/` (generated report examples if appropriate)
- **Details**: Document prerequisites, the two commands, separate target stores,
  collection cache behavior, freshness/vintage rules, status severity meanings,
  raw/normalized/availability/provenance locations, manual/external source
  actions, troubleshooting, and the handoff from collection to estimation.
  Make clear that the technical team owns source updates, reviews collection
  reports, resolves blocking items, and only then runs estimation. Remove
  instructions that imply the estimation pipeline downloads or silently
  creates source data.
- **Test Scenarios**: a new technical team member can follow the guide from a
  clean checkout, identify a blocking source, rerun collection, and run
  estimation only after the gate passes.
- **Tests**: documentation path/command checks and a manual walkthrough recorded
  with the final verification report.
- **Acceptance criteria**: the guide matches the implemented commands, paths,
  reports, and output locations.

## Testing Strategy

- Unit-test pure normalization, availability, status, cache-key, hash, and
  provenance functions with small deterministic fixtures.
- Inject HTTP/request and file-writing functions so API behavior is testable
  without network access.
- Use stored UN SDG, JMP, PIP, and World Bank response fixtures for success,
  schema-change, empty-response, and HTTP-error cases.
- Use target-level tests to verify collection artifacts are upstream of the
  estimation gate and that separate target stores do not share invalidation
  state.
- Preserve and extend the existing vintage comparison, fixture hash, scoring,
  and final-output validation tests.
- Run focused tests after each phase, then `testthat::test_local()` and both
  target manifests before handoff.

## Documentation Checklist

- [ ] Two-command collection-first workflow documented.
- [ ] Separate target stores and cache locations documented.
- [ ] Source registry fields and status severities documented.
- [ ] Raw, normalized, availability, provenance, and report artifacts documented.
- [ ] Source-specific freshness rules and rough age warnings documented.
- [ ] Manual/external source actions documented for all 22 dimensions.
- [ ] Pillar 3 SDG collection and availability artifacts documented.
- [ ] Final outputs documented as `03_output_data/` artifacts.
- [ ] Troubleshooting and blocking-gate behavior documented.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Remote APIs change schema or semantics | Preserve raw responses, validate schemas, hash artifacts, and stop on blocking changes. |
| `{targets}` cache hides remote changes | Run an explicit freshness/status target on every collection command and use source-specific cache keys. |
| API endpoints are rate-limited or unreliable | Cache successful raw responses, inject retry policy deliberately, and classify non-reliable sources as manual/external. |
| `pipr` or another package is unavailable or changes behavior | Isolate acquisition behind a collector contract, pin/record package versions, and maintain a documented equivalent or manual fallback. |
| SDG port changes scoring inputs | Keep the Rmd untouched, retain raw/per-series fixtures, and compare availability and five-year inputs before final scores. |
| Estimation still performs hidden network calls | Complete static/runtime audit and make all external inputs explicit collection artifacts. |
| Direct writes leave incomplete `03_output_data/` | Write to temporary paths, validate the complete set, then replace atomically with tests. |
| Manual sources are silently treated as complete | Require registry records and visible status/action fields for every source. |
| Scope expands beyond a verifiable first release | Keep all sources represented in the registry while implementing collectors in phases; stop at declared blocked conditions. |

## Out of Scope

- Changing indicator definitions, scoring thresholds, weights, or methodology
  without a separate approved decision.
- Editing the legacy Rmd files; they remain replication references.
- Automating sources that lack a reliable public endpoint or reproducible
  transformation without explicit technical-team approval.
- Rebuilding historical vintages beyond the approved fixture/replication scope.
- Adding dashboard or visualization features beyond documenting final outputs.
- Introducing credentials, private data, or non-public source dependencies.

## Completion Contract

### Outcome

The repository contains two independently runnable `{targets}` pipelines. The
collection pipeline owns API extraction, raw/normalized/availability/provenance
artifacts, freshness checks, and manual-source reporting; the estimation
pipeline validates that collection state, produces complete outputs in
`03_output_data/`, and contains no hidden source acquisition.

### Verification Surface

| ID | Phase | Evidence Required | Command/Artifact | Required |
|----|---:|---|---|---|
| V1 | 1 | Complete 22-dimension registry and runtime-call audit | Registry tests and reviewed audit report | yes |
| V2 | 2 | Deterministic raw/cache/provenance behavior | Focused collection tests | yes |
| V3 | 3 | SDG raw, normalized, availability, and score-input fidelity | SDG fixture/regression tests | yes |
| V4 | 4 | API collectors and manual/external checkpoints are target-connected | `_targets_data.R` manifest and status report | yes |
| V5 | 5 | Collection gate and final `03_output_data/` write set | Estimation integration tests | yes |
| V6 | 6 | End-to-end fixture run and vintage comparisons | `testthat::test_local()` and target smoke checks | yes |
| V7 | 7 | Technical-team documentation matches implementation | `docs/user-guide.md` review | yes |

### Constraints

| ID | Constraint | Check |
|----|---|---|
| C1 | Rmd references remain untouched | Git diff and replication tests |
| C2 | Public/open sources only | Source registry review |
| C3 | Blocking source issues stop estimation | Gate tests |
| C4 | Raw artifacts and provenance are preserved | Hash/status artifact tests |
| C5 | Final outputs are complete and written to `03_output_data/` | Output manifest and integration tests |
| C6 | Default tests do not require live network access | Test command and fixture review |
| C7 | No methodology changes are implicit | Vintage comparison and deviation review |

### Boundaries

- **Allowed**: new collection targets/functions/configuration, targeted changes
  to estimation paths and writers, tests, fixtures, and documentation.
- **Out of scope**: methodology redesign, legacy Rmd edits, unsupported API
  automation, dashboard work, and unrelated refactors.

### Iteration Policy

1. Work phase-by-phase; do not connect an unvalidated collector to estimation.
2. Preserve raw evidence before changing normalization logic.
3. Prefer explicit manual/external status over speculative automation.
4. When behavior differs from the Rmd or fixture, stop and request a decision.
5. Keep the approved source registry and status contract as the integration
   authority.

### Blocked-Stop Conditions

- A required source cannot be classified or its expected artifact cannot be
  defined.
- A source endpoint, package, or schema cannot be verified.
- SDG or other transformations cannot be reconciled to the approved Rmd
  behavior.
- The collection gate or output write policy cannot be made deterministic.
- Required dependencies or source files are unavailable after documented
  recovery steps.

### Deviation Policy

`ask`: pause for user approval when implementation would change the approved
source classification, collection artifact contract, methodology, output
ownership, or phase boundaries.

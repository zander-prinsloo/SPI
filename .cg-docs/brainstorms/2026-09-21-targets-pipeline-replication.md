---
date: 2026-09-21
title: "Targets-based SPI estimation pipeline with exact replication of the 2024 vintage"
status: decided
scope: "Deep"
artifact-schema-version: 1
chosen-approach: "Full targets pipeline with per-indicator functions"
tags: [targets, pipeline, replication, testing, user-guide, spi]
---
<!-- Valid status values: decided, in-progress, abandoned -->

# Targets-based SPI Estimation Pipeline

## Context

The SPI data product is produced by a series of R Markdown pipelines. The three
most important files are `01-SPI_data_prep.Rmd` (5,142 lines), `02-SPI_index.Rmd`
(3,384 lines), and `03_SPI_data_validation.Rmd` (166 lines). These have worked
for several vintages and contain valuable comments and documentation, but Rmd
files are not well suited to reliable estimation and pipeline workflows. The
goal is a new estimation pipeline using R's `{targets}` package that:

- exactly, precisely replicates the results of the current pipeline (2024
  vintage, also called 202511);
- remains readable by the SPI technical lead (clarity over efficiency);
- is well documented, drawing on the extensive comments in the existing scripts;
- is accompanied by a user guide for the technical lead covering the step-by-step
  SPI update approach, including where to get sources.

Phase 1 of the work is designing comprehensive tests to ensure the new pipeline
works as expected, run against the 2024 data to verify it produces the same
results as the 202511 vintage.

## Requirements

From Q&A with the user:

- **Primary goal**: All three — exact replication of the 2024 vintage (202511)
  is the gate; future-update readiness and maintainability are equal priorities.
- **Users**: Technical lead (SPI) primarily; other team members may review/run.
- **Replication target**: The committed `03_output_data/` files
  (`SPI_data.csv`, `SPI_index.csv`, etc.) — the 202511 vintage.
- **Difference tolerance**: Tolerance-based comparison (1e-9 relative) to allow
  floating-point noise; real differences fail.
- **Pipeline scope**: Core 3 Rmds (data prep, index, validation) + misc_scripts
  outputs (quantiles, treemap, databank files, SPL admin data) + data pulls
  (download steps included where APIs allow; manual steps as documented
  checkpoints).
- **Data pulls**: Include download steps — automate where reliable APIs exist;
  manual downloads documented as targets with manual triggers.
- **Rmd fate**: Keep untouched as reference source of truth.
- **Environment**: Extend existing `renv` with `{targets}`, `{tarchetypes}`,
  `{testthat}`.
- **Run trigger**: Standard `targets::tar_make()` from R console (primary);
  CLI variant documented as alternative.
- **Edge cases**: Fail loudly and report to the tech lead — schema validation on
  source reads; source format changes (e.g., ILO column renames, ODIN format
  shifts) must be surfaced, not silently adapted. Also: missing/partial country
  coverage, new countries/code changes, reproducibility across machines, long
  run times / partial re-runs.
- **Out of scope**: Changing the SPI methodology itself; the Shiny dashboard
  (`SPI_data_viz/`); the technical methodology document; country reports.
- **Visualization scope**: Pure-visualization chunks (maps, charts) and
  commented-out blocks are EXCLUDED from the porting surface. The pipeline
  covers active estimation logic only. (Deliberate, documented deviation from
  "exactly replicate the Rmds" — framed as "replicate the estimation results
  exactly; visualization is out of scope".)

## Approaches Considered

### Approach 1: Full targets pipeline with per-indicator functions
Refactor the 3 Rmds into a `_targets.R` pipeline where each indicator (or
indicator group) is a named function in `R/`, each producing a target; tests
compare every intermediate and final artifact against the 202511 vintage.

- Pros: True targets benefits (incremental re-runs, dependency graph,
  `tar_visnetwork()` debugging); per-indicator functions map 1:1 to Rmd chunks
  for auditability; schema-validation wrappers catch source format changes
  loudly; test suite can target individual indicators (fast iteration) and the
  full pipeline (final gate).
- Cons: Largest upfront effort (5,100+ lines to port); risk of subtle behavior
  drift during porting (mitigated by the test suite); some chunks interleaved
  with documentation prose require careful extraction.

### Approach 2: Thin targets wrapper around the existing Rmds
Keep the Rmd logic intact; use targets only to orchestrate
`rmarkdown::render()` of the three files in sequence, with the test suite
comparing final outputs.

- Pros: Minimal porting risk; fast to stand up; tests still give the
  replication gate.
- Cons: No incremental re-runs; no per-indicator granularity; doesn't solve the
  "Rmd not great for reliable estimation" problem.
- Not recommended: fails the core motivation.

### Approach 3: Hybrid — targets for data prep + index, Rmd render for validation
Port 01 and 02 to targets functions; keep 03 validation as a rendered Rmd that
reads the new outputs.

- Pros: Focuses effort where the value is; validation stays as-is.
- Cons: Validation logic isn't testable as code; inconsistent architecture.
- Not recommended: the validation checks are exactly what should become
  automated tests in the new pipeline.

## Decision

**Approach 1: Full targets pipeline with per-indicator functions.**

Key design principles:
1. **Tests first (Phase 1)**: Build the comparison harness before porting.
   Compare old vs new outputs at every stage; port indicator-by-indicator with
   tests driving the porting. This de-risks the 5,100-line port.
2. **Fail loudly**: Schema-validation wrappers around source reads; any source
   format change is reported to the tech lead, never silently adapted.
3. **Readability over efficiency**: Functions kept simple and well-commented so
   the technical lead can read and understand them.
4. **Estimation only**: Visualization chunks and commented-out blocks stay in
   the Rmds; the pipeline replicates estimation results exactly.
5. **User guide populated as the pipeline is built**: step-by-step SPI update
   approach, where to get sources, manual checkpoints.

## Next Steps

For handoff to `/cg-plan`:

1. **Phase 0 — Scaffolding**: Extend `renv` with `{targets}`, `{tarchetypes}`,
   `{testthat}`; create `_targets.R`, `R/` function library, `tests/` harness,
   and the user guide skeleton.
2. **Phase 1 — Test harness**: Build comparison utilities (tolerance-based,
   1e-9 relative) for every output artifact; snapshot the 202511 vintage outputs
   as test fixtures; establish the "old vs new" comparison at each pipeline
   stage.
3. **Phase 2 — Port data prep (01)**: Port active estimation chunks of
   `01-SPI_data_prep.Rmd` into per-indicator functions; verify each against the
   vintage; produce `SPI_data.csv`/`.dta` identically.
4. **Phase 3 — Port index (02)**: Port the nested index construction; verify
   `SPI_index.csv` and derived files identically.
5. **Phase 4 — Port validation (03)**: Convert validation expectations into
   automated tests; keep the vintage-comparison and correlation checks.
6. **Phase 5 — misc_scripts + data pulls**: Port quantiles, treemap, databank,
   SPL admin outputs; add download targets where APIs allow; document manual
   checkpoints.
7. **Phase 6 — User guide completion**: Finalize the step-by-step update guide
   for the technical lead, including source locations and manual steps.
8. **Phase 7 — Full replication gate**: Run the complete pipeline on 2024 data;
   confirm zero (or documented, approved) differences vs the 202511 vintage.

Roadmap additions requested by the user (as ideas):
- Source-schema registry (machine-readable expected schema per source file).
- Vintage-diff reporting (standing report of changes between vintages).
- Optional visualization ability for the technical lead (after the estimation
  pipeline) to validate data visually.
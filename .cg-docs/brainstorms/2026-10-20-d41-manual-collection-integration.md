---
date: 2026-10-20
title: "Integrate Dimension 4.1 Manual Collection into the SPI Collection Pipeline"
status: decided
scope: "Deep"
artifact-schema-version: 1
chosen-approach: "Refactor 4.1 collection into tested functions and explicit targets"
tags: [dimension-4.1, manual-collection, microdata, targets, provenance, preprocessing]
---
<!-- Valid status values: decided, in-progress, abandoned -->

# Integrate Dimension 4.1 Manual Collection into the SPI Collection Pipeline

## Context

The SPI collection architecture separates source collection from estimation.
Dimension 4.1 (censuses and surveys) is currently only partially represented
in that architecture. Programmatic catalogue pulls exist in
`02_programs/misc_scripts/microdata_library_pull.Rmd`, while the core evidence
is maintained in eight manually curated Excel workbooks under
`01_raw_data/4.1_SOCS/raw/input/`.

The preprocessing script reads those workbooks and writes eight derived
`D4.1.*.<YEAR>.csv` files. The estimator then reads the generated files, the
D4.1-specific catalogue companion files, and a vintage-specific manual review
workbook. The current `{targets}` collection pipeline checks only the generated
outputs; it does not run or explicitly track the manual-input preprocessing.

The prior collection-pipeline decision remains the architectural foundation:
a registry-driven collection pipeline runs before estimation, preserves raw and
normalized artifacts, records provenance, and blocks estimation on unresolved
source problems. This brainstorm narrows that design to the Dimension 4.1
manual and derived artifacts.

## Requirements

- The eight files in `01_raw_data/4.1_SOCS/raw/input/*.xlsx` must be first-class
  collection inputs.
- `D4.1.Manual.Review.<YEAR>.xlsx` must be a first-class collection input.
- The existing Excel structure must remain unchanged.
- The SPI technical lead owns the run and country economists review the source
  evidence and provide adjustments through the manual review workbook.
- The manual review workbook is the authoritative additive-evidence layer;
  review values are merged with source evidence and do not silently replace it.
- The generated `D4.1.*.<YEAR>.csv` files are derived, validated collection
  artifacts, not independent manual sources.
- D4.1-specific `D4.1.*_NADA.csv` companion files must be included or
  validated in the D4.1 collection flow.
- The separate `D2.4.NADA.<YEAR>.csv` workflow remains Dimension 2.4 and is
  out of scope for this D4.1 integration.
- Changing `end_date` must propagate to output filenames, embedded dates,
  manual-review filenames, validation expectations, and estimation inputs.
- The collection pipeline must execute preprocessing before estimation.
- Missing files, invalid workbook schemas, duplicate country keys, incomplete
  required coverage, stale derived outputs, and invalid review inputs must
  fail loudly and alert the technical lead.
- Basic unit tests must cover workbook structure, country keys, date handling,
  preprocessing outputs, manual-review structure, and derived artifact checks.
- Documentation and the user guide must explain the manual and programmatic
  steps together.
- The original Rmd workflow and existing reference scripts remain untouched as
  replication references.
- The implementation must preserve exact-replication testing and the project's
  open-data, reproducibility, and fail-loudly constraints.

## Inputs and Outputs

The intended data contract is:

```text
raw/input/*.xlsx
  -> parameterized 4.1 preprocessing
  -> D4.1.*.<end_date>.csv

microdata/catalogue collection
  -> D4.1.*_NADA.csv companion artifacts

D4.1.Manual.Review.<end_date>.xlsx
  -> validated country-level override layer

all validated D4.1 artifacts
  -> Dimension 4.1 estimation target
```

The Excel workbooks remain unchanged. Provenance, hashes, review status, and
collection approval should be recorded in a separate manifest rather than by
adding fields to those workbooks.

## Approaches Considered

### Approach 1: Wrap the legacy preprocessing scripts

Add file targets for the eight workbooks and review file, invoke the existing
preprocessing script, and validate its outputs.

Pros: smallest initial change and closest to existing behavior.

Cons: the script is hard-coded to 2024, writes many outputs imperatively, and
would be difficult to test granularly or make fully dependency-aware.

Effort: medium.

### Approach 2: Refactor 4.1 collection into tested functions and targets

Extract workbook validation, manual-review validation, catalogue collection,
D4.1 companion generation, year-parameterized preprocessing, and manifest
creation into ordinary R functions. Connect them through explicit collection
targets while leaving the original Rmd and legacy scripts untouched as
reference artifacts.

Pros: explicit dependencies, correct `end_date` propagation, granular target
caching, strong unit tests, clear provenance, and loud failures.

Cons: larger implementation and comparison effort.

Effort: medium to large.

### Approach 3: Hybrid manifest-driven staging

Keep the existing preprocessing logic but add a D4.1 manifest containing input
hashes, review-file hash, derived outputs, provenance, and validation status.
Track the manifest and all source files in `{targets}`.

Pros: improves provenance with less refactoring.

Cons: retains the preprocessing script's hard-coded and imperative behavior.

Effort: medium.

## Decision

Choose **Approach 2: refactor Dimension 4.1 collection into tested functions and
explicit `{targets}` artifacts**.

The collection pipeline should expose the eight Excel files, the manual review
workbook, the D4.1 catalogue companion inputs, the preprocessing code, and the
derived CSVs as explicit dependencies. A successful collection run should
produce a validated D4.1 manifest that records the source hashes, reference
year, generated artifacts, review state, and validation results. Estimation
should consume that validated artifact rather than discover the files
independently.

The D4.1 workflow should be integrated with the existing registry-driven
collection/status architecture, but D2.4 NADA remains a separate source and
target.

## Devil's Advocate Checks

- The principal risk is stale derived data: a changed workbook must invalidate
  preprocessing and the D4.1 estimation dependency, not merely leave an old
  CSV available.
- Preserving the workbook structure means approval and provenance cannot be
  hidden in new workbook columns; the separate manifest must be authoritative
  for collection state.
- Running the entire legacy Rmd as one target would make failures and source
  dependencies opaque. Refactoring the transformation logic is more work but
  provides the required auditability.
- Catalogue/API collection and manual evidence review should remain distinct
  stages in the manifest. A programmatically discovered survey is not the same
  as a country-economist-approved adjustment.
- D4.1 companion NADA files must not be confused with the separate Dimension
  2.4 NADA indicator.

## Next Steps

1. Define the D4.1 source-registry records and artifact manifest schema.
2. Parameterize the existing 4.1 preprocessing logic by `end_date` without
   modifying the reference Rmd workflow.
3. Add explicit file targets for the eight input workbooks and the current
   manual-review workbook.
4. Add workbook schema, country-key, duplicate, coverage, and year tests.
5. Add the D4.1 catalogue/API collection target and D4.1-specific NADA
   companion generation/validation.
6. Add a preprocessing target that writes the eight current-vintage CSVs and
   fails on incomplete or stale output.
7. Make the D4.1 manifest a blocking dependency of the estimation pipeline.
8. Update `docs/user-guide.md` with the manual-review workflow, roles,
   filenames, validation steps, and the programmatic/manual run order.
9. Compare the refactored D4.1 outputs against the existing 2024/202511
   reference outputs before enabling the 202611 update path.

## Prior Knowledge Applied

- The existing SPI collection architecture is registry-driven and separate
  from estimation — source: `.cg-docs/brainstorms/2026-10-05-api-data-collection-pipeline.md`.
- Manual and externally prepared sources must remain visible through
  provenance, freshness, and blocking-status reports — source:
  `.cg-docs/plans/2026-10-05-spi-data-collection-pipeline.md`.

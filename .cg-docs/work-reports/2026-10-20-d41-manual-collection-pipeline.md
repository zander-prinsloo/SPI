# Execution Report: Dimension 4.1 Manual Collection Pipeline

- **Plan reference**: `.cg-docs/plans/2026-10-20-d41-manual-collection-pipeline.md`
- **Active deviation policy**: `ask`
- **Branch**: `feat/d41-manual-collection-pipeline`
- **Run started**: 2026-10-20

## Completed Steps/Phases

- Phase 1 completed on 2026-10-20.
  - Defined and registered the eight manual workbooks and current manual-review
    workbook.
  - Added workbook, country-key, sheet, review-schema, and coverage validation.
- Phase 2 completed on 2026-10-20.
  - Added end_date-parameterized preprocessing for all eight derived CSVs.
  - Added review hash/override metadata, artifact hashes, and manifest helpers.
- Phase 3 implementation completed on 2026-10-20 but evidence is blocked by
  existing D4.1 companion data quality.
  - Added D4.1 companion validation and an opt-in legacy catalogue adapter.
  - The live adapter is classified external/opt-in because the legacy Rmd
    requires slow upstream catalogue calls and has compatibility defects.
- Phase 4 implementation completed on 2026-10-20 but the live manifest target
  is blocked by the companion data-quality issue.
  - Added collection and estimation target dependencies for the D4.1 manifest.
  - Manual validation target executes successfully.
- Phase 5 documentation and regression evidence completed on 2026-10-20;
  final phase completion is blocked by unresolved source evidence.

## Deviations

- None.

## Accepted Exceptions

- None.

## Evidence Table

| ID | Phase | Required Evidence | Status | Artifact/Command |
|----|---:|---|---|---|
| V1 | 1 | All manual input and review files are explicit target dependencies | passed | `test-pipeline-contract.R` (7 passed) |
| V2 | 1 | Workbook schemas, keys, duplicate rows, dates, and coverage validate | passed | `test-dim4-collection.R` (37 passed) |
| V3 | 2 | `end_date` propagates to all eight output names and embedded dates | passed | `test-dim4-collection.R` (preprocessing/date assertions) |
| V4 | 2 | Manual review overrides are applied and hashed in the manifest | passed | `test-dim4-collection.R` (review/manifest assertions) |
| V5 | 3 | D4.1 companion files have raw/normalized/provenance coverage | blocked | `D4.1.4.SVY.HOUS_NADA.csv` has 16 unmapped country rows |
| V6 | 4 | Collection target runs preprocessing before status completion | blocked | `d41_manifest` stops at companion validation |
| V7 | 4 | Estimation is blocked by invalid or missing D4.1 artifacts | pending | Gate code and target contract pass; live manifest is blocked |
| V8 | 4 | `dim4` consumes only validated collection artifacts | passed | `test-pipeline-contract.R`; manifest path passed into `dim4` |
| V9 | 5 | 2024/202511 output remains within established tolerance | pending | Phase 5 stage comparison |
| V10 | 5 | Manual/programmatic run order is documented | passed | `docs/user-guide.md`, `README.md` |

## Constraints Check

| ID | Constraint | Status | Evidence |
|---|---|---|---|
| C1 | Preserve the eight Excel workbook structures | passed | Workbook schema and sheet tests |
| C2 | Leave legacy Rmd/reference scripts untouched | pending | Git diff and replication checks |
| C3 | Fail loudly; no silent legacy fallback | passed | Missing-input and metadata failure tests |
| C4 | Keep D4.1 NADA separate from D2.4 NADA | passed | Companion-path manifest tests |
| C5 | Use relative paths and reproducible hashes | passed | Review and artifact hash tests |
| C6 | Do not change methodology implicitly | pending | 2024/202511 comparison |

## Remaining Uncertainty

- The catalogue collection adapter and D4.1 companion validation are wired into
  the collection target; live refresh remains an external/opt-in operation.
- The prior collection plan remains blocked on its own Phase 5 evidence; this
  follow-up must not claim that broader plan's unfinished evidence as complete.
- Existing household-survey companion data contain 16 rows with missing country
  values. Upstream PIP country codes include `TWN`, which is absent from the
  current estimation ISO lookup. These rows now have an explicit, manifest-
  recorded exclusion tied to exact PIP dates. Three labour companion rows still
  have missing country values and require a source mapping or approved exclusion.

## Evidence Notes

- Full repository suite: 241 passed, 0 failed, 187 warnings, 12 expected
  skips. Skips cover unavailable `validate` and final-output fixtures before
  the broader estimation plan's Phase 5 completion.
- Focused D4.1 and target-contract suites passed with 0 failures.

## Blocked Stop

- **Blocking artifact**: `01_raw_data/4.1_SOCS/D4.1.4.SVY.HOUS_NADA.csv`.
- **Observed issue**: three rows in `D4.1.6.SVY.LABR_NADA.csv` have missing
  `country` values for dates 2019, 2020, and 2023.
- **Required decision**: identify the source country or approve an auditable
  exclusion rule before the D4.1 manifest can pass.

## Final Status

`blocked`

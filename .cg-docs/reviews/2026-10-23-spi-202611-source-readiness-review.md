---
date: 2026-10-24
depth: full
type: standard
plan: .cg-docs/plans/2026-10-23-spi-202611-source-readiness.md
findings:
  P0.1: open
  P0.2: open
  P0.3: open
  P0.4: open
  P0.5: open
  P0.6: open
  P0.7: open
  P0.8: fixed
  P0.9: open
  P0.10: open
  P1.1: open
  P1.2: open
  P1.3: open
  P1.4: open
  P1.5: open
  P1.6: open
  P1.7: open
  P1.8: open
  P1.9: open
  P1.10: fixed
  P1.11: open
  P2.1: open
  P2.2: open
  P2.3: fixed
  P2.4: open
  P2.5: fixed
  P2.6: open
  P2.7: open
  P2.8: open
  P2.9: open
  P2.10: open
  P3.1: open
---

# SPI 202611 canonical gate review

## Review scope and evidence

Reviewed only the paths listed in `/tmp/spi-gate/review_canonical_scope.txt`,
excluding generated `.cg-docs/views/**` bodies. The review cross-referenced
the current implementation and evidence against:

- `.cg-docs/reviews/2026-09-21-targets-pipeline-replication-review.md`
- `.cg-docs/reviews/2026-10-05-spi-data-collection-pipeline-review.md`
- `.cg-docs/reviews/2026-10-20-d41-manual-collection-pipeline-review.md`
- `.cg-docs/reviews/2026-10-21-nada-gsbp-collection-pipeline-review.md`
- the matched 2026-10-23 source-readiness brainstorm, plan, and handover
- the D4.1 and collection brainstorms/plans

No files were recommended for deletion, replacement, renaming, or moving.
The protected paths remain protected.

Executed evidence includes the full suite (1,055 passed, 0 failed, 14
skipped, 206 warnings), the D4.1 prefetch suite (20 tests, 103 expectations),
the E6-aware attribution (845 cells, 0 unexplained, 0 pipeline differences),
the final 2024 differential replication (1,303 expectations, 13 accepted X1
failures), and the all-row ODIN rehearsal (12,817 allowed changes, 0 outside
the ODIN set).

**Result**: 10 P0, 11 P1, 10 P2, and 1 P3 findings. One P0 cache-integrity
finding and one P1 attribution-gate finding were fixed during review. The
remaining P0/P1 issues are manual release/data-integrity blockers. The
collection gate is intentionally blocked by 17 `attestation_missing` rows;
that is a valid fail-closed state, but it is not a releasable state.

## P0 — Blocking

### [P0.1] Collection artifacts are not content dependencies of estimation

- **File/path**: `_targets.R:131-160, 202-209, 232-239, 305-312`;
  `_targets_data.R:28-31, 101-107`
- **Why**: `load_params()` reads the country snapshot internally, several
  dimension functions read registry artifacts internally, and
  `collection_gate` returns a constant success value after validating a
  mutable status CSV. A changed source can therefore remain invisible to
  `{targets}` and feed stale estimates.
- **Fix**: Add explicit registry-driven file/hash targets for every
  estimation input and make a content/run digest a dependency of all
  consumers. Add mutation tests for a changed source and country snapshot.
- **Tag**: `[manual]`

### [P0.2] Release-critical replication comparisons can skip

- **File/path**: `tests/testthat/test-stage-compare.R:39-56`;
  `tests/testthat/test-vintage-compare.R:24-45`
- **Why**: Missing output manifests cause these tests to call `skip()`. The
  focused suite therefore reported all 11 comparison tests skipped without
  comparing current output to the frozen fixtures.
- **Fix**: In release mode, missing/stale manifests and required outputs must
  fail. Keep skips only behind an explicit porting/development mode, and
  validate the expected vintage and output set.
- **Tag**: `[manual]`

### [P0.3] Empty outputs can be promoted

- **File/path**: `R/output_manifest.R:102-111`;
  `tests/testthat/test-output-manifest.R:18-37, 56-63`
- **Why**: The output gate checks existence but accepts zero-byte or
  header-only files. A truncated statistical output can therefore be
  promoted and locked.
- **Fix**: Validate minimum schema, row/key coverage, and non-empty content
  before promotion; add negative tests for zero-byte, header-only, malformed,
  and truncated outputs.
- **Tag**: `[manual]`

### [P0.4] LFP accuracy awards credit without a valid comparator

- **File/path**: `R/dim1_5.R:654-656, 681-684`
- **Why**: Missing modelled values become `estimate_diff = 0`, and the
  signed mean treats a reported-minus-modelled gap of `-20` as within the
  `<= 10` threshold.
- **Fix**: Preserve missing comparisons as missing, require at least one
  valid pair, and use the approved absolute-gap rule. Add missing-estimate
  and negative-gap tests.
- **Tag**: `[manual]`

### [P0.5] Malformed or duplicate ODIN rows can become valid scores

- **File/path**: `R/dim2.R:143-180, 200-220`
- **Why**: Bare numeric coercion and zero-filling can turn an invalid ODIN
  value into a valid zero. Duplicate or missing all-category country-year
  rows are not rejected.
- **Fix**: Parse numeric fields with explicit missing-token rules, reject
  other text, assert unique country-year keys, and enforce expected-country
  coverage before scoring.
- **Tag**: `[manual]`

### [P0.6] Unknown SDG geography codes are silently dropped

- **File/path**: `R/collect_sdg.R:174-191, 258-270`
- **Why**: An unmapped `GeoAreaCode` disappears during the lookup/template
  joins and is later filled as zero quality.
- **Fix**: Report and reject unknown codes unless explicitly allowlisted as
  non-economies; enforce coverage before filling missing values.
- **Tag**: `[manual]`

### [P0.7] D4.1 evidence can be outside the estimation country universe

- **File/path**: `R/collect_dim4_1.R:147-169`;
  `R/dim4.R:44-66, 535-544`
- **Why**: Lookup validation checks CLASS membership but not the collected
  country snapshot. Current normalized evidence contains a TWN row that is
  absent from the current snapshot; the grid join drops it without a
  blocking diagnostic.
- **Fix**: Validate companion ISO3 codes against the canonical estimation
  universe and assert zero unmatched evidence after each join.
- **Tag**: `[manual]`

### [P0.8] D4.1 cache hashes were recorded but not enforced — fixed

- **File/path**: `R/collect_dim4_1_prefetch.R`;
  `tests/testthat/test-d41-catalogue-prefetch.R`
- **Why**: A changed but valid cached body was served while the index retained
  the old SHA-256.
- **Fix applied**: Cache hits and cached readers now recompute body hashes and
  byte counts; mismatches refetch or stop. A tampering/refetch regression test
  passes.
- **Tag**: `[safe_auto]`

### [P0.9] IGME wealth-quintile rows are counted as independent observations

- **File/path**: `R/dim1_5.R:305-321, 363-365`
- **Why**: The reader does not require/filter `Wealth.Quintile == "Total"`,
  so multiple wealth rows can satisfy the mortality observation-count rule.
- **Fix**: Require the wealth-quintile field, filter to the approved unit, and
  add a repeated-wealth-row regression test. This requires an explicit
  methodology decision because current documentation records the legacy
  behavior.
- **Tag**: `[manual]`

### [P0.10] JMP no-data sentinel can become valid quality

- **File/path**: `R/pull_jmp.R:209-216`
- **Why**: The `max_value <= 0.5` path can classify empty/`-99` rows as
  qualifying observations.
- **Fix**: Treat empty and sentinel rows as missing or zero quality, then
  recalibrate and regenerate water evidence. This requires an explicit
  methodology decision because the current JMP brief documents legacy
  behavior.
- **Tag**: `[manual]`

## P1 — Critical

### [P1.1] D4.1 manual-review values can be silently ignored

- **File/path**: `R/dim4.R:254-267, 291-302`;
  `R/collect_dim4_1.R:627-658`
- **Why**: Each scorer starts with `base_raw` and performs a
  `left_join(manual_raw, by = "iso3c")`. A valid review row whose ISO3C is
  absent from that indicator's derived workbook is discarded; the review
  layer is not additive in that case. The validator checks country metadata
  only when the manifest is built, and its year/register regex is
  unanchored (`[0-9]{4}`), so malformed values such as `"pending 2025"` can
  pass and then be partially interpreted by the scorer. The current 2025
  review has 27 review-only keys but no nonblank indicator values, so this is
  a latent data-loss path rather than a measured current revision.
- **Fix**: Either append validated review rows before scoring, or fail closed
  when a nonblank review value has no corresponding base row. Use an anchored
  parser for comma-separated four-digit years and the exact register-census
  token. Add a test for a valid country absent from the base workbook and for
  malformed values that contain, but are not equal to, a year.
- **Tag**: `[manual]`
- **History**: Recurs the D4.1 review P0.3 finding in
  `.cg-docs/reviews/2026-10-20-d41-manual-collection-pipeline-review.md`.

### [P1.2] D4.1 companion promotion is not an atomic set operation

- **File/path**: `R/collect_dim4_1.R:1344-1373`
- **Why**: The eight staged files are renamed/copied one at a time. An
  interruption can leave a mixed old/new companion set. If the `file.copy()`
  fallback partially changes the current target and then returns failure,
  rollback starts at the prior index and does not restore that current
  target. The tests cover adapter failure, incomplete staging, and invalid
  staged data, but not a failed promotion or process interruption.
- **Fix**: Promote a complete versioned directory through one atomic directory
  swap (or an equivalent manifest pointer), or make the rollback cover the
  current failed target as well as every earlier target. Add injected
  promotion-failure and interruption/recovery tests. Do not call the set
  atomic until the complete-set operation is proven.
- **Tag**: `[manual]`
- **History**: This is the unresolved portion of D4.1 review P1.4 and plan
  requirement R17 in `.cg-docs/plans/2026-10-23-spi-202611-source-readiness.md`.

### [P1.3] D4.1 manual review is not hash-attested at the collection gate

- **File/path**: `config/source_registry.R:319-361`;
  `R/collection_status.R:164-225`
- **Why**: The eight D4.1 input workbooks use `manual_attestation`, but
  `d4_1_manual_review` uses `expected_vintage_rule = "end_date"`. Presence
  and manifest hashing therefore suffice; the status gate does not require
  the country-economist review workbook to be attested, and an edited review
  workbook can become the new authorized manifest after a collection run.
  The same design should be checked for the NADA/GSBP review workbooks.
- **Fix**: Classify the D4.1 review workbook as `manual_attestation` (or add a
  dedicated reviewed/approved manifest record), require a hash-matching
  attestation after review, and block on post-attestation edits. Align the
  user guide and the review-candidate workflow with the chosen approval
  contract.
- **Tag**: `[manual]`
- **History**: Conflicts with the binding B1/R6 hash-attestation decision in
  `.cg-docs/brainstorms/2026-10-23-spi-202611-source-readiness.md`.

### [P1.4] Release lock does not pin provenance sidecars and is not tamper-evident

- **File/path**: `R/release_lock.R:25-39, 87-119, 241-270`
- **Why**: `release_lock_artifacts()` locks normalized payload files and raw
  directories but returns no adjacent `*.provenance.json` paths. The current
  probe found zero provenance sidecars in the 104 locked paths. A changed PIP
  normalized sidecar could therefore change the recorded release identifier
  while leaving the payload hash unchanged; `collection_status` would accept
  the new metadata and `verify_release_lock()` would pass. In addition,
  `read_release_lock()` checks only `end_date` and then trusts the mutable
  lock JSON's artifact list and hashes.
- **Fix**: Include every normalized artifact's provenance sidecar (and the
  relevant provenance/cache identity) in the lock, or hash the provenance
  record into the locked artifact identity. Validate a lock schema and a
  self-hash/signature or immutable archive reference before trusting its
  contents. Add tests for sidecar release-ID edits and lock allow-list/hash
  edits.
- **Tag**: `[manual]`
- **History**: Extends the collection-provenance gap in P1.7 of
  `.cg-docs/reviews/2026-10-05-spi-data-collection-pipeline-review.md`; the
  release-lock plan explicitly requires cache provenance to be locked.

### [P1.5] The collection-status CSV is a mutable gate input

- **File/path**: `R/collection_status.R:324-375`;
  `_targets_data.R` collection-status writer
- **Why**: `validate_collection_status()` checks status values, source IDs,
  run ID, and parameter hash, but never recomputes the status from the current
  registry/artifacts or verifies a status-file hash bound to the completed
  run. Editing a blocking row to `informational` while preserving the
  run/parameter fields can therefore bypass the estimation gate. The run
  marker is mutable in the same way.
- **Fix**: Recompute status during the estimation gate, or write a
  `status_sha256` into the run marker after the report is written and verify
  it before estimation. Include the status/run identities in the release
  lock. Add a mutation test that changes only a status field and expects the
  gate to stop.
- **Tag**: `[manual]`
- **History**: Residual of the earlier collection-status trust problem
  (P1.5 in the 2026-10-05 review); the run-ID check fixes stale failed runs but
  does not authenticate the report contents.

### [P1.6] Duplicate CLASS memberships distort aggregate outputs

- **File/path**: `R/databank.R:59-68`;
  `tests/testthat/test-databank-aggregates.R`
- **Why**: The real `CLASS.xlsx` Groups sheet contains duplicate
  `(iso3c, WB_Group_Code)` memberships for OECD: 75 rows but only 38 unique
  economies. `aggregate_databank()` explicitly permits a many-to-many join,
  so current output counts OECD members as `N = 75` instead of `38`; comparing
  the real 2024 country rows against a de-duplicated classification changes
  1,533 `N`/`N_obs` cells and 248 aggregate values. This contaminates the E6
  aggregate evidence and can affect published regional/income aggregates.
- **Fix**: Have the technical lead confirm that exact duplicate
  country/group rows are not an intentional weighting rule, then
  de-duplicate or fail on duplicate classification keys before joining. Add a
  regression test using the real CLASS structure and regenerate the databank,
  E6 aggregate evidence, revision report, and release evidence.
- **Tag**: `[manual]`
- **History**: Not identified by the prior reviews; it is a current residual
  exposed by the requested E6/aggregation cross-check. The aggregate-order
  fix is correct but does not address duplicate membership.

### [P1.7] Human release blockers and E6 approvals remain unresolved

- **File/path**: `.cg-docs/active-state/current.json`;
  `01_raw_data/_collection/collection_status.csv`;
  `.cg-docs/work-reports/2026-10-24-spi-202611-handover.md`
- **Why**: The current status has 17 blocking `attestation_missing` rows
  (including the eight D4.1 workbooks, IGME/ILO, IMF, SDDS, the ILO
  catalogue, and CNIN/FINA reviews). The active state also records the 853
  review candidates, pending technical-lead review of D4.1/ILO crosswalks
  and exclusions, and the frozen COL D5.5 DIFI 2024 decision. These are
  intentional fail-closed stops, but publication cannot proceed while they
  remain.
- **Fix**: Complete and record the attestations, reviewer workbooks, crosswalk
  approvals, and DIFI decision; rerun collection until the run marker is
  complete with no blocking rows, then regenerate the final preview/revision
  evidence before writing the release lock.
- **Tag**: `[manual]`
- **History**: The current open status continues the NADA/GSBP review P1.1
  and the D4.1 manual-review blockers recorded in the 2026-10-20 and
  2026-10-21 reviews.

### [P1.8] The release diff omits promoted DTA and evidence files

- **File/path**: `R/release_diff.R:38-79`;
  `R/output_manifest.R:7-25, 151-207`
- **Why**: `SPI_data.dta`, the estimation manifest, and revision-evidence
  files are promoted outputs but are not all included in the candidate/archive
  release comparison. A non-ODIN change can therefore reach the final release
  without classification.
- **Fix**: Compare every promoted artifact. Use a format-aware DTA
  comparison, and define explicit allowlists for manifest/evidence fields.
- **Tag**: `[manual]`

### [P1.9] Exception fixtures can mask arbitrary differences

- **File/path**: `tests/testthat/helper-exception-cells.R:12-28, 33-59`;
  `tests/replication/enumerate_exception_cells.R:139-143`
- **Why**: The harness discards the fixture's `baseline` and `new` values,
  silently ignores unknown columns, and does not require exactly one matching
  row. A broadened fixture can hide an unapproved regression.
- **Fix**: Validate fixture schema, uniqueness, key cardinality, known
  columns, and observed baseline/new values before masking.
- **Tag**: `[manual]`

### [P1.10] Attribution acceptance was not fail-closed — fixed

- **File/path**: `docs/revisions/202611/attribute_revisions.R:486-505`
- **Why**: The script previously printed unexplained-cell and pipeline
  mismatch counts but exited successfully.
- **Fix applied**: Unexplained causes now stop the script, and `--current`
  uses a full key join and stops on any mismatch.
- **Tag**: `[safe_auto]`

### [P1.11] Legacy availability removal and tracked target metadata are not reconciled

- **File/path**: deleted `R/availability.R`;
  `_targets_data/meta/meta`; `.cg-docs/plans/2026-10-05-spi-data-collection-pipeline.md`
- **Why**: The worktree removes a legacy compatibility file while tracked
  target metadata still records its functions and collection warnings. The
  historical plan/review trail does not establish that the deletion is an
  approved migration boundary, and the metadata is machine-specific and
  stale.
- **Fix**: Obtain owner approval for the legacy deletion, regenerate target
  metadata from a clean project-relative environment after the final graph is
  agreed, and document the replacement/replay path. Do not hand-edit or
  silently remove the legacy artifact.
- **Tag**: `[manual]`

## P2 — Important

### [P2.1] D4.1 refresh provenance is stored but not enforced

- **File/path**: `R/collect_dim4_1.R:895-969`;
  `config/source_registry.R:286-302`
- **Why**: `d41_manifest` embeds the `catalogue` refresh result, but
  `validate_dim4_1_manifest()` validates only the fixed artifact entries and
  ignores the embedded refresh record. The separate
  `catalogue_refresh.json`, prefetch index, and failure log are not an
  authorized/hash-checked artifact in the registry. A refreshed companion set
  can therefore remain estimable even if the request identity or refresh
  record is altered or removed.
- **Fix**: Validate a refresh-record schema, include its hash and the
  prefetch index/failure-log identities in the D4.1 manifest, and include
  those records in the collection status/release-lock contract. Preserve a
  recorded carried-forward decision for the agricultural-census companion.
- **Tag**: `[manual]`
- **History**: Directly related to D4.1 review P1.4/P2.6; the current code
  adds the record but does not close the enforcement part of the finding.

### [P2.2] Attestation records accept ambiguous rows

- **File/path**: `R/collection_attestation.R:35-52, 88-126`;
  `R/collection_status.R:164-186`
- **Why**: The attestation reader checks only required column names. It does
  not reject duplicate `(source_id, artifact_path)` rows, blank hashes,
  malformed timestamps, or blank attesters in a hand-edited file. The status
  evaluator takes the first matching hash and the first row's `attested_at`,
  so duplicate rows can make the approval ambiguous.
- **Fix**: Validate nonblank SHA-256/attester/time fields and unique
  source/artifact keys; require exactly one row per resolved artifact and
  fail closed on duplicates. Add mutation tests for duplicate and malformed
  attestation records.
- **Tag**: `[manual]`

### [P2.3] User guide still instructs the superseded D4.1/EMPL workflow

- **File/path**: `docs/user-guide.md:559-583`
- **Why**: The guide tells operators to run the legacy microdata pull,
  preprocessing script, and IMF notebook, and says the catalogue-to-EMPL
  link is “not yet in the pipeline.” Current canonical code uses
  `d41_catalogue_collection`, `d41_preprocess`, and
  `collect_empl_vintage()` in the collection graph. Following the guide can
  bypass the collection manifest or overwrite a target-owned output.
- **Fix**: Replace the legacy instructions with the current target commands;
  mark the legacy scripts/notebook reference-only; document the current EMPL
  collector, review/attestation boundary, and recovery procedure. This is a
  recurrence of P2.10 in the 2026-10-05 collection review.
- **Tag**: `[manual]`
- **Status**: Fixed in the current worktree. The guide now points to the
  target-owned collection and EMPL builder, and marks the legacy notebooks as
  reference-only.

### [P2.4] Survey catalogue evidence is dropped from audit output

- **File/path**: `R/dim4.R:291-300, 316-322`
- **Why**: Survey scoring collapses each `(iso3c, indicator_date)` group with
  `nada_dates = first(stats::na.omit(nada_dates))`, whereas the census path
  concatenates unique dates. Multiple catalogue studies can affect the score
  while only the first date is retained in the raw/evidence output. The score
  is currently protected by the grouped count, but the audit trail is
  incomplete.
- **Fix**: Preserve the unique dates/titles (or a row-level evidence table)
  through survey scoring and add a multiple-study regression test. Rebuild
  D4.1 provenance outputs after the change.
- **Tag**: `[manual]`

### [P2.5] Active state is stale relative to generated evidence

- **File/path**: `.cg-docs/active-state/current.json:3, 40-82`
- **Why**: The active state still marks V12 pending and points to a handover
  from 13:06Z, while the E6 summaries were generated at about 14:51–14:56Z
  and the all-row ODIN rehearsal completed at about 15:02Z. V11 and the human
  release decisions remain pending, but V12's evidence status no longer
  reflects the artifacts present in the scoped tree.
- **Fix**: Update only the evidence status and artifact references that are
  actually complete (leave V11 and approval decisions pending), record the
  final-preview/rehearsal paths and hashes, and update `nextCommand`.
- **Tag**: `[advisory]`
- **Status**: Fixed in the current worktree. The active state now references
  the final preview, E6 evidence, and the all-row ODIN rehearsal while
  retaining V11/V12 and approval blockers as pending.

### [P2.6] Release-critical comparison tests are skip-gated

- **File/path**: `tests/testthat/test-stage-compare.R:39-56`;
  `tests/testthat/test-vintage-compare.R:24-45`
- **Why**: Missing promoted outputs cause the comparison tests to skip. The
  focused suite can therefore pass without comparing current outputs against
  frozen fixtures.
- **Fix**: Make missing/stale manifests and required outputs fail in release
  mode; keep skips only behind an explicit development mode.
- **Tag**: `[manual]`

### [P2.7] The replication runner does not return a failure status

- **File/path**: `tests/replication/run_replication.R:42-47`;
  `tests/replication/replicate_vintage.R:335-359`
- **Why**: The runner prints failed expectations and skips but exits
  successfully. Automation can therefore treat a failed replication as
  passed.
- **Fix**: Return nonzero for failures/errors and reject unexpected skips in
  release mode. Preserve an explicit accepted-exception mode for known X1
  failures.
- **Tag**: `[manual]`

### [P2.8] Previous-vintage baselines are not fully hash-bound

- **File/path**: `R/vintage_diff.R:60-69`;
  `R/revision_report.R:40-54, 260-263`;
  `R/release_lock.R:87-119`
- **Why**: Existence checks and a truncated index hash do not ensure that the
  previous-vintage files used for revision evidence are the approved files.
  The baselines are not covered by the release lock.
- **Fix**: Version the baselines, record full SHA-256 and vintage metadata in a
  required manifest, and include those hashes in the release lock.
- **Tag**: `[manual]`

### [P2.9] Official ODIN status does not prove an official file was installed

- **File/path**: `R/setup.R:58-67`; `R/output_manifest.R:117-134`;
  `_targets.R:519-528`
- **Why**: Changing `odin_status` to `"official"` removes the provisional
  marker without requiring an official release identifier or a new approved
  file hash. An unchanged toy file can therefore be labelled official.
- **Fix**: Require an official ODIN release record with source, release date,
  and approved SHA-256; reject an official run when the file hash is still
  provisional.
- **Tag**: `[manual]`

### [P2.10] The canonical worktree is not commit-ready as one changeset

- **File/path**: `git status`; `.gitignore`; `_targets_data/meta/meta`;
  `01_raw_data/`; `02_programs/misc_scripts/`
- **Why**: The current worktree contains a large mixed set of raw inputs,
  generated caches/provenance, target metadata, workflow notes, code, tests,
  and documentation. Bulk staging would create a difficult-to-review
  changeset and could include raw files or machine-specific metadata. The
  deleted legacy availability file and untracked OECD scripts also need owner
  decisions.
- **Fix**: Stage logical commits only after the manual release decisions.
  Curate raw/provenance artifacts from manifests and hashes, regenerate
  target metadata from a clean environment, and obtain owner approval for
  protected legacy-path changes.
- **Tag**: `[manual]`

## P3 — Minor

### [P3.1] D4.1 scorer emits avoidable `unnest()` warnings

- **File/path**: `R/dim4.R:274-284`
- **Why**: The full suite is green but emits two warnings because
  `tidyr::unnest()` is called without an explicit `cols` argument. This is
  legacy-port behavior, not a current score discrepancy, but it adds noise to
  the warning audit around a data-integrity-sensitive scorer.
- **Fix**: Use an explicit `cols = c(data, temp_col)` form and retain the
  focused score/replication checks.
- **Tag**: `[advisory]`

## Explicit no-issue areas

## Autofix status

Three safe fixes were applied during this review:

1. D4.1 cache bodies now verify their recorded SHA-256 and byte count on
   reuse and cached replay, with a tampering/refetch regression test.
2. Revision attribution now fails on unexplained causes or any final-pipeline
   key/value mismatch.
3. The user guide now uses the active collection/EMPL workflow, exact E6
   evidence commands, `test_dir("tests/testthat")`, and current attribution
   causes.

The remaining findings are manual or advisory because they affect release
architecture, statistical methodology, source approvals, exception policy,
or data-integrity gates.

- **Exact 2024 replication**: `/tmp/spi-rep/step-e6-final` reports 12/12
  promoted outputs differentially comparable to the post-E5 reference; the
  replication test table remains 1,303 expectations with the same 13
  accepted X1 failures. The E6 fixture contains 2,349 country-level cells,
  and the aggregate rows are intentionally excluded from this country-level
  exception contract.
- **E6 country matching**: the current IGME ISO-code path and ILO
  crosswalk/exclusion validation stop on unknown mappings; focused scoring
  tests pass, and the generated E6 evidence reports 157 replication cells
  and 251 202611-preview cells with no additional D1.5 series. The remaining
  issue is approval/provenance of mapping additions, not an observed
  unmatched-name result.
- **D4.1 workbook and companion guards**: focused D4.1 tests pass (186
  expectations, 2 known `unnest()` warnings); unknown companion names,
  strict workbook years, prior-vintage coverage, stale/hash-mismatched
  manifests, and normalized-companion drift are guarded.
- **Basic cache/status behavior**: cache checksum, attestation, collection
  status, pipeline-contract, release-lock, release-diff, and aggregate-order
  focused tests pass. The current missing-attestation rows are correctly
  blocking rather than silently downgraded.
- **ODIN release rehearsal**: `rehearsal-final2` reports 12,817 changed
  cells with zero outside the ODIN-dependent outputs, and a non-ODIN payload
  edit is blocked by the lock. This validates the intended normal-path
  release diff; it does not cover the tamper/sidecar gaps above.
- **Protected artifacts**: no remediation in this review recommends deleting,
  replacing, renaming, or moving `.cg-docs/brainstorms/`,
  `.cg-docs/solutions/`, `.cg-docs/archive/`, `compound-gpid.md`,
  `compound-gpid.local.md`, `roadmap.json`, `SCHEMA_VERSION`, or `.github/`.

## Historical cross-reference summary

The `.cg-docs/solutions/` tree contains no solution files, so there are no
prior verified solutions to apply. The most relevant recurring findings are:

1. D4.1 review/companion data loss and refresh atomicity:
   `.cg-docs/reviews/2026-10-20-d41-manual-collection-pipeline-review.md`
   (P0.2–P0.4, P1.4, P1.5, P2.6). Name normalization, coverage, and manifest
   hashes are now materially better; review merge semantics and atomic
   promotion remain open.
2. Collection provenance/status and final-output safety:
   `.cg-docs/reviews/2026-10-05-spi-data-collection-pipeline-review.md`
   (P1.5–P1.8, P2.1–P2.3, P2.10–P2.12). Collection run binding, cache
   checksums, file-target promotion, and release-diff behavior are improved;
   status/lock authentication, sidecar coverage, and the stale guide remain.
3. NADA/GSBP incomplete-run and provenance findings:
   `.cg-docs/reviews/2026-10-21-nada-gsbp-collection-pipeline-review.md`
   (P1.1–P1.4). Hash and cache validation are now exercised, but the current
   collection still has the expected manual blockers.
4. Exact replication and comparison contracts:
   `.cg-docs/reviews/2026-09-21-targets-pipeline-replication-review.md`.
   The current E5/E6 exception fixtures and sandbox evidence close the
   previously missing country-cell enumeration; aggregate rows remain outside
   that contract and therefore need the separate real-CLASS aggregation check
   above.

The binding decisions in `.cg-docs/brainstorms/2026-10-23-spi-202611-source-readiness.md`
require fail-closed collection, hash-bound attestations, ISO3 joins, exact
legacy parity, and an ODIN-only release transition. Findings P1.1–P1.6 are
the current places where those decisions are not fully enforced.

## Validation record

- Full `tests/testthat` run: exit code 0; warnings are present and audited,
  including the two D4.1 `unnest()` warnings and legacy scorer warnings.
- Focused D4.1 collection: 184 expectations, 0 failures, 2 warnings.
- Focused aggregate/release tests: aggregate 7, release-lock 28,
  release-diff 22 expectations; 0 failures.
- Focused collection-status/attestation/pipeline-contract tests: 0 failures.
- Current collection status: 17 blocking `attestation_missing`, 1 warning,
  and no `source_vintage_unverified` rows.

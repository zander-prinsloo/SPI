---
date: 2026-10-21
title: "Integrate D2.4 NADA and D5.2.10 GSBP into the SPI Collection Pipeline"
status: decided
scope: "Standard"
artifact-schema-version: 1
chosen-approach: "Staged collection targets with a shared manual-review helper"
tags: [nada, gsbp, dimension-2.4, dimension-5.2, manual-collection, manual-review, targets, provenance]
---
<!-- Valid status values: decided, in-progress, abandoned -->

# Integrate D2.4 NADA and D5.2.10 GSBP into the SPI Collection Pipeline

## Context

Both indicators are scored by the estimation pipeline (`score_nada()` in
`R/dim2.R`, `score_gsbp()` in `R/dim5.R`), but their vintage files are produced
outside the collection pipeline:

- **D2.4 NADA**: `02_programs/misc_scripts/nada_check.R` reads a hardcoded
  `D2.4.NADA.2023.csv`, checks each `NADA_text` URL, and writes `Nada2024.csv`
  (including to a personal Windows OneDrive path). It only records
  `NADA_working`; the scored `NADA` column is carried forward and edited by
  hand. In 2024, 159 of 160 positive values were carried forward from 2023, one
  changed 0 -> 1, and 20 countries kept `NADA = 1` despite a failed URL check.
  The collection pipeline only checks presence and schema
  (`verify_nada_data()` inside `manual_checkpoints`).
- **D5.2.10 GSBP**: `02_programs/misc_scripts/preprocess-manual-data-4.1-and-5.2.10.R`
  reshapes the hand-curated desk review `01_raw_data/5.2_DISM/raw/D1.12.MSC.csv`
  (`Business Process (GSBPM)`, `DCS data`, `Links`) into
  `D5.2.10.GSBP.2024.csv`, with `date = 2024` hardcoded and a live
  `wb_countries()` call. There is no registry entry, checkpoint, or collection
  target.

The D4.1 brainstorm (2026-10-20) explicitly left D2.4 NADA out of scope; this
brainstorm covers it and GSBP using the same collection architecture.

## Requirements

- Produce reproducible `D2.4.NADA.<end_date>.csv` and
  `D5.2.10.GSBP.<end_date>.csv` from the collection pipeline (no hardcoded
  years or personal paths).
- Value logic per vintage: carry forward the previous vintage, attach the
  automated evidence and checks from the current scripts, then apply a
  per-vintage manual review file (`D2.4.NADA.Manual.Review.<end_date>.xlsx`,
  `D5.2.10.GSBP.Manual.Review.<end_date>.xlsx`).
- NADA URL check runs inside the collection pipeline as a cached target,
  re-run only on demand or when stale.
- NADA URL failure rule: from the 2025 vintage onward only, a URL that still
  fails after retries sets `NADA = 0`; every auto-zero is listed in the
  collection status report. Historical vintages are not re-derived with this
  rule.
- Historical files (2020-2024) are frozen; new code only writes `<end_date>`
  files.
- Regression: rebuilding 2024 with the new functions (replayed evidence from
  the saved `Nada2024.csv` and the saved country metadata) must reproduce the
  indicator-relevant columns (`iso3c`, `NADA`, `NADA_text`; `iso3c`, `GSBP`) of
  the committed 2024 files, and final SPI scores must be identical.
- Blocking failures: review file missing for `<end_date>`; review file with
  unknown `iso3c`, invalid values, or duplicates; a country present in the
  metadata but absent from the previous vintage without a review entry.
- Warning: GSBP desk review (`D1.12.MSC.csv`) unchanged (same hash) since the
  previous vintage.
- The original Rmd files and legacy `misc_scripts` must not be changed under
  any circumstances; they remain replication references.
- Scoring rules for NADA and GSBP are unchanged.

## Inputs and Outputs

```text
NADA
  D2.4.NADA.<end_date-1>.csv            -> carry-forward base
  NADA_text URLs -> cached URL check    -> D2.4.NADA.url_evidence.<end_date>.csv
  auto-zero rule (>= 2025, after retry) -> proposed values
  D2.4.NADA.Manual.Review.<end_date>.xlsx -> validated overrides
  -> D2.4.NADA.<end_date>.csv (iso3c, NADA, NADA_text, NADA_working, ...)

GSBP
  D5.2.10.GSBP.<end_date-1>.csv         -> carry-forward base
  5.2_DISM/raw/D1.12.MSC.csv            -> desk-review evidence (hash tracked)
  D5.2.10.GSBP.Manual.Review.<end_date>.xlsx -> validated overrides
  -> D5.2.10.GSBP.<end_date>.csv (iso3c, date, GSBP, ...)

Both -> source registry entries, collection status report, manifest
```

## Approaches Considered

### Approach 1: Parameterised copies of the legacy scripts

Copy the `nada_check.R` and GSBP preprocessing logic into `end_date`-aware
functions, run one target per indicator, apply a review file at the end.

Pros: smallest change; logic stays recognisable.
Cons: carry-forward, evidence, and review are one opaque step; a review edit
re-runs the URL check; only the final file can be tested.
Effort: small.

### Approach 2: Staged targets with a shared review helper (chosen)

Separate targets per stage (previous vintage, cached evidence, proposed
values, validated review, output) for each indicator, plus one shared helper
for review-file validation and application (schema, unknown `iso3c`,
duplicates, allowed values, new-country block). Registry entries and status
reporting for both indicators.

Pros: each stage is testable and cached; review edits do not re-run the URL
check; the review helper is reusable for later indicators.
Cons: more targets; the 2024 regression needs replayed evidence and saved
metadata.
Effort: medium.

### Approach 3: Generic carry-forward / evidence / review engine

A configuration-driven engine covering NADA, GSBP, and later CNIN, EMPL, and
FINA.

Pros: maximum reuse.
Cons: abstraction designed from two dissimilar cases (URL status vs desk
review; 0/1 vs "yes"); over-engineering risk.
Effort: large.

## Decision

Choose **Approach 2**. It gives reproducible, `end_date`-driven production and
a validated, auditable manual-decision layer, while keeping the expensive URL
check cached and separate from review edits. The review helper is designed to
be reusable, but CNIN, EMPL, and FINA are out of scope for this iteration.

## Devil's Advocate Checks

- **Problem validation**: pre-validated. The scripts hardcode 2023/2024 and a
  personal Windows path, and scored NADA values are not traceable to a rule.
- **Simplicity**: GSBP is a reshape of a hand-curated CSV; most of its value is
  validation and the review layer rather than automation. The staged design is
  justified mainly by NADA.
- **Effort-value**: the URL check (~190 requests, ~15-20 minutes, possibly
  blocked on the World Bank network) is the costly part; caching it as its own
  target contains that cost.
- **Charter alignment**: the original auto-zero rule would have contradicted the
  2024 values (20 countries kept 1 despite failed URLs) and risked false zeros
  from transient failures. Resolved by applying it only from 2025, after
  retries, with every auto-zero reported. This is a prospective change to how
  NADA values are collected and must be documented as such. Byte-for-byte
  reproduction of 2024 files was rejected because the files embed World Bank
  country metadata in two different historical schemas; the regression test
  compares indicator-relevant columns and final SPI scores instead.

## Out of Scope

- CNIN, EMPL, FINA (IMF DSBB scraper indicators); separate brainstorm.
- Changing NADA or GSBP scoring rules.
- Any edit to the original Rmd files or legacy `misc_scripts`.

## Next Steps

1. Add registry entries for D2.4 NADA (update existing `d2_4_nada`) and
   D5.2.10 GSBP, including review-file and evidence artifacts.
2. Write the shared review helper (read, validate, apply) with unit tests.
3. NADA: functions and targets for previous vintage, cached URL evidence (with
   retries and an on-demand/staleness cue), proposed values (auto-zero only
   when `end_date >= 2025`), review application, and output; replace the
   presence-only `verify_nada_data()` check in `manual_checkpoints`.
4. GSBP: functions and targets for previous vintage, desk-review evidence
   (hash tracked, stale warning), review application, and output; read country
   metadata from the saved `world_bank_inputs` snapshot.
5. Regression tests: rebuild 2024 from replayed `Nada2024.csv` and saved
   metadata; compare indicator-relevant columns and final SPI scores.
6. Create the 2025 review workbooks (empty templates with the agreed schema).
7. Update `docs/user-guide.md` (NADA and a new GSBP section) with the run
   order, review-file roles, auto-zero rule, and failure/warning meanings.

## Prior Knowledge Applied

- Collection is registry-driven and separate from estimation; manual sources
  stay visible through provenance and status reports. Source:
  `.cg-docs/brainstorms/2026-10-05-api-data-collection-pipeline.md`.
- Manual inputs become first-class collection artifacts with a validated
  review layer and a manifest; legacy scripts stay untouched. Source:
  `.cg-docs/brainstorms/2026-10-20-d41-manual-collection-integration.md`.

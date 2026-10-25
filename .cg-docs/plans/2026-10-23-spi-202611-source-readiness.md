---
date: 2026-10-23
title: "SPI 202611 source readiness: legacy-faithful fixes for every blocked source"
status: active
scope: "Deep"
brainstorm: ".cg-docs/brainstorms/2026-10-23-spi-202611-source-readiness.md"
execution-report: ".cg-docs/work-reports/2026-10-23-spi-202611-source-readiness.md"
completed-phases: [1, 2, 3, 4, 5, 6]
current-phase: 7
language: "R"
estimated-effort: "large"
deviation-policy: "ask"
artifact-schema-version: 1
phases: 8  # convenience hint -- may be stale; always recount from ## Phase headers
tags: [spi-202611, collection, estimation, revision-policy, pip, jmp, un-sdg, oecd, dimension-3, dimension-4.1, dimension-5.2, odin, release-lock, targets]
---

# Plan: SPI 202611 Source Readiness

> **Current-state notice — 25 October 2026:** This is a dated workflow/evidence
> record. For current operation, use [202611 status](../../docs/update-status-202611.md)
> and the [user guide](../../docs/user-guide.md). The active branch is
> `dev_SPI_2025`; its work is committed and published. The latest collection
> marker is `started`, while the last status report belongs to an older run.
> The retained review snapshot is `replication/spi-rep/preview-p0p1/`
> (1,073 refreshed and 41 frozen-history changes), superseding the earlier
> preview counts below. Old commit IDs map to the rewritten history in
> [the exclusion record](../../docs/revisions/202611/git-history-file-exclusion-2026-10-25.md).
> Historical test counts and completed implementation tasks do not constitute
> a current release gate or source/methodology approval.

## Objective

Make the 202611 SPI update (reference year 2025) fully estimable through the
two `{targets}` pipelines, with every indicator final-quality except the
ODIN-dependent indicators, which use the duplicated 2024 ODIN file until the
official release on 7 December 2026. Fix every collection and estimation
defect found in the 2026-10-23 end-to-end run with ports that are faithful to
the legacy scripts that produced the published data, and make the December
ODIN swap provably change only ODIN-affected outputs.

## Context

- **Brainstorm**: `.cg-docs/brainstorms/2026-10-23-spi-202611-source-readiness.md`
  (Approach 1, decided). All per-item decisions there are binding inputs.
- **Live evidence (2026-10-23)**: in an isolated copy, collection errored in
  `manual_checkpoints`, `sdg_collection`, `pip_collection`,
  `unsdg_collection`, `jmp_collection`, `d41_catalogue_collection` (plus
  dependents) and `collection_status`; estimation errored in
  `estimation_source_registry`, `dim1_5`, `dim2`, `dim3`, `dim4`, `dim5` and
  output promotion. With fixes simulated, estimation produced a complete 2025
  index for 188 countries.
- **Follow-up plan.** This plan absorbs and supersedes the unfinished phases of:
  `2026-10-05-spi-data-collection-pipeline.md` (Phases 5-7),
  `2026-10-20-d41-manual-collection-pipeline.md` (Phases 3-5), and
  `2026-10-21-nada-gsbp-collection-pipeline.md` (Phase 2). Mark those phases
  as superseded when this plan completes (via `/cg-work`, not by editing them
  during planning).
- **Decisions from the brainstorm and contract review**:
  - Revision policy: refresh and revise D1.5, D4.1, D4.2; freeze 2004-2024
    history for D2, D3, D4.3, D5 and add 2025 only. D5.1/D5.5 keep the legacy
    full-series refresh, and any historical change is flagged for approval.
  - CLASS.xlsx economy names and codes are the naming authority; D4.1
    catalogue evidence is joined by ISO3 code for all vintages (new
    replication exception E5).
  - PIP always uses the most recent public release (newest PROD release on the
    default 2021 PPPs), resolved at each collection run and recorded; only the
    release lock holds the approved release between provisional approval and
    the December ODIN swap.
  - CNIN, FINA, GSBP: carry forward 2024 plus evidence-based overrides; the
    technical lead reviews pipeline-generated candidate lists.
  - OECD blending is automated from `oecd_bulk_download.R` (unmodified).
- **Existing replication exceptions** (2024 replication test only, documented
  in `docs/CHANGELOG.md`): E1 `SPI.D5.3.DISK` validation rule; E2 quantile
  jitter columns; E3 databank aggregate rows; E4 corrected `SPI.D1.5.LFP`
  window. E5 is added by Step 16.
- **Legacy reference hashes** (first 16 hex characters of SHA-256 at plan
  time; `oecd_*` files are untracked so git alone cannot prove they are
  untouched): `oecd_bulk_download.R` `e16f4dfa3d808b80`,
  `oecd_stats_pull.Rmd` `f1e6c8e8fa024ace`, `un_stats_cleaning.Rmd`
  `6ee109ab8d30e9c6`, `sdg_indicators_for_SPI.R` `0858fc93c55a0e8c`,
  `imf_dsbb_scrape.ipynb` `da47f231b83dca66`.
- **Key facts**: SDG list has 352 unique Tier-1 series (139 indicator-goal
  pairs); UN SDG DataCSV responses are an 8 MiB NUL-padded buffer; JMP
  "Data Summary" uses `w_*_t/u/r` codes and "[values in square brackets not
  used]"; EMPL 2024 `ISCE` equals `max(2023 ISCE, ILO catalogue ICSE flag)`
  for 190/190 countries; `{targets}` 1.12.0 seeds each target
  deterministically; all needed packages (including `writexl`) are locked.
- **Brain findings applied**: D4.1 review open items P0.4 (coverage and year
  validation), P1.4/P2.6 (staged, provenance-recorded catalogue refresh) and
  P1.5 (recorded companion data-quality policy) are absorbed by Steps 16-17
  (source: `.cg-docs/reviews/2026-10-20-d41-manual-collection-pipeline-review.md`);
  the GSBP design is ported unchanged (source:
  `.cg-docs/plans/2026-10-21-nada-gsbp-collection-pipeline.md`).

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Full internal 202611 release: every non-ODIN indicator final-quality for 2025; ODIN-dependent outputs marked provisional | Brainstorm req. 1 |
| R2 | Revision policy: refresh D1.5, D4.1, D4.2; freeze D2, D3, D4.3, D5 history and add 2025 only | Brainstorm req. 2 |
| R3 | D5.1/D5.5 keep the legacy full-series refresh; historical changes flagged for approval | Brainstorm req. 7 |
| R4 | Legacy Rmds and `02_programs/misc_scripts/` untouched; every port parity-tested against its legacy source | Brainstorm req. 3 |
| R5 | Estimation defects fixed without changing intended values (A1-A6) | Brainstorm A |
| R6 | Collection gate passes only with machine-read release identifiers or hash-bound analyst attestations; freshness from provenance, never file mtime | Brainstorm B1 |
| R7 | Collection wiring defects fixed (B2-B4) | Brainstorm B |
| R8 | PIP: newest public release resolved each collection run, recorded, part of the cache key; correct uniqueness key | Brainstorm C; contract review |
| R9 | UN SDG series (BRTH90N, DETH75N, FPOS, NSDSFND) via a DataCSV port of `sdg_indicators_for_SPI.R`, with a truncation guard | Brainstorm C |
| R10 | JMP inputs parsed from the country workbook "Data Summary" sheet into the legacy long format, calibrated before adoption | Brainstorm C |
| R11 | `OECD_data_scored.csv` produced by collection, ported from `oecd_bulk_download.R` | Brainstorm D; Q3 |
| R12 | 2025 D3 computed by a port of the legacy `un_aki_fun` 5-year scorer and written to `3_DP/2025/` | Brainstorm D |
| R13 | EMPL 2025 automated as `max(ISCE_2024, ILO catalogue ICSE flag)` | Brainstorm E |
| R14 | CNIN, FINA, GSBP 2025: carry forward plus per-vintage review workbooks; GSBP per the 10-21 design | Brainstorm E; Q4 |
| R15 | Review-candidate list covering CNIN, FINA, GSBP, EMPL changes and D4.1 economist review | Brainstorm E/F; Q4 |
| R16 | D4.1 companions normalized to CLASS.xlsx names plus ISO3, recorded exclusions, ISO3 joins; E5 enumerated | Brainstorm F; contract review |
| R17 | D4.1 catalogue refresh staged, validated and atomically promoted with provenance; workbook coverage and strict year validation | Brainstorm F; review P0.4, P1.4, P1.5, P2.6 |
| R18 | ODIN tracked as file targets; ODIN-dependent scoring split out; `odin_status` marker | Brainstorm G1-G2 |
| R19 | Vintage-diff policy report with an approvals file | Brainstorm G5 |
| R20 | Release lock and provisional-to-final diff; ODIN-swap rehearsal | Brainstorm G3-G4 |
| R21 | Documentation updated (user guide, ODIN delayed-update guide, CHANGELOG, README) | Brainstorm next steps |
| R22 | Unfinished phases of the three older plans absorbed and recorded as superseded | Step 0.5 decision |

## Phase 1: Estimation fixes

### 1. Estimation wiring and source readers

- **Requirements**: R5
- **Files**: `_targets.R`, `R/dim1_5.R`, `tests/testthat/test-pipeline-contract.R`, `tests/testthat/test-scoring.R`
- **Details**:
  - `estimation_source_registry` command uses `estimation_source_registry_file`
    (the declared file target) instead of the undefined `source_registry_file`.
  - `read_wdi_metadata()`: cast `Latest.agricultural.census` to character
    (`dplyr::any_of`) before rows are bound.
  - `score_debt_reporting()`: map `"Estimated"` to 0.33 like `"Estimate"`;
    stop on any non-missing label outside {Actual, Preliminary, Estimate,
    Estimated}.
  - `read_ilo_lfp()`: `date = as.numeric(time)` for both files; stop when a
    non-missing `time` fails to convert.
  - Correct the `_targets.R` comment that says `rnorm()` is unseeded inside
    target commands (`{targets}` seeds each target).
- **Test Scenarios**: registry target resolves; mixed-type WDI files bind;
  `"Estimated"` scores 0.33; unseen label stops; text `time` converts; invalid
  `time` stops.
- **Tests**: `testthat::test_file("tests/testthat/test-scoring.R")`,
  `testthat::test_file("tests/testthat/test-pipeline-contract.R")`
- **Acceptance criteria**: `dim1_5`, `dim2`, `dim5` build for `end_date = 2025`
  in a test store; full suite `FAIL 0`; 2024 replication unchanged.

### 2. Collapse D4.1 review vintages per country

- **Requirements**: R5, R2
- **Files**: `R/dim4.R`, `tests/testthat/test-dim4-collection.R`
- **Details**: `.read_manual_review()` reads the current and historical
  `D4.1.Manual.Review.<YEAR>.xlsx` files as character and collapses them to
  one row per `iso3c`: per indicator column, the union of four-digit years plus
  the "Register based census" token (same semantics as
  `dim4_1_merge_review_values()`); `Evidence` concatenated with vintage labels.
  No value is ever dropped. Duplicate `iso3c` within one file still stops.
- **Test Scenarios**: 2024 only (identical to today); 2024 plus empty 2025
  (identical); a new 2025 year for a country with a 2024 override (union);
  register-based token kept; the sandbox failure "can't recycle input of size
  2" reproduced first as a failing test.
- **Tests**: `testthat::test_file("tests/testthat/test-dim4-collection.R")`
- **Acceptance criteria**: all eight census/survey functions run with both
  review files present; 2024 replication unchanged.

### 3. Restore the frozen per-year D3 reader

- **Requirements**: R2, R5, R12
- **Files**: `R/dim3.R`, `_targets.R`, `tests/testthat/test-dim3.R` (new)
- **Details**: `combine_dim3()` maps `un_sdg_data_read()` over `params$span`,
  reading `01_raw_data/3_DP/<year>/SPI_D3_UNSD_data_5yr.csv` and keeping only
  `date == year` (legacy behaviour: renames to `SPI.D3.1.POV` etc., drops
  D3.14). Add a `d3_year_files` file target (one path per year) that `dim3`
  depends on. Missing year file stops. `read_sdg_collection_scores()` leaves
  the estimation path.
- **Test Scenarios**: frozen years equal published values; only same-year rows
  used; missing year stops; renames and D3.14 drop.
- **Tests**: `testthat::test_file("tests/testthat/test-dim3.R")`
- **Acceptance criteria**: with `end_date = 2024`, D3 columns equal the 2024
  fixture exactly.

### 4. Output writers as file targets

- **Requirements**: R5, R18, R20
- **Files**: `_targets.R`, `R/output_manifest.R`, `R/append.R`, `R/index.R`, `R/quantiles.R`, `R/treemap.R`, `R/databank.R`, `R/spl_admin.R`, `tests/testthat/test-output-manifest.R`, `tests/testthat/test-pipeline-contract.R`
- **Details**: `output_prepare` creates `03_output_data/.candidate/` if absent
  and never wipes it. Split computation from writing where needed (for example
  `spi_data` returns data, `spi_data_files` writes and returns paths with
  `format = "file"`); every writer target returns its paths as file targets.
  `quantiles` depends on the index file target it reads. `output_manifest`
  depends on all writer targets, validates the expected set, writes
  `_estimation_manifest.json`, and promotes only the expected files.
- **Test Scenarios**: fresh build promotes the full set; invalidating one writer
  (or deleting one candidate file) rebuilds only that writer and still
  promotes; unexpected files in `.candidate/` are not promoted.
- **Tests**: `testthat::test_file("tests/testthat/test-output-manifest.R")`
- **Acceptance criteria**: two consecutive runs with one invalidated output
  target both complete and promote.

## Phase 2: Collection wiring and gate

### 5. Collection wiring fixes

- **Requirements**: R7, R22
- **Files**: `_targets_data.R`, `config/source_registry.R`, `R/collection_status.R`, `R/collection_checkpoints.R`, `tests/testthat/test-source-registry.R`, `tests/testthat/test-pipeline-contract.R`
- **Details**: ILO registry paths reference the configured filenames through
  `<ILO_MODELLED_FILE>`/`<ILO_SURVEY_FILE>` placeholders resolved from params,
  both under `1.5_DUIO/`. `d41_catalogue_collection` builds a local copy of the
  parameters instead of modifying `collection_params`. `manual_checkpoints`
  depends on `d41_preprocess`; the duplicate microdata presence check is
  removed from `run_collection_checkpoints()` because the D4.1 manifest
  validates those files.
- **Test Scenarios**: placeholders resolve to the configured files; target
  graph contains the new dependencies; catalogue target no longer errors.
- **Tests**: the two test files above
- **Acceptance criteria**: `targets::tar_manifest(script = "_targets_data.R")`
  shows the dependencies; `d1_5_ilo` resolves both files.

### 6. Release attestation and provenance-based freshness

- **Requirements**: R6, R7
- **Files**: `R/collection_status.R`, `R/collection_attestation.R` (new), `config/source_registry.R`, `_targets_data.R`, `tests/testthat/test-collection-status.R`, `tests/testthat/test-collection-attestation.R` (new)
- **Details**:
  - Replace `latest_release` with two rules. `release_identifier`: a per-source
    resolver reads the observed release from provenance or configuration (PIP
    release ID, JMP retrieval and workbook stamp, OECD dataflow version and
    retrieval, UN SDG retrieval). `manual_attestation`: requires a matching row
    in `01_raw_data/_collection/source_attestations_<end_date>.csv`
    (`source_id, artifact_path, sha256, release_label, attested_by, attested_at, notes`).
  - Helper `attest_collection_sources(source_ids, attested_by, release_label, notes)`
    records current hashes after the analyst confirms the release.
  - Status: attested and hash-matched is `informational`; missing attestation
    or hash mismatch is `blocking` with reasons `attestation_missing` or
    `attestation_hash_mismatch`.
  - Freshness uses provenance `retrieved_at` (cached sources) or attestation
    date (manual files), never file mtime.
  - Reclassify the SDDS archive, SDG indicator list, D4.1 workbooks, IGME, ILO
    and both IMF workbooks as `manual_attestation`; PIP, JMP, OECD and UN SDG
    sources as `release_identifier`. Include the attestation file hash in
    `collection_parameters_hash()`.
- **Test Scenarios**: unattested file blocks; attested passes; edit after
  attestation blocks; touching a file (mtime only) changes nothing; missing
  provenance blocks; PIP release recorded passes.
- **Tests**: the two test files above
- **Acceptance criteria**: on the current repo, status shows no
  `source_vintage_unverified` rows; only attestation-pending rows remain for
  the technical lead.

## Phase 3: Source collectors

### 7. PIP: most recent public release

- **Requirements**: R8, R2
- **Files**: `R/collect_pip.R`, `_targets_data.R`, `config/params.R` (`pip_ppp_version <- 2021`), `tests/testthat/test-api-collectors.R`
- **Details**: `resolve_pip_release(versions_fn = pipr::get_versions, ppp_version = 2021)`
  returns the newest `PROD` release for that PPP version (today
  `20260922_2021_01_02_PROD`). `collect_pip_comparability()` calls
  `pipr::get_stats(version = <resolved>)`, puts the release ID in the cache
  request (a new release forces a refresh) and in provenance, and validates
  uniqueness on `(country_code, year, survey_acronym, reporting_level, welfare_type)`.
  A release lock (Step 24) overrides resolution with the approved release ID.
  The estimator is unchanged.
- **Test Scenarios**: newest PROD chosen from mixed versions and PPPs;
  duplicate full key stops; new release triggers a fetch; lock override used.
- **Tests**: `testthat::test_file("tests/testthat/test-api-collectors.R")`
- **Acceptance criteria**: a live run records the release ID and writes
  `PIP_comparability_latest.csv`; `score_poverty_comparability()` runs.

### 8. UN SDG series via DataCSV

- **Requirements**: R9, R2, R3, R4
- **Files**: `R/pull_unsdg.R` (rewrite), `R/collect_sdg.R` (shared request hardening), `config/source_registry.R` (add `SG_REG_DETH75N`), `_targets_data.R`, `tests/testthat/test-api-collectors.R`, `tests/testthat/test-unsdg-parity.R` (new), test fixtures
- **Details**:
  - For `SG_REG_BRTH90N`, `SG_REG_DETH75N`, `SG_STT_FPOS`, `SG_STT_NSDSFND`:
    DataCSV request (2004 to `end_date`) through the raw cache, then transform
    exactly as `sdg_indicators_for_SPI.R`: `date = TimePeriod`, `Nature`,
    `geoAreaCode` as character, join `iso_codes.csv` read as character, join
    the saved country snapshot, keep rows with `iso3c`. Write the four existing
    paths.
  - Shared guard in `sdg_api_csv_request()`: strip trailing NUL padding before
    parsing; stop when the body fills a power-of-two buffer without padding or
    the last line is incomplete (possible truncation).
  - Parity test: run the unmodified `sdg_indicators_for_SPI.R` in an isolated
    environment with `httr::POST` mocked (`testthat::local_mocked_bindings(.package = "httr")`)
    and `here()`/`wb_countries()` shadowed to a temp project and fixture
    metadata; compare its outputs with the port on `iso3c, date, Value, Nature`.
- **Test Scenarios**: parity; padding stripped; truncation detected; death
  series written; unmapped geography codes warned as in legacy.
- **Tests**: `testthat::test_file("tests/testthat/test-unsdg-parity.R")`
- **Acceptance criteria**: parity passes; a live run refreshes all four files;
  `score_crvs()`, `score_legislation()`, `score_difi()` run.

### 9. JMP inputs from the country workbook (time-boxed)

- **Requirements**: R10, R2
- **Files**: `R/pull_jmp.R`, `tests/testthat/test-jmp-collection.R` (new; synthetic workbooks written with `writexl`)
- **Details**:
  - `parse_jmp_data_summary(path, iso3c)`: read the "Data Summary" sheet,
    locate the machine-code header row (`source`, `type`, `year`, `w_*`) by
    content; keep water variables; reshape long; `geo` from suffix (`_t`
    National, `_u` Urban, `_r` Rural); `data_value` numeric with brackets
    stripped; `data_quality` 1 for unbracketed, 0 for bracketed, NA when
    missing; `data_available` = value present. Missing sheet, header row or
    suffixes stops.
  - Calibration (time box: 2 days): compare candidate collapse rules (for
    example `w_imp` only, or any water variable used) with the May 2025
    `Safely_Managed_Water_data.csv` on overlapping `(iso3c, source, geo)`;
    report flag agreement and resulting 2024 `SPI.D1.5.SAFE.MAN.WATER`
    agreement in `01_raw_data/1.5_DUIO/collection/jmp_calibration_<end_date>.md`;
    adopt the best rule only at 95% flag agreement or above.
  - `pull_jmp_water()` uses the parser on cached workbooks and writes
    `Safely_Managed_Water_data.csv` in the legacy schema.
- **Test Scenarios**: brackets mapped; suffixes mapped; header found when
  shifted; layout drift stops; collapse rule deterministic.
- **Tests**: `testthat::test_file("tests/testthat/test-jmp-collection.R")`
- **Acceptance criteria**: calibration at or above 95%; live run covers all
  countries; `score_safely_managed_water()` runs.

## Phase 4: Pillar 3

### 10. OECD SDG collection target

- **Requirements**: R11, R4
- **Files**: `R/collect_oecd.R` (new), `_targets_data.R`, `config/source_registry.R` (`d3_oecd_sdg`), `tests/testthat/test-oecd-collection.R` (new), raw fixture sample
- **Details**: fetch the bulk CSV from the URL in `oecd_bulk_download.R` through
  the raw cache (long timeout, retries); port its transformation exactly
  (`transmute`, `separate_rows(code, sep = "/")`, trim, group by
  `(iso3c, date, goal, code)`, mean value, quality above 0 becomes 1, first
  source); write `01_raw_data/oecd_data/oecd_sdg_data.csv` (raw) and
  `OECD_data_scored.csv`. Parity test: `sys.source()` the unmodified script in
  an environment that shadows `download.file()` (copies the fixture) and
  `here()` (temp root), then compare outputs.
- **Test Scenarios**: parity; multi-code `/` rows split; empty response stops.
- **Tests**: `testthat::test_file("tests/testthat/test-oecd-collection.R")`
- **Acceptance criteria**: parity passes; a live run writes the scored file.

### 11. Legacy D3 scorer and the 2025 file

- **Requirements**: R12, R2, R4
- **Files**: `R/collect_sdg.R`, `R/availability.R`, `_targets_data.R` (`sdg_collection` depends on the OECD target), `config/source_registry.R` (D3 path becomes `3_DP/<END_DATE>/SPI_D3_UNSD_data_5yr.csv`), `tests/testthat/test-sdg-collection.R`, fixtures
- **Details**:
  - Collect only the 352 Tier-1 series (deduplicated requests).
  - Per-series country-year quality as legacy `un_pull` (Nature rules, the
    year-availability rule, mean across disaggregations).
  - Complete the grid and fill missing with 0 as `un_sdg_filled_df`, using all
    `(goal, target, code)` rows of each series (many-to-many, which resolves
    the 16 multi-goal series).
  - Join OECD on `(iso3c, date, goal, code)` and take the maximum quality.
  - For each year 2004 to `end_date`, window `(i - 4, i)`: maximum per
    `(iso3c, code, goal)`, missing to 0, mean by goal, `round(3)`, country
    metadata join, regions only.
  - Write the full table to `3_DP/<end_date>/SPI_D3_UNSD_data_5yr.csv` in the
    legacy layout (`iso3c, date, country, region, income, SPI.D3.1` to
    `SPI.D3.17`). Never write earlier year folders.
  - Parity test: `knitr::purl()` the unmodified `un_stats_cleaning.Rmd` into a
    temp file, parse and evaluate only the `un_pull` and `un_aki_fun`
    definitions against fixture inputs, compare with the port (1e-9).
  - Sanity diff (report only): recomputed 2024 rows versus the published 2024
    file.
- **Test Scenarios**: parity; multi-goal series counted per goal; Tier-1 filter;
  OECD max blend; missing-year fill.
- **Tests**: `testthat::test_file("tests/testthat/test-sdg-collection.R")`
- **Acceptance criteria**: parity passes; a live run writes the 2025 file;
  `dim3` 2025 coverage comparable to 2024.

## Phase 5: D5.2 annual files

### 12. EMPL 2025 automation

- **Requirements**: R13, R4
- **Files**: `R/collect_d5_2.R` (new), `_targets_data.R`, `config/source_registry.R`, `tests/testthat/test-d5-2-collection.R` (new)
- **Details**: read `4.1_SOCS/ilo_sources_catalog.csv`; keep
  `Source type == "Labour force survey"`; map `Country` to ISO3 via
  `metadata/ILO_reference_area.csv` (`ref_area.label` to `ref_area`); flag
  `ICSE` in `International classifications`; maximum per ISO3;
  `ISCE = max(previous ISCE, flag)`. Write `5.2_DISM/D5.2.6.EMPL.<end_date>.csv`
  with `iso3c, ISCE, ISCE_previous, ISCE_catalogue` and no column named `EMPL`
  (that name switches `score_empl()` to the old schema). Unmatched survey
  countries stop or are recorded exclusions; changed flags go to the candidate
  list.
- **Test Scenarios**: 2024 regression from `D5.2.6.EMPL.2023.csv` and
  `ilo_sources_catalog_2024.csv` equals published `ISCE` (190/190) and
  `score_empl()` 2024; no-downgrade rule; unmatched country stops.
- **Tests**: `testthat::test_file("tests/testthat/test-d5-2-collection.R")`
- **Acceptance criteria**: regression passes; 2025 file written.

### 13. CNIN and FINA carry-forward with review workbooks

- **Requirements**: R14, R15, R2
- **Files**: `R/collect_d5_2.R`, `_targets_data.R`, `config/source_registry.R`, generated templates `5.2_DISM/D5.2.3.CNIN.Manual.Review.2025.xlsx` and `5.2_DISM/D5.2.8.FINA.Manual.Review.2025.xlsx`, `tests/testthat/test-d5-2-collection.R`
- **Details**:
  - CNIN: read `D5.2.3.CNIN.<end_date - 1>.csv`, add column `<end_date>`
    equal to the previous year's column, apply the per-vintage review through
    the shared helper (allowed values taken from observed vocabulary), write
    `D5.2.3.CNIN.<end_date>.csv` with `Code, Country, 2020` to `<end_date>`.
    The existing `D5.2.3.CNIN.Manual.Review.xlsx` keeps applying to historical
    years in estimation.
  - FINA: read `D5.2.8.FINA.<end_date - 1>.csv`, keep `Code, Country, FINA`,
    apply the per-vintage review (allowed {2014, ESA 2010, 2001, 1986, other,
    blank}), write `D5.2.8.FINA.<end_date>.csv`.
  - Candidates: CNIN values other than Rev.4 or NACE Rev.2 plus countries with
    historical overrides; FINA values other than 2014 or ESA 2010 whose IMF
    "5. Comp of Gvt Fin Stats" text changed between `imf_file_2024` and
    `imf_file` or mentions "GFSM 2014", plus blank, "other", "Not Found".
- **Test Scenarios**: empty review gives 2025 equal to 2024; override applied;
  invalid value stops; unknown ISO3 stops; candidate list deterministic.
- **Tests**: `testthat::test_file("tests/testthat/test-d5-2-collection.R")`
- **Acceptance criteria**: `score_cnin()` and `score_fina()` run for 2025.

### 14. GSBP vintage builder

- **Requirements**: R14, R22
- **Files**: `R/collect_gsbp.R` (new), `_targets_data.R`, `config/source_registry.R`, template `5.2_DISM/D5.2.10.GSBP.Manual.Review.2025.xlsx`, `tests/testthat/test-gsbp-collection.R` (new), `tests/testthat/fixtures/gsbp/D1.12.MSC.2024.csv`
- **Details**: implement Steps 5 and 6 of
  `.cg-docs/plans/2026-10-21-nada-gsbp-collection-pipeline.md` unchanged:
  union rule (previous "Yes" or desk review "Yes"), review "No" stored as NA,
  2024 column order, stale desk-review hash warning against a 2024 baseline
  manifest, historical-write guard, registry rows, targets. Countries without
  GSBPM evidence go to the candidate list.
- **Test Scenarios**: as in that plan (union, "No" override, invalid desk value,
  stale warning, missing review, historical write refused, 2024 regression).
- **Tests**: `testthat::test_file("tests/testthat/test-gsbp-collection.R")`
- **Acceptance criteria**: 2024 regression equal; 2025 file written.

### 15. Review-candidate artifact

- **Requirements**: R15
- **Files**: `R/review_candidates.R` (new), `R/collection_report.R`, `_targets_data.R`, `tests/testthat/test-review-candidates.R` (new)
- **Details**: assemble `01_raw_data/_collection/review_candidates_<end_date>.csv`
  (`source_id, iso3c, country, current_value, reason, evidence_hint`) from
  Steps 12, 13, 14 and 18; add counts and reasons to `collection_status.md`.
  Candidates are informational and never block.
- **Test Scenarios**: deterministic ordering; empty inputs produce an empty
  file with headers.
- **Tests**: `testthat::test_file("tests/testthat/test-review-candidates.R")`
- **Acceptance criteria**: file produced and summarized in the report.

## Phase 6: D4.1

### 16. CLASS-name normalization, ISO3 joins, recorded exclusions

- **Requirements**: R16, R17, R2, R4
- **Files**: `R/collect_dim4_1.R`, `R/dim4.R`, `config/d41_country_crosswalk.csv` (new), `config/d41_companion_exclusions.csv` (new), `tests/testthat/test-dim4-collection.R`, `tests/testthat/test-stage-compare.R`, `docs/CHANGELOG.md`
- **Details**:
  - Build name-to-ISO3 from `misc/CLASS.xlsx` ("List of economies":
    `Economy`, `Code`) plus a crosswalk for catalogue variants (Republic of
    Cabo Verde to CPV, United Republic of Tanzania to TZA, Yemen to YEM,
    Korea, Dem. Rep. to PRK).
  - Normalized companions carry `iso3c` and the CLASS `country`; raw catalogue
    files are preserved. Estimation joins companions by `iso3c`; remove the two
    name-alias tables (`.country_name_aliases`, `dim4_1_country_aliases`).
  - Recorded exclusions in the D4.1 manifest: Anguilla, Cook Islands,
    Montserrat, Niue, the two multi-country studies, blank-country rows. Any
    other unmatched name stops.
  - Companion quality policy (review P1.5): duplicate country-date groups are
    collapsed by the existing per-`(iso3c, indicator_date)` summary and
    counted in the manifest.
  - Workbook coverage and strict year parsing (review P0.4): expected country
    set from the previous derived CSV; values must be four-digit years or
    "Register based census".
  - E5: compute the 2024 replication differences caused by the name fix,
    enumerate every country-year-column in `docs/CHANGELOG.md` (E5) and in the
    stage-compare exception list; nothing else may differ.
- **Test Scenarios**: crosswalk names match; CLASS names match directly
  (Czech Republic, Nauru); excluded rows recorded; unknown name stops; ISO3
  join independent of World Bank API names; coverage loss stops; invalid year
  text stops.
- **Tests**: `testthat::test_file("tests/testthat/test-dim4-collection.R")`,
  `testthat::test_file("tests/testthat/test-stage-compare.R")`
- **Acceptance criteria**: companion validation passes on current files; 2024
  replication passes with E1-E5 only.

### 17. Staged D4.1 catalogue refresh

- **Requirements**: R17, R1
- **Files**: `R/collect_dim4_1.R`, `_targets_data.R`, `tests/testthat/test-dim4-collection.R`
- **Details**: wrap the existing opt-in adapter so it writes to a staging
  directory; validate all eight companions there with the Step 16 rules;
  promote the set atomically; record request identity, timing, row counts and
  hashes in the D4.1 manifest; add a run-time budget. Live run by the technical
  lead on the World Bank network (`run_downloads <- TRUE`, then back to FALSE).
- **Test Scenarios**: injected failing adapter leaves the previous set intact;
  invalid staged companion blocks promotion; success promotes all eight.
- **Tests**: `testthat::test_file("tests/testthat/test-dim4-collection.R")`
- **Acceptance criteria**: refreshed companions promoted and recorded.

### 18. D4.1 economist-review candidates

- **Requirements**: R15
- **Files**: `R/review_candidates.R`, `tests/testthat/test-review-candidates.R`
- **Details**: list countries whose latest census or survey (derived CSV,
  companions, reviews) falls outside the 2025 scoring windows, and countries
  where the catalogue and the workbook disagree.
- **Test Scenarios**: window boundaries per indicator type; disagreement rule.
- **Tests**: `testthat::test_file("tests/testthat/test-review-candidates.R")`
- **Acceptance criteria**: D4.1 candidates appear in the shared artifact.

## Phase 7: ODIN tracking, policy report, provisional release

### 19. ODIN as tracked inputs

- **Requirements**: R18, R2
- **Files**: `_targets.R`, `R/dim2.R`, `R/dim4.R`, `R/append.R`, `R/checkpoints.R`, `tests/testthat/test-pipeline-contract.R`
- **Details**: `odin_files` file target (`ODIN_2015.csv` to `ODIN_<end_date>.csv`);
  `odin_data` target reads them and validates every column used by both
  readers; split `dim2` into `dim2_core` (SDDS, NADA) and `dim2_odin`, and
  `dim4` into `dim4_core` (D4.1, D4.2) and `dim4_geo`; `spi_data` combines all
  parts; outputs unchanged. Strengthen `verify_odin_data()` to the full column
  set.
- **Test Scenarios**: changing `ODIN_<end_date>.csv` marks only `odin_files`,
  `odin_data`, `dim2_odin`, `dim4_geo` and downstream targets outdated (temp
  store, `tar_outdated()`); replication unchanged.
- **Tests**: `testthat::test_file("tests/testthat/test-pipeline-contract.R")`
- **Acceptance criteria**: V10.

### 20. ODIN provisional marker

- **Requirements**: R18, R1
- **Files**: `config/params.R` (`odin_status <- "provisional"`), `R/output_manifest.R`, `_targets.R`, `tests/testthat/test-output-manifest.R`
- **Details**: `_estimation_manifest.json` records `odin_status`, ODIN file
  hashes and the list of ODIN-dependent output columns; when provisional, write
  `03_output_data/PROVISIONAL_ODIN.md`; when official, remove it.
- **Test Scenarios**: provisional writes the marker; official removes it.
- **Tests**: `testthat::test_file("tests/testthat/test-output-manifest.R")`
- **Acceptance criteria**: manifest and marker present after estimation.

### 21. Vintage-diff policy report

- **Requirements**: R19, R3, R2
- **Files**: `R/vintage_diff.R` (new), `_targets.R`, template `01_raw_data/_collection/vintage_diff_approvals_<end_date>.csv`, `tests/testthat/test-vintage-diff.R` (new)
- **Details**: compare candidate `SPI_data.csv` for 2004 to `end_date - 1` with
  `previous_vintages/SPI_data_<end_date - 1>.csv` per indicator and classify
  by the revision policy. Changes in frozen dimensions (D2, D3, D4.3, D5) block
  promotion unless listed in the approvals file
  (`indicator, iso3c, date, reason, approved_by`); refresh-dimension changes
  are reported only. Write `vintage_diff_<end_date>.csv` and `.md` with the
  outputs.
- **Test Scenarios**: unapproved frozen change blocks; approved change passes;
  refresh-dimension change reported only.
- **Tests**: `testthat::test_file("tests/testthat/test-vintage-diff.R")`
- **Acceptance criteria**: report produced on the live run.

### 22. Documentation for the 202611 workflow

- **Requirements**: R21, R22
- **Files**: `docs/user-guide.md`, `docs/odin-delayed-update.md`, `docs/CHANGELOG.md`, `README.md`
- **Details**: run order; attestation command; review workbooks and candidate
  list; PIP latest-release rule and lock; JMP parser and calibration; OECD
  target; UN SDG series; frozen D3 per-year policy; revision-policy table and
  approvals; E5; ODIN provisional marker; note that this plan supersedes the
  unfinished phases of the three older plans.
- **Test Scenarios**: n/a (documentation).
- **Tests**: path check that every file, target and parameter named exists.
- **Acceptance criteria**: path check passes.

### 23. Live provisional run

- **Requirements**: R1, R6, R11, R12
- **Files**: generated artifacts only
- **Details**:
  1. Full test suite.
  2. Collection: `targets::tar_make(script = "_targets_data.R", store = "_targets_data")`
     (about 352 SDG, 217 JMP, 4 UN series, 1 OECD bulk and 1 PIP request).
  3. Technical lead reviews `review_candidates_2025.csv`, fills review
     workbooks, signs attestations.
  4. Rerun collection until 0 blocking rows and a complete run marker.
  5. Estimation: `targets::tar_make()`.
  6. Review the vintage-diff report; approve D5.1/D5.5 historical changes if any.
  7. Confirm promoted outputs carry the provisional marker; circulate internally.
- **Test Scenarios**: live end-to-end.
- **Tests**: `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'`
- **Acceptance criteria**: V11 and V12.

## Phase 8: December readiness

### 24. Release lock

- **Requirements**: R20, R8
- **Files**: `R/release_lock.R` (new), `_targets_data.R`, `_targets.R`, `tests/testthat/test-release-lock.R` (new)
- **Details**: `write_release_lock(end_date, approved_by)` records hashes of
  every non-ODIN collection artifact (registry-resolved), cache provenance
  (including the PIP release ID) and the approved outputs, and archives the
  approved outputs to `03_output_data/releases/202611-provisional/`. When the
  lock exists, collection uses locked releases and the gate verifies every
  non-ODIN artifact hash; any mismatch stops.
- **Test Scenarios**: tampered non-ODIN artifact blocks; unchanged repo passes;
  locked PIP release used instead of a newer one.
- **Tests**: `testthat::test_file("tests/testthat/test-release-lock.R")`
- **Acceptance criteria**: lock written at approval and verified on rerun.

### 25. Provisional-to-final diff and ODIN-swap rehearsal

- **Requirements**: R20, R1
- **Files**: `R/release_diff.R` (new), `_targets.R`, `tests/testthat/test-release-diff.R` (new), `docs/odin-delayed-update.md`
- **Details**: compare the archived provisional outputs with the new outputs.
  Allowed changes: `SPI.D2.2.*`, `SPI.D4.3.*`, their dimension and pillar 2
  and 4 indices, the overall index, ranks, aggregates, quantiles and databank
  rows derived from them; any other change fails. Rehearse in an isolated copy:
  perturb `ODIN_2025.csv`, set `odin_status <- "official"`, rerun, verify lock
  and diff. Document the December procedure.
- **Test Scenarios**: only allowed columns changed passes; any other change
  fails; marker removed when official.
- **Tests**: `testthat::test_file("tests/testthat/test-release-diff.R")`
- **Acceptance criteria**: V13.

## Testing Strategy

- Write the failing test first for each step; use temp directories and
  injected fetchers or mocked bindings; never call the network in tests.
- Parity tests run unmodified legacy code (`sdg_indicators_for_SPI.R`,
  `oecd_bulk_download.R`, `un_stats_cleaning.Rmd` function definitions) in
  isolated environments with mocked network and paths.
- Run single test files during development and the full suite
  (`Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'`) at each
  phase end, including the 2024 replication suite.
- Live network runs only in Steps 9, 10-11, 17 and 23.

## Documentation Checklist

- [ ] `docs/user-guide.md`: 202611 run order, attestation, review workbooks and candidate list
- [ ] `docs/user-guide.md`: PIP latest-release rule, JMP parser, OECD target, UN SDG series, frozen D3
- [ ] `docs/user-guide.md`: revision-policy table and vintage-diff approvals
- [ ] `docs/odin-delayed-update.md`: provisional marker, release lock, diff, December procedure
- [ ] `docs/CHANGELOG.md`: E5, `"Estimated"` label mapping, corrected seeding note for E2
- [ ] `README.md`: pointer to the 202611 workflow

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| JMP calibration cannot reach 95% | Medium | High | Two-day time box, calibration report, escalation to JMP for an inputs export, decision by the technical lead |
| Subtle legacy D3 semantics missed | Medium | High | Function-level parity against purled legacy definitions; sanity diff against published 2024 |
| UN SDG or OECD API outage or schema change during collection | Medium | Medium | Raw cache, retries, resumable runs; blocked-stop on schema change |
| Catalogue refresh fragile (legacy Rmd, internal network) | Medium | Medium | Staging plus atomic promotion; previous set kept on failure |
| Two-week timeline | High | High | Critical path Phases 1-4 first; Steps 12-14 can run in parallel with Steps 9-11 |
| E5 changes more cells than expected | Low | Medium | Enumerate every changed cell; technical-lead approval before acceptance |
| New catalogue names after refresh | Medium | Low | Unknown names stop; crosswalk or exclusion updated explicitly |
| New PIP release between approval and December | Medium | High | Release lock holds the approved release |
| Frozen-dimension drift (for example UN revisions to D5.1/D5.5) | Medium | Medium | Vintage-diff report with approvals |

## Out of Scope

- Official ODIN 2025 data and the December swap run itself (enabled by Phase 8).
- Any edit to original Rmd files or `02_programs/misc_scripts/` (including the
  OECD scripts).
- Changes to scoring rules other than mapping `"Estimated"` to the existing
  0.33 category.
- Native port of the D4.1 microdata catalogue pull; an IMF API source for
  CNIN/FINA; automated GSBPM evidence discovery; auditing other name-based
  joins against CLASS.xlsx (all tracked as roadmap ideas).

## Completion Contract

### Outcome

The collection and estimation pipelines run end-to-end for `end_date = 2025`
with no blocking issues and promote a complete 202611 output set to
`03_output_data/` in which only ODIN-dependent outputs are marked provisional.
A verified release lock and provisional-to-final diff then allow the December
ODIN swap to change only ODIN-affected outputs.

### Verification Surface

| ID | Phase | Evidence Required | Command/Artifact | Required |
|----|-------|-------------------|------------------|----------|
| V1 | 1 | Full suite green; 2024 replication unchanged (E1-E4) | `testthat::test_dir("tests/testthat")` | yes |
| V2 | 1 | A partial rebuild still promotes a complete output set | `test-output-manifest.R` | yes |
| V3 | 2 | Unattested or changed files block; attested hashes pass; mtime ignored | `test-collection-status.R`, `test-collection-attestation.R` | yes |
| V4 | 3 | PIP, UN SDG series and JMP collectors pass without network; UN SDG parity with `sdg_indicators_for_SPI.R` | collector test files | yes |
| V5 | 3 | JMP calibration at 95% flag agreement or above versus the May 2025 file | `jmp_calibration_2025.md` | yes |
| V6 | 4 | OECD port identical to `oecd_bulk_download.R` on the same raw fixture | `test-oecd-collection.R` | yes |
| V7 | 4 | D3 scorer identical to legacy `un_aki_fun` on fixtures; multi-goal series counted per goal | `test-sdg-collection.R` | yes |
| V8 | 5 | EMPL 2024 rebuild 190/190; GSBP 2024 regression; CNIN/FINA builder tests | `test-d5-2-collection.R`, `test-gsbp-collection.R` | yes |
| V9 | 6 | D4.1 normalization tests; 2024 replication passes with E5 enumerated | `test-dim4-collection.R`, `test-stage-compare.R` | yes |
| V10 | 7 | Replacing `ODIN_2025.csv` invalidates only ODIN targets and downstream outputs | `test-pipeline-contract.R` | yes |
| V11 | 7 | Live collection: 0 blocking rows; run marker complete | `collection_status.csv`, `collection_run.json` | yes |
| V12 | 7 | Live estimation promoted; `odin_status = provisional`; no unapproved frozen-dimension changes | `_estimation_manifest.json`, `vintage_diff_2025.md` | yes |
| V13 | 8 | Release lock verifies; ODIN-swap rehearsal changes only allowed outputs | lock and diff reports | yes |
| V14 | final | Legacy references unchanged (git diff and recorded hashes) | `git diff --stat -- 02_programs/`, `shasum -a 256` | yes |
| V15 | final | Documentation updated and path-checked | docs diff, path check | yes |

### Constraints

| ID | Phase | Constraint | Check |
|----|-------|------------|-------|
| C1 | all | Original Rmds and `02_programs/misc_scripts/` untouched, including the OECD scripts | V14 |
| C2 | all | No scoring-rule changes except `"Estimated"` mapped to 0.33; D3 method equals legacy | Diff review; V7 |
| C3 | all | 2024 replication exact except E1-E5 | V1, V9 |
| C4 | all | Fail loudly; no silent zeros or stale reuse except the ODIN toy file | Tests; status report |
| C5 | all | No network calls in tests | Injected fetchers and mocks |
| C6 | all | No new package dependencies; `renv.lock` unchanged | `git diff renv.lock` |
| C7 | 7 | Frozen-dimension history unchanged unless approved | V12 |
| C8 | all | Publicly accessible data only, except the existing internal microdata library dependency (documented) | Docs |
| C9 | all | Creation-date header on every new R file | Source inspection |

### Boundaries

- Allowed: `R/`, `_targets.R`, `_targets_data.R`, `config/`, `tests/`, `docs/`,
  `README.md`, pipeline-generated artifacts under `01_raw_data/` and
  `03_output_data/`, new review and attestation templates.
- Out of scope: official ODIN data, legacy-script edits, scoring changes,
  native catalogue port, IMF API source, GSBPM discovery automation, wider
  name-join audit.

### Iteration Policy

1. Execute phases in order 1 to 8; Phases 1-4 are the critical path, and Steps
   12-14 may run in parallel with Steps 9-11.
2. Write the failing test first for each step.
3. Run single test files during development and the full suite at each phase end.
4. Never weaken a check to make a run pass; resolve data issues through
   attestation, review overrides or recorded exclusions.
5. Time-box JMP calibration to two working days.
6. Run live network collection only in Steps 9, 10-11, 17 and 23.
7. Handle deviations under the `ask` policy.

### Blocked-Stop Conditions

- JMP flag agreement below 95% after the time box.
- A parity test fails because of an ambiguity in legacy methodology.
- A 2024 replication difference outside E1-E5.
- An unapproved change to frozen-dimension history.
- A live API is unavailable or its schema changed.
- Blocking status rows that need the technical lead's attestation or review.
- Any change would require editing a legacy reference script.

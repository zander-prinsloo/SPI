---
date: 2026-10-23
title: "SPI 202611 source readiness: legacy-faithful fixes for every blocked source"
status: decided
scope: "Deep"
artifact-schema-version: 1
chosen-approach: "Faithful-to-legacy collectors plus release lock"
tags: [spi-202611, data-collection, estimation, revision-policy, dimension-1.5, dimension-3, dimension-4.1, dimension-4.2, dimension-5.2, odin, release-lock, targets]
---
<!-- Valid status values: decided, in-progress, abandoned -->

# SPI 202611 Source Readiness: Legacy-Faithful Fixes for Every Blocked Source

## Context

On 2026-10-23 both pipelines were run end-to-end in an isolated copy of the
repository (working tree untouched). The 202611 update (reference year 2025)
cannot currently be estimated:

- **Collection** (`_targets_data.R`) errored in 8 targets: `manual_checkpoints`,
  `sdg_collection`, `pip_collection`, `unsdg_collection`, `jmp_collection`,
  `d41_catalogue_collection` (and its dependents), and `collection_status`.
  The status gate can never pass because every `latest_release` source is
  always classified `blocking`.
- **Estimation** (`_targets.R`) errored in `estimation_source_registry`,
  `dim1_5`, `dim2`, `dim3`, `dim4`, `dim5`, and the output promotion step.
- With the code defects patched and temporary stand-ins in the isolated copy,
  estimation completed and produced a complete 2025 index (188 countries), so
  the work below is bounded.

ODIN is delayed until **7 December 2026**. The duplicated 2024 ODIN file
(`01_raw_data/2.2_DSOA/ODIN_2025.csv`, labelled toy data) is the only accepted
provisional input. `01_raw_data/misc/CLASS.xlsx` is confirmed correct by the
technical lead. Two legacy scripts were added on 2026-10-23:
`02_programs/misc_scripts/oecd_bulk_download.R` (current producer of
`OECD_data_scored.csv`) and `oecd_stats_pull.Rmd` (2020; retired OECD.Stat
API, historical reference only).

## Requirements

1. **Full internal release now.** Every indicator must be final-quality except
   the ODIN-dependent indicators (`SPI.D2.2.*`, `SPI.D4.3.GEO.*`) and the
   indices they affect. After internal approval, the December update replaces
   only ODIN and recomputes the affected outputs; nothing else may change.
2. **Explicit revision policy**, adopted from observed SPI practice (2023 vs
   2024 vintages, years 2018-2022):

   | Dimension | Observed changes | Policy for 202611 |
   |---|---|---|
   | D1.5 (PIP, IGME, debt, JMP, ILO) | 327 cells revised | Refresh and revise history |
   | D4.1 censuses/surveys | 692 cells revised | Refresh and revise history |
   | D4.2 CRVS | 18 cells revised | Refresh and revise history |
   | D2.x (SDDS, ODIN, NADA), D3, D4.3 | 0 changes | Freeze history; add 2025 only |
   | D5.x | 13 cells (D5.1: 1, D5.2: 11, D5.5: 1) | Freeze history; add 2025 only (see D5.1/D5.5 rule below) |

3. **Legacy references untouched.** Original Rmd files and every script in
   `02_programs/misc_scripts/` (including the new OECD scripts) are never
   edited. Ports are regression-tested against them.
4. **OECD blending automated.** `OECD_data_scored.csv` is produced by the
   collection pipeline on every collection run.
5. **Judgement-based sources** (D5.2.3 CNIN, D5.2.8 FINA, D5.2.10 GSBP): carry
   forward the 2024 value and apply documented, evidence-based reviewer
   overrides. The pipeline must produce review-candidate lists. The technical
   lead is the reviewer (also for D4.1 country-economist additions).
6. **Country names follow CLASS.xlsx.** CLASS.xlsx economy names and codes are
   the authority. D4.1 catalogue companion files are normalized to CLASS names
   plus ISO3 code (raw catalogue output preserved) and joined by ISO3 code.
   This applies to all vintages.
7. **D5.1/D5.5 history:** keep the legacy full-series refresh; any change to a
   2004-2024 value is surfaced for explicit approval.
8. Fail loudly, no silent fallbacks, publicly accessible data, reproducible
   environment (`renv.lock`).
9. `{targets}` must support the ODIN-only December update; gaps must be closed.

## Evidence Gathered

- **D3 is frozen per year.** Each vintage's file recomputes all years (the
  2024 file's 2023 values differ from the 2023 file for 38 of 215 countries),
  but each published year is taken only from that year's own file
  (`01_raw_data/3_DP/<year>/SPI_D3_UNSD_data_5yr.csv`).
- **Legacy D3 scorer** (`un_stats_cleaning.Rmd`, `un_aki_fun`, 5-year file):
  Tier-1 series (`code1`), per-series country-year quality from `un_pull`
  (Nature rules), missing filled with 0 (`un_sdg_filled_df`), OECD blend
  `ind_quality = max(SDG, OECD)`, max per `(iso3c, code, goal)` over the
  5-year window, mean by goal, `round(3)`. The current collector aggregates by
  series instead of SDG indicator code, drops all-missing series-years, has no
  OECD blend, and rejects the 16 Tier-1 series that belong to several goals.
- **UN SDG series files** (CRVS birth/death, legislation, finance) for 2024
  were produced by `misc_scripts/sdg_indicators_for_SPI.R` using the DataCSV
  endpoint (`Value`, `TimePeriod`, ISO codes as text). `R/pull_unsdg.R` uses
  the JSON endpoint (lowercase `value`), fails on a `geoAreaCode` type clash,
  and never collects `SG_REG_DETH75N`, which `dim4` reads.
- **UN SDG DataCSV** responses are a fixed 8 MiB buffer padded with NUL bytes;
  larger series would be truncated silently.
- **OECD SDMX endpoint** used by `oecd_bulk_download.R` is live and returns the
  expected columns (checked 2026-10-23).
- **IMF DSBB** country pages are now rendered by JavaScript; the
  `imf_dsbb_scrape.ipynb` scraper (also hard-coded to Windows SharePoint paths)
  cannot work. The IMF 2026.10 workbook's GFS sheets contain free-text notes
  only.
- **EMPL** 2024 `ISCE` equals `max(2023 ISCE, ILO-catalogue ICSE flag)` for
  190/190 countries; `ilo_sources_catalog_2024.csv` is preserved for the
  regression test.
- **JMP** per-country download is now a 16-sheet workbook. Its "Data Summary"
  sheet has one row per source with `w_*_t/u/r` variables and the note
  "[values in square brackets not used]". The JSON API
  (`api.washdata.org/v1/household/estimates/...`) exposes estimates only.
- **PIP**: live data are unique on `(country_code, year, survey_acronym,
  reporting_level, welfare_type)`; `pipr::get_versions()` returns release
  identifiers (for example `20260922_2021_01_02_PROD`). The 2024 file came from
  the PIP QA server.
- **WDI**: `Latest agricultural census` parses as numeric only in the 2026
  file; the label `"Estimated"` first appears in 2026 (LBN). Under the
  existing file-year convention the `end_date + 1` file feeds no 2025 value.
- **CLASS.xlsx vs World Bank API names** differ for 9 economies (CIV, CUW,
  CZE, NRU, PRI, SOM, STP, TUR, VNM), including `Nauru` vs `Naoero`.
- **`{targets}` 1.12.0** seeds every target deterministically: a forced
  rebuild reproduces random draws exactly, so quantile jitter is reproducible.

## Approaches Considered

### Approach 1: Faithful-to-legacy collectors plus release lock

Fix every blocker inside the two pipelines by porting the scripts that actually
produced the 2024 data, add review-candidate lists for judgement-based
sources, and add a release lock so the December update can change only ODIN.

- **Pros**: reproducible and testable against the 2024 vintage; satisfies
  "only ODIN provisional"; reusable for future vintages; consistent with the
  collection-first architecture.
- **Cons**: largest effort; JMP calibration and the D3 port are on the critical
  path for a roughly two-week target.
- **Effort**: large (about 10 working days).

### Approach 2: Pipeline fixes plus hand-run legacy scripts

Fix estimation and the gate, then produce D3, OECD, the SDG series, and D5.2
inputs by running edited copies of the legacy scripts by hand and attesting the
outputs.

- **Pros**: faster first run.
- **Cons**: legacy scripts hard-code 2024 and external paths, so edited copies
  are needed; not reproducible; the DSBB notebook cannot run; JMP and the gate
  still need new code; repeated manual work every vintage.
- **Effort**: medium (about 6 working days), plus recurring manual effort.

### Approach 3: Relax the collection gate

Downgrade blocking checks to warnings and reuse last year's artifacts wherever
a collector fails.

- **Pros**: fastest.
- **Cons**: violates the "only ODIN provisional" requirement and the
  fail-loudly principle; JMP, D3, and D5.2 values would be stale.
- **Effort**: small.

## Decision

Choose **Approach 1: faithful-to-legacy collectors plus release lock**, with
the per-item solutions below.

### A. Estimation fixes (no change to intended values)

| # | Issue | Fix | Consistency rationale |
|---|---|---|---|
| A1 | `estimation_source_registry` references a non-existent target | Reference `estimation_source_registry_file` | Wiring only |
| A2 | WDI 2026 numeric `Latest agricultural census` breaks the bind | Cast to character before binding; map `"Estimated"` to 0.33 in the debt score; fail loudly on any unseen scored label | Column not scored; `"Estimated"` never appeared before 2026, so no history changes |
| A3 | ILO `.xlsx` reads `time` as text | `as.numeric(time)` | Earlier CSV vintages were numeric |
| A4 | D4.1 review files stacked (two rows per country) | Collapse all vintage review files per country into one additive evidence row (union of years) | Keeps the 37 overrides from 2024 plus 2025 additions; matches the additive-evidence decision; 2024 unchanged |
| A5 | D3 recomputes every year and is not renamed | Restore the legacy per-year reader: 2004-2024 from frozen `3_DP/<year>/` files, 2025 from `3_DP/2025/`; rename goal columns and drop D3.14 as before | Frozen-D3 policy; identical to legacy for 2004-2024 |
| A6 | Output promotion fails on any partial rebuild | Make each output writer a file target in `.candidate/`; stop wiping the folder on every run | Required for the December ODIN-only rebuild |

### B. Collection gate and wiring

| # | Issue | Fix |
|---|---|---|
| B1 | `latest_release` sources always block (PIP, SDDS archive, IGME, JMP, ILO, both IMF workbooks) | Release attestation: record machine-readable release identifiers automatically (PIP `release_version`; ILO download timestamp and IMF edition from the configured filenames; IGME release year; JMP retrieval record). Manual or static files (including the SDDS archive) use a hash-bound attestation record signed by the technical lead (for example `01_raw_data/_collection/source_attestations_<end_date>.csv`). A changed or unattested file still blocks. Freshness comes from cache provenance (`retrieved_at`), not file modification time. |
| B2 | ILO registry path for the survey file lacks `1.5_DUIO/` | Fix the path and bind it to the filenames configured in `config/params.R` |
| B3 | `d41_catalogue_collection` modifies the upstream `collection_params` target in place | Use a local copy of the parameters |
| B4 | `manual_checkpoints` can run before D4.1 preprocessing | Make it depend on `d41_preprocess` (or remove the duplicate microdata presence check; the D4.1 manifest already validates) |

### C. Source collectors

| Source | Fix | Consistency rationale |
|---|---|---|
| PIP (D1.5.1) | Correct the uniqueness key (add `reporting_level`, `welfare_type`); pin the PIP release in `config/params.R`; record it in provenance. Estimator unchanged. | D1.5 refresh policy; public PROD release fits the open-data constraint (2024 used the QA server) |
| UN SDG series: `SG_REG_BRTH90N`, `SG_REG_DETH75N`, `SG_STT_FPOS`, `SG_STT_NSDSFND` | Replace the JSON-based pull with a port of `sdg_indicators_for_SPI.R` (DataCSV, ISO codes as text, saved country snapshot); add `SG_REG_DETH75N` to the collector and registry; strip NUL padding and fail loudly when a response may be truncated | Reproduces how the 2024 files were produced; D4.2 refresh policy; D5.1/D5.5 per rule 7 |
| JMP (D1.5.4) | Parse the cached country workbook's "Data Summary" sheet into the legacy long format (`source`, `type`, `year`, `geo`, `data_available`, `data_quality`, `data_value`): geography from the `_t/_u/_r` suffix (National/Urban/Rural), `data_quality = 1` for used values and `0` for bracketed values. Calibrate the variable choice against the May 2025 `Safely_Managed_Water_data.csv` for overlapping sources before adoption; fail loudly on layout drift. | Same score definition; D1.5 refresh policy |

### D. Pillar 3 (D3) for 2025, following the legacy method

| Part | Fix |
|---|---|
| Scorer | Port `un_aki_fun` and its inputs (`un_pull`, `un_sdg_filled_df`): Tier-1 via `code1`; each series counts in every `(goal, code)` it belongs to (resolves the 16 multi-goal series); missing filled with 0; max per `(iso3c, code, goal)` over the 5-year window; mean by goal; `round(3)` |
| OECD blend | New collection target porting `oecd_bulk_download.R`: cache the raw bulk SDMX CSV; regression test proves the ported transformation equals the original script's output on the same raw file; blend `max(SDG, OECD)` |
| Output | Write `01_raw_data/3_DP/2025/SPI_D3_UNSD_data_5yr.csv` in the legacy layout; the estimator reads only `date == 2025` from it |
| Parity | The UN database has changed since 2024, so exact reproduction of the published 2024 file is impossible. Parity is proven with fixture-level equivalence against the legacy functions on identical inputs, plus a reported sanity diff of a recomputed 2024 against the published 2024 |

### E. D5.2 annual files (2025)

| Source | Fix | Review-candidate list |
|---|---|---|
| D5.2.6 EMPL (automated) | Port notebook cell 10: ILO catalogue labour-force-survey rows give an ICSE flag per ISO3; `ISCE_2025 = max(ISCE_2024, flag)`. Regression: rebuilding 2024 from the 2023 file and `ilo_sources_catalog_2024.csv` must equal the published 2024 values (190/190). | Countries whose flag changed |
| D5.2.3 CNIN | Write `D5.2.3.CNIN.2025.csv` with a `2025` column carried forward from 2024; overrides through the review layer (the existing `D5.2.3.CNIN.Manual.Review.xlsx` year columns, already applied by the estimator) | About 87 countries not on ISIC Rev.4 / NACE Rev.2, plus countries with earlier overrides |
| D5.2.8 FINA | Write `D5.2.8.FINA.2025.csv` carried forward from 2024; overrides through a new per-vintage review workbook using the shared manual-review helper | Countries not on GFSM 2014 / ESA 2010 whose IMF GFS notes changed between the 2025.10 and 2026.10 workbooks or mention GFSM 2014; blank, "other", or "Not Found" values |
| D5.2.10 GSBP | Implement Phase 2 of `.cg-docs/plans/2026-10-21-nada-gsbp-collection-pipeline.md` as designed (previous vintage union desk review, then review workbook; stale-desk-review warning) | The 113 countries without GSBPM evidence; warn that `raw/D1.12.MSC.csv` is unchanged since May 2025 |

All candidate lists are written to one collection artifact (for example
`01_raw_data/_collection/review_candidates_<end_date>.csv`) and summarized in
`collection_status.md`. Every file keeps the schema the estimator already reads.

### F. D4.1

| Issue | Fix |
|---|---|
| Catalogue companions date from October 2025 | Run the existing opt-in catalogue refresh once for 2025 (requires the World Bank network for the internal microdata library) and preserve the raw outputs |
| Name mismatches in 7 of 8 companion files; Nauru silently dropped | Normalize companions to CLASS.xlsx economy names plus ISO3 code via a small, tested crosswalk (Republic of Cabo Verde to CPV, United Republic of Tanzania to TZA, Yemen to YEM, Korea, Dem. Rep. to PRK; Czech Republic and Nauru match CLASS directly). Estimation joins by ISO3. Explicit, manifest-recorded exclusions for non-economies (Anguilla, Cook Islands, Montserrat, Niue), the 2 multi-country studies, and the 3 blank LABR rows; Taiwan, China keeps its code and falls outside the SPI grid as before. Applies to all vintages; the 2024 replication test gets an enumerated, approved exception list for the affected D4.1 country-years. |
| 2025 economist review workbook is empty | Valid as is; review-candidate list of countries whose latest census or survey falls outside the scoring windows |

### G. ODIN-only December update

Verified as already working: estimation reads only saved collection
artifacts (no live API calls), every target is deterministically seeded, and
`spi_index`, quantiles, treemap, and databank recompute automatically from
their inputs.

| # | Gap | Fix | Timing |
|---|---|---|---|
| G1 | ODIN files are read invisibly inside `dim2` and `dim4` | One file target per ODIN year; an `odin_scores` target feeds D2.2 and D4.3, split out of `dim2`/`dim4` | Before the provisional run |
| G2 | No provisional marker | `odin_status` parameter (`provisional`/`official`) stamped into the output manifest | Before the provisional run |
| G5 | Revision policy not enforced | Vintage-diff report: any 2004-2024 change in a frozen dimension (D2, D3, D4.3, D5) is flagged for approval (implements rule 7 for D5.1/D5.5) | With the provisional run |
| G3 | Nothing proves non-ODIN inputs are unchanged in December | At approval, write a release lock (hashes of every non-ODIN collection artifact and approved output); the December run verifies it and stops on any mismatch | After the provisional run, before 7 December |
| G4 | No proof that only ODIN-affected outputs changed | Automatic provisional-to-final diff asserting that only `SPI.D2.2.*`, `SPI.D4.3.*`, pillars 2 and 4, the overall index, ranks, aggregates, and quantiles changed | After the provisional run, before 7 December |

### Deliberately unchanged

- WDI file-year convention (the `end_date + 1` file feeds no 2025 value),
  consistent with frozen D2.1 and D5.2.1 history.
- `ODIN_2025.csv` toy stand-in (official file arrives 7 December).
- `CLASS.xlsx` (confirmed correct).
- NADA 2025 output (already hash-validated, 65 review decisions).

## Devil's Advocate Checks

1. **Problem validation**: pre-validated. Every item was reproduced in the
   live isolated run or confirmed by direct inspection of the files.
2. **Simplicity**: Approach 2 saves about four days this vintage but needs
   edited copies of legacy scripts and still leaves JMP and the gate unsolved.
   G3/G4 are new machinery; a manual `tar_invalidate()` plus a hand-made diff
   would work once, but the lock directly protects the "approved = final except
   ODIN" promise. They are scheduled after the provisional run.
3. **Effort-value**: about 10 working days against a two-week target is tight.
   JMP calibration is time-boxed to two days, with escalation to JMP for an
   inputs export if parity cannot be shown.
4. **Charter alignment**:
   - The CLASS-name normalization changes D4.1 values for a few countries even
     in a rebuilt 2024 vintage, so the charter's exact-replication constraint
     is relaxed for an enumerated, approved list of D4.1 country-years. This
     is an explicit choice of correct names over replicating a matching error.
   - D5.1/D5.5 keep the legacy logic, so exact replication holds; historical
     changes are surfaced by G5 rather than suppressed.
   - The D4.1 catalogue refresh uses the World Bank internal microdata library,
     which strains the open-data constraint. This is existing behaviour, kept
     for this vintage and tracked separately.

## Risks

- **JMP calibration** (highest risk): the mapping from "Data Summary" variables
  to the legacy `data_quality` flags must be shown on overlapping sources
  before adoption.
- **D3 parity**: proven at function level, not against the published 2024 file.
- **D4.1 catalogue refresh**: depends on the legacy Rmd (run through `purl`),
  live catalogue APIs, and the World Bank network.
- **Timeline**: roughly two weeks for a full internal release.

## Out of Scope

- The official ODIN 2025 data and the December swap run itself (enabled by G).
- Any edit to the original Rmd files or `02_programs/misc_scripts/`
  (including `oecd_bulk_download.R` and `oecd_stats_pull.Rmd`).
- Changes to scoring rules, other than mapping the new `"Estimated"` label to
  the existing 0.33 category.
- A native port of the D4.1 microdata catalogue pull; an IMF API replacement
  for the DSBB scraper; automated GSBPM evidence discovery.
- Auditing other name-based joins (for example IGME and ILO) against CLASS.xlsx.

## Prior Knowledge Applied

- Collection owns all source acquisition and estimation consumes only saved,
  validated artifacts; the SDG port must reproduce `un_stats_cleaning.Rmd` and
  be tested against existing vintages — source:
  `.cg-docs/brainstorms/2026-10-05-api-data-collection-pipeline.md`.
- The D4.1 manual review is an additive evidence layer; catalogue collection
  and economist review are distinct manifest stages — source:
  `.cg-docs/brainstorms/2026-10-20-d41-manual-collection-integration.md`.
- GSBP is built from the previous vintage, a hash-tracked desk review, and a
  per-vintage review workbook; historical files are frozen; scoring rules are
  unchanged — source:
  `.cg-docs/brainstorms/2026-10-21-nada-gsbp-collection-pipeline.md`.

## Next Steps

Hand off to `/cg-plan` with these phases (provisional release targeted in
about two weeks; G3/G4 before 7 December):

1. **Estimation fixes**: A1-A6 and B2-B4; keep the 2024 replication suite green.
2. **Source collectors**: PIP (C), UN SDG series including `SG_REG_DETH75N`
   with the DataCSV truncation guard (C), OECD target (D), JMP parser with a
   two-day calibration time box (C).
3. **D3 2025**: legacy scorer port, per-year output, fixture-level parity tests.
4. **D5.2**: EMPL automation with the 2024 regression; CNIN and FINA
   carry-forward with review workbooks; GSBP Phase 2; review-candidate lists.
5. **D4.1**: catalogue refresh; CLASS-name normalization, ISO3 join,
   recorded exclusions; enumerated 2024 replication exceptions; candidate list.
6. **Gate and ODIN tracking**: release attestation and provenance-based
   freshness (B1); ODIN file targets and `odin_scores` split (G1);
   `odin_status` marker (G2); vintage-diff policy report (G5).
7. **Provisional release**: full collection run, technical-lead review of the
   candidate lists and overrides, estimation, internal circulation and approval.
8. **Before 7 December**: release lock (G3) and provisional-to-final diff (G4).
   On ODIN release: replace `ODIN_2025.csv`, rerun, verify the lock and diff.
9. Update `docs/user-guide.md` and `docs/odin-delayed-update.md` for the new
   workflow; consider updating the charter's Current Focus.

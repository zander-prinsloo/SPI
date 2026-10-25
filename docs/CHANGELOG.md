# SPI Pipeline Changelog

Notes on what was ported to the `{targets}` pipeline and what was excluded
(plan requirement R12). The original Rmd files remain the reference source
of truth and are untouched.

Created: 2026-09-22

## What was ported

### Stage A: Data prep (from `01-SPI_data_prep.Rmd`)

| Rmd chunk(s) | Pipeline function(s) | Output |
|--------------|----------------------|--------|
| `set-parameters`, `spi_df` | `R/setup.R`: `load_params()`, `read_iso_codes()`, `build_country_grid()` | country × year grid |
| `3.1`, `aki_3.3`, `3.15_debt`, `safely_managed_scored`, `lfp` | `R/dim1_5.R` | 5 D1.5 indicators |
| `idds`, `online_access`, `nada` | `R/dim2.R` | 3 D2 indicators |
| `unstats` | `R/dim3.R` | 16 D3 indicators |
| `cs`, `crvs`, `geo` | `R/dim4.R` | 8 censuses/surveys + CRVS + geospatial |
| `legislation_governance`, `standards_meta`, `snau`, `naby`, `cnin`, `cpiby`, `hous`, `empl`, `cgov`, `fina`, `mony`, `gsbp`, `msc`, `finance` | `R/dim5.R` | 12 D5 indicators |
| `append`, `save` | `R/append.R`: `append_spi()`, `save_spi()` | `SPI_data.csv`, `SPI_data.dta` |

### Stage B: Index (from `02-SPI_index.Rmd`)

| Rmd chunk(s) | Pipeline function(s) | Output |
|--------------|----------------------|--------|
| `data`, `index_weights`, `index`, `saver` | `R/index.R`: `load_index_weights()`, `build_index()`, `save_index()` | `SPI_index.csv` |

### Stage C: Validation (from `03_SPI_data_validation.Rmd`)

| Rmd chunk(s) | Pipeline function(s) | Output |
|--------------|----------------------|--------|
| `compdf`, `compres`, `corrleations` | `tests/testthat/test-vintage-compare.R` | vintage comparison + correlation |
| `validate::validator()` rules | `tests/testthat/test-validation.R` | expectation checks |
| `dataCompareR::rCompare()` (replaced) | `R/compare.R` (`compare_frames()`, `expect_frames_match()`) | 1e-9 tolerance comparison harness |

### Stage D: Misc outputs (from `misc_scripts/`)

| Original script | Pipeline function(s) | Output |
|-----------------|----------------------|--------|
| `SPI_quantiles.R` | `R/quantiles.R` | `SPI_quantiles.csv`, `SPI_quantiles_2024.csv`, `SPI_indicators_2024.csv` |
| `SPI_treemap.R` | `R/treemap.R` | `SPI_treemap.csv` |
| `databank.R` | `R/databank.R` | `SPI_databank_*.csv` (4 files) |
| `microdata_library_pull.Rmd` (ASPIRE) | `R/spl_admin.R` | `SPL_admin_data_availability.csv` |

### Data pulls (new)

| Target | Source | Notes |
|--------|--------|-------|
| `pull_jmp` | JMP washdata API | opt-in (`run_downloads = TRUE`) |
| `pull_unsdg` | UN SDG API | opt-in (`run_downloads = TRUE`) |
| `checkpoint_wdi`, `checkpoint_ilo`, `checkpoint_odin`, `checkpoint_nada`, `checkpoint_microdata`, `checkpoint_unigme` | manual downloads | fail loudly with instructions |

## 202611 readiness (plan 2026-10-23)

Changes made so that the 202611 update (reference year 2025) runs end to end,
with ODIN as the only provisional input. Plan:
`.cg-docs/plans/2026-10-23-spi-202611-source-readiness.md`; evidence:
`.cg-docs/work-reports/2026-10-23-spi-202611-source-readiness.md`.

- **Estimation fixes for the 2026 source formats**: `score_debt_reporting()`
  scores the WDI label `"Estimated"` (first seen in `WDI_metadata_2026.csv`)
  as 0.33 like `"Estimate"` and stops on any other unseen label; ILO bulk
  files with text years are converted with a guard; the unscored WDI column
  `Latest agricultural census` is read as text; D4.1 review vintages collapse
  to one additive row per country; D3 reads each year from its own frozen
  file; output writers are file targets and a partial rebuild still promotes
  a complete output set.
- **Collection gate**: hash-bound attestations for manual sources and
  provisional release identifiers for collected sources; freshness from
  provenance records, never file modification times.
- **Collectors**: PIP resolves the newest PROD release for the configured PPP
  year; UN SDG series (BRTH90N, DETH75N, FPOS, NSDSFND) through DataCSV; JMP
  ports the legacy "Data Summary" reader (sheet, URL and SHA-256 cached; the
  legacy deviations D1 and D2 are documented in
  `docs/jmp-safely-managed-water-brief.md`); the OECD SDG bulk download and the
  D3 legacy scorer are pipeline targets (2025 file only; 2004-2024 frozen).
- **D5.2 annual files**: EMPL rebuilt from the ILO catalogue; CNIN and FINA
  carried forward with per-vintage review workbooks; GSBP vintage builder.
- **D4.1**: catalogue companions normalized to CLASS.xlsx names plus ISO3
  codes with recorded exclusions (E5); strict year text and coverage checks
  on the workbooks; staged, validated catalogue refresh with a run-time
  budget; economist-review candidates.
- **D4.1 catalogue refresh**: the URLs the legacy
  `microdata_library_pull.Rmd` requests (16,852 internal and 1,786 FAO study
  pages, about 8.5 hours one at a time) are fetched concurrently into a
  cache with an index of status, attempts and SHA-256, and the unmodified
  script reads them from the cache. Failed requests are retried, then stop
  the refresh with `catalogue_fetch_failures.csv` (a rerun retries only
  those); studies the catalogue does not hold get the legacy blank and are
  listed; incomplete internal or FAO searches stop the refresh, and the public
  library's empty answer above its page-size cap (a list no companion uses)
  is recorded. The refresh record persists in `catalogue_refresh.json`.
  The agricultural census companion, which the script does not write, is
  carried forward and recorded. The retired ILO Survey Catalog is replayed
  from its final snapshot while its endpoint shows the retirement notice; the
  PIP survey metadata is cached; script errors are logged. Crosswalk: World
  Bank API names `Naoero`, `Curacao`, `Puerto Rico (US)`; exclusions:
  `Cook Island`, `Serbia and Montenegro`.
  Catalogue studies dated up to two years after `end_date` are kept and
  counted instead of stopping normalization (they never score for earlier
  years, as in the legacy method).
- **Review candidates**: `01_raw_data/_collection/review_candidates_<YEAR>.csv`
  for EMPL, CNIN, FINA, GSBP and D4.1; superseded lists are archived
  unchanged in `review_candidates_history/` with a change log.
- **Revision evidence**: the `revision_report` target writes
  `revision_summary`, `revision_indicators`, `revision_index` and
  `revision_new_year` files with the outputs (indicator revisions, index
  score, rank and quintile revisions against
  `previous_vintages/SPI_index_<end_date - 1>.csv`, reference-year coverage).
  The Working Group report is `docs/revisions/202611-revision-report.md`,
  with the attribution in `docs/revisions/202611/`.
- **Estimation**: ODIN files are tracked inputs shared by D2.2 and D4.3
  (`dim2_core`/`dim2_odin`, `dim4_core`/`dim4_geo`); `odin_status` labels the
  outputs and writes `PROVISIONAL_ODIN.md`; the vintage-diff report blocks
  promotion when frozen history (D2, D3, D4.3, D5) changes without approval.
- **December ODIN update**: after approval, `write_release_lock()` records the
  hashes of the non-ODIN inputs and the PIP release, and archives the
  provisional outputs in `03_output_data/releases/202611-provisional/`. While
  the lock exists, collection and estimation stop on `RELEASE LOCK MISMATCH`,
  and `release_diff` blocks promotion of any change outside the ODIN-dependent
  outputs (`docs/odin-delayed-update.md`). `tests/replication/rehearse_odin_swap.R`
  rehearses the swap in a sandbox.
- **Superseded plans**: this plan replaces the unfinished phases of
  `2026-10-05-spi-data-collection-pipeline.md` (phases 5-7),
  `2026-10-20-d41-manual-collection-pipeline.md` (phases 3-5) and
  `2026-10-21-nada-gsbp-collection-pipeline.md` (GSBP phase and the live
  certification run).

## What was excluded (R12)

- **Visualization chunks** (maps, charts) from the Rmds — tracked as a
  roadmap idea.
- **Commented-out blocks** in the Rmds (e.g. alternative ILO filenames,
  commented joins).
- **The Shiny dashboard** (`SPI_data_viz/`) — out of scope.
- **The technical methodology document** (bookdown) — out of scope.
- **Country reports** — out of scope.
- **`dataCompareR`** — archived on CRAN (not installable); replaced by the
  project's `compare_frames()` utility (1e-9 relative tolerance).
- **`SPI_index_labelled.csv`** — a Stata-label artifact (column labels
  bound as the first row, from `02-SPI_index.Rmd`). The pipeline produces
  the unlabelled `SPI_index.csv`; the labelled variant is a Stata-specific
  output not needed by the pipeline (P2.16).

## Documented exceptions

- **E1**: `SPI.D5.3.DISK` validation rule errors (column not produced by
  the pipeline nor present in the vintage — skills indicator gap). Rule
  kept for exact rule-set fidelity.
- **E2**: `jitter_y`/`jitter_x` in `SPI_quantiles_2024.csv` are unseeded
  `rnorm()` values in the original Rmd — inherently non-reproducible there.
  The targets pipeline sets `tar_option_set(seed = 2024)`, from which
  `{targets}` derives a deterministic seed per target, so the jitter is
  reproducible within the pipeline but differs from the vintage values.
  Excluded from the stage-compare test. The jitter is drawn in index order,
  so it moves between countries whose rank changes; the release diff allows
  it.
- **E3**: databank aggregate rows differ at the 2nd decimal from the
  vintage (the vintage databank was generated from an earlier index
  vintage). Country-level values are identical.
- **E4**: `SPI.D1.5.LFP` window logic corrected. The original Rmd had
  `else if (end_date - 1)` which is always TRUE, making the `i - 4` branch
  unreachable. Fixed to `else if (end == end_date - 1)` (user-approved
  methodology correction). For years 2010-2022, the old code therefore
  used a six-year inclusive window (`i - 5` through `i`), while the
  corrected code uses the intended five-year inclusive window (`i - 4`
  through `i`). The final `SPI_data.csv` comparison shows 102 changed
  country-year values across 81 countries and 13 years. The affected
  observations are those where the dropped boundary-year observation
  changes the accuracy or source component of the LFP score. Excluded from
  the stage-compare test.
- **E5**: D4.1 catalogue companions joined by ISO3 code (202611 readiness
  plan, Step 16; approved by the technical lead on 2026-10-24, including
  PRK). The microdata-catalogue companions (`4.1_SOCS/<stem>_NADA.csv`) are
  now normalized at collection time to CLASS.xlsx economy names plus ISO3
  codes (`config/d41_country_crosswalk.csv`); non-economies, the two
  multi-country studies and blank-country rows are recorded exclusions
  (`config/d41_companion_exclusions.csv`, listed in the D4.1 manifest).
  Before, the companions were joined by country name to the World Bank API
  names, and catalogue names that did not match were dropped silently. The
  2024 replication differs from `8df2865` (and the 202511 vintage) only in
  these cells, all for six economies whose catalogue names did not match
  (newly matched catalogue years in brackets):
  - TZA `SPI.D4.1.2.AGRI` 2018: 0.5 to 1 [agricultural census 2004, 2009;
    agricultural survey 2016]; `SPI.DIM4.1.CEN.INDEX` 0.5 to 0.667,
    `SPI.INDEX.PIL4` 37.58 to 41.74, `SPI.INDEX` 57.68 to 58.51.
  - YEM `SPI.D4.1.5.AGSVY` 2021-2024: 0 to 0.33 [agricultural survey 2021];
    `SPI.DIM4.1.SVY.INDEX` 0.332 to 0.398, `SPI.INDEX.PIL4` +1.65 and
    `SPI.INDEX` +0.33 in each year.
  - CPV `SPI.D4.1.7.HLTH` 2004-2008: +0.33 [population census 2010; health
    surveys 1998, 2005; business surveys 2009, 2024];
    `SPI.DIM4.1.SVY.INDEX` about +0.066.
  - CZE `SPI.D4.1.7.HLTH` 2007 and 2010-2013: +0.33; `SPI.D4.1.8.BZSVY`
    2004-2006: +0.33 [health surveys 1993, 2003; business surveys 2002,
    2008, 2013]; `SPI.DIM4.1.SVY.INDEX` about +0.066 in those years.
  - PRK `SPI.D4.1.7.HLTH` 2004-2024: NA to 0 (2004-2008, 2020-2024) and
    0.33 (2009-2019) [health survey 2009]. PRK is not in the D4.1
    workbooks, so its other D4.1 indicators, sub-index and overall index
    stay NA; the databank aggregates of `SPI.D4.1.7.HLTH` now include it.
  - NRU: household-survey catalogue years listed in
    `RAW.D4.1.4.HOUS.SURVEYS_nada` [2006, 2012] (no score change).
  - The RAW evidence strings of these economies, and the downstream copies
    of these values in `SPI_indicators_2024.csv`, the quantile files,
    `SPI_treemap.csv` and the databank files (including regional and income
    aggregates).
  Every cell (1,733: file, key, column, previous and new value) is listed
  in `tests/fixtures/exceptions/E5_d41_name_normalization.csv`; the
  stage-compare and vintage-compare tests blank exactly these cells.
- **E6**: D1.5 country matching corrected (approved by the technical lead on
  2026-10-24: correct all affected history and document the impact for the
  Working Group). The legacy UN IGME reader joined on country name and
  silently dropped the Netherlands, Türkiye and Kosovo; the legacy ILO
  reader similarly dropped Congo, Dem. Rep., Côte d'Ivoire, Hong Kong,
  Macao, West Bank and Gaza, Türkiye and Kosovo. The 2026 ILO files also
  renamed Bolivia, Cabo Verde, Iran, Micronesia, Nauru and Venezuela. IGME
  now joins on `REF_AREA` (with `RKS` recorded as `XKX`); ILO names use
  `config/ilo_area_crosswalk.csv` and recorded aggregate/non-economy
  exclusions in `config/ilo_area_exclusions.csv`. Unknown codes or names
  stop the run. The 2024 replication changes 157 D1.5 indicator cells
  (63 child-mortality and 94 LFP) across eight economies; the 202611
  preview changes 251 cells (66 child-mortality and 185 LFP) across 14
  economies. The full country, rank, quintile and aggregate effects are in
  `docs/revisions/202611/e6/`; the 2,349 country-level exception cells are
  in `tests/fixtures/exceptions/E6_d15_country_matching.csv`.
- **Databank aggregate order**: group means are now summed in ISO3 order
  before rounding. This prevents a country reorder (especially the December
  ODIN swap) from changing unrelated aggregate values by 0.01 at a
  floating-point rounding boundary. Country values are unchanged; the
  legacy aggregate-order difference is documented as E3.
- **WB API drift**: metadata columns (country name, income, population,
  GDP, last_updated) change between vintages because the World Bank API is
  live. Documented, not a pipeline bug.
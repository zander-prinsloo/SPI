# Execution Report: SPI 202611 Source Readiness

- **Plan reference**: `.cg-docs/plans/2026-10-23-spi-202611-source-readiness.md`
- **Brainstorm**: `.cg-docs/brainstorms/2026-10-23-spi-202611-source-readiness.md`
- **Run started**: 2026-10-23
- **Phase boundaries**: technical lead approved continuing through all phases, pausing only for blocked-stops and required decisions.
- **Branch**: `feat/d41-manual-collection-pipeline`
- **Active deviation policy**: `ask` (plan value; no runtime override)
- **Review mode**: `review:manual` (default; recommendation only)
- **Supersedes**: unfinished phases of `2026-10-05-spi-data-collection-pipeline.md`
  (Phases 5-7), `2026-10-20-d41-manual-collection-pipeline.md` (Phases 3-5),
  `2026-10-21-nada-gsbp-collection-pipeline.md` (Phase 2).

## Run 1 (2026-10-23)

### Baseline

- Full suite before any change: 299 passed, 0 failed, 14 skipped, 200
  warnings (`Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'`).
- All 14 skips are the 2024 replication tests (`test-stage-compare.R`,
  `test-validation.R`, `test-vintage-compare.R`): they only run when
  `03_output_data/_estimation_manifest.json` exists, which it does not.

### Implementation notes

- **Replication evidence mechanism.** Because the replication tests skip in
  the repository, V1/V9 are executed with a sandboxed harness
  (`tests/replication/`) that rebuilds the 2024 vintage with 2024-vintage
  parameters (from commit `d7b368f`) and compares outputs differentially
  (code at the start of this run versus modified code) and absolutely
  (against `tests/fixtures/`). The sandbox symlinks `01_raw_data` read-only
  and never writes into the repository.

## Completed Steps/Phases

- **Phase 1 (Estimation fixes)**, steps 1-4, completed 2026-10-23:
  - Step 1: registry target reference; WDI `Latest agricultural census`
    cast; `"Estimated"` debt label and unseen-label guard; ILO text years
    converted with a guard; corrected seeding comment.
  - Step 2: D4.1 review vintages collapse to one additive row per country.
  - Step 3: frozen per-year D3 reader with `d3_year_files` file target;
    `read_sdg_collection_scores()` removed.
  - Step 4: writer file targets (`spi_data_files`, `spi_index_file`,
    `quantiles_files`, `treemap_file`, `databank_files`, `spl_admin_file`);
    `ensure_output_candidate()` (never wipes); `output_manifest` returns the
    promoted paths as a file target.

### Phase 1 evidence

- Full suite: 358 passed, 0 failed, 14 skipped (the same replication skips as
  baseline).
- Differential 2024 replication (`tests/replication/run_replication.R`,
  worktree vs `8df2865`): 12 of 12 promoted outputs identical; replication
  test results identical (13 pre-existing expectation failures).
- Partial rebuild (treemap invalidated, a candidate file deleted): worktree
  "completed; candidate set complete and promoted"; `8df2865` FAILED
  (`SPI_index.csv` missing after the candidate wipe).
- Pre-existing absolute replication gaps at `8df2865` (unchanged by this
  work), key-based against `tests/fixtures/SPI_data.csv`: `SPI.D1.5.LFP`
  102 cells (documented E4); D5.2.4 CPIBY 78 SPI cells (IMF readers bound to
  the 2026.10 layout since `8cb21c8`, plus the harness IMF pairing, which also
  duplicates 42 D5.2.5/5.2.7/5.2.9 keys for 2024); D4.1 surveys 35 SPI cells
  (AGSVY 7, HLTH 11, BZSVY 17) from D4.1 inputs updated after the 202511
  release. All other dimensions match exactly.

- **Phase 2 (Collection wiring and gate)**, steps 5-6, completed 2026-10-23:
  - Step 5: ILO, IGME and IMF registry paths use `<ILO_MODELLED_FILE>`,
    `<ILO_SURVEY_FILE>`, `<UNIGME_FILE>`, `<IMF_FILE>`, `<IMF_FILE_2024>`
    resolved from params by `collection_artifact_substitutions()`; an
    unresolved placeholder stops. `d41_catalogue_collection` uses a local
    parameter copy; `manual_checkpoints` depends on `d41_preprocess`; the
    duplicate microdata check left `run_collection_checkpoints()` (the
    estimation-side `checkpoint_microdata` target is unchanged).
  - Step 6: new `R/collection_attestation.R` (hash-bound attestations in
    `01_raw_data/_collection/source_attestations_<end_date>.csv`;
    `<artifact>.provenance.json` sidecars). `latest_release` retired;
    `validate_source_registry()` rejects unsupported rules. Reclassified:
    SDDS archive, IGME, ILO, both IMF workbooks -> `manual_attestation`
    (SDG list and the 8 D4.1 workbooks already were); PIP, JMP, D3.1-3.4 and
    the BRTH90N/FPOS/NSDSFND series -> `release_identifier` (OECD row arrives
    with Step 10). Status and cache ages come from provenance or attestation
    records, never mtime. The attestation file hash is part of
    `collection_parameters_hash()`, so attesting after a collection run makes
    the estimation gate demand a fresh collection run.
  - `docs/user-guide.md`: how to clear `attestation_missing` (full workflow
    docs remain Step 22).

### Phase 2 evidence

- Targeted files: `test-source-registry.R` 12, `test-collection-status.R` 38,
  `test-collection-attestation.R` 11, `test-collection-cache.R` 16,
  `test-pipeline-contract.R` 17 expectations; 0 failures.
- Full suite: 403 passed, 0 failed, 14 skipped (same replication skips).
- Differential 2024 replication (worktree vs `8df2865`): 12 of 12 outputs
  identical; replication test outcomes identical to Phase 1; partial rebuild
  "completed; candidate set complete and promoted".
- Gate on the real repository (`evaluate_collection_status()` with params
  substitutions, no attestations yet): 0 `source_vintage_unverified` rows;
  `d1_5_ilo` resolves both configured workbooks. Non-informational rows, all
  mapped: 14 `attestation_missing` (technical lead; Step 23), 5
  `provenance_missing` (PIP Step 7; BRTH90N, FPOS, NSDSFND Step 8; JMP Step 9),
  5 `artifact_missing` (D3.1-3.4 file, Step 11; D4.1 manifest, written by the
  collection run). The literal Step 6 acceptance ("only attestation-pending
  rows remain") therefore completes once Phases 3-4 write provenance; it is
  re-verified at Step 23 (V11).
- Documented attestation snippet dry-run against a temporary collection
  directory: IGME and ILO become `attested` (informational); the real
  attestation file was not created.
- Catalogue wiring: a throwaway `{targets}` project reproduces the original
  failure (`collection_params$country_metadata <- ...` errors with
  "object 'collection_params' not found") and builds with the local copy.
- Test changes tied to the behaviour change (intent preserved):
  `test-collection-cache.R` "old cache entries are refreshed after the age
  threshold" now ages the entry through provenance `retrieved_at` instead of
  file mtime (Step 6 forbids mtime); `test-collection-status.R` sources
  `collection_attestation.R` at the top because status evaluation now reads
  provenance.
- Note (Iteration Policy 6): while preparing Step 7, one read-only
  `pipr::get_versions()` schema probe was made (no artifact written) to
  confirm the column names (`version`, `release_version`, `ppp_version`,
  `identity`); newest PPP-2021 PROD release today is
  `20260922_2021_01_02_PROD`. No live collection was run.

- **Phase 3 (Source collectors)**, steps 7-9, completed 2026-10-23:
  - Step 7 done: `resolve_pip_release()` picks the newest PROD release for
    `pip_ppp_version` (new param, 2021); a release lock short-circuits
    resolution without an API call (deliberate refinement so the December
    swap does not depend on the PIP API; the locked response is cached). The
    release is in the cache request (`pipr-v2`) and in the provenance
    sidecar; uniqueness is on `(country_code, year, survey_acronym,
    reporting_level, welfare_type)`. The current file has 61 duplicates on
    the old 3-part key and 0 on the 5-part key. Estimator unchanged.
    `test-api-collectors.R` 24 expectations; existing PIP fixtures gained
    `reporting_level`/`welfare_type` and an explicit release. Live acceptance
    (release recorded) runs at Step 23 per Iteration Policy 6.
  - Step 8 done: `R/pull_unsdg.R` rewritten as a DataCSV port of
    `sdg_indicators_for_SPI.R` for BRTH90N, DETH75N, FPOS, NSDSFND (explicit
    join keys with a column-clash stop; unmapped geography codes warned and
    dropped as in legacy; provenance per output). `sdg_clean_csv_body()` in
    `R/collect_sdg.R` strips NUL padding and stops on possible truncation or
    embedded NULs (the legacy raw files are NUL-padded to 512 KiB/1 MiB).
    Parity: the unmodified legacy script runs in a `callr` process with
    `httr::POST` mocked, `here()`/`wb_countries()` shadowed and its two unused,
    uninstalled packages (flextable, ggpubr) skipped; all four outputs are
    byte-identical to the port's. Registry `d4_2_crvs` now covers DETH75N;
    `unsdg_collection` depends on `world_bank_inputs`. The legacy request had
    a stray comma (`timePeriodStart=,2004`); the port sends the well-formed
    parameter (series start in 2015/2019, so outputs are unaffected).
  - Step 9 done (technical lead chose Option A, exact port, on 2026-10-23
    after the brief `docs/jmp-safely-managed-water-brief.md`). The first
    calibration (simple bracket rules, 44.5%) wrongly concluded JMP had
    retired a CSV; the original `hyper_read()` always read the workbook's
    "Data Summary" sheet. `R/pull_jmp.R` rewritten as a faithful port
    (header found by content; read_excel name repair mirrored; layout drift,
    missing sheet and non-numeric years stop). Storage per the lead: only the
    "Data Summary" sheet (all cells as text) is cached in
    `01_raw_data/1.5_DUIO/raw/jmp/`, with workbook URL, effective URL,
    SHA-256, size and release stamp in provenance (new
    `collection_payload()` in `R/collection_cache.R`). Parity: the
    unmodified `hyper_read()` extracted from the Rmd runs in a `callr`
    process on synthetic OOXML fixtures (`tests/fixtures/jmp/`, generator
    committed) and matches the port for both end dates. Production code on
    all 217 real workbooks: 100.00% agreement on all four value columns over
    24,420 shared rows, identical columns, 2,160 of 2,170 published values
    (Australia only: failed download in the 202511 run, 0 to 0.5). Cache
    19.3 MB, no workbooks kept. D1/D2 documented in `docs/user-guide.md`;
    methodology review added to the roadmap. Test changes: obsolete
    `normalize_jmp_data` test removed; `test-downloads.R` JMP failure test
    now targets `jmp_download_workbook()` with `httr::GET` mocked (the old
    test made a live call to washdata.org, against C5). Live download into
    `01_raw_data` runs at Step 23 (keeps the 2024 replication inputs stable
    through Phase 6).

### Phase 3 evidence

- Full suite: 498 passed, 0 failed, 14 skipped (same replication skips).
- Differential 2024 replication (worktree vs `8df2865`): 12 of 12 outputs
  identical; replication test outcomes unchanged; partial rebuild promoted.
- Collector files: `test-api-collectors.R` 22, `test-unsdg-parity.R` 30,
  `test-jmp-collection.R` 46, `test-collection-cache.R` 21 expectations.

- **Phase 4 (Pillar 3)**, steps 10-11, completed 2026-10-24 (gate below):
  - Step 10 done: `R/collect_oecd.R` ports `oecd_bulk_download.R`; the full
    329.6 MB SDMX download is cached gzip-compressed (5.0 MB) with its
    URL, SHA-256 and size in provenance; `OECD_data_scored.csv` written as
    the script does (the uncompressed `oecd_sdg_data.csv` copy is not kept).
    Parity: the unmodified script runs in a `callr` process on a 226-row
    sample of the real download (`tests/fixtures/oecd/`); outputs are
    line-identical. Implementation was written before its test (slip from
    test-first); compensated by a mutation check on the source text: dropping
    `separate_rows`, changing the quality threshold and `first()` to `last()`
    are all detected; `str_trim` is an equivalent mutant (codes cannot carry
    spaces). Live run: 126,240 scored rows, 38 countries, 17 goals; gate
    informational with the dataflow release recorded. Registry `d3_oecd_sdg`;
    target `oecd_collection`.
  - Step 11 code done: `R/collect_sdg.R` rewritten as the legacy
    `un_stats_cleaning.Rmd` port (`un_pull`, many-to-many series expansion,
    OECD blend that keeps NA, grid fill to 0, `un_aki_fun` 5-year window);
    Tier-1 only (352 series); DataCSV bodies cached gzip-compressed;
    output `3_DP/<end_date>/SPI_D3_UNSD_data_5yr.csv` in the published layout;
    earlier year folders never written. Parity: the Rmd is purled and its
    setup, api_indicators, api_download, api_download2, save, shape and
    saver (5-year) chunks run unmodified in a `callr` process (wbstats
    mocked; `write_excel_csv()` shimmed for the `path` argument removed in
    readr 2); 30+ expectations; mutation check detects window length, OECD
    filling missing years, rounding, the year-availability rule, the
    many-to-many expansion and the Nature rule. Superseded non-legacy D3 code
    removed (`R/availability.R`, `normalize_sdg_series()`,
    `collect_sdg_series()`, `collect_sdg_pipeline()` and their tests, which
    asserted the multi-goal rejection the audit found blocking);
    `sdg_collection_dir` param removed; registry D3 rows point at
    `3_DP/<END_DATE>/`. `sdg_api_csv_request()` timeout raised to 1800 s
    (SE_TOT_CPLR returns a 64 MiB buffer). Live 2025 run completed
    2026-10-24 (result under "Live D3 2025 result" below).
- **Phase 5 (D5.2 annual files)**, steps 12-15, implemented 2026-10-23:
  - Step 12: `build_empl_vintage()` (notebook cell 10 rule); 2024
    regression 190/190 and `score_empl()` 2024 identical. Catalogue
    countries without an ISO3 code are dropped as in the notebook and
    reported (7 in the current catalogue, including USA, UK and Korea).
  - Step 13: CNIN/FINA carry-forward with per-vintage review workbooks
    (blank templates created once, never overwritten; shared review
    helper; CNIN vocabulary from observed values; FINA values {2014, ESA
    2010, 2001, 1986, other}). Interpretation (plan says "equal to the
    previous year's column"): CNIN carries the previous year as published,
    i.e. with the historical review override of that year applied, so
    India and Somalia (2024 overrides to ISIC Rev.4 with documented
    evidence) keep their score instead of silently dropping (1 to 0.5 and
    1 to 0).
  - Step 14: `R/collect_gsbp.R` per the 10-21 plan (union rule, "No" stored
    as NA, scope and metadata checks, historical-write guard, manifest,
    stale desk-review warning against the 2024 baseline manifest recording
    the `95b3959` hash). 2024 regression identical (values and
    `score_gsbp()`). Frozen fixture at `tests/fixtures/gsbp/` (the repo's
    fixture folder; the 10-21 plan named `tests/testthat/fixtures/`). The
    desk-review rule is `manual_attestation` with warning severity (the
    10-21 plan predates the attestation rule).
  - Step 15: `assemble_review_candidates()` writes
    `_collection/review_candidates_<end_date>.csv`; the status report gains
    a candidates summary and EMPL/GSBP warnings.
  - Real-data check (offline): 2025 EMPL, CNIN, FINA and GSBP files written;
    all four scorers run for 2025 with values equal to 2024 (carry-forward
    before review). 228 candidates: GSBP 113 (no GSBPM evidence), CNIN 83
    (not Rev.4/NACE Rev.2) + 2 (historical overrides), FINA 13 (blank,
    other, Not Found) + 8 (IMF text mentions GFSM 2014) + 2 (both), EMPL 7
    (unmapped catalogue countries). The GSBPM desk review is unchanged since
    the 2024 vintage (stale warning).

### Phase 4 and 5 gate (2026-10-24)

- Full suite: 616 passed, 0 failed, 14 skipped (same replication skips).
- Differential 2024 replication (worktree vs `8df2865`): 12 of 12 outputs
  identical; replication tests 1303 expectations, 13 failed (the
  pre-existing X1 set, unchanged); partial rebuild promoted (2 targets
  completed, 28 skipped).
- Live D3 2025 run (Step 11): in progress at gate time (150 of 352 Tier-1
  series cached); completed afterwards (next item).
- **Live D3 2025 result (Step 11, completed 2026-10-24)**: 4,730 rows (215
  countries x 2004-2025), 352 Tier-1 series, 98.5 min; gzip cache 22 MB;
  release "UN SDG API DataCSV, 352 Tier-1 series, retrieved 2026-10-23;
  OECD SDG dataflow OECD.WISE.RSB:DSD_SDG@DF_SDG(1.0)". Coverage 215
  countries (2024 published: 215). Sanity check (report only, frozen years
  are never replaced): the 2024 scores recomputed from today's UN data
  differ from the published 2024 file (identical shares by goal 12/215 to
  214/215), the size of UN revisions since November 2025. Mean of goal means:
  2025 0.684, 2024 recomputed 0.692, 2024 published 0.671. Four series
  (ER_CBD_ORSPGRFA, ER_CBD_PTYPGRFA, NV_IND_MANF_CD, SH_STA_ANEM_PREG) emit
  readr parsing warnings, all in the `FootNote` column (guessed logical,
  later text); the scorer does not read footnotes and the legacy `un_pull()`
  reads the same way, so scores are unaffected.

### Phase 6 progress

- **Step 16 done (2026-10-24)**: `normalize_dim4_1_companions()` maps the
  eight raw catalogue companions (kept unchanged) to CLASS.xlsx economies
  (rows with a region; aggregates excluded) plus
  `config/d41_country_crosswalk.csv` (12 spellings), drops only the
  exclusions recorded in `config/d41_companion_exclusions.csv` (4
  non-economies, 2 multi-country studies, blank rows in HOUS and LABR), and
  writes `4.1_SOCS/collection/<stem>_NADA.iso3c.csv`. Any other name stops.
  `validate_dim4_1_companions()` recomputes the normalization and stops on
  stale files. Manifest schema v2 adds the naming-file hashes, raw and
  normalized companions with row and duplicate counts, and the exclusions;
  `validate_dim4_1_manifest()` checks all of them and rejects v1 manifests.
  Estimation (`census_fun()`, `survey_fun()`) reads the normalized
  companions by ISO3; the two alias tables and the TWN date filter are
  removed (that filter dropped every HOUS companion row in a TWN PIP year,
  not only the blank rows; it never reached a published vintage). Workbook
  preprocessing now requires four-digit years (plus "Register based census"
  in census workbooks) and full coverage of the previous derived CSV.
  `test-dim4-collection.R`: 137 expectations, written first (red run
  recorded). Real-data checks: current companions normalize for 2025 with
  only the recorded exclusions; the current workbooks pass the year and
  coverage checks.
- **E5 enumerated and approved**: the 2024 replication (worktree vs
  `8df2865`) differs in exactly 1,733 cells, all D4.1-derived, for CPV, CZE,
  NRU, PRK, TZA and YEM (score changes: TZA AGRI 2018, YEM AGSVY 2021-2024,
  CPV HLTH 2004-2008, CZE HLTH 2007 and 2010-2013, CZE BZSVY 2004-2006, PRK
  HLTH 2004-2024 NA to a value). Verification on a second run: 0 cells
  outside the E5 fixture, 0 fixture cells not reproduced, 0 value
  mismatches. Fixture `tests/fixtures/exceptions/E5_d41_name_normalization.csv`;
  `docs/CHANGELOG.md` E5. The stage-compare and vintage-compare tests blank
  exactly these cells (`tests/testthat/helper-exception-cells.R`).
  Replication tests: 1303 expectations, 13 failed, the same tests and counts
  as Phase 5; the failure text differs only in the already-failing treemap
  test (positional comparison misaligned by the replication-only duplicate
  rows below, so the masked Yemen cell lands on different rows).
- **Replication-only duplicate rows (pre-existing, part of X1)**: in the 2024
  replication, `SPI_data.csv` and downstream files carry 62 duplicate
  (iso3c, 2024) keys, because `score_hous()`, CGOV and MONY bind the
  hard-coded 2024 IMF file and the current IMF file dated `end_date`, which
  coincide when `end_date = 2024`. The 202511 vintage has none, and with
  `end_date = 2025` the dates cannot coincide. The Step 21 report will check
  key uniqueness of the 2025 outputs.
- Post-E5 differential reference for later gates: `replication/spi-rep/step16b`.
- **Step 17 done (code; live refresh pending)**: `dim4_1_refresh_catalogue()`
  runs an adapter into `4.1_SOCS/collection/staging-*`, requires all eight
  companions, validates them with the Step 16 rules (naming files from the
  real tree), promotes all staged CSVs with backup and rollback, and removes
  the staging folder. Budget `d41_catalogue_budget_minutes` (240) through
  `setTimeLimit()` plus a post-return check; the live adapter runs the
  purled, unmodified `microdata_library_pull.Rmd` in a `callr` process with
  `here()` shadowed to the staging root and the same timeout. The refresh
  record (adapter, script SHA-256, endpoint URLs, timing, rows and SHA-256
  per companion, promoted files) is returned in the catalogue result that
  `d41_manifest` stores. Tests: failing adapter, invalid companion,
  incomplete set, budget, success; the tests were written first but not run
  red before the implementation (slip), compensated by a mutation check: skipping
  staged validation, the completeness check, the budget and the cleanup are
  each caught by the intended test. The live refresh needs the World Bank
  network and runs with the Step 23 collection (`run_downloads <- TRUE`).
- **Step 18 done**: `d41_review_candidates()` lists, per D4.1 indicator,
  countries with no census or survey recorded, a latest census more than 10
  years before `end_date` (register-based excepted) or a latest survey
  outside the 12-year window, using workbook, normalized companion and all
  review vintages; and countries where catalogue evidence alone changes the
  `end_date` score. Interpretation: the plan's "catalogue and workbook
  disagree" was first implemented as any in-window difference; on real data
  that flagged 486 rows, mostly survey rounds that cannot change a score, so
  the rule was narrowed to score-changing catalogue evidence (207 rows).
  Wired into `review_candidates` after `d41_manifest`. Test-first (red run
  recorded); 22 expectations.
- **Real-data check (offline, 2025)**: 2025 derived CSVs written; companions
  normalized (rows 18, 15, 5, 2388, 239, 1742, 653, 403) with exactly the
  recorded exclusions; manifest written and validated
  (`4.1_SOCS/collection/D4.1_collection_manifest.json`); duplicate keys
  counted (HOUS 1, SVY.AGRI 118: NADA plus FAO copies). D4.1 candidates:
  611 (217 none recorded, 187 outside the window, 207 catalogue changes the
  score); `review_candidates_2025.csv` now 839 rows.

### Phase 6 gate (2026-10-24)

- Full suite: 730 passed, 0 failed, 14 skipped. The first run found 2 errors
  in `test-scoring.R` (two census/survey tests still wrote name-keyed
  companions); fixed to write normalized companions.
- Differential 2024 replication (worktree vs `replication/spi-rep/step16b`): 12 of
  12 outputs identical; replication tests 1303 expectations, 13 failed,
  failure text identical; partial rebuild promoted.

### Phase 7 progress

- **Step 19 done**: `odin_files` (file target, 2015 to `end_date`) and
  `odin_data` (one validated read of every column both readers use);
  `dim2_core`/`dim2_odin`/`dim2` and `dim4_core`/`dim4_geo`/`dim4` with the
  original join order; `score_geospatial()` uses the shared read (its reader
  was line-for-line the same code); `verify_odin_data()` validates the full
  column set. Tests written first (red recorded). V10 evidence: graph test in
  `test-pipeline-contract.R`, plus a real store (kept replication sandbox,
  ODIN folder copied into the sandbox, `ODIN_2024.csv` perturbed): outdated
  became exactly `odin_files`, `odin_data`, `dim2_odin`, `dim4_geo`, `dim2`,
  `dim4`, `spi_data(_files)`, `spi_index(_file)`, `quantiles(_files)`,
  `treemap(_file)`, `databank(_files)`, `output_manifest`; `dim1_5`,
  `dim2_core`, `dim3`, `dim4_core`, `dim5`, `spl_admin` stayed current; the
  real ODIN file still equals HEAD. Replication 12/12 identical.
- **Step 20 done**: `odin_status <- "provisional"` (`config/params.R`);
  `_estimation_manifest.json` records `odin_status`, the SHA-256 of every
  ODIN file and the ODIN-dependent columns found in the candidate
  `SPI_data.csv`/`SPI_index.csv`; provisional writes and promotes
  `PROVISIONAL_ODIN.md`, official removes it. Design addition: `odin_status`
  is read by its own target and removed from the `params` value, so switching
  to "official" reruns only `output_manifest` (graph test). Tests first.
- **Step 21 done**: `R/vintage_diff.R`; targets `previous_vintage_file`,
  `vintage_diff_approvals_file` (template created once, never overwritten),
  `vintage_diff` (before `output_manifest`); the report files are part of the
  complete output set. Policy per the brainstorm table (refresh D1.5, D4.1,
  D4.2; frozen D2, D3, D4.3, D5; unclassified columns stop). Approvals accept
  `*` wildcards and need a reason and approver; unused approvals are listed.
  Duplicate country-year keys are blocking findings (the Step 16 guard). The
  replication harness neutralizes only the enforcement in its sandbox (as for
  the collection gate). Tests first; 30 expectations. Preview on the 2024
  replication (2024 run vs 2023 vintage): 3,001 refresh cells reported, 171
  frozen cells (CPIBY 2015 49; CRI history NA in the 2023 vintage across 8
  frozen indicators; IND CNIN 1; SAU MONY 1), 42 replication-only duplicates.
- **Step 22 done**: user guide (run order, revision policy and approvals,
  review workbooks and candidates, ODIN status, split targets), ODIN guide
  (tracked inputs, marker, December steps without `tar_destroy()`), CHANGELOG
  (202611 section, supersede note), README (commands; `test_dir()` instead of
  `test_local()`, which needs an R package). `superseded-by` added to the
  2026-10-05, 2026-10-20 and 2026-10-21 plans (status unchanged: the plan
  schema has no superseded value). Path check: 527 backticked tokens; every
  file, target, function and parameter introduced resolves; unresolved
  tokens are column names, status values, chunk names, code, legacy scripts,
  or outputs generated by the live run. Two stale pre-existing references
  were fixed: section 5.1 named `checkpoint_*` targets that the estimation
  graph does not contain (now the `manual_checkpoints` collection target),
  and the `run_downloads` comment named removed `pull_*` targets.
- **Gate (Steps 19-21)**: suite 791 passed, 0 failed, 14 skipped;
  replication 12/12 identical vs `step16b`, failures identical, partial
  rebuild promoted.
- **Replication harness hardening before the live run**: tracked raw files
  that differ from `8df2865` are restored inside the sandbox
  (`pin_tracked_raw_files()`, verified on a throwaway repository: sandbox
  gets the reference content, real files untouched, symlinked folders are
  materialized before any write, writes outside the sandbox refused), and the
  World Bank snapshot used by every replication so far is frozen in
  `tests/replication/world_bank_snapshot/` (byte-identical copies). The live
  collection therefore cannot change later replication evidence.

### Phase 8 progress (code ahead of the Step 23 approval)

Phase 8 code was written while Step 23 waits for the technical lead's
attestations and reviews; the lock itself is written at approval.

- **Step 24 (code done)**: `R/release_lock.R`. `write_release_lock()` archives
  the promoted outputs to `03_output_data/releases/<end_date + 1>11-<status>/`
  and writes `_collection/release_lock_<end_date>.json` with the hashes of
  every registry-resolved non-ODIN artifact plus the World Bank snapshot
  (directories such as `4.1_SOCS/raw/` are expanded file by file, skipping
  hidden and `~$` files: 104 hashed files in the rehearsal; the first
  rehearsal stopped with "not a file" on that directory, which this fixed), the PIP release from the PIP provenance, and
  the archived outputs; it never overwrites a lock or archive. JSON manifests
  are hashed without `*_at`/`*_seconds` fields (the D4.1, NADA and GSBP
  manifests are rewritten with timestamps on every run). Wiring: the PIP
  collector uses the locked release; `collection_status` verifies the lock
  before marking the run complete; estimation verifies it in
  `release_lock_verification` (always run, constant value) before
  `output_prepare`. Tests first (red recorded): 24 expectations (tampered,
  missing and new artifacts block; ODIN changes pass; timestamps ignored;
  locked PIP release used without an API call; no overwrite; complete
  outputs required) plus contract tests.
- **December finding fixed**: the NADA collector re-checks URLs when its
  evidence is older than `nada_url_max_age_days` (30, file mtime), which by
  December would change D2.4 after approval and trip the lock. Under a lock
  the evidence is now reused whatever its age; a refresh request or missing
  evidence under a lock stops. Test first.
- **Step 25 (done)**:
  `R/release_diff.R`; the `release_diff` target (always run; a no-op without
  a lock) compares every candidate output with the locked archive before
  `output_manifest`, after checking the archive against the lock hashes.
  Allowed: `(SPI|RAW).D2.2.*`, `(SPI|RAW).D4.3.*`, `SPI.DIM2.2.INDEX`,
  `SPI.DIM4.3.INDEX`, `SPI.INDEX.PIL2/PIL4`, `SPI.INDEX`, their quintiles,
  the Data Services/Data Sources/SPI Overall scores, the plotting jitter of
  `SPI_quantiles_<end_date>.csv` (added after the rehearsal, below), and
  treemap and databank rows of those series; any other change and any added
  or removed row or column block. Reports `release_diff_<end_date>.csv/.md`
  are promoted with the outputs. Tests first: 17 expectations, 20 with the
  jitter test. Rehearsal script `tests/replication/rehearse_odin_swap.R`
  (sandbox; guards refuse writes outside it).
- **ODIN-swap rehearsal (V13)**: run on the live 2025 inputs in a sandbox
  (collection gate and vintage-diff enforcement neutralized there only).
  1. Provisional estimation completed; marker present.
  2. Lock written in the sandbox: 104 files, PIP release
     `20260922_2021_01_02_PROD`.
  3. Unchanged rerun: only `release_lock_verification`, `release_diff` and
     `output_manifest` ran; release diff 0 cells.
  4. Ten ODIN "All Categories" rows perturbed and `odin_status` set to
     "official": rebuilt `odin_data`, `dim2_odin`, `dim4_geo`, `dim2`,
     `dim4`, the data, index, quantile, treemap and databank outputs (not
     `spl_admin`), `vintage_diff`, `odin_status`, `params`
     (unchanged value, so nothing downstream of it alone reran) and the
     always-run targets; `dim1_5`, `dim2_core`, `dim3`, `dim4_core` and `dim5`
     stayed current;
     release diff 1,122 changed cells, 0 outside the ODIN-dependent outputs;
     marker removed; manifest `odin_status = official`.
  5. One non-ODIN artifact changed (`1.5_DUIO/PIP_comparability_latest.csv`):
     estimation stopped with `RELEASE LOCK MISMATCH` naming the file.
  No sandbox left behind. Summary and reports:
  `replication/spi-rep/rehearsal/_rehearsal_summary.txt`.
- **Rehearsal finding fixed (jitter)**: the first complete step 4 stopped
  with `RELEASE DIFF BLOCKS PROMOTION: 44 change(s)`, all `jitter_x`/`jitter_y`
  in `SPI_quantiles_2025.csv` (22 rows each). `build_quantiles_2024()` draws
  the jitter by row position from a fixed per-target seed, and the rows follow
  the overall index, so reordering moves the jitter between countries. In the
  kept sandbox the jitter values were the identical set, permuted across
  exactly the 22 positions whose country changed. The jitter is therefore
  derived from the ranks, which the plan's Step 25 allows; the columns were
  added to the allowed set (test first: red, then green), and a non-ODIN
  column in the same file still blocks. Documented in
  `docs/odin-delayed-update.md` and CHANGELOG E2.
- **Rehearsal script hardening**: the summary is written line by line and
  release/vintage diff reports (including unpromoted `candidate_*` copies)
  are copied out before the sandbox is removed, so a failed step can be
  diagnosed; `params.R` (no final newline at `HEAD`) is read without the
  warning; documented usage runs without `--vanilla` so the project
  `.Rprofile` activates renv.

### Final gate (2026-10-24)

- Full suite: 855 passed, 0 failed, 14 skipped, 206 warnings (baseline 200).
  Warning audit by test and message: 203 in `test-scoring.R` and 2 in the
  D4.1 survey tests come from the ported legacy scorers (`max()` over empty
  groups, `unnest()` without `cols`, coercion in the IMF CPIBY rule),
  unchanged behaviour; 2 are `dir.create()` "already exists" warnings from
  pre-existing `test-scoring.R` tests that share the session `tempdir()`; 1 is
  a readr type guess on the unscored IGME column `Time Since First Birth`
  (all 772 parsing problems are in that column; the scored columns parse
  correctly).
- IGME check prompted by that warning: the legacy child-mortality scorer
  counts rows, and both the 2024 input (2021 wealth-quintile extract) and the
  2025 input carry `Time Since First Birth` rows. In the 2025 run these rows
  decide 37 country-years (2004-2016; BTN, DJI, SUR, THA, TKM, TTO, UZB,
  VNM): 35 equal the published 2024 value (1) and 2 are reported refresh
  changes (0 to 1) in the vintage diff. No change (scoring rules are out of
  scope, and the current behaviour matches the published values).
- Differential 2024 replication (worktree vs `replication/spi-rep/step16b`): 12 of
  12 outputs and the replication-test table identical; 1303 expectations, 13
  failed, failure text identical (X1); partial rebuild promoted.
- Network audit (C5): collector tests inject their fetchers or mock
  `httr::GET` (for example the JMP 404 test); legacy-parity tests purl the
  unmodified scripts and run them offline on fixtures.

### Handover (2026-10-24)

Work paused for handover; brief:
[2026-10-24-spi-202611-handover.md](2026-10-24-spi-202611-handover.md)
(state, evidence, outstanding engineering and documentation in order, the
technical lead's actions, commands, suggested commits).

- **Full suite**: 1,050 passed, 0 failed, 14 skipped, 206 warnings (the
  audited legacy-scorer warnings).
- **Not rerun since E6 and the aggregation-order fix**: the differential
  replication and the ODIN rehearsal. They wait for the E6 fixture and the
  stronger rehearsal (brief, section 4).
- **Pre-E6 baselines** (cannot be regenerated from the current code), kept
  in the session folder `files/handover-baselines/` with SHA-256 in the
  brief: `replication/spi-rep/preview-pre-e6` and `replication/spi-rep/step16b`, plus
  `preview-e6` and `step-e6`.

## Deviations

All recorded 2026-10-24 under the `ask` policy; each was requested or approved
by the technical lead in conversation, or fixes a defect found while running
a requested step.

- **D4.1 catalogue prefetch (Step 17 adapter; approved: "Concurrent, cached
  fetch of the same URLs", with two conditions: find every relevant survey,
  and document any API failure so it can be retried).** The internal library
  has 16,852 studies; the legacy script fetches one detail page at a time
  (about 8.5 hours, beyond the 240-minute budget) inside `possibly()`, so a
  failure silently becomes a blank series label. New
  `R/collect_dim4_1_prefetch.R`: the URLs the script builds are fetched
  concurrently into a cache with an index (status, attempts, SHA-256), the
  unmodified script reads them through a cached `fromJSON()`, failures are
  retried and then stop the refresh with `catalogue_fetch_failures.csv`
  (reruns retry only those), not-found studies keep the legacy blank and are
  listed, searches must return every study they report, and requests outside
  the cache are logged and fail loudly. Live check: 42 of 42 cached bodies
  parse identically to the legacy `fromJSON(url)`. Two defects found in the
  first live attempts and fixed test-first: (1) the public library caps its
  page size and answers `ps=10000` with an empty success, which the guard
  caught; that list feeds no companion, so it is recorded as a non-blocking
  anomaly with the true count from a one-row probe; (2) the fetcher queued a
  whole batch behind 8 connections and libcurl's connect timer timed queued
  requests out (602 of 1,000); requests now join the pool as others finish
  (600 of 600 in a live check).
- **D4.1.2 agricultural census companion (Step 17 defect).** The legacy
  script writes seven of the eight companions: it writes the FAO
  agricultural census list to `D4.1.2.CEN.AGRI_NADA_FAO.csv` (122 economies in
  October 2025, 118 in the October 2026 pull),
  which the estimation never reads, and never writes
  `D4.1.2.CEN.AGRI_NADA.csv` (16 rows, 12 countries, last changed
  2024-02-26). Requiring all eight would have stopped every refresh. The
  refresh now requires the companions the script writes
  (`dim4_1_catalogue_written_companions()`), keeps the other unchanged and
  records it (`carried_forward`, `refreshed = FALSE`). Whether to use the FAO
  list is a method question for the Working Group (revision report).
- **Retired ILO Survey Catalog (source change, found in the live run).** The
  ILO Survey Catalog (NADA), one of the script's three labour force survey
  sources, now answers with a "410 Gone | ILO Survey Catalog Retired" page;
  the script read it as a one-column table and stopped. Its final snapshot
  (1,705 studies, byte-identical in the October 2025 and 20 October 2026
  downloads) is kept in `4.1_SOCS/retired/` with provenance and replayed to the
  unmodified script page by page; each refresh first confirms the endpoint
  still shows the retirement notice and stops if it serves data again.
  Test-first (3 tests). Reported to the Working Group.
- **Catalogue names (crosswalk and exclusions, live run).** Normalization now
  lists every unknown name of every companion at once. Added to
  `config/d41_country_crosswalk.csv`: `Naoero` (NRU), `Curacao` (CUW),
  `Puerto Rico (US)` (PRI), the World Bank API names the script uses for PIP
  survey rows. Added to `config/d41_companion_exclusions.csv`: `Cook Island`
  (non-economy; variant of `Cook Islands`) and `Serbia and Montenegro`
  (former state union of two current economies; new in the refreshed health
  companion, so excluding it leaves the evidence as before). For review by
  the technical lead.
- **PIP survey metadata and script errors (live run).** The PIP API returned
  HTTP 502 on every endpoint during the refresh; the script's direct
  `readLines()` failed. The request is now fetched and cached with the
  catalogue responses (retried, documented, served through a cached
  `readLines()`), and any error inside the script is written to the failure
  log (`source = legacy_script`). Test-first (3 tests).
- **Refresh record persistence (defect).** The refresh record lived only in
  the target value, so the next run with `run_downloads <- FALSE` would drop
  it from the manifest. It is now written to `catalogue_refresh.json` and
  carried as `catalogue$last_refresh`.
- **Catalogue studies dated after the reference year (Step 16 defect).** The
  normalization stopped on any catalogue date after `end_date`. A catalogue
  pulled in October 2026 lists 2026 studies (18 internal, 2 FAO), which the
  legacy method keeps and never scores for earlier years. Such rows are now
  kept and counted (`after_end_date`); dates more than two years ahead still
  stop. The Step 16 test was changed accordingly (old: rejects any later
  date; new: keeps and counts, rejects more than two years ahead).
- **Review candidates retained (requested).** Superseded candidate lists are
  archived unchanged in `review_candidates_history/` with a per-source change
  log; the list reviewed on 2026-10-24 (SHA-256 `a74b0f42...`) is archived.
- **Revision evidence and Working Group report (requested).** New
  `R/revision_report.R` and targets `previous_index_file` and
  `revision_report` (four files promoted with the outputs);
  `01_raw_data/previous_vintages/SPI_index_2024.csv` added (byte-identical
  to the published fixture `tests/fixtures/SPI_index.csv`); the replication
  harness substitutes an empty previous index for the 2024 vintage (no 2023
  index is kept). `odin_status` now reaches `revision_report` as well as
  `output_manifest` (the evidence labels ODIN columns provisional), still no
  estimation target; the Step 20 graph test was updated. Attribution script
  and Working Group report in `docs/revisions/`. Preview estimation script
  `tests/replication/preview_estimation.R`.
- **E6: D1.5 country matching (defect found while attributing revisions;
  approved by the technical lead on 2026-10-24: "correct all", with full
  Working Group documentation of the revision, its reason and its impact on
  country estimates and aggregates).**
  - **Defect.** The UN IGME and ILO readers matched countries by exact name
    against `metadata/iso_codes.csv` and silently dropped unmatched names,
    which then scored 0:
    - IGME: the Netherlands, Türkiye and Kosovo, in every release;
    - ILO: Congo, Dem. Rep., Côte d'Ivoire, Hong Kong SAR, Macao SAR, West
      Bank and Gaza, Türkiye and Kosovo, in every release;
    - ILO 2026 files: Bolivia, Cabo Verde, Iran, Micronesia, Nauru and
      Venezuela (renamed), giving 79 false downward LFP revisions that the
      pre-E6 attribution labelled "source update".
  - **Fix.** IGME is matched on `REF_AREA` (alias `RKS` to `XKX`; unknown
    codes stop). ILO names go through `iso_codes.csv` plus
    `config/ilo_area_crosswalk.csv` (18 rows) and
    `config/ilo_area_exclusions.csv` (91 rows); an unrecorded name stops.
    The config is a file target (`ilo_area_names_files`) feeding `dim1_5`.
  - **Tests.** 9 tests in `test-scoring.R` and 1 contract test, red first.
  - **Outstanding.** Exception fixture, impact tables, attribution update
    and WG text (brief, sections 4-5).
- **Databank aggregates summed in a fixed order (defect found by the E6
  comparison).**
  - **Defect.** `build_databank()` averaged group members in the order of
    `SPI_index.csv`, which is sorted by the overall score. About 20
    aggregate means sit on a rounding boundary, so any reordering moved
    unrelated aggregates by 0.01. The December ODIN swap would likely have
    tripped the release diff. The rehearsal missed it because it changed
    only 10 economies.
  - **Fix.** New `aggregate_databank()` sums members in ISO3 order;
    `test-databank-aggregates.R` was red on the behaviour-preserving
    refactor.
  - **Effect.** About 20 aggregate values move by ±0.01 relative to the
    legacy order; country values are unchanged; aggregate rows are already
    outside the vintage comparisons (E3).
  - **Outstanding.** Rehearsal perturbing every ODIN row.
- **Attribution evidence for LFP (defect, not yet fixed).** The evidence
  uses a fixed 5-year window; the scorer uses 7, 6 and 5 years by year.
  The accuracy component (reported minus modelled rate) is not described.
  Fix with the E6 attribution update.
- **Real-data D4.1 snapshot test updated (refresh).** `test-dim4-collection.R`
  expected the pre-refresh health exclusions. It now expects Anguilla, Cook
  Island, Montserrat, Niue, and Serbia and Montenegro; the new rows are
  still pending the technical lead's review.

## Accepted Exceptions

- **X1 (V1 absolute part / C3)** -- 2026-10-23, approved by the technical lead
  in conversation ("accept_differential"). The 2024 vintage could not be
  reproduced exactly before this work began: D5.2.4 CPIBY (78 SPI cells; IMF
  readers bound to the 2026.10 layout since `8cb21c8`) and D4.1 surveys (35
  SPI cells; inputs updated after the 202511 release). C3 and V1 are
  evaluated differentially: this work must introduce no change relative to
  `8df2865` other than the approved E5. Restoring exact CPIBY replication is
  out of scope.
- **E5 (C3, Step 16)** -- 2026-10-24, approved by the technical lead in
  conversation ("approve_all", including PRK): the 1,733 enumerated D4.1
  cells in `tests/fixtures/exceptions/E5_d41_name_normalization.csv`.
- **E6 (C3)** -- 2026-10-24, approved by the technical lead in conversation
  ("correct all", with full Working Group documentation): D1.5 child
  mortality and labour force values of the economies lost to the legacy name
  join, and their downstream index cells. The 2,349-cell country-level
  fixture `tests/fixtures/exceptions/E6_d15_country_matching.csv` was
  enumerated and verified with 0 outside cells, 0 missing cells, and 0 value
  mismatches.

## Phase 7 continuation (2026-10-24)

- **E6 impact evidence**: the final 202611 preview versus the pre-E6 preview
  changes 251 D1.5 indicator values, 219 corrected-index rows, 935 rank
  side-effect rows, and 2,814 recomputed aggregate values. The 2024
  replication versus the post-E5 reference changes 157 D1.5 indicator cells,
  128 corrected-index rows, 510 rank side-effect rows, and 2,069 aggregate
  values. These effects are in `docs/revisions/202611/e6/`.
- **Attribution**: 845 revised cells are attributed, 0 are unexplained, and
  the last attribution step differs from the final preview in 0 of 63,798
  cells. E6 is derived from the unmatched 202511 source labels. LFP evidence
  uses the scorer's 7/6/5-year windows and reports the accuracy gap.
- **Differential replication**: the E6 fixture matches the final replication
  exactly (`got=2349`, `fixture=2349`, outside=0, missing=0,
  value_mismatch=0). The replication has 1,303 expectations and the same 13
  accepted X1 failures as the post-E5 reference.
- **ODIN rehearsal**: perturbing every all-category ODIN row produces 12,817
  changed cells, 0 outside the ODIN-dependent outputs; the unchanged rerun
  has a zero diff, and the non-ODIN tamper is blocked by the release lock.
- **Final preview**: completed in `replication/spi-rep/preview-final`; revision
  evidence is copied to `docs/revisions/202611/preview/`. The WG report now
  has no `[SOURCE NEEDED]` markers. The final full-suite gate is recorded
  below.

## Evidence Table

| ID | Phase | Evidence | Status | Artifact |
|----|-------|----------|--------|----------|
| V1 | 1 | Full suite green; 2024 replication unchanged | passed (differential; X1) | 358 passed/0 failed; 12/12 outputs identical vs 8df2865 |
| V2 | 1 | Partial rebuild still promotes | passed | worktree complete and promoted; 8df2865 failed |
| V3 | 2 | Attestation gate behaviour | passed | status 38 and attestation 11 expectations; suite 403/0; 12/12 identical vs 8df2865 |
| V4 | 3 | Collector tests and UN SDG parity | passed | PIP, UN SDG parity (byte-identical), JMP parity; suite 498/0; 12/12 identical vs 8df2865 |
| V5 | 3 | JMP calibration >= 95% | passed | exact port: 100% row agreement, 2,160/2,170 published values; jmp_calibration_2025.md; Option A chosen |
| V6 | 4 | OECD parity | passed | line-identical outputs vs unmodified script; mutation check; live run 126,240 rows |
| V7 | 4 | D3 scorer parity | passed | unmodified Rmd chunks vs port on fixtures incl. multi-goal series; mutation check; live 2025 file 4,730 rows, 352 series |
| V8 | 5 | EMPL 190/190, GSBP, CNIN/FINA | passed | EMPL and GSBP 2024 regressions identical; CNIN/FINA builder tests; 2025 scorers run |
| V9 | 6 | D4.1 normalization; replication with E5 | passed | `test-dim4-collection.R` (166), `test-review-candidates.R` (22); replication differs from `8df2865` in exactly the 1,733 approved E5 cells; Phase 6 gate 12/12 identical vs post-E5 reference |
| V10 | 7 | ODIN invalidation scope | passed | graph test plus real-store `tar_outdated()` after perturbing a sandbox `ODIN_2024.csv`: only the ODIN chain and its outputs |
| V11 | 7 | Live collection 0 blocking | pending (technical lead) | first live pass 2026-10-24: run marker complete, 17 blocking rows, all `attestation_missing`, plus 1 warning (GSBP desk review); clears after the Step 23 attestations and reviews |
| V12 | 7 | Live estimation promoted, provisional marker, vintage diff | pending (technical lead) | final sandbox preview complete, marker present, `odin_status = provisional`; vintage diff 846 changes (845 reported refresh cells: D1.5 478, D4.1 362, D4.2 5; 1 frozen change awaiting decision: COL `SPI.D5.5.DIFI` 2024 0 to 1) |
| V13 | 8 | Release lock and ODIN-swap rehearsal | passed (sandbox); real lock at approval | all-row rehearsal: lock 104 files; unchanged rerun diff 0; ODIN swap 12,817 cells, 0 outside the ODIN-dependent outputs, marker removed; non-ODIN change blocked by `RELEASE LOCK MISMATCH`; `test-release-lock.R` 28, `test-release-diff.R` 22 |
| V14 | final | Legacy references unchanged | passed | `git diff --stat -- 02_programs/` empty; untracked OECD scripts unchanged since before the brainstorm: SHA-256 `e16f4dfa3d808b803a533e9ca9f5ec05d677201aafaddf39751c0a643ab37ebe` (`oecd_bulk_download.R`), `f1e6c8e8fa024acec16baec2e47a006f1f7160f849c22d1f9c473df9b135fb1a` (`oecd_stats_pull.Rmd`) |
| V15 | final | Documentation updated | passed | user guide, ODIN guide, CHANGELOG, README, and WG report with no source markers; path check plus the Phase 8 references |
| V16 | 7 | E6 correction evidence and differential fixture | passed | E6 impact tables, 2,349-cell fixture verified exactly, and 845-cell attribution with 0 unexplained and 0 pipeline differences |
| V17 | final | Full test suite after the Phase 7 continuation | passed | 1,052 passed, 0 failed, 0 errors, 14 skipped, 206 audited warnings |

## Constraints Check

| ID | Constraint | Status | Check |
|----|------------|--------|-------|
| C1 | Legacy references untouched | passed | V14 |
| C2 | No scoring-rule changes except "Estimated", reviewed E6 country matching, and fixed-order aggregate summation | passed | E6 changes identifiers and fail-loud guards, not indicator thresholds; aggregate order changes only the floating-point order of group means; `index.R` unchanged |
| C3 | 2024 replication exact except E1-E6 | passed (differential; X1) | final replication has the same 1,303 expectations and 13 X1 failures as the post-E5 reference; 2,349 E6 cells are enumerated and verified |
| C4 | Fail loudly | passed | stop conditions tested across collectors, gate, lock and diffs; the ODIN toy file is the only reuse and is labelled provisional (marker, manifest) |
| C5 | No network in tests | passed | injected fetchers and `httr::GET` mocks; offline purl parity |
| C6 | No new packages | passed | `git diff renv.lock` empty |
| C7 | Frozen history unchanged unless approved | enforced; 1 decision pending | vintage diff blocks the COL DIFI 2024 change until approved or resolved |
| C8 | Public data except internal microdata library | passed | user guide: catalogue refresh "World Bank network required" |
| C9 | Creation-date headers on new R files | passed | every untracked `.R` file has `Created:` |

## Remaining Uncertainty

- **Live JMP values versus the May 2025 file**: an ad hoc comparison was not
  conclusive (its keys were not unique). Evidence rests on the exact-port
  calibration (V5) and the vintage diff, which reports the D1.5 changes.
- **D4.1 catalogue refresh** ran live on 2026-10-24: 18,642 requests, 0
  failures (`catalogue_refresh.json`). The new crosswalk and exclusion rows
  await the technical lead's review.
- **D3 parsing warnings** on four series are confined to the unused
  `FootNote` column; the legacy reader behaves identically.
- **Replication-only defects (X1)**: the hard-coded 2024 IMF readers create
  62 duplicate keys in the 2024 harness; the 2025 run is unaffected.
- **Official ODIN file format**: assumed to match `ODIN_2025.csv`;
  `verify_odin_data()` stops on any missing column.
- **The real release lock** is written only at approval; the rehearsal used
  the same code with a sandbox lock.

## Final Status

Phase 7 engineering and evidence work is complete for handover
([handover brief](2026-10-24-spi-202611-handover.md)). This includes the D4.1
refresh, review-candidate retention, revision evidence, E6 correction,
aggregation-order fix, final preview, all-row ODIN rehearsal, and WG report.

The plan stays at Phase 7 until the technical lead completes Step 23:

- review the new D4.1 and ILO config rows;
- attest the 17 blocking sources and the GSBP desk review;
- have the 853 candidates reviewed and the workbooks filled;
- decide on COL `SPI.D5.5.DIFI` 2024;
- run the live estimation;
- write the release lock at approval (Step 24).

Nothing committed.

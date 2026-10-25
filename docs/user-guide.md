# SPI Update User Guide

**For the SPI Technical Lead**

This guide explains how the SPI technical team runs an update using the
collection-first `{targets}` workflow. The collection stage refreshes and
reports source data before the estimation stage produces final outputs.

---

## 1. Overview

The SPI update has two explicit stages:

1. **Collection** runs API-backed collectors, validates manual/external inputs,
  caches raw and normalized artifacts, and writes a status report under
  `01_raw_data/_collection/`.
2. **Estimation** consumes only validated collection artifacts, cleans and
  scores indicators, builds the nested index, and writes final dissemination
  files to `03_output_data/`.

Both stages use the R `{targets}` package. The estimation stage remains
replication-tested against the original R Markdown pipeline (the 2024 vintage
/ "202511"), while the collection stage preserves raw and intermediate source
artifacts for reproducibility.

**Important**: Run collection before estimation. Estimation stops when the
collection status report contains a blocking source issue. Final validated
outputs are written to `03_output_data/`.

### 202611 update identity

The **SPI 202611 update** is the update released in **November 2026**. Its
reference year is **2025**, so `config/params.R` must use:

```r
end_date <- 2025
```

This produces the 2004--2025 SPI span. The `end_date + 1` WDI input for this
update is `01_raw_data/metadata/WDI_metadata_2026.csv`. The previous official
SPI vintage is 202511, with reference year 2024; preserve its approved
`SPI_data.csv` as `01_raw_data/previous_vintages/SPI_data_2024.csv` for the
D5.2 carry-forward inputs.

ODIN is delayed for this update. The previous ODIN vintage may be used only as
an explicitly labelled provisional stand-in: keep `odin_status <-
"provisional"` in `config/params.R`, which writes
`03_output_data/PROVISIONAL_ODIN.md` and records the ODIN file hashes and the
ODIN-dependent columns in `_estimation_manifest.json`. It must be replaced and
the ODIN-dependent outputs rebuilt before the 202611 results are released
(`docs/odin-delayed-update.md`).

### Pipeline structure

The pipeline mirrors the original Rmd structure as a sequence of targets:

| Stage | Targets | Source (original) |
|-------|---------|-------------------|
| Collection | `source_registry`, `pip_collection`, `world_bank_inputs`, `sdg_collection`, `jmp_collection`, `unsdg_collection`, `manual_checkpoints`, `collection_status` | source downloads and collection scripts |
| Parameters | `params`, `iso_codes`, `country_grid` | `01-SPI_data_prep.Rmd` "set-parameters" + "spi_df" |
| Dimension 1.5 | `dim1_5` | "3.1", "aki_3.3", "3.15_debt", "safely_managed_scored", "lfp" |
| ODIN inputs | `odin_files`, `odin_data` | ODIN_2015.csv to ODIN_<end_date>.csv, shared by D2.2 and D4.3 |
| Dimension 2 | `dim2_core` (SDDS, NADA), `dim2_odin` (D2.2), `dim2` | "idds", "online_access", "nada" |
| Dimension 3 | `dim3` | "unstats" |
| Dimension 4 | `dim4_core` (D4.1, D4.2), `dim4_geo` (D4.3), `dim4` | "cs", "crvs", "geo" |
| Dimension 5 | `dim5` | "legislation_governance", "standards_meta", "snau", "naby", "cnin", "cpiby", "hous", "empl", "cgov", "fina", "mony", "gsbp", "msc", "finance" |
| Append + save | `spi_data` | "append" + "save" |
| Index | `spi_index` | `02-SPI_index.Rmd` "data", "index_weights", "index", "saver" |
| Quantiles | `quantiles` | `misc_scripts/SPI_quantiles.R` |
| Treemap | `treemap` | `misc_scripts/SPI_treemap.R` |
| Databank | `databank` | `misc_scripts/databank.R` |
| SPL admin | `spl_admin` | `misc_scripts/` (ASPIRE) |
| Vintage diff | `previous_vintage_file`, `vintage_diff_approvals_file`, `vintage_diff` | revision-policy check (section 3) |
| Release lock | `release_lock_verification`, `release_diff` | provisional-to-final checks (`docs/odin-delayed-update.md`) |
| Promotion | `output_manifest` (with `odin_status`) | complete output set to `03_output_data/` |
| Collection | `pip_collection`, `world_bank_inputs`, `sdg_collection`, `jmp_collection`, `unsdg_collection`, `manual_checkpoints`, `collection_status` | see section 5 |

## 2. Prerequisites

- R version 4.6.1 (see `renv.lock`)
- The renv environment restored:
  ```r
  renv::restore()
  ```
- Packages: all packages in `renv.lock` (key ones: `targets`, `tarchetypes`,
  `testthat`, `tidyverse`, `wbstats`, `haven`, `httr`, `readr`, `validate`,
  `jsonlite`, `readxl`, `stringr`, `tidyr`, `purrr`, `zoo`, `magrittr`,
  `here`, `dplyr`)

## 3. How to Run the Pipelines

From R, in the project root, run collection first:

```r
targets::tar_make(
  script = "_targets_data.R",
  store = "_targets_data"
)
```

Review the generated reports:

```r
read.csv("01_raw_data/_collection/collection_status.csv")
file.edit("01_raw_data/_collection/collection_status.md")
```

Resolve every `blocking` item before running estimation. Manual source files
(registry rule `manual_attestation`, for example IGME, ILO and the IMF
workbooks) block with `attestation_missing` until the technical lead confirms
the release and records a hash-bound attestation. Editing an attested file
afterwards blocks again with `attestation_hash_mismatch`. Collected sources
(rule `release_identifier`) need a provenance sidecar
(`<artifact>.provenance.json`) written by their collector. Freshness comes from
these records, never from file modification times.

```r
for (f in list.files("R", full.names = TRUE)) source(f)
params <- load_params()
attest_collection_sources(
  c("d1_5_igme", "d1_5_ilo"),
  attested_by = "Technical lead name",
  release_label = "UN IGME 2025; ILOSTAT 2026-10-06 bulk files",
  params = params
)
```

Attestations are written to
`01_raw_data/_collection/source_attestations_<end_date>.csv`. Re-run the
collection pipeline afterwards so the status report reflects them, then run
estimation:

```r
targets::tar_make(
  script = "_targets.R",
  store = "_targets"
)
```

### 202611 run order

1. Run the full test suite (`testthat::test_dir("tests/testthat")`).
2. Run collection (`_targets_data.R`).
3. Refresh the D4.1 catalogue on the World Bank network (see "Catalogue
   refresh" in section 4.4) and rerun collection.
4. Circulate the review package to the reviewers and collect the filled
   review workbooks (see "Review workbooks and candidates" below); check the
   evidence and attest the manual sources (`attest_collection_sources()`).
5. Rerun collection until `collection_status.csv` has no blocking rows and
   `collection_run.json` is complete.
6. Run estimation (`_targets.R`).
7. Read `03_output_data/.candidate/vintage_diff_2025.md`. If frozen history
   changed and the change is intended, record it in the approvals file and
   rerun estimation.
8. Read `revision_summary_2025.md` (revision evidence, below), rerun
   `Rscript docs/revisions/202611/attribute_revisions.R`, and update the
   numbers in `docs/revisions/202611-revision-report.md` for the Working
   Group.
9. Confirm that `03_output_data/PROVISIONAL_ODIN.md` is present before
   circulating the outputs internally.
10. After approval, write the release lock (`write_release_lock()`); in
    December replace ODIN and rerun as described in
    `docs/odin-delayed-update.md`.
11. After the final (official ODIN) release, copy the published
    `03_output_data/SPI_data.csv` and `SPI_index.csv` to
    `01_raw_data/previous_vintages/SPI_data_2025.csv` and
    `SPI_index_2025.csv`; the next vintage compares against them.

The E6 country-matching evidence is generated with
`Rscript docs/revisions/202611/e6_country_matching_impact.R` for both the
202611 preview and the 2024 differential replication. It reports indicator
changes, corrected-country scores and ranks, rank/quintile side effects, and
regional, income and world aggregates. The attribution script must report
zero unexplained cells and zero differences from the pipeline's final step
before the Working Group report is circulated.

### Revision policy and the vintage-diff report

Estimation compares the candidate `SPI_data.csv` with
`01_raw_data/previous_vintages/SPI_data_<end_date - 1>.csv` for 2004 to
`end_date - 1` and writes `vintage_diff_<end_date>.csv` and `.md` next to
the outputs:

| Dimensions | Policy | History changes |
|---|---|---|
| D1.5, D4.1, D4.2 | Refresh and revise history | Reported |
| D2 (SDDS, ODIN, NADA), D3, D4.3, D5 | Freeze history; add `end_date` only | Block promotion unless approved |

D5.1 and D5.5 keep the legacy full-series refresh, so their history may
change; each change needs an approval like any frozen change. Duplicate
country-year keys in the candidate always block. Approvals go in
`01_raw_data/_collection/vintage_diff_approvals_<end_date>.csv` (created
empty by the pipeline) with the columns `indicator`, `iso3c`, `date`,
`reason` and `approved_by`; `*` matches any indicator, country or year, and
every row needs a reason and an approver. The report lists approvals that
match no change.

### Revision evidence for the Working Group

After the vintage diff, the `revision_report` target writes four files next
to the outputs (promoted with them):

| File | Content |
|---|---|
| `revision_summary_<end_date>.md` | readable summary of the three tables below |
| `revision_indicators_<end_date>.csv` | per revised indicator: cells, countries, years, up/down/new/removed, policy and approval status |
| `revision_index_<end_date>.csv` | overall index and pillars for every year of the previous index: previous and revised score, rank and overall-index quintile (rule of `R/quantiles.R`) |
| `revision_new_year_<end_date>.csv` | per indicator in the reference year: coverage, values equal to the previous year (carried-forward sources show "identical"), new and dropped values, provisional ODIN columns |

The index comparison reads the previous published index from
`01_raw_data/previous_vintages/SPI_index_<end_date - 1>.csv`; the run stops
if it is missing. `docs/revisions/202611/attribute_revisions.R` recomputes
the refreshed indicators one input group at a time and attributes every
revised value to its cause (window shift, source update, E4, E5, E6, 2025
workbooks, catalogue refresh); the Working Group report
`docs/revisions/202611-revision-report.md` explains the revisions and the
method and process changes with this evidence.

For the final sandbox preview, run:

```sh
Rscript docs/revisions/202611/attribute_revisions.R --current /tmp/spi-rep/preview-final
Rscript docs/revisions/202611/e6_country_matching_impact.R \
  --before /tmp/spi-rep/preview-pre-e6 \
  --after /tmp/spi-rep/preview-final \
  --label 202611
Rscript docs/revisions/202611/e6_country_matching_impact.R \
  --before /tmp/spi-rep/step16b \
  --after /tmp/spi-rep/step-e6-final \
  --label 2024_replication
```

### Review workbooks and candidates

The collection writes `01_raw_data/_collection/review_candidates_<YEAR>.csv`
(columns `source_id`, `iso3c`, `country`, `current_value`, `reason`,
`evidence_hint`) and summarizes it in `collection_status.md`. The candidates
are informational; overrides go in the per-vintage review workbooks, which are
created once as blank templates and never overwritten:

| Source | Candidates | Review workbook |
|---|---|---|
| D5.2.3 CNIN | not ISIC Rev.4 or NACE Rev.2; historical overrides | `5.2_DISM/D5.2.3.CNIN.Manual.Review.<YEAR>.xlsx` |
| D5.2.8 FINA | blank, other or not found; IMF text mentions GFSM 2014 | `5.2_DISM/D5.2.8.FINA.Manual.Review.<YEAR>.xlsx` |
| D5.2.10 GSBP | no GSBPM evidence | `5.2_DISM/D5.2.10.GSBP.Manual.Review.<YEAR>.xlsx` |
| D5.2.6 EMPL | catalogue countries without an ISO3 code | correct `ilo_sources_catalog.csv` |
| D4.1 | no census/survey, outside the scoring window, catalogue changes the score | `4.1_SOCS/raw/D4.1.Manual.Review.<YEAR>.xlsx` |

CNIN, FINA and GSBP overrides need an entry in the workbook's `Evidence`
column (collection stops with `MANUAL REVIEW OVERRIDE REQUIRES EVIDENCE`
otherwise). Record the source of D4.1 additions in its `Evidence` column as
well.

**Candidate history.** Every collection run regenerates the candidate list.
When the list changes, the previous list is kept unchanged in
`01_raw_data/_collection/review_candidates_history/` as
`review_candidates_<YEAR>.<write time>.<SHA-256 prefix>.csv`, and
`review_candidates_<YEAR>_changes.csv` there records the rows added and
removed per source. Cite the file name (or hash) of the list that was sent
to reviewers, so later changes can be traced; a list already archived is
never copied twice.

**Review package.** Reviewers work from the collection outputs only (not
from new ODIN data or other reviewers' workbooks). For each source, send:

1. the candidate rows for that source (`source_id`), from the current
   `review_candidates_<YEAR>.csv`, with the file name and SHA-256 of the full
   list;
2. the blank review workbook for that source (table above); the
   `current_value` column shows what the pipeline holds now (the
   carried-forward value for CNIN, FINA and GSBP; the recorded years for
   D4.1) and `evidence_hint` where to look;
3. the instructions: confirm or change the value only with evidence a third
   party can check (publication, metadata page or catalogue entry, with a
   link and access date) in the `Evidence` column; leave countries without
   evidence blank (the carried-forward value stands); never edit the
   candidate list.

Place the returned workbooks at the paths in the table, rerun collection,
and attest the reviewed sources (`d5_2_cnin_review`, `d5_2_fina_review`,
`d5_2_10_gsbp_review`) once the evidence is checked. A workbook edited after its
attestation blocks again (`attestation_hash_mismatch`).

To inspect either graph:

```r
targets::tar_manifest(script = "_targets_data.R")
targets::tar_manifest(script = "_targets.R")
```

This repository is not an R package, so run the tests with:

```r
testthat::test_dir("tests/testthat")
```

The collection target store and estimation target store are separate. Target
caching does not replace the source-specific freshness checks in the collection
status report.

To run a single target (e.g. after changing one indicator):

```r
targets::tar_make(dim3)      # rebuild only dim3 and its dependents
```

## 4. Step-by-Step SPI Update

The update steps below come from the "Update steps" tab of `SPI updates.xlsx`
and the original Rmd comments. Each indicator's source and update procedure
is documented in its section.

### 4.1 Before starting

Run the collection pipeline and review `01_raw_data/_collection/` before
starting the estimation stage. The registry in `config/source_registry.R`
identifies whether each source is API-backed, manual, external, or unavailable.
Each report row includes the expected vintage rule, age warning, artifact path,
status, and analyst action.

1. Run the collection pipeline. To refresh the D4.1 catalogue, set
   `run_downloads <- TRUE` in `config/params.R`, run
   `targets::tar_make(names = "d41_catalogue_collection",
   script = "_targets_data.R", store = "_targets_data")`, then restore
   `run_downloads <- FALSE` and rerun collection. Do not run the legacy
   catalogue notebook directly.
2. Download the new CLASS file:
   `https://databankfiles.worldbank.org/public/ddpext_download/site-content/CLASS.xlsx`
   and place it in `01_raw_data/misc/CLASS.xlsx`. Rename the old CLASS file with "_VINTAGE".

### 4.2 WDI metadata

Download from the WDI site, rename to be consistent, and place in
`01_raw_data/metadata/WDI_metadata_<YEAR>.csv`.
Source: <https://datacatalog.worldbank.org/int/search/dataset/0037712>

The pipeline reads WDI metadata for years `2016:(end_date + 1)`. The most
recent file (`WDI_metadata_<end_date+1>.csv`) is the one to update.

### 4.3 Indicator updates

| Indicator | Source | Update procedure |
|-----------|--------|------------------|
| 1.5.1 PIP | Povcalnet PIP comparability | Run the collection pipeline; the locked `pipr` package writes `PIP_comparability_latest.csv` and its cached provenance artifact |
| 1.5.2 Child mortality | UN IGME | Use `UN IGME 2025.csv` from childmortality.org and place it in `01_raw_data/1.5_DUIO/` |
| 1.5.3 Debt service | WDI metadata | Use `WDI_metadata_2026.csv` for the 202611 update |
| 1.5.4 Safely managed water | JMP country files ("Data Summary" sheet) | Run through pipeline, save to `1.5_DUIO/Safely_Managed_Water_data.csv` |
| 1.5.5 ILO labor force | ILO ilostat | Use the 2026-10-06 modelled (2WAP) and survey (DWAP) Excel downloads |
| 2.1 SDDS | WDI metadata (IMF) | Automatic via WDI metadata |
| 2.2 ODIN | Open Data Watch | Use the documented provisional stand-in until the 2025 release arrives |
| 2.4 NADA | NSO websites | Run `02_programs/misc_scripts/nada_check.R` |
| 3.x UN SDG | UN SDG database | Confirm the frozen `SDG_indicator_list.csv` methodology input is present, then run collection and review all SDG artifacts and five-year score inputs |
| 4.1 Censuses/surveys | Microdata libraries | Create the eight 2025 current-vintage files and `D4.1.Manual.Review.2025.xlsx` |
| 4.2.3 CRVS | UN SDG data | Refresh both birth and death registration series through the collection pipeline |
| 4.3 Geospatial | ODIN | Same provisional or official ODIN inputs as 2.2 |
| 5.1 Legislation | UN SDG API | Run the collection pipeline; review the cached API artifact |
| 5.2 Standards | WDI metadata + IMF + annual inputs | Copy `SPI_data_2024.csv` to `previous_vintages/`, verify the 2026.10 IMF workbook, and add the 2025 D5.2 files |
| 5.5 Finance | UN SDG API | Run the collection pipeline; review the cached API artifact |

#### 4.3.1 202611 source map

The confirmed source-to-indicator mapping for the November 2026 update is:

| 202611 source or change | SPI indicator(s) | Required action |
|---|---|---|
| `PIP_comparability_latest.csv` and its `pipr` provenance cache | `SPI.D1.5.POV` | Refresh or explicitly verify the accepted PIP release |
| `UN IGME 2025.csv` | `SPI.D1.5.CHLD.MORT` | Validate the detailed IGME metadata file and run the checkpoint |
| `WDI_metadata_2026.csv` | `SPI.D1.5.DT.TDS.DPPF.XP.ZS`, `SPI.D2.1.GDDS`, the WDI CRVS supplement, and WDI-backed D5.2 inputs | Preserve the raw file and run the WDI checkpoint |
| JMP country downloads and `Safely_Managed_Water_data.csv` | `SPI.D1.5.SAFE.MAN.WATER` | Run the JMP collector; the normalized output must retain country codes |
| ILO 2WAP and DWAP Excel files dated 2026-10-06 | `SPI.D1.5.LFP` | Validate both files, filters, source labels, and coverage |
| UN SDG series collection (scope set by the frozen indicator list) | `SPI.D3.1.*` through `SPI.D3.17.*` (D3.14 excluded) | Confirm the indicator list is present, collect raw/normalized/availability files, and build the five-year score input |
| UN SDG CRVS series | `SPI.D4.2.3.CRVS` | Refresh both birth and death registration inputs |
| Microdata library extracts and manual review | `SPI.D4.1.*` | Produce all eight 2025 CSVs and the 2025 review workbook |
| IMF compiled workbook plus D5.2 annual files | `SPI.D5.2.*` | Verify the IMF workbook, previous-vintage baseline, and current-year annual files |
| ODIN 2024 carry-forward, pending official 2025 release | `SPI.D2.2.*`, `SPI.D4.3.GEO.*` | Use only as provisional input; replace before final release |

The ILO Excel reader and checkpoint, the configurable IGME checkpoint, and the
JMP country-code normalization are collection-pipeline changes supporting these
inputs; they do not introduce additional SPI indicators.

### 4.4 Detailed source instructions

#### 1.5.1 PIP (poverty comparability)

- **Source**: World Bank Povcalnet PIP comparability metadata.
- **File**: `01_raw_data/1.5_DUIO/PIP_comparability_latest.csv`
- **Update**: Run the collection pipeline. The locked `pipr` package writes
  this normalized file and a cached raw/provenance artifact. If PIP changes
  its schema or is unavailable, collection reports a blocking action.
- **Required columns**: `survey_acronym`, `country_code`, `year`,
  `survey_comparability`, and `survey_coverage`. `year` must be numeric, and
  country/year/survey rows must be unique. The estimator excludes the `CPHS`
  survey for `IND` because it is not produced by the statistical system.

#### 1.5.2 Child mortality (UN IGME)

- **Source**: <https://childmortality.org>
- **File**: `01_raw_data/1.5_DUIO/UN IGME 2025.csv`
- **Choose the detailed metadata CSV**, not a country-rates workbook,
  report-only spreadsheet, or a summary table. The filename above is the
  filename expected by the pipeline; rename the downloaded file only after
  verifying that its contents match the checklist below.
- **Required columns** (exact raw names, including spaces and capitalization):
  `Indicator`, `Sex`, `Observation Status`, `Series Year`, `REF_DATE`,
  `Geographic area`, and `OBS_VALUE`. The file may contain additional UN IGME
  metadata columns; do not delete them before running the pipeline.
- **Required records**: the file must contain rows where
  `Indicator == "Under-five mortality rate"`, `Sex == "Total"`, and
  `Observation Status == "Included in IGME"`. The reader uses the first four
  characters of `Series Year` and `REF_DATE` as years, so both fields must
  contain year-like values. `OBS_VALUE` must be numeric.
- **Country matching**: `Geographic area` is joined to the `country` column in
  `01_raw_data/metadata/iso_codes.csv`; retain the published country names.
  Côte d'Ivoire is handled by an explicit `CIV` mapping in the code.
- **Update**: Download the current UNICEF CME file with the wealth-quintile
  metadata, verify the columns and record values above, save it under the
  expected filename, and rerun collection. The checkpoint stops with a schema
  error if a different IGME download is selected.

#### 1.5.3 Debt service (WDI)

- **Source**: WDI metadata.
- **File**: `01_raw_data/metadata/WDI_metadata_<end_date+1>.csv`.
- **Required columns**: `Country Code`, `Income Group`, `External debt Reporting status`,
  and `National accounts reference year`. Some vintages use `Code` instead of
  `Country Code`; preserve the raw file and let the reader normalize it.
- **Update**: Download the metadata file for `end_date + 1`, preserve all
  columns, and run the collection checkpoint.

#### 1.5.4 Safely managed water (JMP)

- **Source**: WHO/UNICEF JMP country files
  (`https://washdata.org/data/country/<ISO3>/household/download`), sheet
  "Data Summary". Kosovo uses the Serbia file.
- **File**: `01_raw_data/1.5_DUIO/Safely_Managed_Water_data.csv`
- **Update**: Run the collection pipeline. For each country it downloads the
  workbook, caches only the "Data Summary" sheet (every cell as text) in
  `01_raw_data/1.5_DUIO/raw/jmp/` with the workbook URL, SHA-256 and release
  stamp in the provenance record, and discards the workbook. It then applies
  the original `hyper_read()` method (`01-SPI_data_prep.Rmd`, chunk
  `safely_managed`) unchanged and records the JMP release in the output's
  provenance sidecar.
- **Required normalized columns**: `iso3c`, `geo`, `year`, and `data_quality`.
  The collector also preserves `source`, `type`, `data_available`,
  `data_value`, and `max_value`. `geo` must contain the `Rural`, `Urban`, or
  `National` categories used by the score.
- **Known behaviours of the current method** (kept for comparability; see
  `docs/jmp-safely-managed-water-brief.md`):
  - D1: the coverage rule credits every year when an area's highest value
    is at least 99.5 or at most 0.5. Areas without data are coded -99, so
    they receive the same credit; a country with no JMP sources scores 1.
  - D2: national columns are recognised by the `_n` suffix, but most JMP
    files now label national totals `_t`, so national values are not read.
    Because of D1, every country still receives national credit (at least
    0.5).

  Correcting both would change 52 countries in 2024. That correction is a
  separate methodology decision, recorded on the roadmap.

#### 1.5.5 ILO labor force

- **Source**: ILO ILOSTAT bulk explorer.
- **Current files**: `01_raw_data/1.5_DUIO/EAP_2WAP_SEX_AGE_RT_A-20261006T1235.xlsx`
  (modelled) and `EAP_DWAP_SEX_AGE_RT_A-20261006T1234.xlsx` (survey).
  For future vintages, retain the same 2WAP/DWAP filename pattern with the
  download timestamp.
- **Update**: Download from
  <https://www.ilo.org/shinyapps/bulkexplorer2/>. Filter sex = Total,
  classif1 = Age (Youth, adults): 15+. Update the filename in BOTH
  `R/dim1_5.R` (`read_ilo_lfp()`) and `R/pull_ilo.R`
  (`checkpoint_ilo_lfp()`). CSV exports with the same columns remain supported.
- **Required columns in both files**: `sex.label`, `classif1.label`,
  `ref_area.label`, `time`, and `obs_value`. Select `sex.label = Total` and
  `classif1.label = Age (Youth, adults): 15+`. The 2WAP file must be the
  `ILO - Modelled Estimates` source; the DWAP file is the survey-source file
  and its `source.label` values identify records such as `LFS - ...`.

#### 2.1 SDDS

- **Source**: WDI metadata (IMF data dissemination standard).
- **Update**: Automatic via the WDI metadata file.

#### 2.2 ODIN

- **Source**: Open Data Watch.
- **File**: `01_raw_data/2.2_DSOA/ODIN_<YEAR>.csv`
- **Update**: Download from <https://odin.opendatawatch.com>. Select
  Data > Select All regions/countries/years > Show standard scores > csv
  output > data categories as rows > Include subscores.
- **Required raw columns**: `Country Code`, `Year`, `Data categories`,
  `Openness subscore`, `Machine readable`, `Non-proprietary`,
  `Download options`, `Metadata available`, and `Terms of use`. The reader
  keeps the `All Categories` row and converts the score columns to numeric.

#### 2.4 NADA

- **Source**: National statistical office websites.
- **File**: `01_raw_data/2.4_DSDS/D2.4.NADA.<YEAR>.csv`
- **Update**: The collection target reads the previous vintage, checks the
  `NADA_text` URLs, and writes the current-vintage file only after the current
  review workbook has been validated. Run:
  `targets::tar_make(names = "nada_output", script = "_targets_data.R",
  store = "_targets_data")`.
- **Manual review**: Complete
  `D2.4.NADA.Manual.Review.<YEAR>.xlsx` before running the current target.
  It must contain `iso3c`, `country`, `NADA`, `NADA_text`, and `Evidence`.
  Blank value cells mean no override; every non-blank override requires an
  evidence note. Country keys must match the current World Bank country
  metadata.
- **URL evidence**: The target writes
  `2.4_DSDS/collection/D2.4.NADA.url_evidence.<YEAR>.csv` and reuses it while
  fresh. Set `refresh_nada_urls <- TRUE` in `config/params.R` to force a new
  check. The evidence records URL, HTTP status, transport errors, timestamp,
  and retry count.
- **Failure handling**: HTTP errors, timeouts, missing URLs, incomplete
  evidence, and duplicate keys do not prove that a NADA catalogue is absent.
  Positive values with unresolved URL evidence block collection and require an
  explicit manual-review value. The pipeline does not silently auto-zero them.
- **Provenance**: The target writes
  `2.4_DSDS/collection/D2.4.NADA_manifest_<YEAR>.json`, which records the
  input/output hashes, review hash, evidence hash, overrides, and warnings.
  The collection status gate validates these hashes before estimation.
- **Legacy script**: `02_programs/misc_scripts/nada_check.R` is retained as a
  historical reference. It is not the reproducible collection entry point.
- **Required output columns**: `iso3c`, `NADA`, and `NADA_text`. Keep
  `NADA_text` because it is used for databank footnotes; the generated file
  also carries URL-check evidence columns for provenance.

#### 3.x UN SDG data products

- **Source**: UN SDG database (DataCSV endpoint), blended with the OECD SDG
  database.
- **Files**: raw per-series responses (Tier-1 series only) cached under
  `01_raw_data/3_DP/sdg_data/raw/`; the OECD scores at
  `01_raw_data/oecd_data/OECD_data_scored.csv` (written by the
  `oecd_collection` target from the cached bulk download in
  `01_raw_data/oecd_data/raw/`, a port of `oecd_bulk_download.R`); and the
  current year's scores at `01_raw_data/3_DP/<end_date>/SPI_D3_UNSD_data_5yr.csv`.
  Earlier year folders are frozen published inputs and are never rewritten.
- **Method**: a port of `02_programs/misc_scripts/un_stats_cleaning.Rmd`
  (`un_pull()`, the OECD blend, the country-year grid fill and `un_aki_fun()`
  with the 5-year window), checked against the unmodified Rmd code. A series
  listed under several goals or indicators counts under each of them.
- **Indicator list (methodology input)**:
  `01_raw_data/metadata/SDG_indicator_list.csv` is not produced by the SPI and
  is not refreshed each vintage. It defines which SDG series are scored
  (`code1`, Tier 1 via `Tier_Nov2020`) and maps each series to its `goal`. It
  is kept fixed so scores stay comparable over time; change it only as a
  deliberate, documented methodology revision.
- **Update**: Run collection only after the indicator list is present. A
  missing list is a blocking source issue and estimation will stop.

#### 4.1 Censuses and surveys

- **Source**: National microdata libraries.
- **Collection ownership**: the SPI technical lead runs the collection and
  country economists review the source evidence and record adjustments in the
  manual-review workbook. The Excel structures are preserved unchanged.
- **Manual input workbooks**: update the eight files under
  `01_raw_data/4.1_SOCS/raw/input/`:
  `D2.1.CEN.POPU.xlsx`, `D2.2.CEN.AGRI.xlsx`, `D2.3.CEN.BIZZ.xlsx`,
  `D2.4.SVY.HOUS.xlsx`, `D2.5.SVY.AGRI.xlsx`, `D2.6.SVY.LABR.xlsx`,
  `D2.7.SVY.HLTH.xlsx`, and `D2.8.SVY.BIZZ.xlsx`.
- **Manual review**: update
  `01_raw_data/4.1_SOCS/raw/D4.1.Manual.Review.<YEAR>.xlsx`. Country-
  economist adjustments in this workbook are the authoritative additive
  evidence layer: reviewed values are merged with source evidence and do not
  silently replace it. Provenance and review counts are recorded in the
  collection manifest rather than by changing the workbook layout.
- **Files**: `01_raw_data/4.1_SOCS/raw/D4.1.*.<YEAR>.csv` (8 files, where
  `<YEAR>` is the vintage year, e.g. `D4.1.1.CEN.POPU.2025.csv` for 202611). The
  pipeline reads the files for the CURRENT vintage (`end_date` in
  `config/params.R`) and fails loudly if they are missing.
- **Manual review**: `01_raw_data/4.1_SOCS/raw/D4.1.Manual.Review.<YEAR>.xlsx`
  (one per vintage; the current vintage file is required, historical files
  are read when present).
- **Update**: The collection target validates the eight current-vintage
  workbook CSVs and the manual review workbook, normalizes the catalogue
  companions, and writes the D4.1 manifest. The catalogue refresh is
  opt-in and uses the cached adapter described above. The ILO Survey Catalog
  is replayed from its final retired snapshot; the current ILO national
  sources catalogue is used for D4.1 labour-force surveys and for the EMPL
  builder in `R/collect_d5_2.R`. Update the configured ILO catalogue input
  and rerun the collection target rather than running the legacy notebooks.
- **Targets collection**: the collection pipeline now validates the eight
  workbooks and review workbook, runs the parameterized D4.1 preprocessing,
  validates the D4.1 catalogue companion files, and writes
  `01_raw_data/4.1_SOCS/collection/D4.1_collection_manifest.json`. Run the
  focused collection target with:

  ```r
  targets::tar_make(
    names = "d41_manifest",
    script = "_targets_data.R",
    store = "_targets_data"
  )
  ```

  The generated manifest is a blocking estimation input. A changed workbook,
  review file, `end_date`, or preprocessing function invalidates the derived
  artifacts. Missing files, invalid sheets or columns, duplicate country keys,
  missing country metadata, stale derived files, and invalid companion files
  stop the collection run with an action for the technical lead.
- **Workbook checks**: year values must be comma-separated four-digit years
  (census workbooks may also say `Register based census`), and each workbook
  must still list every country of the previous year's derived CSV
  (`D4.1.*.<YEAR - 1>.csv`). Other text (for example `c. 2015` or
  `2011; 2021`) or a dropped country stops preprocessing; correct the
  workbook.
- **Catalogue companions**: D4.1 uses files such as
  `01_raw_data/4.1_SOCS/D4.1.*_NADA.csv` as catalogue evidence for the eight
  census/survey indicators. These are distinct from the Dimension 2.4
  `D2.4.NADA.<YEAR>.csv` indicator. Existing companions are validated by
  default; programmatic refresh is an explicit external/opt-in operation and
  must complete before the manifest can pass.
- **Catalogue refresh** (World Bank network required): with
  `run_downloads <- TRUE`, the `d41_catalogue_collection` target runs
  `02_programs/misc_scripts/microdata_library_pull.Rmd` unchanged in a
  separate R process, with its output redirected to a staging folder
  (`01_raw_data/4.1_SOCS/collection/staging-*`, removed afterwards). The
  refreshed files replace the previous ones only when all eight companions
  were produced and pass the normalization rules below; a failure, or a run
  longer than `d41_catalogue_budget_minutes` (default 240), leaves the
  previous set in place. The script writes seven companions; it never writes
  `D4.1.2.CEN.AGRI_NADA.csv` (agricultural censuses; it writes the FAO list to
  `D4.1.2.CEN.AGRI_NADA_FAO.csv`, which the estimation does not read), so that
  file is carried forward unchanged and recorded as `carried_forward` (last
  changed February 2024). Run only this target, then set `run_downloads`
  back to `FALSE` and rerun the collection:

  ```r
  # config/params.R: run_downloads <- TRUE
  targets::tar_make(names = "d41_catalogue_collection",
                    script = "_targets_data.R", store = "_targets_data")
  # config/params.R: run_downloads <- FALSE
  targets::tar_make(script = "_targets_data.R", store = "_targets_data")
  ```

- **Catalogue prefetch**: the script requests one metadata page per study in
  the internal World Bank library (16,852 studies in October 2026) and the
  FAO library, one at a time, about 8.5 hours, and wraps each request in
  `possibly()`, so a failed request would silently become a blank series
  label. Before the script runs, the collection therefore requests exactly
  the URLs the script builds (three catalogue searches, then every detail
  page they list) with `d41_catalogue_connections` (8) concurrent
  connections, about 65 minutes, and serves them to the unmodified script
  from a cache (`R/collect_dim4_1_prefetch.R`):
  - Every response is indexed in
    `4.1_SOCS/collection/catalogue_cache/catalogue_fetch_index.csv`
    (versioned): URL, HTTP status, attempts, time, size and SHA-256. The
    bodies (`responses/*.json.gz`, about 130 MB, not versioned) can be
    deleted once the refresh is accepted; the index keeps their hashes.
  - A study the catalogue does not hold (HTTP 400 `IDNO-NOT-FOUND`, HTTP 404)
    is requested twice, listed in the index as `not_found`, and gets the
    legacy blank. Any other failure (network error, other HTTP status, a
    response that is not JSON) is retried up to `d41_catalogue_max_attempts`
    (4) times; if it persists, the refresh stops before the script runs and
    `catalogue_fetch_failures.csv` lists every failed URL. Rerunning the
    target retries only the failed and missing requests; responses younger
    than `d41_catalogue_cache_max_age_days` (7) are reused.
  - Each search must return every study it reports. The public library now
    answers page sizes above its cap with an empty result; that list feeds no
    D4.1 companion, so the gap is recorded as a non-blocking row
    (`blocking = FALSE`) in the failure log with the true study count. An
    incomplete internal or FAO search stops the refresh.
  - The PIP survey metadata the script reads with `readLines()` is fetched
    and cached the same way. A request the script makes outside the cache is
    logged, and a failure there stops the refresh even though `possibly()` hid
    it from the script; an error inside the script is also written to
    `catalogue_fetch_failures.csv` (`source = legacy_script`).
  - **Retired source**: the ILO Survey Catalog (one of the script's three
    labour force survey sources) was permanently retired in 2026 (HTTP 410
    notice pointing to ILOSTAT). Its final snapshot,
    `4.1_SOCS/retired/ilo_survey_catalog_final_2026-10-20.csv` (1,705
    studies; byte-identical to the October 2025 download; provenance in the
    `.provenance.json` next to it), is replayed to the script page by page,
    so no recorded survey is lost. Before each refresh the endpoint is
    checked: if it no longer shows the retirement notice, the refresh stops
    (`AVAILABLE AGAIN` or `COULD NOT CONFIRM`) so that live data is not
    hidden.
  - The refresh record (script hash, endpoints, timing, prefetch counts,
    companion rows and hashes) is written to the manifest
    (`catalogue$refresh`) and to `4.1_SOCS/collection/catalogue_refresh.json`;
    later runs without a refresh carry it as `catalogue$last_refresh`, with
    `matches_current_companions` false if a companion was changed afterwards.
- **New catalogue names**: a refreshed catalogue can bring names the
  crosswalk does not know. Normalization lists every unknown name of every
  companion in one error; the October 2026 refresh added the World Bank API
  names `Naoero`, `Curacao` and `Puerto Rico (US)` (used by the script for
  PIP survey rows) to the crosswalk and excluded `Cook Island` (non-economy)
  and `Serbia and Montenegro` (former state union of two current economies).
- **Studies dated after the reference year**: a catalogue pulled after the
  reference year lists studies that started later (for example 2026 labour
  force surveys in an October 2026 pull). As in the legacy scoring they never
  count for an earlier reference year; they are kept and counted
  (`after_end_date` in the manifest). Dates more than two years after
  `end_date` stop collection as a likely parsing error.
- **Legacy FAO filter**: the script keeps FAO studies with
  `created <= 2023`. `created` is text ("2024/04/09 09:46:19"), so the
  comparison keeps only studies catalogued in 2022 or earlier. This legacy
  behaviour is kept for 202611; its effect is reported in the 202611
  revision report (`docs/revisions/202611-revision-report.md`).
- **Country names follow CLASS.xlsx**: the collection normalizes each raw
  companion (kept unchanged) to
  `01_raw_data/4.1_SOCS/collection/D4.1.*_NADA.iso3c.csv` with the ISO3 code
  and the CLASS economy name, and estimation joins these files by ISO3 code.
  Names are matched against `01_raw_data/misc/CLASS.xlsx` ("List of
  economies") and `config/d41_country_crosswalk.csv` (catalogue spellings
  such as `Republic of Cabo Verde`). Entries that are not economies are
  dropped only when listed in `config/d41_companion_exclusions.csv` with a
  category (`non_economy`, `multi_country_study`, `blank_country`) and a
  reason; the D4.1 manifest records every exclusion with its row count and
  years, plus the hashes of the three naming files. Any other unmatched
  name stops collection with `UNKNOWN COUNTRY NAME(S)`: add a crosswalk row
  for an economy, or an exclusion row for a non-economy, then rerun
  `d41_manifest`.
- **Economist-review candidates**: the collection writes D4.1 rows (source
  id = indicator stem, for example `D4.1.4.SVY.HOUS`) to
  `01_raw_data/_collection/review_candidates_<YEAR>.csv`: countries with no
  census or survey recorded, countries whose latest census is more than 10
  years old (register-based censuses excepted) or whose latest survey is
  outside the 12-year window, and countries where catalogue evidence alone
  changes the score. Record confirmed additions with evidence in
  `D4.1.Manual.Review.<YEAR>.xlsx`; the list is informational and does not
  block collection.
- **Required CSV structure**: each current-vintage file must contain `iso3c`
  and its indicator-specific year field (for example `POP.CENSUS`, `AGRI.CENSUS`,
  `BIZZ.CENSUS`, `HOUS.SVY`, `AGRI.SVY`, `LABR.SVY`, `HLTH.SVY`, or
  `BIZZ.SVY`). The corresponding `D4.1.Manual.Review.<YEAR>.xlsx` must contain
  `iso3c` and the same indicator columns. Raw NADA companion files must
  contain `country`, `indicator_date`, `nada_dates`, and `nada_title`; the
  normalized companions add `iso3c` and carry the CLASS `country` name.

#### 4.2.3 CRVS

- **Source**: UN SDG data.
- **Update**: Run the collection pipeline; it caches the UN SDG response and
  writes the normalized CRVS artifact.
- **Required normalized columns**: `iso3c`, `date`, and `Value` in both
  `SG_REG_BRTH90N.csv` and `SG_REG_DETH75N.csv`. The estimator uses `Value`
  for the birth and death registration completeness indicators.

#### 4.3 Geospatial

- **Source**: ODIN (same file as 2.2).

#### 5.1 Legislation

- **Source**: UN SDG API (series SG_STT_FPOS).
- **File**: `01_raw_data/5.1_DILG/SG_STT_FPOS.csv`
- **Update**: Run the collection pipeline; it caches the UN SDG response and
  writes `SG_STT_FPOS.csv`.

#### 5.2 Standards

- **Source**: WDI metadata + IMF.
- **202611 reference**: set `end_date <- 2025`, retain
  `WDI_metadata_2026.csv`, and copy the approved 202511 output to
  `01_raw_data/previous_vintages/SPI_data_2024.csv`.
- **IMF input**: place `2026.10_Compiled Data for World Bank - Sep 2026 - Final.xlsx`
  in `01_raw_data/5.2_DISM/`. This is the IMF workbook for the 202611 release
  using 2025 as the reference year, so `config/params.R` must set
  `end_date <- 2025` and the same filename in `imf_file`.
- **Historical IMF inputs**: retain `2020.11.04_Compiled Data for World Bank.xlsx`
  for 2020, `2022.10_Compiled Data for World Bank.xlsx` for 2021-2022,
  `2024.02_Compiled Data for World Bank.xlsx` for 2023, and
  `2025.10_Compiled Data for World Bank.xlsx` for 2024. The latter is configured
  as `imf_file_2024`; it must not be replaced by the current workbook.
- **Validated IMF sheets**: the collection checkpoint requires `2. CPI Reference
  Period` (header row after `skip = 2`), `2. Household Consump Class`,
  `3. COICOP Month_Last Change` (header row after `skip = 3`),
  `4. Cntrl Gct Acct Status` (header row after `skip = 9`), and
  `6. MFS Compilation status`. Release-date columns are identified from their
  `As of ...` headers rather than hard-coded month names.
- **IMF-backed indicators**: the workbook supplies D5.2.4, D5.2.5, D5.2.7,
  and D5.2.9 for the 2025 reference-year observation only. Historical years
  remain sourced from the previous vintage or their year-specific historical
  IMF workbooks.
  Run the collection checkpoint before estimation; it fails loudly when the
  exact filename, sheet, or required header is missing.
- **Annual inputs**: create the current-vintage D5.2.3, D5.2.6, D5.2.8, and
  D5.2.10 files for 2025, plus any required reviewed metadata.
- **Update**: the D5.2 indicators combine previous-vintage values with WDI,
  IMF, and annual source inputs; do not overwrite the previous-vintage file.

#### 5.5 Finance

- **Source**: UN SDG API (series SG_STT_NSDSFND).
- **File**: `01_raw_data/5.5_DIFI/SG_STT_NSDSFND.csv`
- **Update**: Run the collection pipeline; it caches the UN SDG response and
  writes the normalized finance artifact.

### 4.5 Next steps (after data prep)

The original Rmd sequence (01 → 02 → 03) maps to the pipeline targets:

| Original step | Pipeline target | Produces |
|---------------|-----------------|----------|
| 1. `01_SPI_data_prep.Rmd` | `spi_data` | `03_output_data/SPI_data.csv`, `SPI_data.dta` |
| 2. `02_SPI_index.Rmd` | `spi_index` | `03_output_data/SPI_index.csv` |
| 3. `03_SPI_data_validation.Rmd` | tests | validation + vintage comparison |
| 4. `misc_scripts/SPI_quantiles.R` | `quantiles` | `03_output_data/SPI_quantiles*.csv`, `SPI_indicators_<YEAR>.csv` |
| 5. `misc_scripts/SPI_treemap.R` | `treemap` | `03_output_data/SPI_treemap.csv` |
| 6. `misc_scripts/databank.R` | `databank` | `03_output_data/SPI_databank_*.csv` |
| 7. `misc_scripts/` (ASPIRE) | `spl_admin` | `03_output_data/SPL_admin_data_availability.csv` |

After collection passes its status gate, run estimation and review the final
outputs in `03_output_data/`. The estimation target refuses to proceed while
blocking collection issues remain.

## 5. Data Pulls and Manual Checkpoints

The collection command runs API collectors and manual/external checkpoints
together. It writes the machine-readable status file and human-readable report
under `01_raw_data/_collection/`. Review every `blocking` row before running
estimation; `warning` and `informational` rows remain visible for analyst QA.

### 5.1 Manual download checkpoints

The collection target `manual_checkpoints` (`run_collection_checkpoints()`)
verifies that manually downloaded source files are present and schema-valid.
It runs with every collection run and **fails loudly** (R8) with download
instructions when a file is missing or the format changed:

```r
targets::tar_make(script = "_targets_data.R", store = "_targets_data")
```

| Check | Source | Expected file | Download instructions |
|--------|--------|---------------|----------------------|
| `checkpoint_wdi_metadata()` | WDI catalog | `01_raw_data/metadata/WDI_metadata_<YEAR>.csv` | <https://datacatalog.worldbank.org/int/search/dataset/0037712> |
| `checkpoint_ilo_lfp()` | ILO bulk explorer | `01_raw_data/1.5_DUIO/EAP_2WAP_SEX_AGE_RT_A-20261006T1235.xlsx` + `EAP_DWAP_SEX_AGE_RT_A-20261006T1234.xlsx` | <https://www.ilo.org/shinyapps/bulkexplorer2/> (modelled + survey, sex=Total, age 15+) |
| `verify_odin_data()` | Open Data Watch | `01_raw_data/2.2_DSOA/ODIN_<YEAR>.csv` | <https://odin.opendatawatch.com> |
| `nada_output` target | NSO websites | `01_raw_data/2.4_DSDS/D2.4.NADA.<YEAR>.csv` | See section 4.4, 2.4 NADA |
| `d41_manifest` target | Microdata libraries | `01_raw_data/4.1_SOCS/raw/D4.1.*.<YEAR>.csv` (8 files) | See section 4.4, 4.1 Censuses and surveys |
| `verify_unigme_data()` | UN IGME | `01_raw_data/1.5_DUIO/UN IGME 2025.csv` | <https://childmortality.org> |

The IMF workbook check (`checkpoint_imf_workbook()`) also runs here. When a
check fails, read the error message — it contains the exact download
instructions for that source.

## 6. Troubleshooting

### 6.1 A checkpoint fails with "FILE NOT FOUND"

The source file is missing. Read the error message for the exact download
instructions, download the file, and re-run the checks:

```r
targets::tar_make(
  names = "manual_checkpoints",
  script = "_targets_data.R",
  store = "_targets_data"
)
```

### 6.2 A checkpoint fails with "SCHEMA MISMATCH"

The source file format has changed (e.g. ILO renamed a column, ODIN changed
its layout). The pipeline refuses to proceed because the estimates would be
wrong. Investigate the source download, update the schema registry in
`config/params.R` (or the checkpoint in `R/checkpoints.R`), and re-run.

### 6.3 An ILO or IGME country is missing from D1.5

The D1.5 readers fail loudly rather than silently scoring an unrecognised
area as zero. For ILO errors of the form `ILO AREA NAMES NOT RECOGNISED`,
check whether the label is an SPI economy. Add an economy to
`config/ilo_area_crosswalk.csv` with its SPI ISO3 code, or record a regional,
income or non-economy area in `config/ilo_area_exclusions.csv`. The config is
validated against `metadata/iso_codes.csv` and the collected SPI country
metadata. For an IGME error of the form `UN IGME AREA CODES NOT RECOGNISED`,
verify the file's `REF_AREA` code and add a reviewed alias to
`unigme_area_code_aliases` in `R/dim1_5.R`; do not add a name-only fallback.
The two ILO config files are tracked by the `ilo_area_names_files` target, so
editing them invalidates D1.5 and its downstream outputs.

### 6.4 The pipeline fails on a source read

Every source read is schema-validated (R8). If a source file is missing or
its format changed, the pipeline stops with a precise report. Fix the source
file and re-run `targets::tar_make()` — targets resumes from the failed
target.

### 6.5 A test fails in the stage-compare suite

The staged output differs from the vintage fixture. Read the failure message
for the exact column and row. Common causes:

- **WB API drift**: metadata columns (country name, income, population,
  GDP) change between vintages because the World Bank API is live. These
  are documented and excluded from the comparison.
- **Floating-point boundary**: a value like 52.95 rounds differently at the
  15th significant digit. The CSV round-trip in the misc_scripts port
  handles this; if a new one appears, investigate the arithmetic order.
- **Vintage artifact**: databank aggregate rows were generated from an
  earlier index vintage. Country-level values are identical.

### 6.6 renv is out of sync

If you see "The project is out-of-sync", run:

```r
renv::status()      # see what changed
renv::snapshot()    # update the lockfile after adding packages
```

### 6.7 The pipeline is slow

The pipeline uses incremental re-runs: `targets::tar_make()` only rebuilds
targets whose inputs changed. The slow steps are the API pulls (JMP ~200
requests) and the microdata library pull — run those explicitly when
updating.

### 6.7 Forcing a rebuild after changing `end_date`

`targets` tracks file hashes, so changing `end_date` in `config/params.R`
invalidates the `params` target and everything downstream. However, some
targets read files whose names do NOT include the year (e.g.
`D2.4.NADA.csv`, `D5.2.6.EMPL.csv`), so targets may not detect that the
underlying data changed. To force a full rebuild:

```r
targets::tar_destroy()   # delete all targets
targets::tar_make()      # rebuild from scratch
```

This is the safest way to guarantee a clean run after a vintage change.
Note that `tar_destroy()` also removes the staged outputs — re-run
`targets::tar_make()` to regenerate them.

### 6.8 Schema mismatch in a dimension source

Each dimension source is validated against its expected schema (R8). If a
source file's format changed (e.g. a new column, a renamed column, a
different type), the pipeline stops with a "SCHEMA MISMATCH" error naming
the file and the missing/expected columns.

To fix:

1. Read the error message — it lists the missing required columns and the
   found columns.
2. Investigate the source download (the format may have changed upstream).
3. If the format change is legitimate, update the schema check in the
   relevant `R/` function (or the `source_schema` registry in
   `config/params.R`).
4. Re-run `targets::tar_make()` — targets resumes from the failed target.

Never bypass a schema check by editing the source file to match the old
format — that hides real format changes and silently breaks the estimates.

### 6.9 Reading the pipeline graph

To see the full dependency graph of the pipeline:

```r
targets::tar_visnetwork()   # interactive graph in the viewer
```

To see which targets are outdated (need rebuilding) and why:

```r
targets::tar_outdated()     # names of outdated targets
targets::tar_manifest()     # why each target is outdated
```

To inspect a specific target's value:

```r
targets::tar_read(params)          # the parameters list
targets::tar_read(spi_data)        # the final SPI data frame
```

The graph is useful for understanding why a change triggers a rebuild: a
target rebuilds when any of its dependencies (files or targets) changed.

## 7. Interpreting Test Results

Run the full suite:

```r
testthat::test_dir("tests/testthat")
```

The suite covers:

| Test file | What it verifies |
|-----------|------------------|
| `test-compare.R` | The comparison harness (1e-9 relative tolerance) |
| `test-fixtures.R` | Vintage fixture integrity + historical-output protection (C7) |
| `test-stage-compare.R` | Staged outputs match the vintage fixtures (SPI_data, SPI_index, quantiles, treemap, databank, SPL admin) |
| `test-validation.R` | `validate::validator()` expectation rules (min/max ranges, country/year coverage) |
| `test-vintage-compare.R` | Vintage comparison + positive correlation checks |
| `test-downloads.R` | Download/checkpoint targets (happy path + fail-loudly) |

**Reading the results**: `testthat` reports `X passed, Y failed, Z skipped`.
A failure message names the test file, the test, and the exact difference
(column, row, new vs vintage value). Fix the underlying cause (section 6.4)
and re-run.

**The replication gate**: the stage-compare and vintage-compare tests are
the gate. They compare only the reproducible value columns — WB-drift
metadata, jitter columns, and databank aggregate rows are documented
exceptions (see the execution report).
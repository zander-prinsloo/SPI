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
an explicitly labelled provisional stand-in. It must be replaced and the ODIN-
dependent outputs rebuilt before the 202611 results are released.

### Pipeline structure

The pipeline mirrors the original Rmd structure as a sequence of targets:

| Stage | Targets | Source (original) |
|-------|---------|-------------------|
| Collection | `source_registry`, `pip_collection`, `world_bank_inputs`, `sdg_collection`, `jmp_collection`, `unsdg_collection`, `manual_checkpoints`, `collection_status` | source downloads and collection scripts |
| Parameters | `params`, `iso_codes`, `country_grid` | `01-SPI_data_prep.Rmd` "set-parameters" + "spi_df" |
| Dimension 1.5 | `dim1_5` | "3.1", "aki_3.3", "3.15_debt", "safely_managed_scored", "lfp" |
| Dimension 2 | `dim2` | "idds", "online_access", "nada" |
| Dimension 3 | `dim3` | "unstats" |
| Dimension 4 | `dim4` | "cs", "crvs", "geo" |
| Dimension 5 | `dim5` | "legislation_governance", "standards_meta", "snau", "naby", "cnin", "cpiby", "hous", "empl", "cgov", "fina", "mony", "gsbp", "msc", "finance" |
| Append + save | `spi_data` | "append" + "save" |
| Index | `spi_index` | `02-SPI_index.Rmd` "data", "index_weights", "index", "saver" |
| Quantiles | `quantiles` | `misc_scripts/SPI_quantiles.R` |
| Treemap | `treemap` | `misc_scripts/SPI_treemap.R` |
| Databank | `databank` | `misc_scripts/databank.R` |
| SPL admin | `spl_admin` | `misc_scripts/` (ASPIRE) |
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

Resolve every `blocking` item before running estimation:

```r
targets::tar_make(
  script = "_targets.R",
  store = "_targets"
)
```

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

1. Run the microdata library pull: `02_programs/misc_scripts/microdata_library_pull.Rmd`
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
| 1.5.4 Safely managed water | JMP washdata API | Run through pipeline, save to `1.5_DUIO/Safely_Managed_Water_data.csv` |
| 1.5.5 ILO labor force | ILO ilostat | Use the 2026-10-06 modelled (2WAP) and survey (DWAP) Excel downloads |
| 2.1 SDDS | WDI metadata (IMF) | Automatic via WDI metadata |
| 2.2 ODIN | Open Data Watch | Use the documented provisional stand-in until the 2025 release arrives |
| 2.4 NADA | NSO websites | Run `02_programs/misc_scripts/nada_check.R` |
| 3.x UN SDG | UN SDG database | Provide the reviewed indicator list, then run collection and review all SDG artifacts and five-year score inputs |
| 4.1 Censuses/surveys | Microdata libraries | Create the eight 2025 current-vintage files and `D4.1.Manual.Review.2025.xlsx` |
| 4.2.3 CRVS | UN SDG data | Refresh both birth and death registration series through the collection pipeline |
| 4.3 Geospatial | ODIN | Same provisional or official ODIN inputs as 2.2 |
| 5.1 Legislation | UN SDG API | Run the collection pipeline; review the cached API artifact |
| 5.2 Standards | WDI metadata + IMF + annual inputs | Copy `SPI_data_2024.csv` to `previous_vintages/`, verify IMF 2025.10, and add the 2025 D5.2 files |
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
| UN SDG indicator list and series collection | `SPI.D3.1.*` through `SPI.D3.4.*` | Provide the reviewed list, collect raw/normalized/availability files, and build the five-year score input |
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

- **Source**: WHO/UNICEF JMP washdata API.
- **File**: `01_raw_data/1.5_DUIO/Safely_Managed_Water_data.csv`
- **Update**: Run the collection pipeline. It downloads and caches the JMP
  country files before writing the normalized combined source file.
- **Required normalized columns**: `iso3c`, `geo`, `year`, and `data_quality`.
  The collector also preserves `source`, `type`, `data_available`, and
  `data_value`. `geo` must contain the `Rural`, `Urban`, or `National`
  categories used by the score.

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
- **Update**: Run `02_programs/misc_scripts/nada_check.R`. It reads last
  year's spreadsheet, checks if each URL returns a valid response, and
  saves. For invalid responses, manually check if the site works with a
  different URL or if the NSO created a new website. The output becomes
  next year's input.
- **Required columns**: `iso3c`, `NADA`, and `NADA_text`. Keep `NADA_text`
  because it is used for databank footnotes.

#### 3.x UN SDG data products

- **Source**: UN SDG database.
- **Files**: raw per-series responses under `01_raw_data/3_DP/sdg_data/raw/`,
  normalized series under `01_raw_data/3_DP/sdg_data/normalized/`, binary
  availability tables under `01_raw_data/3_DP/availability/`, and the
  collection score input at `01_raw_data/3_DP/collection/SPI_D3_UNSD_data_5yr.csv`.
- **Update**: Run collection only after the reviewed
  `01_raw_data/metadata/SDG_indicator_list.csv` is present. A missing list is
  a blocking source issue and estimation will stop.

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
- **Update**: Run the microdata library pull
  (`02_programs/misc_scripts/microdata_library_pull.Rmd`) and the
  preprocess script
  (`02_programs/misc_scripts/preprocess-manual-data-4.1-and-5.2.10.R`),
  which reads the `input/` Excel files and writes the per-year CSVs. For
  the ILO catalog, download `sources_en.csv` from
  <https://ilostat.ilo.org/data/national-sources-catalogue/> and rename to
  `ilo_sources_catalog.csv` in `01_raw_data/`.
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
- **Catalogue companions**: D4.1 uses files such as
  `01_raw_data/4.1_SOCS/D4.1.*_NADA.csv` as catalogue evidence for the eight
  census/survey indicators. These are distinct from the Dimension 2.4
  `D2.4.NADA.<YEAR>.csv` indicator. Existing companions are validated by
  default; programmatic refresh is an explicit external/opt-in operation and
  must complete before the manifest can pass.
- **Required CSV structure**: each current-vintage file must contain `iso3c`
  and its indicator-specific year field (for example `POP.CENSUS`, `AGRI.CENSUS`,
  `BIZZ.CENSUS`, `HOUS.SVY`, `AGRI.SVY`, `LABR.SVY`, `HLTH.SVY`, or
  `BIZZ.SVY`). The corresponding `D4.1.Manual.Review.<YEAR>.xlsx` must contain
  `iso3c` and the same indicator columns. NADA companion files must contain
  `country` plus the indicator date fields used by the matching census/survey
  function.

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
- **IMF inputs**: verify `2025.10_Compiled Data for World Bank.xlsx` for the
  IMF-backed D5.2.4, D5.2.5, D5.2.7, and D5.2.9 indicators.
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

These targets verify that manually-downloaded source files are present and
schema-valid. They run by default and **fail loudly** (R8) with download
instructions when a file is missing or the format changed:

```r
targets::tar_make(script = "_targets_data.R", store = "_targets_data")
```

| Target | Source | Expected file | Download instructions |
|--------|--------|---------------|----------------------|
| `checkpoint_wdi` | WDI catalog | `01_raw_data/metadata/WDI_metadata_<YEAR>.csv` | <https://datacatalog.worldbank.org/int/search/dataset/0037712> |
| `checkpoint_ilo` | ILO bulk explorer | `01_raw_data/1.5_DUIO/EAP_2WAP_SEX_AGE_RT_A-20261006T1235.xlsx` + `EAP_DWAP_SEX_AGE_RT_A-20261006T1234.xlsx` | <https://www.ilo.org/shinyapps/bulkexplorer2/> (modelled + survey, sex=Total, age 15+) |
| `checkpoint_odin` | Open Data Watch | `01_raw_data/2.2_DSOA/ODIN_<YEAR>.csv` | <https://odin.opendatawatch.com> |
| `checkpoint_nada` | NSO websites | `01_raw_data/2.4_DSDS/D2.4.NADA.<YEAR>.csv` | Run `02_programs/misc_scripts/nada_check.R` |
| `checkpoint_microdata` | Microdata libraries | `01_raw_data/4.1_SOCS/raw/D4.1.*.<YEAR>.csv` (8 files) | Run `02_programs/misc_scripts/microdata_library_pull.Rmd` |
| `checkpoint_unigme` | UN IGME | `01_raw_data/1.5_DUIO/UN IGME 2025.csv` | <https://childmortality.org> |

When a checkpoint fails, read the error message — it contains the exact
download instructions for that source.

## 6. Troubleshooting

### 6.1 A checkpoint fails with "FILE NOT FOUND"

The source file is missing. Read the error message for the exact download
instructions, download the file, and re-run the checkpoint:

```r
targets::tar_make(checkpoint_<name>)
```

### 6.2 A checkpoint fails with "SCHEMA MISMATCH"

The source file format has changed (e.g. ILO renamed a column, ODIN changed
its layout). The pipeline refuses to proceed because the estimates would be
wrong. Investigate the source download, update the schema registry in
`config/params.R` (or the checkpoint in `R/checkpoints.R`), and re-run.

### 6.3 The pipeline fails on a source read

Every source read is schema-validated (R8). If a source file is missing or
its format changed, the pipeline stops with a precise report. Fix the source
file and re-run `targets::tar_make()` — targets resumes from the failed
target.

### 6.4 A test fails in the stage-compare suite

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

### 6.5 renv is out of sync

If you see "The project is out-of-sync", run:

```r
renv::status()      # see what changed
renv::snapshot()    # update the lockfile after adding packages
```

### 6.6 The pipeline is slow

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
testthat::test_local()
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
# SPI Update User Guide

**For the SPI Technical Lead**

This guide explains how to run an SPI update using the new `{targets}`
pipeline. It is populated incrementally as the pipeline is built (per the
implementation plan).

---

## 1. Overview

The SPI is produced by an estimation pipeline that:

1. Reads raw data from `01_raw_data/` (one folder per dimension).
2. Cleans and scores each indicator.
3. Builds the nested SPI index (dimension → pillar → overall).
4. Validates the results against the previous vintage.
5. Produces the dissemination files (quantiles, treemap, databank).

The new pipeline uses the R `{targets}` package. It produces **identical
results** to the original R Markdown pipeline (the 2024 vintage / "202511"),
but with incremental re-runs, schema validation, and automated tests.

**Important**: The pipeline writes new outputs to `staging/` and **never
overwrites** the historical outputs in `03_output_data/`.

### Pipeline structure

The pipeline mirrors the original Rmd structure as a sequence of targets:

| Stage | Targets | Source (original) |
|-------|---------|-------------------|
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
| Downloads | `pull_jmp`, `pull_unsdg`, `checkpoint_*` | see section 5 |

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

## 3. How to Run the Pipeline

From R (in the project root):

```r
targets::tar_make()
```

From the terminal:

```bash
Rscript -e "targets::tar_make()"
```

To see the pipeline graph:

```r
targets::tar_manifest()      # list all targets
targets::tar_visnetwork()    # visualize the dependency graph
```

To run the tests:

```r
testthat::test_local()
```

To run a single target (e.g. after changing one indicator):

```r
targets::tar_make(dim3)      # rebuild only dim3 and its dependents
```

## 4. Step-by-Step SPI Update

The update steps below come from the "Update steps" tab of `SPI updates.xlsx`
and the original Rmd comments. Each indicator's source and update procedure
is documented in its section.

### 4.1 Before starting

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
| 1.5.1 PIP | Povcalnet PIP comparability | Download `PIP_comparability_latest.csv` to `01_raw_data/1.5_DUIO/`; QA needed if PIP update delayed |
| 1.5.2 Child mortality | UN IGME | Download from childmortality.org, place in `01_raw_data/1.5_DUIO/` |
| 1.5.3 Debt service | WDI metadata | Automatic once WDI metadata is updated |
| 1.5.4 Safely managed water | JMP washdata API | Run through pipeline, save to `1.5_DUIO/Safely_Managed_Water_data.csv` |
| 1.5.5 ILO labor force | ILO ilostat | Download modelled (2WAP) and survey (DWAP) estimates |
| 2.1 SDDS | WDI metadata (IMF) | Automatic via WDI metadata |
| 2.2 ODIN | Open Data Watch | Download from odin.opendatawatch.com |
| 2.4 NADA | NSO websites | Run `02_programs/misc_scripts/nada_check.R` |
| 3.x UN SDG | UN SDG database | Brian pulls UNSDG results |
| 4.1 Censuses/surveys | Microdata libraries | Run microdata library pull |
| 4.2.3 CRVS | UN SDG data | Download UNSDG data |
| 4.3 Geospatial | ODIN | Same ODIN file as 2.2 |
| 5.1 Legislation | UN SDG API | Script in misc_scripts |
| 5.2 Standards | WDI metadata + IMF | Copy previous vintage's SPI_data.csv to `01_raw_data/previous_vintages/` |
| 5.5 Finance | UN SDG API | Script in misc_scripts |

### 4.4 Detailed source instructions

#### 1.5.1 PIP (poverty comparability)

- **Source**: World Bank Povcalnet PIP comparability metadata.
- **File**: `01_raw_data/1.5_DUIO/PIP_comparability_latest.csv`
- **Update**: Download the latest `PIP_comparability_latest.csv` from
  Povcalnet and place it in `01_raw_data/1.5_DUIO/`. The pipeline reads it
  directly (it does not use the `pipr` package). If the PIP update is
  delayed, QA the comparability file manually.

#### 1.5.2 Child mortality (UN IGME)

- **Source**: <https://childmortality.org>
- **File**: `01_raw_data/1.5_DUIO/UNICEF-CME_DF_2021_WQ-1.0-download.csv`
- **Update**: Download the UNICEF CME data file (with wealth quintile
  breakdown). The latest data for the 2024 version (data up to 2023) was
  released 25 March 2025.

#### 1.5.3 Debt service (WDI)

- **Source**: WDI metadata.
- **Update**: Automatic once the WDI metadata file is updated (section 4.2).

#### 1.5.4 Safely managed water (JMP)

- **Source**: WHO/UNICEF JMP washdata API.
- **File**: `01_raw_data/1.5_DUIO/Safely_Managed_Water_data.csv`
- **Update**: Run the `pull_jmp` target (section 5.1) or download manually
  from <https://washdata.org/data/country/<ISO3C>/household/download> for
  each country.

#### 1.5.5 ILO labor force

- **Source**: ILO ILOSTAT bulk explorer.
- **Files**: `01_raw_data/1.5_DUIO/EAP_2WAP_SEX_AGE_RT_A-<timestamp>.csv`
  (modelled) and `EAP_DWAP_SEX_AGE_RT_A-<timestamp>.csv` (survey).
- **Update**: Download from
  <https://www.ilo.org/shinyapps/bulkexplorer2/>. Filter sex = Total,
  classif1 = Age (Youth, adults): 15+. Update the filename in BOTH
  `R/dim1_5.R` (`read_ilo_lfp()`) and `R/pull_ilo.R`
  (`checkpoint_ilo_lfp()`).

#### 2.1 SDDS

- **Source**: WDI metadata (IMF data dissemination standard).
- **Update**: Automatic via the WDI metadata file.

#### 2.2 ODIN

- **Source**: Open Data Watch.
- **File**: `01_raw_data/2.2_DSOA/ODIN_<YEAR>.csv`
- **Update**: Download from <https://odin.opendatawatch.com>. Select
  Data > Select All regions/countries/years > Show standard scores > csv
  output > data categories as rows > Include subscores.

#### 2.4 NADA

- **Source**: National statistical office websites.
- **File**: `01_raw_data/2.4_DSDS/D2.4.NADA.<YEAR>.csv`
- **Update**: Run `02_programs/misc_scripts/nada_check.R`. It reads last
  year's spreadsheet, checks if each URL returns a valid response, and
  saves. For invalid responses, manually check if the site works with a
  different URL or if the NSO created a new website. The output becomes
  next year's input.

#### 3.x UN SDG data products

- **Source**: UN SDG database (pre-computed by Brian's pipeline).
- **File**: `01_raw_data/3_DP/<YEAR>/SPI_D3_UNSD_data_5yr.csv`
- **Update**: Brian pulls UNSDG results from the UN Stats SDG Indicators
  pipeline and places the file in the year folder.

#### 4.1 Censuses and surveys

- **Source**: National microdata libraries.
- **Files**: `01_raw_data/4.1_SOCS/raw/D4.1.*.<YEAR>.csv` (8 files)
- **Update**: Run the microdata library pull
  (`02_programs/misc_scripts/microdata_library_pull.Rmd`). For the ILO
  catalog, download `sources_en.csv` from
  <https://ilostat.ilo.org/data/national-sources-catalogue/> and rename to
  `ilo_sources_catalog.csv` in `01_raw_data/`.

#### 4.2.3 CRVS

- **Source**: UN SDG data.
- **Update**: Download UNSDG data (birth registration, series
  SG_REG_BRTH90N).

#### 4.3 Geospatial

- **Source**: ODIN (same file as 2.2).

#### 5.1 Legislation

- **Source**: UN SDG API (series SG_STT_FPOS).
- **File**: `01_raw_data/5.1_DILG/SG_STT_FPOS.csv`
- **Update**: Run the `pull_unsdg` target (section 5.1) or Brian's script
  in misc_scripts.

#### 5.2 Standards

- **Source**: WDI metadata + IMF.
- **Update**: Copy the previous vintage's `SPI_data.csv` to
  `01_raw_data/previous_vintages/SPI_data_<YEAR>.csv`. The D5.2 indicators
  (SNA, base years, classifications) come from the WDI metadata and IMF
  data.

#### 5.5 Finance

- **Source**: UN SDG API (series SG_STT_FIN).
- **File**: `01_raw_data/5.5_DIFI/SG_STT_FIN.csv`
- **Update**: Run the `pull_unsdg` target (section 5.1) or Brian's script
  in misc_scripts.

### 4.5 Next steps (after data prep)

The original Rmd sequence (01 → 02 → 03) maps to the pipeline targets:

| Original step | Pipeline target | Produces |
|---------------|-----------------|----------|
| 1. `01_SPI_data_prep.Rmd` | `spi_data` | `staging/SPI_data.csv`, `SPI_data.dta` |
| 2. `02_SPI_index.Rmd` | `spi_index` | `staging/SPI_index.csv` |
| 3. `03_SPI_data_validation.Rmd` | tests | validation + vintage comparison |
| 4. `misc_scripts/SPI_quantiles.R` | `quantiles` | `staging/SPI_quantiles*.csv`, `SPI_indicators_2024.csv` |
| 5. `misc_scripts/SPI_treemap.R` | `treemap` | `staging/SPI_treemap.csv` |
| 6. `misc_scripts/databank.R` | `databank` | `staging/SPI_databank_*.csv` |
| 7. `misc_scripts/` (ASPIRE) | `spl_admin` | `staging/SPL_admin_data_availability.csv` |

After running `targets::tar_make()`, review the staged outputs in
`staging/`, run the tests (section 7), and copy validated outputs to
`03_output_data/` only after review.

## 5. Data Pulls and Manual Checkpoints

The pipeline includes OPT-IN download targets and manual download checkpoints.
They are **not** triggered by a default `targets::tar_make()` — this keeps the
replication gate deterministic (the committed raw files in `01_raw_data/` are
the source of truth for the 202511 vintage).

### 5.1 API pulls (opt-in)

These targets download fresh data from public APIs into `01_raw_data/`. They
only run when `run_downloads <- TRUE` in `config/params.R`:

```r
# config/params.R
run_downloads <- TRUE   # set to TRUE only when updating to a new vintage
```

Then run:

```r
targets::tar_make(pull_jmp)      # JMP washdata (safely managed water)
targets::tar_make(pull_unsdg)    # UN SDG API (legislation, finance, CRVS)
```

| Target | Source | Writes to | Notes |
|--------|--------|-----------|-------|
| `pull_jmp` | JMP washdata API (`washdata.org/data/country/<ISO3C>/household/download`) | `01_raw_data/1.5_DUIO/Safely_Managed_Water_data.csv` | ~200 HTTP requests; takes several minutes |
| `pull_unsdg` | UN Stats SDG API (`unstats.un.org/SDGAPI`) | `01_raw_data/5.1_DILG/SG_STT_FPOS.csv`, `5.5_DIFI/SG_STT_FIN.csv`, `4.2_SOAD/SG_REG_BRTH90N.csv` | Series: SG_STT_FPOS, SG_STT_FIN, SG_REG_BRTH90N |

### 5.2 Manual download checkpoints

These targets verify that manually-downloaded source files are present and
schema-valid. They run by default and **fail loudly** (R8) with download
instructions when a file is missing or the format changed:

```r
targets::tar_make(checkpoint_wdi)        # WDI metadata (manual download)
targets::tar_make(checkpoint_ilo)        # ILO ilostat (bulk explorer)
targets::tar_make(checkpoint_odin)       # ODIN (Open Data Watch)
targets::tar_make(checkpoint_nada)       # NADA check (NSO websites)
targets::tar_make(checkpoint_microdata)  # microdata library pull
targets::tar_make(checkpoint_unigme)     # UN IGME child mortality
```

| Target | Source | Expected file | Download instructions |
|--------|--------|---------------|----------------------|
| `checkpoint_wdi` | WDI catalog | `01_raw_data/metadata/WDI_metadata_<YEAR>.csv` | <https://datacatalog.worldbank.org/int/search/dataset/0037712> |
| `checkpoint_ilo` | ILO bulk explorer | `01_raw_data/1.5_DUIO/EAP_2WAP_SEX_AGE_RT_A-*.csv` + `EAP_DWAP_SEX_AGE_RT_A-*.csv` | <https://www.ilo.org/shinyapps/bulkexplorer2/> (modelled + survey, sex=Total, age 15+) |
| `checkpoint_odin` | Open Data Watch | `01_raw_data/2.2_DSOA/ODIN_<YEAR>.csv` | <https://odin.opendatawatch.com> |
| `checkpoint_nada` | NSO websites | `01_raw_data/2.4_DSDS/D2.4.NADA.<YEAR>.csv` | Run `02_programs/misc_scripts/nada_check.R` |
| `checkpoint_microdata` | Microdata libraries | `01_raw_data/4.1_SOCS/raw/D4.1.*.<YEAR>.csv` (8 files) | Run `02_programs/misc_scripts/microdata_library_pull.Rmd` |
| `checkpoint_unigme` | UN IGME | `01_raw_data/1.5_DUIO/UNICEF-CME_DF_2021_WQ-1.0-download.csv` | <https://childmortality.org> |

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
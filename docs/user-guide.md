# SPI Update User Guide

**For the SPI Technical Lead**

This guide explains how to run an SPI update using the new `{targets}`
pipeline. It is populated incrementally as the pipeline is built (per the
implementation plan). Sections marked *(draft)* are not yet complete.

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

## 2. Prerequisites

- R version 4.6.1 (see `renv.lock`)
- The renv environment restored:
  ```r
  renv::restore()
  ```
- Packages: `targets`, `tarchetypes`, `testthat`, `tidyverse`, `wbstats`,
  `haven`, `httr`, `readr`, `validate` (all in `renv.lock`)

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

## 4. Step-by-Step SPI Update

*(draft — being populated as the pipeline is built)*

The update steps below come from the "Update steps" tab of `SPI updates.xlsx`
and the original Rmd comments. Each indicator's source and update procedure
is documented in its section.

### 4.1 Before starting

1. Run the microdata library pull: `02_programs/misc_scripts/microdata_library_pull.Rmd`
2. Download the new CLASS file:
   `https://databankfiles.worldbank.org/public/ddpext_download/site-content/CLASS.xlsx`

### 4.2 WDI metadata

Download from the WDI site, rename to be consistent, and place in
`01_raw_data/metadata/WDI_metadata_<YEAR>.csv`.
Source: <https://datacatalog.worldbank.org/int/search/dataset/0037712>

### 4.3 Indicator updates

| Indicator | Source | Update procedure |
|-----------|--------|------------------|
| 1.5.1 PIP | `pipr` package | Read automatically; QA needed if PIP update delayed |
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

### 4.4 Next steps (after data prep)

1. `01_SPI_data_prep.Rmd` → produces `SPI_data.csv`
2. `02_SPI_index.Rmd` → creates the index, updates working paper results
3. `03_SPI_data_validation.Rmd` → additional checks (e.g. number of countries)

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

*(draft)*

## 7. Interpreting Test Results

*(draft)*
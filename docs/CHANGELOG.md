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

## Documented exceptions

- **E1**: `SPI.D5.3.DISK` validation rule errors (column not produced by
  the pipeline nor present in the vintage — skills indicator gap). Rule
  kept for exact rule-set fidelity.
- **E2**: `jitter_y`/`jitter_x` in `SPI_quantiles_2024.csv` are unseeded
  `rnorm()` values in the original script — inherently non-reproducible.
- **E3**: databank aggregate rows differ at the 2nd decimal from the
  vintage (the vintage databank was generated from an earlier index
  vintage). Country-level values are identical.
- **WB API drift**: metadata columns (country name, income, population,
  GDP, last_updated) change between vintages because the World Bank API is
  live. Documented, not a pipeline bug.
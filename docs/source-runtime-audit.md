# SPI Source Runtime Audit

**Created:** 2026-10-05

This audit records where source acquisition currently occurs before the
collection-first migration. It distinguishes confirmed runtime acquisition
from prepared-file reads and reference-only code.

## Confirmed Runtime Acquisition in Current Targets/Helpers

| Location | Source or operation | Current behavior | Collection action |
|---|---|---|---|
| `config/params.R` | `wbstats::wb_countries()` | Loads live country metadata while loading estimation parameters | Cache as a collection artifact; estimation reads the saved snapshot |
| `R/append.R` | World Bank country API, OECD region | Fetches OECD country codes and caches an RDS under `staging/` | Move to collection raw/normalized artifacts |
| `R/append.R` | `wbstats::wb_data()` population | Fetches population and caches an RDS under `staging/` | Move to collection artifacts |
| `R/quantiles.R` | `wbstats::wb_data()` GDP per capita | Fetches GDP during quantile construction | Move to collection artifacts |
| `R/pull_jmp.R` | JMP country downloads | HTTP GET for country files; target is currently opt-in and disconnected from `dim1_5` | Make a collection target and explicit dependency |
| `R/pull_unsdg.R` | UN SDG JSON API | HTTP GET for CRVS, legislation, and finance series; target is currently opt-in and disconnected from consuming dimensions | Make collection targets and preserve raw responses |
| `config/params.R` / `R/setup.R` | World Bank country metadata | Used to build the country grid and country filters | Consume the collection snapshot in estimation |

## Confirmed Acquisition in Legacy or Miscellaneous Scripts

| Location | Source or operation | Current behavior | Collection action |
|---|---|---|---|
| `02_programs/misc_scripts/un_stats_cleaning.Rmd` | UN SDG `DataCSV` POST | Downloads raw per-series files, then creates normalized and scored files outside `{targets}` | Port into tested collection functions and targets |
| `02_programs/misc_scripts/sdg_indicators_for_SPI.R` | UN SDG `DataCSV` POST | Downloads raw CRVS, legislation, and finance series and writes normalized files | Consolidate behind shared collectors |
| `02_programs/misc_scripts/microdata_library_pull.Rmd` | Microdata catalog APIs/downloads | Pulls public catalog metadata and writes intermediate files | Register as external/API source and migrate where reproducible |
| `02_programs/misc_scripts/nada_check.R` | National-site HTTP checks | Checks URLs supplied by the NADA source process | Keep as explicit collection checkpoint unless a stable source API is established |
| `02_programs/01-SPI_data_prep.Rmd` | `pipr` package | Loads `pipr`, but the acquisition call and CSV write are commented; the active code reads `PIP_comparability_latest.csv` | Verify package behavior and implement a tested collector or document external PIP input |

## Dimension 1.5 Source Coverage

Dimension 1.5 has five separate estimation inputs and scoring paths:

| Indicator | Source | Estimation reader/scorer |
|---|---|---|
| `SPI.D1.5.POV` | PIP | `read_pip_data()` / `score_poverty_comparability()` |
| `SPI.D1.5.CHLD.MORT` | UN IGME | `read_child_mortality_data()` / `score_child_mortality()` |
| `SPI.D1.5.DT.TDS.DPPF.XP.ZS` | WDI metadata | `read_wdi_metadata()` / `score_debt_reporting()` |
| `SPI.D1.5.SAFE.MAN.WATER` | JMP | `read_safely_managed_water()` / `score_safely_managed_water()` |
| `SPI.D1.5.LFP` | ILO | `read_ilo_lfp()` / `score_ilo_lfp()` |

The collection registry represents these as five distinct source records. PIP
and JMP have collection functions; IGME, WDI metadata, and ILO remain explicit
manual checkpoints until their source-specific collection is automated.

Other prepared or manual inputs include ODIN, NADA, census/survey extracts and
manual reviews, IMF workbooks, previous-vintage standards inputs, CLASS, ASPIRE,
and other dimension-specific files.

These are represented in `config/source_registry.R` as `manual`, `external`,
or `unavailable` sources until a reproducible collection method is verified.

## Audit Boundary

This document is a baseline for migration. It is not evidence that every
listed source has a stable public API or that a collector is safe to automate.
Each source must pass the registry schema, cache/provenance, freshness, and
fixture-backed transformation tests before it becomes an estimation dependency.

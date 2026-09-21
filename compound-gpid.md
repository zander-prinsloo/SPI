---
project-name: "Statistical Performance Indicators (SPI)"
team: "DECDG / GPID -- World Bank"
created: "2026-09-21"
last-reviewed: "2026-09-21"
---

# Statistical Performance Indicators (SPI)

## Objective

The new Statistical Performance Indicators (SPI) builds on the SCI, which the World Bank has regularly published since 2004. The SPI is designed to monitor how well countries' statistical systems are meeting the purpose of helping users make better decisions. By helping countries and development partners identify the strengths and weaknesses of national statistical systems, the SPI can support policy advice for countries, investment decisions for donors including the World Bank, benchmarking of national statistical systems, and advocacy for national statistics.

## Key Deliverables

- `Run_SPI.R` — master file to reproduce results by running `01-data_prep.Rmd` and `02-SPI_index.Rmd`
- `01_raw_data/` — raw data for each indicator across the 22 dimensions
- `02_programs/` — cleaning code consolidated into `01-data_prep.Rmd` (also auto-writes the technical methodology document); `02-SPI_index.Rmd` creates the overall/dimension index
- `03_output_data/` — final outputs in CSV/Stata `.dta` format (`SPI_data.csv`, `SPI_index.csv`, etc.)
- `SPI_data_viz/` — Shiny dashboard for dissemination

## Constraints

- Open data and open code to build confidence in the work
- Uses only publicly accessible data
- Reproducibility via `renv::restore()` from `renv.lock` (WB-specific packages like wbgviz may need manual install)
- Raw data and outputs are version-controlled via explicit `.gitignore` rules

## Current Focus

Current focus is to create a better estimation pipeline from `01-SPI_data_prep.Rmd`, `02-SPI_index.Rmd`, and `03_SPI_data_validation.Rmd`. The pipeline should use `{targets}` and should exactly replicate the Rmd files. It is very important that the Rmd files remain untouched to test, and that the new pipeline exactly replicates the results from the existing pipeline.
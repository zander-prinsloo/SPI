# Statistical Performance Indicators (SPI)

<!-- cg:auto:overview -->
The Statistical Performance Indicators (SPI) build on the SCI, which the World Bank has regularly published since 2004. The SPI monitors how well countries' statistical systems are meeting the purpose of helping users make better decisions. By helping countries and development partners identify the strengths and weaknesses of national statistical systems, the SPI supports policy advice for countries, investment decisions for donors including the World Bank, benchmarking of national statistical systems, and advocacy for national statistics.

The SPI framework covers five pillars — data use, data services, data products, data sources, and data infrastructure — spanning 22 dimensions of national statistical performance.

This repository is a reproducible R analysis pipeline. Raw data flows from `01_raw_data/` through cleaning and index construction in `02_programs/` to final outputs in `03_output_data/`. A Shiny dashboard in `SPI_data_viz/` supports dissemination.
<!-- cg:auto:end -->

## Contents
- [Data Sources](data-sources.md)
- [Replication](replication.md)
- [Results](results.md)

<!-- cg:auto:methodology -->
The SPI is constructed from indicators across the 22 dimensions of the framework. The methodology is transparent and uses only publicly accessible data. Key characteristics of the SPI are: (i) uses only publicly accessible data; (ii) transparent methodology; (iii) easily replicable; (iv) provides a long-time series to track progress in performance; (v) captures outcomes and supporting elements; (vi) reflects the SDGs; (vii) facilitates at-a-glance comparisons on a global scale.

The estimation pipeline is implemented in R Markdown/Quarto:

- `01-SPI_data_prep.Rmd` — cleans raw indicator data and auto-writes the technical methodology document
- `02-SPI_index.Rmd` — creates the overall and dimension indices
- `03_SPI_data_validation.Rmd` — validates the prepared data

A `{targets}`-based pipeline is under development to replicate the Rmd results exactly.
<!-- cg:auto:end -->
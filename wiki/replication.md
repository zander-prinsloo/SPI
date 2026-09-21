# Replication

<!-- cg:auto:environment-setup -->
The project uses `renv` for dependency management. To reproduce the environment:

1. Install R (the repository was built with R 4.3.1).
2. Run `renv::restore()` from the project root to install the package versions recorded in `renv.lock`.

Note: World Bank–specific packages (e.g., `wbgviz` for WB-standard maps) may need manual installation from https://github.com/worldbank/wbgviz.
<!-- cg:auto:end -->

<!-- cg:auto:steps -->
To reproduce the results end to end, run the master file `Run_SPI.R`, which executes:

1. `01-SPI_data_prep.Rmd` — data cleaning and preparation
2. `02-SPI_index.Rmd` — overall and dimension index construction

The pipeline follows the folder convention `01_raw_data/` → `02_programs/` → `03_output_data/`.
<!-- cg:auto:end -->

<!-- cg:auto:validation -->
`03_SPI_data_validation.Rmd` validates the prepared data. A `{targets}`-based pipeline is under development that must exactly replicate the results of the existing Rmd files; the Rmd files themselves remain untouched as the reference implementation.
<!-- cg:auto:end -->

← [Home](README.md)
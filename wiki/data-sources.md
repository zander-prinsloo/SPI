# Data Sources

<!-- cg:auto:datasets -->
The SPI uses only publicly accessible data. Raw data for each indicator across the 22 dimensions is stored in `01_raw_data/`, organized in subfolders linked to the framework dimensions (e.g., `1.1_DUNL/`, `1.2_DUNE/`, `2.1_DSDR/`, `3.1_DPSS/`, `4.1_SOCS/`, `5.1_DILG/`). Sources include international databases such as FAOSTAT and other public statistical sources.
<!-- cg:auto:end -->

<!-- cg:auto:vintages -->
Previous vintages of raw data are retained under `01_raw_data/previous_vintages/` to support time-series construction and reproducibility of earlier releases.
<!-- cg:auto:end -->

<!-- cg:auto:access -->
All raw data is publicly accessible. Raw data and outputs are version-controlled via explicit `.gitignore` rules. Final outputs are written to `03_output_data/` in CSV and Stata `.dta` formats.
<!-- cg:auto:end -->

← [Home](README.md)
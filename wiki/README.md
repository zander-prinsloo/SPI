# Statistical Performance Indicators (SPI)

<!-- cg:auto:overview -->
The Statistical Performance Indicators (SPI) measure national statistical
systems through five pillars and 22 dimensions. This is an R analysis
repository with separate collection (`_targets_data.R`) and estimation
(`_targets.R`) graphs. Source artifacts live under `01_raw_data/`, candidate
outputs under `03_output_data/.candidate/`, and validated promoted outputs
under `03_output_data/`.

Start with the [documentation index](../docs/README.md) and
[202611 status](../docs/update-status-202611.md). The preliminary review files
are in `replication/spi-rep/preview-p0p1/`; the main output CSVs still contain
the previous release through 2024. `SPI_data_viz/` contains the Shiny app.
<!-- cg:auto:end -->

## Contents

- [Data Sources](data-sources.md)
- [Replication](replication.md)
- [Results](results.md)

<!-- cg:auto:methodology -->
SPI combines indicator, dimension, and pillar scores into an overall index.
The source-specific [user guide](../docs/user-guide.md) explains preparation
and scoring inputs; the [architecture](../docs/pipeline-architecture.md)
explains orchestration and validation.

The original R Markdown files under `02_programs/` remain reference
implementations. The active targets pipeline has documented corrections and
replication exceptions; see [CHANGELOG](../docs/CHANGELOG.md). A source refresh,
methodology approval, and release approval are separate decisions. Most data
sources are public, but the D4.1 internal library requires World Bank network
access and some manual inputs require separate acquisition.
<!-- cg:auto:end -->
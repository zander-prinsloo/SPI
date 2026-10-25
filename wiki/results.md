# Results

<!-- cg:auto:key-findings -->
SPI produces country-level indicators, dimension/pillar indices, an overall
score, and derived dissemination outputs. The retained 202611 preview is
preliminary: it uses provisional ODIN and precedes completed reviewer/source
acceptance. See [current status](../docs/update-status-202611.md) for the exact
snapshot, revision counts, and pending decisions. Historical review counts
must not be substituted for that snapshot's evidence.
<!-- cg:auto:end -->

<!-- cg:auto:tables -->
For internal review, use:

- [SPI_data.csv](../replication/spi-rep/preview-p0p1/SPI_data.csv): prepared indicators and source/metadata fields.
- [SPI_index.csv](../replication/spi-rep/preview-p0p1/SPI_index.csv): dimension, pillar, overall index, and included indicator fields.
- [Revision summary](../docs/revisions/202611/preview/revision_summary_2025.md): historical changes and new-year coverage.

`03_output_data/` contains the last promoted set; as of the dated status page,
its two main CSVs still end in 2024. Quantiles, treemap, Databank, SPL, Stata,
and revision outputs are built in the candidate folder before validation and
promotion. Consult `_estimation_manifest.json` rather than inferring the
vintage from a filename or directory timestamp.
<!-- cg:auto:end -->

<!-- cg:auto:figures -->
`SPI_data_viz/` contains the Shiny dissemination application. The active
estimation graph builds data for downstream products; it does not reproduce
every legacy notebook visualization, publish the dashboard, or authorize an
external release. Label any figures derived from the review snapshot as
preliminary with provisional ODIN.
<!-- cg:auto:end -->

← [Home](README.md)
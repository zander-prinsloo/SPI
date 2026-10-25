# Provisional SPI outputs: ODIN

The outputs in this folder use a provisional ODIN file for 2025 (ODIN_2025.csv).
Only the ODIN-dependent columns listed in `_estimation_manifest.json`
(`odin_dependent_columns`: SPI.D2.2, SPI.D4.3, their dimension indices,
Pillars 2 and 4, the overall index, and the ranks, quantiles and databank
rows derived from them) are provisional. Every other value is final.

After the official ODIN release, replace the file, set
`odin_status <- "official"` in `config/params.R`, and rerun the estimation
pipeline; this marker is then removed.

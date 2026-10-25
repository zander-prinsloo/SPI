---
project-name: "Statistical Performance Indicators (SPI)"
team: "DECDG / GPID -- World Bank"
created: "2026-09-21"
last-reviewed: "2026-10-25"
---

# Statistical Performance Indicators (SPI)

## Objective

The new Statistical Performance Indicators (SPI) builds on the SCI, which the World Bank has regularly published since 2004. The SPI is designed to monitor how well countries' statistical systems are meeting the purpose of helping users make better decisions. By helping countries and development partners identify the strengths and weaknesses of national statistical systems, the SPI can support policy advice for countries, investment decisions for donors including the World Bank, benchmarking of national statistical systems, and advocacy for national statistics.

## Key Deliverables

- `_targets_data.R` — collection graph with the `_targets_data/` store
- `_targets.R` — estimation, candidate validation, and promotion, with the `_targets/` store
- `R/` and `config/` — active functions, source registry, and reference-year configuration
- `01_raw_data/` — manual sources, cached/normalized artifacts, review workbooks, provenance, and collection reports
- `03_output_data/` — last promoted outputs; candidate files are under `.candidate/`
- `replication/` — preliminary review snapshots, local historical runs, and scratch files
- `docs/README.md` — documentation index; `docs/update-status-202611.md` is the current operational handoff
- `02_programs/` and `Run_SPI.R` — preserved legacy references
- `SPI_data_viz/` — Shiny dissemination application

## Constraints

- Preserve approved previous-vintage outputs, their hash manifest, and immutable test fixtures.
- Collect sources before estimation; require current matching hash-bound run/status evidence and no blocking sources.
- Record explicit source, methodological, and release approvals; a preview bypasses gates only in its sandbox.
- Most sources are public; D4.1 also uses an internal library requiring World Bank network access.
- Restore recorded dependencies from `renv.lock`; do not change it to hide environment warnings.
- Keep SPI artifacts and temporary work inside the repo. Bulk archives/scratch and the exact oversized `UN IGME 2025.csv` are local-only and Git-ignored.
- Preserve legacy scripts as reference code; exact replication has documented corrections and differential exceptions in `docs/CHANGELOG.md`.

## Current Focus

The active branch is `dev_SPI_2025`; the planned 202611 update has reference
year 2025. Preliminary review CSVs are in
`replication/spi-rep/preview-p0p1/`, with provisional ODIN. Main output CSVs
still end in 2024. The latest collection marker is started and its earlier
status report is stale for that run. Complete reviews, source attestations,
frozen-history decisions, current validation, normal estimation, and the
approved official ODIN transition before final release. See the dated status
page rather than older handover counts or branch names.

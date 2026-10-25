# Project context

Additional context for repository tools and future contributors. Operational
instructions are indexed in [docs/README.md](docs/README.md).

## Data sources

Collection is `_targets_data.R` with store `_targets_data/`; estimation is
`_targets.R` with store `_targets/`. Registry rules in
`config/source_registry.R` determine required sources, paths, release rules,
and analyst actions. Most sources are public; the D4.1 internal catalogue
requires World Bank network access. The exact 2025 IGME CSV must be obtained
separately on a fresh clone because it is Git-ignored.

## Domain rules

- Update 202611 has reference year 2025; the previous approved SPI vintage
  is 202511, reference year 2024.
- A completed collection run and an unblocked source report are separate
  requirements. Require matching run IDs/parameters, report hash, and marker
  self-hash; never edit these to bypass a gate.
- Writers use `03_output_data/.candidate/`; validated complete sets are
  promoted automatically. The root `staging/` folder is legacy.
- Preserve previous baselines, immutable test fixtures, source identities,
  and human approval records. Document exceptions rather than hiding them.
- Keep working artifacts under `replication/`; initialize temporary variables
  before R starts. Historical bulk runs/probes/logs are local and ignored.
- Preview outputs and historical passing tests are not final release approval.
  Use `docs/update-status-202611.md` for current pending work.

## Work in progress

`dev_SPI_2025` contains the active pipeline. The retained review snapshot is
`replication/spi-rep/preview-p0p1/`; it has provisional ODIN and precedes
completed reviews/attestations. The observed current gate, methodology,
41-cell frozen-history decisions, and actual official ODIN transition still
need reconciliation and validation. Historical commit IDs can be mapped via
`docs/revisions/202611/git-history-rewrite-map-2026-10-25.csv`.

## Workspace notes

Fresh clones include the designated review CSVs/evidence, not all 4 GB of
recovered historical artifacts. The executable raw baseline for replication
and attribution is `25b534706ff6`. `renv.lock` records R 4.6.1; restore it and
inspect environment differences before changing dependencies.

## Wiki Configuration
<!-- folder: wiki -->
<!-- audience: developers -->
<!-- tone: technical -->

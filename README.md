# Statistical Performance Indicators (SPI)

The SPI measures the performance of national statistical systems across five
pillars: data use, data services, data products, data sources, and data
infrastructure. Its 22 dimensions support country benchmarking, diagnosis of
strengths and weaknesses, and tracking progress over time.

This repository contains the R code, source artifacts, validation evidence,
and country-level outputs used to prepare an SPI update. The active workflow
uses **two `{targets}` pipelines**: collection in `_targets_data.R`, followed
by estimation in `_targets.R`. The original notebooks in `02_programs/` are
retained as reference implementations.

## Start here

| Task | Documentation |
|---|---|
| Find the 202611 review files and outstanding work | [Current update status](docs/update-status-202611.md) |
| Set up R, collect sources, review inputs, and estimate SPI | [Technical lead user guide](docs/user-guide.md) |
| Understand targets, dependencies, validation, and output promotion | [Pipeline architecture](docs/pipeline-architecture.md) |
| Reproduce or inspect a preliminary run | [Replication and review artifacts](replication/README.md) |
| Replace provisional ODIN data and finalize the release | [Delayed ODIN workflow](docs/odin-delayed-update.md) |
| Review historical revisions and Working Group decisions | [202611 revision report](docs/revisions/202611-revision-report.md) |
| Browse the documentation and contributor guidance | [Documentation index](docs/README.md) |

## Current 202611 update

The update identifier **202611** refers to the planned November 2026 update;
its **reference year is 2025**, with a 2004–2025 span. It is not a statement
that the update has been released.

The preliminary review files are
[`SPI_data.csv`](replication/spi-rep/preview-p0p1/SPI_data.csv) and
[`SPI_index.csv`](replication/spi-rep/preview-p0p1/SPI_index.csv).
They use **provisional ODIN data** and precede completed source attestations
and reviewer workbooks. The `03_output_data/` copies still contain the
previous release through 2024. See the dated [status](docs/update-status-202611.md)
for the retained preview, collection-run mismatch, approval requirements,
and evidence that needs to be refreshed before release.

## Set up and run

Use R **4.6.1**, as recorded in `renv.lock`, and run commands from the project
root. Restore the recorded environment with `renv::restore()`; check
`renv::status()` rather than changing the lockfile to clear a warning.
World Bank packages and the internal D4.1 catalogue can require additional
access; see the [prerequisites](docs/user-guide.md#2-prerequisites).

The oversized manual source `01_raw_data/1.5_DUIO/UN IGME 2025.csv` is
**local-only and Git-ignored**. Obtain it separately before running this
update. Other IGME vintages remain tracked. The
[exclusion record](docs/revisions/202611/git-history-file-exclusion-2026-10-25.md)
records its checksum and the rewritten unpublished commit IDs.

Keep temporary files inside the repository by setting these variables before
starting R or Rscript:

```sh
mkdir -p replication/.scratch
export TMPDIR="$PWD/replication/.scratch"
export TMP="$TMPDIR"
export TEMP="$TMPDIR"
```

Then, in R:

```r
renv::restore()  # Initial environment setup.

targets::tar_make(script = "_targets_data.R", store = "_targets_data")
# Inspect collection_run.json and collection_status.csv under
# 01_raw_data/_collection/. Complete reviews and source attestations,
# then rerun collection until the current run is complete and unblocked.

targets::tar_make(script = "_targets.R", store = "_targets")
```

Collection completion and source acceptance are separate checks. Estimation
requires a completed, matching, hash-bound collection report with no blocking
rows. It writes to `03_output_data/.candidate/`, applies revision and release
checks, then promotes the complete validated output set to `03_output_data/`.
There is no manual copy from the old root `staging/` folder.

`run_downloads <- FALSE` does **not** disable all network access: it controls
the opt-in D4.1 catalogue refresh. Other collectors use their source caches
and may fetch missing or stale responses. Read the source-specific procedures
before running collection.

## Repository layout

| Path | Role |
|---|---|
| `config/params.R` | Reference year, filenames, directories, ODIN status, and refresh settings |
| `config/source_registry.R` | Source identities, paths, freshness rules, and required analyst actions |
| `R/` | Collection, scoring, output, provenance, and validation functions |
| `01_raw_data/` | Manual sources, cached responses, normalized inputs, and collection reports |
| `01_raw_data/previous_vintages/` | Approved prior SPI outputs and their baseline manifest |
| `02_programs/`, `Run_SPI.R` | Legacy scripts and master runner; preserve for reference |
| `03_output_data/.candidate/` | Working output set before promotion |
| `03_output_data/` | Most recently promoted outputs; inspect the manifest to identify the vintage |
| `03_output_data/releases/` | Approved output archives referenced by release locks |
| `replication/` | Review snapshots, historical runs, audits, and local scratch folders |
| `staging/` | Legacy compatibility files; not the current candidate or review folder |
| `_targets_data/`, `_targets/` | Separate collection and estimation dependency stores |
| `tests/` | Unit/contract tests, immutable vintage fixtures, and replication tools |
| `docs/`, `wiki/` | Operational reference and concise navigation |
| `.cg-docs/` | Dated plans, reviews, execution evidence, and active-state metadata |
| `SPI_data_viz/` | Shiny dissemination application |

The two review CSVs, their supporting evidence, and the relocation inventory
are versioned. Recovered bulk runs, probes, logs, and scratch folders remain
local inside `replication/` and are ignored by Git. They are not supplied by a
fresh clone. See [replication](replication/README.md) for details.

## Validation and reproducibility

The legacy notebooks and the immutable **202511 / reference-year 2024**
fixtures provide the replication reference. Comparisons have documented
exceptions and a pre-existing differential-replication limitation; the new
pipeline is not an unconditional byte-for-byte reproduction of every legacy
output. See the [test guide](docs/user-guide.md#7-interpreting-test-results)
and [changelog](docs/CHANGELOG.md).

Strict vintage tests require a complete estimation manifest. Development
runs may explicitly use `SPI_COMPARISON_MODE=porting` to skip unavailable
comparison outputs; that mode is not release evidence. Use the isolated 2024
replication harness for vintage comparisons rather than comparing a 2025
output set directly with the 2024 fixtures.

For changes to the pipeline, add or update relevant tests, preserve the raw
source and approved baselines, and document the effect on estimates. See
[contributor guidance](docs/contributing.md).

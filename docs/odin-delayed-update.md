---
title: "Running an SPI Update When ODIN Is Delayed"
created: "2026-10-20"
status: "operational guidance"
---

# Running an SPI Update When ODIN Is Delayed

## Purpose

This document describes how to prepare an SPI update when the Open Data
Inventory (ODIN) release is not yet available. It covers the use of the
previous ODIN vintage as a temporary stand-in, how the `{targets}` pipeline
tracks and labels it, and the steps required when the official release
arrives.

The stand-in produces a **provisional** SPI result. It must not be presented as
the final SPI vintage or as evidence that the new ODIN data were available.

## 202611 context

The **SPI 202611 update** is released in November 2026 and uses 2025 as its
reference year. Set `end_date <- 2025` for this update. The previous official
ODIN inputs are therefore the 2024 files, and any 2025 carry-forward must be
labelled provisional until the official 2025 ODIN release is available.

## Short answer

The ODIN files are explicit `{targets}` file dependencies (`odin_files`), read
once (`odin_data`) and scored in their own targets (`dim2_odin` for D2.2,
`dim4_geo` for D4.3). Replacing `ODIN_<end_date>.csv` therefore reruns only
those targets and the outputs built from them; every other dimension is
reused. `odin_status` in `config/params.R` labels the run: `"provisional"`
writes `03_output_data/PROVISIONAL_ODIN.md` and records the ODIN file hashes
and the ODIN-dependent columns in `_estimation_manifest.json`; `"official"`
removes the marker. Changing `odin_status` reruns only the labelling outputs
(the output manifest and the revision evidence, which marks the
ODIN-dependent columns as provisional while the status is provisional).

A copied previous ODIN file is a carry-forward assumption. It must be
labelled provisional and preserved separately from the official release.

## ODIN's role in the pipeline

The current pipeline reads files from:

```text
01_raw_data/2.2_DSOA/ODIN_<YEAR>.csv
```

The ODIN reader loads every file from 2015 through `end_date`. The same files
are used for both:

- Dimension 2.2, online access; and
- Dimension 4.3, geospatial data.

The dependency path is therefore:

```text
odin_files (ODIN_2015.csv ... ODIN_<end_date>.csv)
  -> odin_data (all columns both readers use are validated)
  -> dim2_odin (D2.2) and dim4_geo (D4.3)
  -> dim2 and dim4 (joined with dim2_core and dim4_core, which do not use ODIN)
  -> spi_data -> vintage_diff, spi_index
  -> quantiles, treemap, databank, and the output manifest
```

A change to ODIN can affect both dimensions, their dimension scores, pillar and
overall index scores, rankings, aggregates, quantiles, and dissemination files.

## Important distinction: new year versus revised release

Do not assume that a new ODIN release only adds one new year. It may revise
historical scores or country coverage. When the official release arrives,
compare every ODIN year used by the update, normally 2015 through `end_date`.

Keep the previous files unchanged so that the provisional and final results
remain reproducible.

## Recommended workflow

### 1. Freeze the previous ODIN vintage

Before preparing the update:

1. Confirm which ODIN files are currently used by the SPI vintage.
2. Preserve those files without overwriting them.
3. Record the ODIN release date, download URL, file names, and file hashes if
   available.

The previous ODIN files are the reference inputs for the provisional run.

### 2. Prepare all non-ODIN inputs

Update and validate the other SPI sources normally. Run the collection stage
from the project root:

```r
targets::tar_make(
  script = "_targets_data.R",
  store = "_targets_data"
)
```

The current collection gate treats ODIN as a blocking source. If the new
ODIN file is absent, the collection status will not pass. The provisional
workflow therefore requires either the stand-in described below or a future
provisional-source mode that distinguishes a delayed source from a missing
source.

### 3. Create a temporary stand-in, if a provisional full build is needed

Suppose the previous available ODIN year is 2024 and the new SPI reference
year is 2025. The current reader expects `ODIN_2025.csv`. A temporary
carry-forward can be created as follows:

```sh
cp "01_raw_data/2.2_DSOA/ODIN_2024.csv" \
   "01_raw_data/2.2_DSOA/ODIN_2025.csv"
```

This means that the provisional 2025 ODIN values are exactly the 2024 values.
It does not estimate or predict the 2025 ODIN release.

Record the stand-in in the collection run notes. At minimum, record:

```text
SPI reference year: 2025
ODIN status: provisional, release delayed
ODIN file used: ODIN_2025.csv
Stand-in source: ODIN_2024.csv
Stand-in rule: carry forward the previous ODIN file unchanged
Required follow-up: replace the stand-in with the official ODIN release
```

Do not overwrite `ODIN_2024.csv`, and do not leave the copied file labelled as
an official 2025 release in a final publication directory.

### 4. Build provisional outputs

Keep `odin_status <- "provisional"` in `config/params.R`. The two ODIN
registry sources (`d2_2_odin`, `d4_3_odin`) only require `ODIN_<end_date>.csv`
to be present, so the provisional label comes from `odin_status`. Run
estimation:

```r
targets::tar_make()
```

The promoted outputs carry `03_output_data/PROVISIONAL_ODIN.md`, and
`_estimation_manifest.json` records `odin_status`, the hash of every ODIN file
read and the ODIN-dependent output columns. Confirm before circulating that:

- the stand-in is documented;
- all other source checks have passed;
- the marker is present; and
- provisional files will not be published as the final vintage.

The resulting SPI data and index are useful for preparing tables, checking
layout, reviewing narrative text, and identifying changes that are unrelated to
ODIN. They are not final results.

### 5. Lock the approved provisional release

After internal approval of the provisional outputs, write the release lock:

```r
for (f in list.files("R", full.names = TRUE)) source(f)
params <- load_params()
write_release_lock(params, approved_by = "Technical lead name")
```

This archives the promoted outputs to
`03_output_data/releases/202611-provisional/` and writes
`01_raw_data/_collection/release_lock_2025.json` with the SHA-256 of every
non-ODIN collection artifact (resolved through the source registry, plus the
World Bank snapshot), the PIP release, and the archived outputs. It never
overwrites an existing lock or archive. While the lock exists:

- collection uses the locked PIP release instead of resolving a newer one;
- the collection run and the estimation (`release_lock_verification`) stop
  with `RELEASE LOCK MISMATCH` when a non-ODIN artifact differs from the lock;
- the estimation compares every candidate output with the archive
  (`release_diff`) and stops with `RELEASE DIFF BLOCKS PROMOTION` when a
  change falls outside the ODIN-dependent outputs.

### 6. Keep a provisional-to-final comparison plan

Before the official release, prepare the comparison inputs and review process.
The final comparison should identify changes in:

- ODIN country-year rows and component scores;
- Dimension 2.2 and Dimension 4.3 scores;
- `spi_data` indicator and dimension columns;
- overall index values, rankings, and aggregates; and
- quantile, treemap, databank, and report outputs.

## When the official ODIN release arrives

### 1. Store the official release separately first

Download the official files without immediately overwriting the stand-in.
Check the raw schema before using the files. The readers require the
following fields (the checkpoint and `odin_data` also require the other score
columns: indicator coverage, data available in the last 5 and 10 years, and
the overall score):

```text
Country Code
Year
Data categories
Machine readable
Non-proprietary
Download options
Metadata available
Terms of use
Openness subscore
First administrative level
Second administrative level
Coverage subscore
```

`verify_odin_data()` and the `odin_data` target stop with `ODIN SCHEMA
MISMATCH` when any of these columns is missing.

### 2. Compare the complete annual input set

Compare the official files with the provisional inputs for every year from
2015 through `end_date`. Check for:

- new or missing countries;
- changed country codes;
- changed category labels;
- changed component scores;
- revised historical values; and
- changed column names or types.

Stop and investigate any schema or coverage change before rebuilding.

### 3. Replace the stand-in and rerun collection

After the official files pass review, place them at the paths expected by the
pipeline, for example:

```text
01_raw_data/2.2_DSOA/ODIN_2025.csv
```

Rerun the collection pipeline. The ODIN sources are excluded from the
release lock, and every other artifact must still match it:

```r
targets::tar_make(
  script = "_targets_data.R",
  store = "_targets_data"
)
```

### 4. Rebuild ODIN-dependent outputs

Set `odin_status <- "official"` in `config/params.R` and run estimation:

```r
targets::tar_make()
```

The new file invalidates `odin_files`, `odin_data`, `dim2_odin`, `dim4_geo`
and the outputs built from them; the other dimensions are reused. Before
promotion, `release_diff` compares every output with the locked provisional
archive and writes `release_diff_2025.csv` and `.md` next to the outputs.
Allowed changes: `SPI.D2.2.*`, `SPI.D4.3.*` (and their RAW columns),
`SPI.DIM2.2.INDEX`, `SPI.DIM4.3.INDEX`, Pillars 2 and 4, the overall index,
the quintiles and scores derived from them, the plotting jitter of
`SPI_quantiles_2025.csv` (it is drawn in index order, so it moves between
countries whose rank changes), and the treemap and databank rows of those
series (including aggregates). Any other change, or an added or removed row or
column, stops promotion. The output manifest records
`odin_status = "official"` and the marker is removed. Keep the release-diff
report as part of the update record.

To rehearse the swap without touching the repository, run
`Rscript tests/replication/rehearse_odin_swap.R --out <dir>` from the
repository root (see the header of that script). The steps are summarized in
`<dir>/_rehearsal_summary.txt`.

## What the pipeline does for a delayed ODIN release

- Every annual ODIN file is a file target, and both readers share one
  validated read, so only ODIN-dependent targets rerun after a replacement.
- `odin_status` labels the outputs (marker file and output manifest) without
  invalidating the rest of the graph.
- Every column used by either reader is validated in every annual file.
- The vintage-diff report treats D2.2 and D4.3 history as frozen, so a
  revised ODIN release that changes 2015 to `end_date - 1` values blocks
  promotion until the changes are approved.

`{targets}` does not append a year to an existing data frame; a new or
replaced annual file reruns the shared ODIN read and its dependents.

## Final acceptance checklist

Before releasing the final SPI update, confirm that:

- the previous ODIN files remain preserved;
- the stand-in is clearly labelled as provisional;
- the official release was checked for all years used by the pipeline;
- the collection status was rerun with the official files in place;
- `odin_status` is `"official"` and `PROVISIONAL_ODIN.md` is gone;
- both Dimensions 2.2 and 4.3 were rebuilt;
- downstream index and dissemination outputs were regenerated;
- provisional and final outputs were compared (`release_diff_2025.md`);
- the revision evidence (`revision_summary_2025.md`) and the Working Group
  report (`docs/revisions/202611-revision-report.md`) were updated with the
  final ODIN values;
- the published `SPI_data.csv` and `SPI_index.csv` were copied to
  `01_raw_data/previous_vintages/SPI_data_2025.csv` and `SPI_index_2025.csv`
  for the next vintage; and
- no provisional output was published as the official SPI vintage.

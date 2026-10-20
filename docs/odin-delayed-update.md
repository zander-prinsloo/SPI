---
title: "Running an SPI Update When ODIN Is Delayed"
created: "2026-10-20"
status: "operational guidance"
---

# Running an SPI Update When ODIN Is Delayed

## Purpose

This document describes how to prepare an SPI update when the Open Data
Inventory (ODIN) release is not yet available. It covers the use of the
previous ODIN vintage as a temporary stand-in, the limits of the current
`{targets}` pipeline, and the steps required when the official release arrives.

The stand-in produces a **provisional** SPI result. It must not be presented as
the final SPI vintage or as evidence that the new ODIN data were available.

## 202611 context

The **SPI 202611 update** is released in November 2026 and uses 2025 as its
reference year. Set `end_date <- 2025` for this update. The previous official
ODIN inputs are therefore the 2024 files, and any 2025 carry-forward must be
labelled provisional until the official 2025 ODIN release is available.

## Short answer

`{targets}` can reuse completed results, but only when the dependency graph
contains the relevant input. In the current implementation, ODIN files are
read inside the combined `dim2` and `dim4` functions. The files are not yet
explicit `{targets}` file dependencies, and `{targets}` does not append a new
year to an existing data frame automatically.

A copied previous ODIN file can therefore be used as a stand-in, but it is a
carry-forward assumption. It must be labelled and preserved separately from the
official release.

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
ODIN files
  -> dim2 and dim4
  -> spi_data
  -> spi_index
  -> quantiles, treemap, databank, and final outputs
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

### 4. Build provisional outputs in isolation

The current pipeline does not have a built-in provisional flag. Its output
manifest can promote results to `03_output_data/`. Therefore, do not run a
stand-in build against the production output directory unless the output
promotion step has first been isolated or guarded.

Use a scratch or candidate environment and run the estimation pipeline only
after confirming that:

- the stand-in is documented;
- all other source checks have passed;
- the output is labelled provisional; and
- provisional files will not be published as the final vintage.

The normal estimation command is:

```r
targets::tar_make()
```

The resulting SPI data and index are useful for preparing tables, checking
layout, reviewing narrative text, and identifying changes that are unrelated to
ODIN. They are not final results.

### 5. Keep a provisional-to-final comparison plan

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
Check the raw schema before using the files. The readers currently require the
following fields, depending on the dimension:

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

The checkpoint currently validates fewer fields than the readers use. Perform
the complete check manually until the checkpoint is strengthened.

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

Rerun the collection pipeline so that the checkpoint and collection status
reflect the official files:

```r
targets::tar_make(
  script = "_targets_data.R",
  store = "_targets_data"
)
```

Do not rely only on the old collection status file. The current parameter hash
does not include an ODIN content hash, so a same-year replacement must trigger
a deliberate collection rerun.

### 4. Rebuild ODIN-dependent outputs

In the current implementation, changing an ODIN file with the same name may not
invalidate `dim2` or `dim4`, because the file is read inside those functions
rather than declared as a file target. The safest current procedure is to
force a clean estimation rebuild after the official replacement:

```r
targets::tar_destroy()
targets::tar_make()
```

This removes the estimation target store but leaves the raw source files and
the separate collection artifacts in place. It guarantees that the official
ODIN values flow through both affected dimensions and all downstream outputs.

After rebuilding, compare the official result with the provisional result and
retain the comparison as part of the update record.

## Improvements to make this workflow incremental

The preferred implementation is to make ODIN a first-class `{targets}`
dependency:

1. Add an `odin_vintage` parameter separate from the SPI `end_date`.
2. Add an explicit ODIN file target, or one file target per annual ODIN input,
   with `format = "file"`.
3. Pass the ODIN target output into the Dimension 2.2 and Dimension 4.3
   functions instead of reading files invisibly inside those functions.
4. Add a `provisional` or `release_status` field to the collection manifest.
5. Prevent output promotion when a blocking source is represented by a
   provisional stand-in.
6. Validate every column and every annual file used by both ODIN readers.

With those changes, `{targets}` can reuse unchanged annual ODIN inputs and
rebuild only the changed ODIN branches and their dependents. It will still not
perform row-level appends automatically; the annual files or annual branches
must be explicit targets.

## Final acceptance checklist

Before releasing the final SPI update, confirm that:

- the previous ODIN files remain preserved;
- the stand-in is clearly labelled as provisional;
- the official release was checked for all years used by the pipeline;
- the collection checkpoint and status report were rerun;
- both Dimensions 2.2 and 4.3 were rebuilt;
- downstream index and dissemination outputs were regenerated;
- provisional and final outputs were compared; and
- no provisional output was promoted or published as the official SPI vintage.

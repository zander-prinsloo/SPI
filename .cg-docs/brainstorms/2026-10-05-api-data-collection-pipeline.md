---
date: 2026-10-05
title: "API-backed data collection pipeline for all SPI indicators"
status: decided
scope: "Deep"
artifact-schema-version: 1
chosen-approach: "Registry-driven two-pipeline collection and estimation architecture"
tags: [targets, data-collection, api, caching, provenance, raw-data, availability, sdg, spi]
---
<!-- Valid status values: decided, in-progress, abandoned -->

# API-Backed Data Collection Pipeline for All SPI Indicators

## Context

The existing `{targets}` work should focuse on estimation and consume files that are
already present in `01_raw_data/`. It does not guarantee that API-backed sources
are collected before estimation, and some sources are fetched only in memory or
through optional/disconnected targets. The Pillar 3 SDG process in
`02_programs/misc_scripts/un_stats_cleaning.Rmd` downloads and transforms source
data outside the current targets graph.

The SPI technical team needs a reproducible collection stage that runs before
the estimation stage, keeps `01_raw_data/` current, preserves source and
intermediate data, and reports every source that remains manual or externally
prepared.

## Requirements

- Use two explicit commands and pipeline stages:
  1. a data collection pipeline; and
  2. the estimation pipeline.
- Represent all indicators across all 22 dimensions in the collection source
  registry, even when implementation is phased.
- Run every feasible API extraction inside the collection pipeline.
- Audit the current estimation targets, helper functions, and legacy Rmd
  references for runtime API or package-backed acquisition calls (including
  `pipr` and `wbstats`). Any confirmed source acquisition must move into the
  collection pipeline; estimation must consume saved collection artifacts
  only. The current `R/dim1_5.R` reads `PIP_comparability_latest.csv`, while
  the legacy Rmd loads `pipr` but leaves the acquisition call commented out;
  the collection design must still implement and test the acquisition needed
  to create that file.
- Preserve the raw API/download payload, a normalized source table, and a
  provenance/status record for each source where applicable.
- Produce binary country-indicator-year availability intermediates (`0`/`1`)
  before scoring, for Pillar 3 and other API-driven sources where the concept
  applies.
- Port the behavior of `un_stats_cleaning.Rmd` into ordinary R functions and
  targets, leaving the Rmd untouched as a replication reference.
- Test the collection and transformation functions against the intended Rmd
  behavior and existing vintage outputs.
- Use source-specific expected vintage/update rules, supplemented by a rough
  configurable age threshold as a warning.
- Classify collection findings as blocking, warning, or informational.
- Make missing, stale, schema-invalid, manual, and externally prepared sources
  visible to the analyst through machine-readable and human-readable reports.
- Make estimation consume validated collection outputs and write complete final
  outputs to `03_output_data/`.
- Update `docs/user-guide.md` as the collection and estimation workflow is
  implemented for the SPI technical team.
- Preserve the project's fail-loudly, open-data, reproducibility, and exact
  replication constraints.

## Approaches Considered

### Approach 1: Registry-driven collection pipeline

Create a separate `_targets_data.R` pipeline with a machine-readable source
registry. Each source record defines its extraction method, endpoint or manual
location, raw/normalized/availability paths, schema, vintage rule, freshness
threshold, status policy, and supplied indicators. Keep `_targets.R` as the
estimation pipeline, with a validation gate on collection status.

Pros: consistent caching, provenance, freshness checks, source reporting, and
fine-grained tests across all dimensions. It scales as sources are added while
keeping manual and external sources explicit.

Cons: largest implementation effort; APIs differ in formats, rate limits,
update conventions, and reliability.

### Approach 2: Bespoke collection functions by dimension

Create `_targets_data.R`, but implement collection logic independently inside
each dimension module.

Pros: closely follows the existing Rmd organization and makes dimension-level
replication straightforward.

Cons: duplicates caching, provenance, freshness, and reporting logic, making
source handling inconsistent and harder to audit.

### Approach 3: Target-wrapped legacy scripts

Run existing collection scripts as target commands and capture their outputs and
a completion report, initially wrapping the SDG Rmd as one command.

Pros: quickest migration and lower short-term replication risk.

Cons: weak target dependency granularity, hidden side effects, limited testing,
and does not satisfy the requirement to replace the SDG Rmd with tested
functions.

## Decision

Choose **Approach 1: Registry-driven collection pipeline**.

The collection pipeline will run first and own source acquisition and
freshness reporting. The estimation pipeline will run second, consume only
validated collection artifacts, and write final outputs to `03_output_data/`.
The implementation may be phased internally, but the registry and status model
must cover every indicator and dimension from the outset.

All runtime source acquisition must be audited across the target code and the
legacy Rmd references. Calls that currently occur during estimation, such as
World Bank metadata/population/OECD/GDP retrievals, must be represented as
collection targets and cached source artifacts. The PIP source requires the
same treatment: the current estimator reads the prepared CSV, but the
collection stage must create or refresh it through a tested `pipr`-compatible
function or documented equivalent rather than silently assuming the file
already exists.

For Pillar 3, the SDG Rmd's intended sequence will become tested functions and
targets: download and preserve each series response, normalize the series,
create indicator-level country-year availability tables, reproduce the scoring
inputs, and expose the resulting artifacts to estimation. Existing Rmd files
remain unchanged for comparison.

Caching must distinguish local reproducibility from remote freshness: raw
responses should be retained and identified by source/query/vintage, while a
collection status check must run deliberately for each collection command.
Targets caching alone must not be assumed to detect remote API changes.

## Next Steps

1. Define the complete source registry for all 22 dimensions and classify each
  source as API, manual download, external/prepared, or unavailable. Include
  an audit of every runtime API/package call currently reachable from
  estimation or legacy Rmd code.
2. Design the collection artifact contract for raw payloads, normalized tables,
   availability tables, provenance metadata, and status reports.
3. Port the Pillar 3 SDG download and cleaning process from
   `un_stats_cleaning.Rmd` into functions and targets.
4. Connect API-capable sources to collection targets with cache and freshness
   checks, then add explicit manual/external checkpoints for the remainder.
5. Add collection-to-estimation blocking validation and tests for source,
   intermediate, and final outputs.
6. Update `docs/user-guide.md` incrementally with the two-command technical-team
   workflow and source-specific analyst actions.
7. Consider updating `compound-gpid.md` and `roadmap.json` because this decision
   expands the current focus from estimation-only work to a full collection and
   estimation system.

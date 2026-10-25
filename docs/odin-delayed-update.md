---
title: "Running an SPI Update When ODIN Is Delayed"
created: "2026-10-20"
updated: "2026-10-25"
status: "operational guidance"
---

# Running an SPI update when ODIN is delayed

A delayed Open Data Inventory (ODIN) release can be represented by an explicitly
labelled carry-forward input for internal review. It does not establish that
the new ODIN vintage exists or that the SPI result is final. The
[202611 status](update-status-202611.md) identifies the retained preview and
outstanding source/release decisions.

For 202611, `end_date <- 2025` and `odin_status <- "provisional"`.
The update label is a planned release identifier. Earlier plans anticipated
7 December 2026 for the official ODIN file; actual receipt, review, and the
approved release record determine readiness, not that calendar date.

## Dependency and output contract

`odin_files` tracks every `ODIN_<YEAR>.csv` from 2015 through `end_date` under
`01_raw_data/2.2_DSOA/`. `odin_data` reads and validates the shared inputs for
D2.2 online access and D4.3 geospatial data. The main chain is:

```text
odin_files -> odin_data -> dim2_odin / dim4_geo -> dim2 / dim4
  -> spi_data -> spi_index -> quantiles / treemap / Databank / revision evidence
```

The non-ODIN parts of D2 and D4 have separate scoring targets. Replacing ODIN
invalidates its dependents; collection run/control files and release checks
may also rerun. Do not promise that no other orchestration target will run.
The release diff checks the permissible **output changes**.

`odin_status` is read separately from scoring parameters. It controls the
output label/manifest, provisional notice, revision-evidence labels, and the
official release-record check. Setting it to `"official"` alone is insufficient.
Normal estimation writes to `03_output_data/.candidate/` and promotes a
validated complete set. A provisional set includes `PROVISIONAL_ODIN.md`;
successful official promotion removes it. Sandbox previews have the same
notice in their own output folder and do not replace normal release gates.

## Prepare and review provisional outputs

1. Preserve the previous ODIN input set and record its exact hashes. Keep the
   approved prior SPI indicator/index outputs and baseline manifest intact.
2. Obtain all other manual inputs, run collection, and complete the relevant
   workbook reviews and source attestations. See the [user guide](user-guide.md).
3. If using a stand-in, prepare `ODIN_2025.csv` from the previous release as
   a documented carry-forward. Ensure its embedded year/schema matches the
   intended source-file convention; do not blindly copy bytes if the
   checkpoint requires adjusted metadata. Do not overwrite the preserved
   previous-year input. The current retained stand-in is already present.
4. Keep `odin_status <- "provisional"`. Confirm a matching complete collection
   run with no blocking sources, then run normal estimation.
5. Review the vintage diff, source evidence, and all non-ODIN revisions.
   Frozen-history changes still require explicit approval. Share only
   clearly labelled preliminary material while those decisions are pending.

Run commands from the repository root with repository-local temporary
variables initialized as in [replication instructions](../replication/README.md).

```r
targets::tar_make(script = "_targets_data.R", store = "_targets_data")
# Inspect the run/status reports and complete source acceptance first.
targets::tar_make(script = "_targets.R", store = "_targets")
```

ODIN registry presence/schema checks do not certify an official release. The
label, provenance and approval record matter. Likewise, a completed collection
run may still have blocking rows and is not itself source approval.

## Lock an approved provisional set

Only after the complete **promoted** provisional outputs are approved:

```r
for (file in list.files("R", full.names = TRUE, pattern = "[.]R$")) source(file)
params <- load_params()
write_release_lock(params, approved_by = "Technical lead name")
```

The approver must be the actual authorized person. The call requires the
promoted manifest and expected files. It archives outputs under
`03_output_data/releases/202611-provisional/` and writes
`01_raw_data/_collection/release_lock_2025.json` and its detached `.sha256`
integrity record. Existing locks and archive folders are not overwritten.

The lock covers non-ODIN registry artifacts, World Bank snapshots, relevant
provenance sidecars, collection/control identities, baseline controls,
approval/attestation records, and approved output hashes. PIP collection uses
the pinned release. Collection and estimation fail on unexpected non-ODIN
changes. Schema, self-hash, and detached integrity checks detect inconsistency;
they do not replace independent human approval.

Do not delete/recreate a lock to absorb unapproved changes. Review the change
and record the appropriate decision before establishing a different release
baseline. Historical sandbox locks are not the real release lock.

## Install an approved official ODIN release

### 1. Preserve and validate the supplied files

Stage the official download in a new folder **inside the repository**, keeping
the provisional annual files and hashes available. Record the actual source
URL, release label/date, approver, filenames, and raw-file hashes.

Compare **all annual inputs** from 2015 through 2025 for schema, country codes,
coverage, category labels, numeric values, duplicate country/year keys, and
historical revisions. The shared reader requires the columns in
`odin_required_columns` (`R/dim2.R`), including openness and geospatial fields.
It accepts the documented numeric missing tokens and stops on invalid text.
All-category country rows must have unique keys; geography must match the
collected country universe after the explicit crosswalk/exclusions.

A valid source download may legitimately revise older years. Those changes
must also pass the frozen-history approval gate; an ODIN-dependent column is
not automatically approved for a historical revision.

### 2. Create the official release record

The configured path is `01_raw_data/2.2_DSOA/ODIN_release.json`.
`read_odin_release_record()` in `R/output_manifest.R` enforces this schema:

```json
{
  "schema_version": "spi-odin-release-v1",
  "source_url": "<actual official download URL>",
  "release_label": "<actual source release>",
  "released_at": "<actual UTC timestamp: YYYY-MM-DDTHH:MM:SSZ>",
  "approved_by": "<actual approver>",
  "files": [
    {
      "file": "ODIN_2015.csv",
      "sha256": "<64-character SHA-256 of the approved official file>",
      "provisional_sha256": "<64-character SHA-256 of the prior provisional file>"
    }
  ]
}
```

This is a structural example, not a complete record to copy. The real `files`
array must contain exactly every filename consumed by `odin_files` with valid
hashes; `released_at` must be a valid UTC date/time. Each `sha256` must match
the installed annual file. Approval is a human action, not a script-generated
name inserted to make validation pass.

**Current implementation restriction:** the verifier also requires
`sha256 != provisional_sha256` for **every** annual entry. If an official
release leaves historical annual files byte-identical and changes only 2025,
the current contract rejects that otherwise plausible file set. Stop and
resolve this restriction through a reviewed implementation decision before
finalization. Do not alter source bytes or invent hashes to satisfy it.
Documentation does not resolve or bypass this limitation.

### 3. Activate and validate the transition

After the supplied files and record meet the reviewed contract, install them
at the expected annual paths and set `odin_status <- "official"`.
Rerun collection and estimation using their separate stores. A retained
release lock must still validate the non-ODIN inputs and controls.

Before promotion, `release_diff` compares the candidate set with the locked
provisional archive and writes `release_diff_2025.csv` and `.md` next to the
outputs. The allowed changes are defined by `R/release_diff.R`: ODIN RAW/SPI
columns, their dimension scores, pillars 2 and 4, overall index and derived
rank/quantile/Databank/treemap results, with the documented jitter treatment.
Unexpected key/row/schema changes or values outside this scope block
promotion. Inspect the exact report; an allowed series is not a guarantee
that any source coverage change will be accepted.

## Rehearse without changing the normal output set

The rehearsal uses an isolated repository-local sandbox and explicit
sandbox-only overrides of the collection/vintage gates. It perturbs ODIN,
checks an unchanged rerun, tests a non-ODIN change, and records the comparison.
It is engineering evidence, not approval of the actual final source release.

```sh
Rscript tests/replication/rehearse_odin_swap.R \
  --out replication/spi-rep/rehearsal-next
```

Read `replication/spi-rep/rehearsal-next/_rehearsal_summary.txt` and all step
logs. Earlier rehearsals predate some current controls, including official
release verification. Their success does not establish that the actual final
file set meets the newer contract. Use a new run name to retain earlier
results; fresh clones do not include the local historical rehearsal folders.

## Final acceptance and next vintage

Confirm the approved input set and release record, matching unblocked
collection, current tests/replication scope, explicit history approvals,
complete promoted manifest, `odin_status = "official"`, and absence of the
provisional notice. Review the release diff against the approved archive and
refresh attribution, E6/aggregate evidence, and the Working Group narrative
from the same final output set.

Preserve the approved final `SPI_data.csv` and `SPI_index.csv` as the next
vintage's baselines and prepare the reviewed baseline manifest with their
hashes. Keep the source/download evidence, lock/archive, approvals, and run
records together. Promotion inside this repo and external publication are
separate steps; release only the authorized final set.

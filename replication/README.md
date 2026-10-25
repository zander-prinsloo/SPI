# SPI replication and review artifacts

The preliminary 202611 files for internal review are:

- [SPI_data.csv](spi-rep/preview-p0p1/SPI_data.csv)
- [SPI_index.csv](spi-rep/preview-p0p1/SPI_index.csv)
- [Provisional ODIN notice](spi-rep/preview-p0p1/PROVISIONAL_ODIN.md)
- [Revision summary](spi-rep/preview-p0p1/revision_summary_2025.md)

These files contain reference years 2004–2025. They are preliminary, precede
the completed source attestations and reviewer workbooks, and use provisional
ODIN data. The matching durable summary is also in
`docs/revisions/202611/preview/revision_summary_2025.md`.

This is the retained 24 October snapshot, not a claim that the latest branch
has passed normal estimation. The [current status](../docs/update-status-202611.md)
records the mismatched collection run/report and pending approvals.
`03_output_data/` still contains the prior release through 2024.

## Locations

| Directory | Contents |
|---|---|
| `spi-rep/` | Retained preview and replication outputs, comparison baselines, ODIN rehearsals, and run logs |
| `spi-gate/` | Historical source-readiness review helpers and evidence |
| `jmp-probe/` | Retained JMP download and calibration probes |
| `oecd-probe/` | Retained OECD and other collection/scoring probes |
| `external-logs/` | Historical SPI test logs and acceptance helpers recovered from the system temporary directory |
| `r-session-artifacts/` | Recovered D4.1 catalogue script and response files from an R session |
| `.scratch/` | Working sandboxes and temporary intermediate files for new runs; ignored by Git |

Git tracks the two review CSVs, provisional ODIN notice, estimation manifest,
revision and vintage-diff reports, and relocation documentation and inventory.
Bulk derived outputs, earlier runs, probes, and recovered helpers and logs
remain in this repository's local folders and are ignored by Git.

Keep all SPI run outputs, logs, working sandboxes, and intermediate files
inside this repository. Run the following commands from the repository root.
Setting the temporary-directory variables before starting R also contains
that R session's temporary files:

```sh
mkdir -p replication/.scratch
export TMPDIR="$PWD/replication/.scratch"
export TMP="$TMPDIR"
export TEMP="$TMPDIR"

Rscript tests/replication/preview_estimation.R \
  --out replication/spi-rep/preview-next
```

The preview, replication, and rehearsal scripts reject output locations
outside the repository. Their working sandboxes and child R sessions use
`replication/.scratch/`. Use a new output directory to retain an earlier run.

## Run modes and prerequisites

Restore the recorded R environment and provide the required manual sources
first. The exact `01_raw_data/1.5_DUIO/UN IGME 2025.csv` is not in Git; see
the [exclusion record](../docs/revisions/202611/git-history-file-exclusion-2026-10-25.md).
Network access can still be required when collectors lack usable caches;
`run_downloads = FALSE` only disables the optional D4.1 catalogue refresh.

| Script | Purpose and important flags |
|---|---|
| `tests/replication/preview_estimation.R` | Current-reference-year preliminary build; `--out` is required; `--keep-sandbox` retains working files; `--legacy-e6` uses the older country-name joins for a matched E6 comparison |
| `tests/replication/run_replication.R` | Isolated 2024 reconstruction; `--code worktree` or a Git ref, `--vintage 2024`, `--out`, optional `--compare`, `--keep-sandbox`, and explicit `--allow-skips` |
| `tests/replication/rehearse_odin_swap.R` | Sandbox rehearsal of a provisional/official transition; `--out` is required and `--keep-sandbox` retains the working set |

Preview and rehearsal scripts disable collection acceptance and vintage-diff
enforcement only inside their sandboxes. Source readers and other validation
can still fail. These modes produce diagnostic/review evidence; they do not
approve sources or replace normal release gates.

Example reconstruction using a retained local comparison reference:

```sh
Rscript tests/replication/run_replication.R \
  --code worktree --vintage 2024 \
  --out replication/spi-rep/replication-next \
  --compare replication/spi-rep/step16b
```

`step16b` and most older run folders are local archives and are not included
in a fresh clone. Restore/rebuild an appropriate reference before comparing.
The executable raw baseline is `25b534706ff6`; historical IDs can be mapped
using the exclusion record. Existing X1 differences and E1–E6 exceptions have
specific scopes; see the [test guide](../docs/user-guide.md#7-interpreting-test-results).
The runner exits nonzero on failures, errors, comparison differences, and
unaccepted skips. `--allow-skips` does not approve failed expectations.

For every deliberate new run, record the invoked command and Git revision
alongside the logs. Inspect the output manifest, provisional notice, vintage
diff, and revision evidence; the manifest's timestamp and vintage do not by
themselves establish which code/source snapshot was used. An earlier preview
cannot be assumed to reproduce newer code. The actual official ODIN transition
also has the [release-record constraint](../docs/odin-delayed-update.md#2-create-the-official-release-record).

## Relocation on 25 October 2026

Existing external artifacts were moved here without changing their contents.
The [audit](external-artifact-audit-2026-10-25.md) describes the scope and
findings. The [manifest](relocation-manifest-2026-10-25.json) records every
original path, current path, byte count, and SHA-256 checksum.

Historical logs and archived helper scripts retain the paths recorded when
they ran. For example, `/tmp/spi-rep/preview-p0p1/` now corresponds to
`replication/spi-rep/preview-p0p1/`. Current documentation references the new
locations. The historical helpers are retained as evidence; use the scripts
under `tests/replication/` for new runs.

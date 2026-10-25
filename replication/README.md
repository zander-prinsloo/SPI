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

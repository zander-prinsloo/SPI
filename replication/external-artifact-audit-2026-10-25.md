# SPI external artifact audit — 25 October 2026

The 202611 review files now reside in
`replication/spi-rep/preview-p0p1/SPI_data.csv` and `SPI_index.csv`.

## Scope

- Searched tracked SPI run scripts, guides, handover records, active-state
  references, and revision evidence for external output paths.
- Inspected `/private/tmp/` (`/tmp` on macOS) for SPI run directories, probes,
  helpers, and logs; checked ambiguous files for SPI-specific content.
- Checked the current user's macOS temporary directory for SPI sandboxes and
  inspected its retained R-session directories for SPI output filenames and
  project-specific intermediate files.
- This was a project artifact audit of these locations and repository
  references, not a search of every file on the computer.

## Findings and action

| Original location | Current repository location | Findings |
|---|---|---|
| `/tmp/spi-rep/` | `replication/spi-rep/` | Earlier replication runs, published-vintage comparison baselines, previews, ODIN rehearsals, and logs |
| `/tmp/spi-gate/` | `replication/spi-gate/` | Review helpers, diagnostics, and supporting evidence |
| `/tmp/jmp-probe/` | `replication/jmp-probe/` | JMP download and calibration probes |
| `/tmp/oecd-probe/` | `replication/oecd-probe/` | OECD and other SPI source/scoring probes |
| Standalone SPI files in `/tmp/` | `replication/external-logs/` | Test logs and acceptance helpers |
| User temporary directory, `RtmpbM53Bj/` | `replication/r-session-artifacts/RtmpbM53Bj/` | D4.1 catalogue script and two response files |

Moved **1,363 files, approximately 4.04 GB**, and verified every file against
its SHA-256 checksum recorded before relocation. No identified SPI run
artifact remains at the original locations. The two main output files in
`03_output_data/` were not replaced, and no estimation was rerun.

The [relocation manifest](relocation-manifest-2026-10-25.json) is the complete
file inventory. Historical artifacts remain unchanged, including old paths
inside logs and scripts. Current guides and evidence pointers were updated.

Generic R runtime files remain in the system temporary directory, including
library-location caches and callr process bookkeeping. No retained
`SPI_data.csv`, `SPI_index.csv`, estimation manifest, provisional ODIN notice,
or revision-report output was found there after relocation. Shared R package
caches and operating-system/application files were outside the artifact move.

The legacy reference script `02_programs/misc_scripts/nada_check.R` also
contains a hard-coded Windows output path. This audit found no evidence that
the current pipeline wrote to that location; the legacy reference was left
unchanged.

## Future runs and validation

- Preview, replication, and rehearsal output paths must be within the repo;
  checks reject external paths, parent-directory traversal, and symlinks to
  external directories before creating an output directory.
- Run sandboxes and child-process temporary files use
  `replication/.scratch/`. The attribution and agriculture evidence scripts
  also create their working folders there.
- The [run instructions](README.md) set `TMPDIR`, `TMP`, and `TEMP` before R
  starts, so the parent R session's temporary files are also inside the repo.
- Verified local relative and absolute paths, rejected external/traversal/
  symlink paths without creating external folders, and checked that a child
  R session uses the repository temporary directory.
- Parsed all six changed R scripts and ran the focused replication-runner
  tests. Full collection and estimation were not necessary for relocation.

# SPI source runtime inventory

**Updated: 25 October 2026.** This replaces the pre-migration inventory of
5 October. Acquisition now belongs to `_targets_data.R`; estimation in
`_targets.R` reads collected files. See the
[architecture](pipeline-architecture.md) and
[current source/run status](update-status-202611.md).

## Where acquisition runs now

| Source/group | Current implementation | Retained collection evidence |
|---|---|---|
| PIP poverty comparability | `R/collect_pip.R`, `pip_collection` | Request/release identity, raw/cache artifacts, normalized comparability CSV, provenance sidecar; a release lock pins the approved release |
| World Bank countries, OECD list, population, GDP | `R/collect_world_bank.R`, `world_bank_inputs` | Raw responses and RDS snapshots under `_collection/world_bank/`; estimation reads the snapshots |
| JMP safely managed water | `R/pull_jmp.R`, `jmp_collection` | Cached Data Summary sheets and workbook URL/hash/size identities, normalized quality file, and calibration evidence; the collector does not retain every original workbook |
| OECD SDG evidence | `R/collect_oecd.R`, `oecd_collection` | SDMX raw/cache data and normalized OECD SDG file |
| UN SDG D3 data products | `R/collect_sdg.R`, `sdg_collection` | Per-series compressed/cache data, geography validation, annual scored D3 artifacts |
| UN SDG CRVS, legislation, finance | `R/pull_unsdg.R`, `unsdg_collection` | Raw API responses and normalized dimension inputs |
| NADA | `R/collect_nada.R`, `nada_url_evidence`, `nada_output` | Prior vintage, URL checks, current review workbook, output CSV, collection manifest |
| D4.1 censuses/surveys | `R/collect_dim4_1.R`, `R/collect_dim4_1_prefetch.R` | Workbook validation, annual derived files, manual review, normalized companions, cache/failure log, refresh record and manifest |
| EMPL, CNIN, FINA | `R/collect_d5_2.R`, annual collection targets | ILO national-sources catalogue, prior inputs, review workbooks, and derived annual outputs |
| GSBP | `R/collect_gsbp.R`, `gsbp_output` | Prior vintage, desk review, current manual-review workbook, output/manifest and warnings |

A target name in this table identifies orchestration; the source registry
records the authoritative required artifact paths and acceptance rules.
The same source may have several registered artifacts and review layers.

## Manual files and access requirements

IGME, ILO bulk extracts, WDI metadata, IMF workbooks, ODIN annual files,
CLASS, annual review workbooks, and other prepared inputs still require
source-specific analyst action. `manual_checkpoints` validates presence and
schema; hash-bound source attestations are a separate acceptance step.

The configured `UN IGME 2025.csv` is local-only because it exceeds the regular
Git file-size limit. A fresh clone must obtain it separately. See the
[exclusion record](revisions/202611/git-history-file-exclusion-2026-10-25.md).
The source-specific [user guide](user-guide.md#44-detailed-source-instructions)
lists filenames and preparation steps.

Most sources are public. The D4.1 refresh also uses the World Bank internal
microdata library and therefore requires World Bank network access; retaining
that source is a Working Group decision. Some IMF/manual material may require
institutional access. Do not describe all raw inputs as anonymously available.

## Controls that do not mean “offline”

`run_downloads = FALSE` disables the optional D4.1 catalogue refresh only.
Other collectors may fetch cache misses or stale responses. `refresh_nada_urls`
controls NADA URL checks. A locked PIP release restricts the selected source
vintage; it does not guarantee every request can be served without network
access. Cached payload and provenance validation still applies on reuse.

## Estimation boundary

The collected country snapshot is loaded by `R/setup.R`; `R/append.R` reads
collected population/OECD inputs and `R/quantiles.R` reads collected GDP.
These are no longer live acquisitions into the root `staging/` folder.
Registry-resolved source files and content digests are explicit estimation
dependencies. The shared ODIN reader validates annual files for D2.2/D4.3.

Original scripts in `02_programs/` can contain live requests, legacy output
paths, and assumptions predating the new graphs. They remain references, not
the operational entry points for an update. In particular, the legacy NADA
script has a hard-coded Windows output location; use the active collection
implementation described above.

## Repeating this audit

Check the actual calls in `_targets_data.R`, `_targets.R`, and `R/`; identify
raw writes, provenance, normalized artifacts, manual prerequisites, and the
consumer file targets. Distinguish persistent source artifacts from temporary
transport files. Confirm fresh-clone availability and internal access needs.
Do not promote a source to automated acquisition solely because an old script
contains a URL. Validate schema, geography, keys, hashes, and fail-loud behavior
before changing source contracts.

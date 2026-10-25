# SPI 202611 status

**Checked: 25 October 2026. Branch: `dev_SPI_2025`.** This page reports the
observed repository state. It does not approve sources, methodology changes,
or publication. Update it after a new collection/estimation run.

## Review files

Use these retained preliminary files for internal review:

- [SPI_data.csv](../replication/spi-rep/preview-p0p1/SPI_data.csv)
- [SPI_index.csv](../replication/spi-rep/preview-p0p1/SPI_index.csv)
- [Provisional ODIN notice](../replication/spi-rep/preview-p0p1/PROVISIONAL_ODIN.md)
- [Revision summary](revisions/202611/preview/revision_summary_2025.md)
- [Working Group draft](revisions/202611-revision-report.md)

The preview was produced on 24 October 2026 and contains 4,774 economy-year
rows in each main CSV, covering 2004–2025 and 217 economy rows for 2025.
It uses provisional ODIN data and precedes completed manual reviews and
attestations. It is a retained snapshot, not proof that the latest branch
has passed normal collection and estimation. Label shared material
**“Preliminary 202611 estimates — subject to review; ODIN provisional.”**

`03_output_data/SPI_data.csv` and `SPI_index.csv` still match the archived
202511 outputs through 2024 (4,557 rows each). They have not been replaced by
the preview. The root `staging/` folder contains older compatibility files.

## Collection state and source review

| Evidence | Observed state |
|---|---|
| `01_raw_data/_collection/collection_run.json` | Latest run `20261024T202211Z-932a14ce7bf7` remains `started` |
| `collection_status.csv` and `.md` | Earlier report for `20261024T101422Z-376f4ac13a8b`: 17 blocking `attestation_missing`, 1 GSBP warning, 35 informational rows |
| `review_candidates_2025.csv` | 853 candidate rows; these are review items, not 853 separate workbooks |
| D4.1 refresh record | A retained 24 October refresh exists; check its manifest/cache identities when rerunning |
| Real 2025 release lock | Not present; historical rehearsal locks are sandbox evidence |

The report and latest run marker are from different runs. Rerun collection
using the current code after the required reviews and attestations; do not
edit `collection_state`, hashes, status rows, or approval records to make the
gate pass. The earlier count of 17 does not predict the outcome of that rerun:
newer validation controls may surface additional issues.

## Retained-preview revision evidence

The current durable summary matches `replication/spi-rep/preview-p0p1/`.
Compared with the 202511 indicator vintage, it records:

| Policy/dimension | Historical cells changed |
|---|---:|
| D1.5, refreshed | 706 |
| D4.1, refreshed | 362 |
| D4.2, refreshed | 5 |
| Refreshed total | 1,073 |
| D2.2, frozen: Andorra, 2017–2021 | 30 |
| D4.3, frozen: Andorra, 2017–2021 | 10 |
| D5.5, frozen: Colombia, 2024 | 1 |
| Frozen total awaiting a decision | 41 |
| Total | 1,114 |

The attribution summary contains 1,073 refreshed-cell assignments. For 2024,
the overall-index comparison has 188 comparable economies, 98 revised scores,
mean absolute change 0.95, maximum change 8.00, 159 rank changes, and 16
quintile changes. See the generated tables for definitions and full detail.

The E6 comparison for this preview contains 233 changed indicator cells
(66 child mortality, 167 LFP) across 12 economies. The separate 2024
replication E6 evidence contains 157 indicator cells. These are different
comparisons and must not be added together.

Older handover figures (845 refreshed changes, one frozen change, and 251
E6 preview cells) refer to an earlier snapshot. They are not the counts to
use for the retained `preview-p0p1` review package.

## Remaining work

1. Review source-name/country mappings and outstanding methodological issues.
   The dated gate review still flags IGME observation-unit and JMP sentinel
   questions, human release approvals, and legacy metadata reconciliation.
   Current code includes an IGME Total-wealth filter; a prose update does not
   resolve the associated methodology/approval finding.
2. Complete the CNIN, FINA, GSBP, D4.1, and relevant source reviews. Check the
   853 candidate rows, record evidence, and attest the actual reviewed bytes.
3. Decide explicitly on all 41 frozen-history changes or revise inputs to
   retain the approved history. Do not infer approval from a preview report.
4. Run collection to a completed, matching, hash-bound, unblocked report;
   run normal estimation and the relevant validation/replication checks.
5. Regenerate revision attribution, E6/aggregate evidence, and the Working
   Group narrative from the exact new output set. Historical test runs and
   exception fixtures are evidence with a scope, not current release sign-off.
6. Approve provisional outputs, then create the real release lock/archive.
7. When official ODIN is available and approved, validate its release record,
   rerun the documented transition, inspect the release diff, and publish
   only the approved final outputs. Preserve the final baseline for the next
   update. Calendar dates alone do not establish source readiness.

## Repository and Git handoff

The branch is published as `origin/dev_SPI_2025`. The oversized manual file
`01_raw_data/1.5_DUIO/UN IGME 2025.csv` remains local and ignored; a fresh
clone must obtain it separately. Its checksum and the unpublished-history
rewrite map are in the [exclusion record](revisions/202611/git-history-file-exclusion-2026-10-25.md).
The executable replication baseline is now `25b534706ff6`.

The two review CSVs and supporting reports are versioned. Earlier runs,
JMP/OECD probes, recovered helpers/logs, and scratch directories are retained
locally under `replication/`, are ignored, and will not appear in a fresh
clone. See the [artifact guide](../replication/README.md) and relocation audit.

For operation, use the [user guide](user-guide.md),
[architecture](pipeline-architecture.md), and [ODIN guide](odin-delayed-update.md).
Dated `.cg-docs/` plans/reviews remain historical records; consult their
frontmatter finding statuses and this page before resuming work.

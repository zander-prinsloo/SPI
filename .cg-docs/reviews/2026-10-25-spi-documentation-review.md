---
date: 2026-10-25
type: documentation
baseline: eed6723
scope: active repository guides, wiki, pipeline comments, and current-state pointers
---

# SPI repository documentation reconciliation

Operational documentation was reconciled with the current source code,
collection records, retained `preview-p0p1` evidence, and Git handoff. Start
with the [documentation index](../../docs/README.md) and
[current status](../../docs/update-status-202611.md).

## Improvements implemented

| Area | Gap | Resolution |
|---|---|---|
| Entry point | Duplicate README heading and legacy-first instructions | Active two-pipeline quick start, documentation map, current review-file links, and directory table |
| Architecture | Collection, scoring, output promotion, and approval mixed together | New graph/reference explaining separate stores, file/content dependencies, run integrity, gates, promotion, and release scope |
| Current status | Old branch name, complete-run claim, and outdated preview counts | Dated status page and active-state update; stale report/latest-run mismatch is explicit |
| Review evidence | Narrative mixed 845-cell and later 1,073-cell previews | Working Group draft reconciled with the current retained generated tables, including 41 frozen cells and 233 E6 cells |
| Source acquisition | Runtime audit still described pre-migration live estimation requests | Current collector/artifact inventory, manual sources, cache/network controls, and institutional access requirements |
| Fresh clones | Oversized ignored input and local-only archives easy to miss | IGME filename/checksum/history-map links and precise versioned versus local artifact guidance |
| Output directories | `staging/`, candidate files, current outputs, and release archives conflated | Folder roles documented consistently; obsolete manual-copy/never-overwrite claims corrected |
| Source details | IGME name joins and hard-coded ILO filenames still prescribed | Actual ISO3/wealth/date filters, config-driven filenames, and accuracy safeguards documented |
| ODIN finalization | A label/file replacement was described without the newer release contract | Official record schema, annual hashes, lock/control integrity, comparison scope, and unchanged-history restriction documented |
| Validation | Unqualified full-suite and exact-replication claims | Focused checks, explicit porting skips, strict manifests, isolated 2024 reconstruction, and historical X1/E1–E6 scope distinguished |
| Recovery | Routine store destruction and lockfile snapshots recommended | Targeted invalidation, inspection of failed evidence, and deliberate dependency-change guidance |
| Historical records | Old handovers/readiness review read as current instructions | Scope notices preserve historical findings while linking to current operational state and commit map |
| Wiki and tool context | Pipeline still “under development,” old R version, public-only source claims | Managed wiki sections and manifest date refreshed; repository context aligned with active code |
| Inline documentation | Candidate writers still described as root `staging/` writes | R/config/orchestration comments corrected without changing executable expressions |
| Maintenance | No clear ownership or update path | Contributor guide and documentation-authority/refresh instructions added |

## Validation

- Checked local file links and heading anchors in all edited/new Markdown.
- Parsed documented shell blocks without executing them; quoted historical
  placeholders that previously looked like shell redirections.
- Parsed 21 R documentation examples and JSON examples; validated active-state
  JSON and wiki/frontmatter YAML, schema identity, and managed section markers.
- Compared parsed R expressions with `HEAD`: all 11 changed R files are
  comment-only, with no executable change.
- Inspected both target manifests without running collection or estimation:
  48 estimation targets and 32 collection targets; checked the documented
  gate, report, and release target names.
- Cross-checked revision totals, attribution rows, frozen economies/years,
  2024 score/rank/quintile counts, E6 preview counts, review row/year coverage,
  and the unchanged previous-vintage main CSV hashes against retained files.
- Confirmed no raw inputs, generated CSV/evidence snapshots, immutable fixtures,
  output files, or dependency lockfile changed. No collector, statistical
  estimation, source attestation, release approval, or publication was run.

Validation scratch records are local under
`replication/.scratch/documentation-audit-20261025/`. They are working files,
not a replacement for release evidence.

## Remaining substantive work

Documentation now exposes rather than resolves the incomplete collection run,
manual source/reviewer acceptance, methodology findings, 41-cell frozen-history
decisions, current-code statistical validation, and final ODIN transition.
The official verifier's requirement that every annual hash differ can reject
an actual release with unchanged historical files; this needs a reviewed
implementation decision if encountered. None of these approvals or contract
changes was made as part of this documentation task.

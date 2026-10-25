# SPI documentation

This is the navigation index for the collection-first SPI workflow. Read
[current update status](update-status-202611.md) before using historical
handover or review records as operational instructions.

## Operators and reviewers

- [Technical lead user guide](user-guide.md): environment setup, collection,
  source-specific instructions, review workbooks, attestations, estimation,
  troubleshooting, and validation.
- [202611 status](update-status-202611.md): review-file locations, observed
  run state, retained-preview figures, blockers, and remaining decisions.
- [Pipeline architecture](pipeline-architecture.md): the two graphs, input
  dependencies, caches, output directories, validation, and promotion.
- [Delayed ODIN update](odin-delayed-update.md): provisional inputs, approval
  record, release lock, and comparison before final publication.
- [202611 revision report](revisions/202611-revision-report.md): Working Group
  draft based on the retained preview, with linked quantitative evidence.
- [Source runtime audit](source-runtime-audit.md): where acquisition occurs
  now and which inputs remain manual or require World Bank network access.
- [JMP methodology brief](jmp-safely-managed-water-brief.md): dated water
  scoring analysis and proposed methodology decisions; not a release approval.

## Developers and replication

- [Contributor guidance](contributing.md): documentation ownership, tests,
  generated artifacts, source changes, and Git practices.
- [Replication artifacts](../replication/README.md): the review snapshot,
  repository-local run commands, archives, and relocation audit.
- [Changelog](CHANGELOG.md): implementation history and legacy exceptions.
- [IGME file exclusion and history map](revisions/202611/git-history-file-exclusion-2026-10-25.md):
  the local-only manual input and old-to-new commit references.
- [Wiki](../wiki/README.md): concise overview with links to these guides.

## Documentation authority and maintenance

`_targets_data.R`, `_targets.R`, `config/`, and `R/` define actual behavior.
Operational guides explain that behavior. Generated CSV/Markdown reports
record a particular run; their figures need not describe the latest code.
The status page identifies the snapshot currently being reviewed.

Dated plans and reviews under `.cg-docs/` preserve the observations and
approvals recorded at that time. A finding marked fixed means implementation
work was recorded; it does not mean the current sources, methodology choices,
or release were approved. Historical test counts are not a current test run.
Current-state notices link older documents to the operational status page.

When code or data changes, update the relevant guide, the dated status and
revision narrative, and the active-state pointers. Regenerate evidence with
the documented scripts rather than hand-editing report tables. Reconcile
links and file paths, including whether a target is versioned, local-only, or
created by a future run. Never change an approval or a source attestation as
part of a prose update.

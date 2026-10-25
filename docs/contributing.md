# Contributing to SPI

Use the [architecture](pipeline-architecture.md) to locate the active logic,
and the [status page](update-status-202611.md) for the current release work.
The repository is an R analysis project, not an R package; run tests with
`testthat::test_dir()` or focused `test_file()` calls.

## Changes to sources and estimation

- Put acquisition and normalization in the collection graph. Preserve raw
  responses, request/release identities, timestamps, and hashes. Register
  new required inputs in `config/source_registry.R` and make file/content
  dependencies explicit in the consuming graph.
- Keep estimation based on collected files. Validate required columns,
  country codes, unique keys, and coverage before joins or missing-value
  fills. New source spellings require reviewed crosswalks/exclusions.
- Keep the original `02_programs/` reference scripts intact when changing
  the active pipeline. Document an intentional statistical correction and
  quantify its historical and downstream effects; obtain the relevant human
  decision rather than broadening an exception to hide a difference.
- Add meaningful tests for changed behavior and failure paths. Inject/mock
  network fetchers in tests. Separate live collection validation from unit
  tests; a cached response is still provenance-bearing source data.
- Keep the locked environment stable. Use `renv::status()` to investigate
  mismatches and `renv::restore()` to restore recorded dependencies. Change
  `renv.lock` only for an intended, reviewed dependency update.

## Outputs, fixtures, and local artifacts

Write new output files through the existing candidate/writer targets. Let
normal validation and promotion manage `03_output_data/`; preserve approved
prior vintages and their baseline manifest. Do not replace immutable
`tests/fixtures/` files to make a failing comparison pass.

Keep working files under `replication/`, and initialize `TMPDIR`, `TMP`, and
`TEMP` as described in its [README](../replication/README.md). Use new run
names to preserve previous evidence. Record the exact input/output snapshot
behind any published count. A sandbox preview bypasses approval gates and
must remain visibly preliminary.

Git tracks the designated review CSVs and evidence. Bulk downloads, old runs,
probes, logs, and scratch directories remain local and ignored. The exact
2025 IGME CSV is also ignored because it exceeds the regular-file size limit;
its earlier vintages remain tracked. Before committing, inspect `git status`,
the staged diff, and staged file sizes. Keep credentials and local access
configuration out of version control.

## Validation and documentation

Use the [test instructions](user-guide.md#7-interpreting-test-results) to
choose development checks, strict comparisons, or isolated vintage
replication. Distinguish skipped comparisons from passing comparisons and
accepted historical differential failures from new failures. A previous
suite's counts do not verify newly changed code.

For documentation-only edits, check local links, filenames, JSON/YAML metadata,
and R example syntax. Inspect target manifests without executing collection
when verifying target names. Do not run live collectors or rewrite generated
statistical evidence solely to validate prose.

Maintain the [documentation index](README.md), user guide, current status,
and relevant source/release guide together. Keep wiki updates inside the
existing managed sections and update its manifest date. Add a current-state
notice to dated handovers instead of rewriting their historical evidence.
Generated tables belong to their producing scripts; change the narrative
around them or regenerate the exact run deliberately.

When methodology, source acceptance, or release approval remains undecided,
state the unresolved decision and its effect on the workflow. Documentation
maintenance does not authorize attestations, approvals, source substitutions,
or final publication.

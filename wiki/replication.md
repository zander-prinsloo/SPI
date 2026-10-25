# Replication

<!-- cg:auto:environment-setup -->
Use R 4.6.1 as recorded in `renv.lock`, restore the recorded environment with
`renv::restore()`, and work from the repository root. Initialize repository-
local temporary variables before R starts, following the
[artifact guide](../replication/README.md).

A fresh clone must separately obtain
`01_raw_data/1.5_DUIO/UN IGME 2025.csv`. It is intentionally ignored because
of its size; other IGME vintages remain tracked. See the
[exclusion record](../docs/revisions/202611/git-history-file-exclusion-2026-10-25.md).
Historical bulk runs and probes in `replication/` are local-only.
<!-- cg:auto:end -->

<!-- cg:auto:steps -->
Run collection, review and attest its sources, then estimate:

```r
targets::tar_make(script = "_targets_data.R", store = "_targets_data")
# Require a matching complete run/report and no blocking sources.
targets::tar_make(script = "_targets.R", store = "_targets")
```

Estimation validates its candidate output set and history/release differences
before promotion. The root `staging/` folder is a legacy cache. `run_downloads`
controls only the optional D4.1 catalogue refresh; other collectors may use
network access on a cache miss or stale response.

For a preliminary sandbox run and an isolated 2024 reconstruction, use the
[replication tools](../replication/README.md), not `Run_SPI.R`. The legacy
master runner remains a reference entry point for the old notebooks.
<!-- cg:auto:end -->

<!-- cg:auto:validation -->
Unit/contract tests, strict vintage comparisons, and live source/release gates
have different scopes. The 202511 fixtures represent reference year 2024;
use the isolated reconstruction harness for that comparison. Strict tests
fail on missing manifests; explicit `SPI_COMPARISON_MODE=porting` can permit
missing-output skips during development but is not release evidence.

See the [test guide](../docs/user-guide.md#7-interpreting-test-results) for
commands, exceptions, differential X1 limitations, and result interpretation.
The current [status](../docs/update-status-202611.md) distinguishes historical
suite results from validation still required for the latest code and sources.
<!-- cg:auto:end -->

← [Home](README.md)
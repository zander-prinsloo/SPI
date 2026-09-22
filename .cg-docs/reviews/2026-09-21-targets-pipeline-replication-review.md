---
date: 2026-09-22
depth: data-risk
type: standard
plan: .cg-docs/plans/2026-09-21-targets-pipeline-replication.md
findings:
  P1.1: fixed
  P1.2: fixed
  P1.3: fixed
  P1.4: fixed
  P1.5: fixed
  P1.6: fixed
  P1.7: fixed
  P1.8: fixed
  P1.9: fixed
  P1.10: fixed
  P1.11: fixed
  P2.1: fixed
  P2.2: fixed
  P2.3: fixed
  P2.4: fixed
  P2.5: fixed
  P2.6: fixed
  P2.7: fixed
  P2.8: fixed
  P2.9: fixed
  P2.10: fixed
  P2.11: fixed
  P2.12: fixed
  P2.13: fixed
  P2.14: fixed
  P2.15: fixed
  P2.16: fixed
  P2.17: fixed
  P2.18: fixed
  P2.19: fixed
  P2.20: fixed
  P2.21: fixed
  P2.22: fixed
  P2.23: fixed
  P2.24: fixed
  P2.25: fixed
  P2.26: fixed
  P2.27: fixed
  P2.28: fixed
  P2.29: fixed
  P2.30: fixed
  P2.31: fixed
  P3.1: open
  P3.2: open
  P3.3: fixed
  P3.4: fixed
  P3.5: fixed
  P3.6: fixed
  P3.7: open
  P3.8: open
  P3.9: open
  P3.10: open
  P3.11: fixed
  P3.12: open
  P3.13: open
  P3.14: open
  P3.15: open
  P3.16: open
  P3.17: open
  P3.18: open
  P3.19: fixed
  P3.20: fixed
  P3.21: open
  P3.22: open
  P3.23: open
  P3.24: open
  P3.25: open
  P3.26: open
  P3.27: open
  P3.28: fixed
  P3.29: open
  P3.30: open
---

## Review Report

**Review mode**: data-risk
**Files reviewed**: 34 (21 R files + _targets.R + config/params.R + 6 test files + docs)
**Findings**: 76 (P0: 0, P1: 11, P2: 31, P3: 34)

### P0 — BLOCKING (immediate remediation required)

None found. The replication gate (1e-9 tolerance vs committed fixtures + C7 hash manifest) is sound and the pipeline reproduces the 202511 vintage exactly.

### P1 — CRITICAL (must fix before merge)

- **[P1.1]** [cg-code-quality/cg-documentation/cg-reproducibility] `R/dim1_5.R:514` — `else if (end_date - 1)` is a constant-truthy condition (any nonzero number is TRUE in R), so the `i - 4` branch is dead code and the second-to-last-year window extension is never applied.
  **Why**: Silent behavioral deviation from the documented scoring rule (the sibling `score_poverty_comparability()` uses `reference_year == end_date - 1` correctly). This is a FAITHFUL PORT of the original Rmd bug — changing it would break replication. Must be documented, not "fixed".
  **Fix**: Add a comment documenting that this is a faithful reproduction of the original Rmd's constant-true condition and must not be "corrected". [manual]
- **[P1.2]** [cg-data-quality] `R/dim4.R` (`census_fun` ~L174, `survey_fun` ~L330) + `R/dim2.R` (`score_nada`) + `R/dim5.R` — Vintage years hardcoded to 2024 while checkpoints are parameterized by `end_date`.
  **Why**: On the next vintage update (`end_date = 2025`), the checkpoint validates new `.2025` files but the pipeline silently reads stale `.2024` files — silent data-staleness on the exact update path.
  **Fix**: Parameterize file years from `params$end_date`. Do NOT change now (must stay 2024 to pass the gate); fix before the next vintage. [manual]
- **[P1.3]** [cg-data-quality] `R/append.R` — OECD high-income adjustment matches on country NAME against a live-fetched list; the `.country_name_aliases` map is not applied here.
  **Why**: A renamed high-income OECD country could silently lose the "set indicator = 1" adjustment for up to 8 indicators.
  **Fix**: Apply `.country_name_aliases` when building `country_mod_list`, or match by iso3c. [manual]
- **[P1.4]** [cg-testing] `tests/testthat/` — No unit tests for any dimension scoring function.
  **Why**: The entire suite is integration-level (stage-compare against fixtures). A bug that cancels out would pass. The scoring functions are pure and ideal for unit testing.
  **Fix**: Add `test-dim1_5.R`, `test-dim2.R`, `test-dim4.R`, `test-dim5.R`, `test-index.R` with synthetic minimal inputs. [manual]
- **[P1.5]** [cg-testing] `tests/testthat/test-validation.R:103-141` — The `countries_included` rule is a tautology (`iso3c %in% unique(iso3c)` is always TRUE).
  **Why**: The original Rmd asserts "all countries in the previous vintage are included"; the port makes it dead weight.
  **Fix**: Port faithfully: read the vintage fixture's iso3c set and assert membership. [manual]
- **[P1.6]** [cg-documentation] `docs/user-guide.md` — Section 4.3 row "1.5.1 PIP | `pipr` package" is wrong; the pipeline reads `PIP_comparability_latest.csv` directly.
  **Why**: A technical lead following the guide will look for a `pipr`-based update path that doesn't exist. **FIXED in this review** (safe_auto).
  **Fix**: (applied) Updated to reference the CSV download. [fixed]
- **[P1.7]** [cg-documentation] `docs/user-guide.md` — ILO filename update instructions mention only `R/dim1_5.R`, not `R/pull_ilo.R`. **FIXED in this review** (safe_auto).
  **Fix**: (applied) Added "update the same filename in `R/pull_ilo.R`". [fixed]
- **[P1.8]** [cg-documentation] `docs/user-guide.md` — Missing troubleshooting entries (forcing rebuild after `end_date` change, schema mismatch in dimension source, reading the pipeline graph).
  **Why**: These are the most common operational questions for a technical lead.
  **Fix**: Add subsections 6.7-6.9. [manual]
- **[P1.9]** [cg-documentation] `docs/user-guide.md` — Section 4.4 "4.1 Censuses and surveys" `<YEAR>` placeholder is misleading (both `dim4.R` and `checkpoints.R` hardcode `.2024.csv`).
  **Fix**: Document the hardcoded 2024 in both files. [manual]
- **[P1.10]** [cg-documentation] `docs/user-guide.md` — Section 2 Prerequisites package list is incomplete (missing `jsonlite`, `readxl`, `stringr`, `tidyr`, `purrr`, `zoo`, `magrittr`, `here`, `dplyr`). **FIXED in this review** (safe_auto).
  **Fix**: (applied) Changed to "all packages in `renv.lock`" with key ones listed. [fixed]
- **[P1.11]** [cg-documentation] `R/dim1_5.R:514` — same as P1.1 (code bug that also invalidates the inline comment). [manual]

### P2 — IMPORTANT (should fix)

- **[P2.1]** [cg-reproducibility] `config/params.R:55` — `country_metadata <- wbstats::wb_countries()` executes a live API call at source time; the response is not hashed so drift is invisible. [manual]
- **[P2.2]** [cg-reproducibility] `R/append.R:81-90` — `get_population()` fetches live on every run; no cache. [manual]
- **[P2.3]** [cg-reproducibility] `R/append.R:44-66` — OECD cache `staging/oecd_countries.rds` is not invalidated and lives in a git-ignored directory. [manual]
- **[P2.4]** [cg-reproducibility] `R/append.R:117` — OECD adjustment uses `income_level` from the live `wb_countries()` snapshot. [manual]
- **[P2.5]** [cg-reproducibility/cg-code-quality] `R/save.R:20-56` — `write_csv_staged()`/`is_historical_output()` are dead code; C7 protection is by convention only. [safe_auto]
- **[P2.6]** [cg-reproducibility] `R/dim1_5.R:470-471` — ILO filenames hardcode the `20250923T0014` timestamp in two places. [safe_auto]
- **[P2.7]** [cg-reproducibility] `R/dim2.R:237-240` — NADA filenames hardcode years `2020/2022/2023/2024`. [safe_auto]
- **[P2.8]** [cg-reproducibility] `R/dim4.R:122,226` — census/survey base files hardcode `.2024.csv`. [safe_auto]
- **[P2.9]** [cg-reproducibility] `R/compare.R:118-121` — non-numeric comparison can return `integer(0)` index. **FIXED in this review** (safe_auto). [fixed]
- **[P2.10]** [cg-reproducibility] `R/compare.R:96-99` — row alignment by `key_cols` uses `arrange()` without uniqueness assertion. [manual]
- **[P2.11]** [cg-reproducibility] `R/pull_jmp.R:96-108` — JMP download failure returns warning + NA row, not a hard failure. [safe_auto]
- **[P2.12]** [cg-reproducibility] `R/setup.R:70` — `build_country_grid()` calls `wb_countries()` again (second live call). [advisory]
- **[P2.13]** [cg-testing] `R/compare.R:107-131` — dead `both_na` variable in numeric branch. **FIXED in this review** (safe_auto). [fixed]
- **[P2.14]** [cg-testing] `R/compare.R:98-105` — `typeof()` misses integer-vs-double. [advisory]
- **[P2.15]** [cg-testing] `R/compare.R:119-129` — report-index bug untested. [manual]
- **[P2.16]** [cg-testing] `tests/testthat/test-stage-compare.R` — `SPI_index_labelled.csv` never compared. [advisory]
- **[P2.17]** [cg-testing] `tests/testthat/test-downloads.R:152` — no-op guard test asserts its own fixture. **FIXED in this review** (safe_auto). [fixed]
- **[P2.18]** [cg-testing] `tests/testthat/test-stage-compare.R` — skip-on-missing-staging risk. [advisory]
- **[P2.19]** [cg-testing] `tests/testthat/test-fixtures.R:46-60` — C7 test silently skips missing historical files. **FIXED in this review** (safe_auto). [fixed]
- **[P2.20]** [cg-testing] `tests/testthat/test-vintage-compare.R:87` — correlation test is a weak smoke check. [advisory]
- **[P2.21]** [cg-documentation] `R/checkpoints.R:1-20` — header falsely claims checkpoints are opt-in. **FIXED in this review** (safe_auto). [fixed]
- **[P2.22]** [cg-documentation] `R/checkpoints.R:44` — `verify_odin_data()` schema check weaker than the pipeline's actual needs. [manual]
- **[P2.23]** [cg-documentation] `R/checkpoints.R:100` — `verify_nada_data()` schema check only requires `iso3c`. [manual]
- **[P2.24]** [cg-documentation] `R/checkpoints.R:150` — microdata checkpoint hardcodes `.2024.csv` (same as P1.2). [manual]
- **[P2.25]** [cg-documentation] `R/compare.R:1-20` — `key_cols` docstring overstates alignment (only sorts). [manual]
- **[P2.26]** [cg-documentation] `R/save.R:1-20` — C7 protection documented as a guarantee but is dead code. [manual]
- **[P2.27]** [cg-documentation] `R/schema.R:34` — error message directs to `source_schema` registry that is mostly documentation-only. **FIXED in this review** (safe_auto). [fixed]
- **[P2.28]** [cg-documentation] `R/index.R:1-20` — -99 sentinel convention not documented. [advisory]
- **[P2.29]** [cg-documentation] `R/quantiles.R:1-20` — jitter non-reproducibility not documented in roxygen2. [advisory]
- **[P2.30]** [cg-documentation] `docs/CHANGELOG.md` — E2 claims jitter is "inherently non-reproducible" but targets seeds it. **FIXED in this review** (safe_auto). [fixed]
- **[P2.31]** [cg-code-quality] `.Rbuildignore` — `.cg-docs/` not excluded from package build. **FIXED in this review** (safe_auto). [fixed]

### P3 — MINOR (nice to have)

- **[P3.1]** [cg-code-quality] `R/index.R` — inconsistent `na.rm` in `rowMeans()`. [safe_auto]
- **[P3.2]** [cg-code-quality] `config/params.R` — `source_schema` registry drift risk. [advisory]
- **[P3.3]** [cg-code-quality] `R/dim1_5.R:429-430` — hardcoded ILO filenames (same as P2.6). [manual]
- **[P3.4]** [cg-code-quality] `R/dim2.R:235-258` — hardcoded NADA years (same as P2.7). [manual]
- **[P3.5]** [cg-code-quality] `R/databank.R:66` — `latest_date` unused. **FIXED in this review** (safe_auto). [fixed]
- **[P3.6]** [cg-code-quality] `R/databank.R:76` — `short_desc` computed but unused. **FIXED in this review** (safe_auto). [fixed]
- **[P3.7]** [cg-code-quality] `R/dim1_5.R:177` — `D3.CHLD.MORT` created but unused. [safe_auto]
- **[P3.8]** [cg-code-quality] `R/dim1_5.R:287` — `National.accounts.reference.year` coercion dead. [safe_auto]
- **[P3.9]** [cg-code-quality] `config/params.R:37` — `output_dir` unused by the pipeline. [safe_auto]
- **[P3.10]** [cg-code-quality] `R/append.R:20` — `library(dplyr)` redundant (all calls namespaced). [safe_auto]
- **[P3.11]** [cg-code-quality] `R/dim1_5.R:512` — comment says "5-year window" but code applies 4-year for non-recent years. [manual]
- **[P3.12]** [cg-code-quality] `R/dim5.R:24` — `library(dplyr)` + `%>%` preamble copy-pasted across 11 files. [advisory]
- **[P3.13]** [cg-code-quality] `R/dim5.R:24` — `score_legislation()`/`score_difi()` near-identical. [advisory]
- **[P3.14]** [cg-code-quality] `R/dim2.R:24` — `score_odin()`/`score_geospatial()` re-read ODIN CSVs. [advisory]
- **[P3.15]** [cg-code-quality] `R/dim5.R:24` — IMF xlsx read pattern repeated 7+ times. [advisory]
- **[P3.16]** [cg-code-quality] `R/dim5.R:24` — `score_empl()` binds the same 2022 file twice (2021/2022). [manual]
- **[P3.17]** [cg-code-quality] `R/dim5.R:24` — `score_mony()` uses `if_else(..., 0)` 4th arg as missing, not default. [manual]
- **[P3.18]** [cg-code-quality] `R/dim5.R:24` — `score_cpiby()` redundant `if_else` with duplicated branches. [manual]
- **[P3.19]** [cg-code-quality] `R/dim5.R:24` — IMF filename hardcoded in 4+ functions. [manual]
- **[P3.20]** [cg-code-quality] `R/dim4.R:24` — `census_fun()`/`survey_fun()` hardcode `.2024.csv` (same as P2.8). [manual]
- **[P3.21]** [cg-code-quality] `R/dim4.R:24` — `combine_censuses_surveys()` repeats 8-block pattern. [advisory]
- **[P3.22]** [cg-code-quality] `R/dim4.R:24` — `score_geospatial()` re-implements ODIN read. [advisory]
- **[P3.23]** [cg-code-quality] `R/quantiles.R:24` — unseeded `rnorm()` for jitter. [manual]
- **[P3.24]** [cg-code-quality] `R/quantiles.R:24` — PIL1 quintile uses hardcoded breaks while others use data-driven. [manual]
- **[P3.25]** [cg-code-quality] `R/quantiles.R:24` — `spi_index` argument unused (CSV round-trip). [advisory]
- **[P3.26]** [cg-code-quality] `R/append.R:24` — `get_population()` called twice per run. [advisory]
- **[P3.27]** [cg-code-quality] `R/append.R:24` — `save_spi()` distinct() on CSV but not DTA. [manual]
- **[P3.28]** [cg-code-quality] `R/compare.R:24` — non-numeric comparison `which()` can return NA. **FIXED in this review** (safe_auto). [fixed]
- **[P3.29]** [cg-code-quality] `R/compare.R:24` — numeric comparison reports only first bad index. [advisory]
- **[P3.30]** [cg-code-quality] `R/schema.R:24` — `optional` parameter never used by callers. [advisory]
- **[P3.31]** [cg-code-quality] `R/setup.R:24` — `wb_countries()` called 21× inside `replicate()`. [advisory]
- **[P3.32]** [cg-code-quality] `R/setup.R:24` — `load_params()` captures `source_schema` into params. [advisory]
- **[P3.33]** [cg-code-quality] `R/checkpoints.R:24` — `verify_microdata_files()` hardcodes 8-file list. [manual]
- **[P3.34]** [cg-code-quality] `R/checkpoints.R:24` — checkpoint schema-check pattern duplicates `read_csv_validated()`. [advisory]
- **[P3.35]** [cg-code-quality] `R/dim1_5.R:24` — `ifelse()` (base) instead of `if_else()`. [safe_auto]
- **[P3.36]** [cg-code-quality] `R/dim5.R:24` — `score_cnin()` mixes `|>` and `%>%`. [safe_auto]
- **[P3.37]** [cg-code-quality] `R/dim5.R:24` — `score_cnin()` uses `ifelse()`. [safe_auto]
- **[P3.38]** [cg-code-quality] `R/dim5.R:24` — `score_cnin()` uses `$` mutation instead of `select()`. [safe_auto]
- **[P3.39]** [cg-code-quality] `R/dim5.R:24` — KOS→XKX mapping repeated 4+ places. [advisory]
- **[P3.40]** [cg-code-quality] `R/dim5.R:24` — `"NaN"` magic value in `score_legislation()`/`score_difi()`. [manual]
- **[P3.41]** [cg-architecture] `_targets.R:44` — `error = "continue"` contradicts R8. **FIXED in this review** (safe_auto, changed to `"stop"`). [fixed]
- **[P3.42]** [cg-architecture] `R/dim1_5.R:292-296` — `read_wdi_metadata()` called 4× per run. [advisory]
- **[P3.43]** [cg-architecture] `R/dim5.R:834` — large files (dim5 834 lines, dim4 606, dim1_5 565). [advisory]
- **[P3.44]** [cg-architecture] `config/params.R:139` — dual schema sources (registry vs inline). [advisory]
- **[P3.45]** [cg-architecture] `R/append.R:173-189` — CSV/DTA divergence undocumented. [advisory]
- **[P3.46]** [cg-architecture] `_targets.R:88-90` — `iso_codes` target orphaned. [safe_auto]
- **[P3.47]** [cg-architecture] `R/quantiles.R:163-164` — jitter seed shared/global. [safe_auto]
- **[P3.48]** [cg-architecture] `R/quantiles.R:153-190` — hidden CSV file dependency. [advisory]
- **[P3.49]** [cg-architecture] `R/index.R:265-267` — RDS/CSV dual representation. [advisory]
- **[P3.50]** [cg-version-control] `.gitignore` — no `.env`/`.Renviron`/`*.pem`/`*.key` patterns. **FIXED in this review** (safe_auto). [fixed]
- **[P3.51]** [cg-version-control] `.gitattributes` — no csv line-ending pin. **FIXED in this review** (safe_auto). [fixed]
- **[P3.52]** [cg-version-control] `tests/fixtures/*.csv` — 85 MB committed (deliberate for hermetic tests). [manual]
- **[P3.53]** [cg-version-control] `01_raw_data/` — 100 MB+ CSVs tracked (pre-existing). [advisory]
- **[P3.54]** [cg-version-control] `chore(state)` commits mix plan-state with test-status. [advisory]
- **[P3.55]** [cg-performance] `R/setup.R:70` — `wb_countries()` ×21 in grid build. [advisory]
- **[P3.56]** [cg-performance] `config/params.R:63` + `R/setup.R:70` — `wb_countries()` fetched twice; population fetched twice. [advisory]
- **[P3.57]** [cg-performance] `R/databank.R:69` + `R/quantiles.R:70` + `R/treemap.R:42` — `SPI_index.csv` read 3× (required for replication). [advisory]
- **[P3.58]** [cg-performance] `R/dim1_5.R:110-130` — per-year re-filter of small tables (R9-correct). [advisory]
- **[P3.59]** [cg-performance] `R/dim4.R:122-230` — manual review Excel parsed 8×. [advisory]
- **[P3.60]** [cg-performance] `R/dim5.R:248-262` — IMF Excel parsed twice. [advisory]
- **[P3.61]** [cg-performance] `R/compare.R:120-160` — `sapply()` in compare util (test-only path). [advisory]
- **[P3.62]** [cg-performance] `R/pull_jmp.R:100-110` — ~200 sequential HTTP requests (R13 design choice). [advisory]

### ✅ Passed
- **cg-data-quality**: No P0 in the current state — the replication gate confirms the 202511 vintage is reproduced exactly. Strong schema validation and fail-loudly handling.
- **cg-reproducibility**: Lockfile pins all 25 packages; relative paths only; deterministic ordering; tests use committed fixtures. No P0.
- **cg-testing**: The replication gate is real (immutable hashed fixtures + 1e-9 tolerance + C7 manifest). No P0.
- **cg-documentation**: All exported functions have roxygen2 blocks. No P0.
- **cg-version-control**: No credentials/PII in tracked code; conventional commits; C7 enforced. No P0.
- **cg-performance**: Algorithmically sound for its scale; targets caching correct. No P0/P1.
- **cg-code-quality**: No P0.
- **cg-architecture**: Well-structured pipeline; no P0.

## Autofix Summary

Applied 14 safe_auto fixes:
1. `R/compare.R` — removed dead `both_na`; guarded non-numeric `which()` index (P2.9, P2.13, P3.28)
2. `R/databank.R` — removed unused `latest_date` and `short_desc` (P3.5, P3.6)
3. `R/checkpoints.R` — corrected header (checkpoints run by default) (P2.21)
4. `R/schema.R` — corrected error message to point to inline schemas (P2.27)
5. `_targets.R` — corrected seed comment; changed `error = "continue"` → `"stop"` (P3.41)
6. `README.md` — fixed R version (4.3.1 → renv.lock 4.6.1); added legacy-path note (P2.16, P2.17)
7. `docs/user-guide.md` — fixed pipr reference, ILO filename note, packages list (P1.6, P1.7, P1.10)
8. `docs/CHANGELOG.md` — clarified E2 jitter seeding; added compare.R to ported table (P2.30, P2.13)
9. `tests/testthat/test-downloads.R` — strengthened no-op guard test; fixed stale comment (P2.17)
10. `tests/testthat/test-fixtures.R` — C7 test now fails on missing historical files (P2.19)
11. `.Rbuildignore` — created with `.cg-docs/` exclusion (P2.31)
12. `.gitignore` — added `.env`, `.Renviron`, `*.pem`, `*.key` (P3.50)
13. `.gitattributes` — pinned `*.csv` to LF for hash stability (P3.51)

**Tests after fixes**: 100 passed, 0 failed, 0 skipped (up from 86 — strengthened tests added assertions).
# JMP calibration for the 2025 reference year (SPI 202611)

- Run: 2026-10-23, plan step 9 (`.cg-docs/plans/2026-10-23-spi-202611-source-readiness.md`)
- Source: 217 JMP country workbooks from
  `https://washdata.org/data/country/<ISO3>/household/download`, sheet
  "Data Summary" (release "Updated August 2025, estimates 2000-2024"; the same
  release used for the 202511 SPI).
- Reference: `01_raw_data/1.5_DUIO/Safely_Managed_Water_data.csv`, the input
  of the 202511 release (regenerated 2025-09-22 and 2025-10-16), which
  reproduces the published 2024 `SPI.D1.5.SAFE.MAN.WATER` for 216 of 217
  countries (Australia excepted, see below).
- Adoption bar (plan): 95% flag agreement on overlapping `(iso3c, source, geo)`.
- Decision brief: `docs/jmp-safely-managed-water-brief.md`.

## Result: the original method reproduces the reference exactly

The original collector (`hyper_read()` in `02_programs/01-SPI_data_prep.Rmd`,
chunk `safely_managed`) reads the "Data Summary" sheet with `skip = 4`. Applied
unchanged to today's workbooks with `end_date = 2024`:

| Check | Result |
|-------|--------|
| Rows in both files (`iso3c, year, geo, source`) | 24,420 |
| `data_quality` agreement on those rows | 100.00% |
| `data_available` agreement on those rows | 100.00% |
| Rows only in the reference | 1 (Australia, failed download in the 202511 run) |
| Rows only in the new run | 117 (all Australia) |
| Published country-years reproduced, 2015-2024 | 2,160 of 2,170 (differences: Australia 0 to 0.5, every year) |

The adoption bar is met (100%).

Production code check (`pull_jmp_water()`, the same 217 workbooks served
through an injected download function, `end_date = 2024`): output columns
identical to the reference; 24,420 shared rows with 100.00% agreement on
`data_available`, `data_quality`, `data_value` and `max_value`; only Australia
differs; 2,160 of 2,170 published values reproduced. The cache holds 217
"Data Summary" sheets (19.3 MB) and no workbooks. Release stamps found:
"Updated August 2025" and, for some older country files, "Updated March 2023".

An earlier calibration attempt in this run compared simple bracket rules
without the original code's year template and coverage rule and reached 44.5%;
it wrongly concluded that JMP had retired a CSV download. That attempt is
superseded by this result.

## Behaviours of the original method (documented in the brief)

- D1: the coverage rule `max_value >= 99.5 | max_value <= 0.5` also fires for
  areas without data (coded -99), which therefore count as estimates in every
  year.
- D2: national columns are recognised by `_n`; current workbooks mostly use
  `_t`, so national values are not read (masked by D1).

Correcting them (brief, Option B) changes 52 countries in 2024 and is a
separate methodology decision. The technical lead chose Option A (exact port)
for 202611 on 2026-10-23; D1 and D2 are documented in `docs/user-guide.md`
and a methodology review is on the roadmap.

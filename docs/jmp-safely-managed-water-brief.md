# Safely managed drinking water (SPI.D1.5.SAFE.MAN.WATER): method options for the 202611 update

Prepared 2026-10-23 for the SPI technical lead. Evidence: all 217 JMP country
workbooks downloaded on 2026-10-23 (JMP release "Updated August 2025,
estimates 2000-2024") and the input file behind the 202511 release
(`01_raw_data/1.5_DUIO/Safely_Managed_Water_data.csv`, regenerated in
October 2025).

## Bottom line

- **The JMP input has not changed.** The original SPI code always read the
  "Data Summary" sheet of each JMP country workbook, and today's workbooks have
  the same sheet and layout. JMP has not published new household data since
  the 202511 run, so the 202611 update uses the same JMP release.
  (An earlier note in this work said JMP had retired a CSV download. That was
  wrong.)
- **The published values can be reproduced exactly.** Running the original
  method unchanged on today's workbooks reproduces the 202511 input file row
  for row and **2,160 of 2,170 published country-year values (2015-2024)**.
  The 10 differences are all Australia: its download failed in the 202511 run,
  so it was published as 0 in every year. Processed correctly, it scores 0.5.
- **Recommendation:** for 202611, use the original method unchanged
  (Option A). It meets both criteria: it is the documented SPI method as
  applied in every release since December 2021, and the series stays
  comparable. Two behaviours in the original code depart from the written
  definition (below). Correcting them is a methodology change affecting 52
  countries, so it should be a separate, announced decision, not part of a
  data update.

## The indicator

SPI documentation (`SPI_data_viz/SPI_dimensions_sources.csv`,
`02_programs/01-SPI_data_prep.Rmd`): "Availability of Safely Managed Drinking
Water data for use by JMP", scored within an 8-year window:

| Points | Rule |
|--------|------|
| 1 | At least two estimates, with breakdowns for urban/rural areas |
| 0.5 | At least two estimates, but not an urban/rural breakdown |
| 0 | Otherwise |

An "estimate" is a survey, census or administrative source listed in the JMP
country file whose water values JMP used (values in square brackets were not
used).

How much it weighs: Pillar 1 is dimension 1.5, the average of five
indicators, and the overall SPI score is the average of five pillars.
**A change of 0.5 in this indicator moves Pillar 1 by 10 points and the
overall SPI score by 2 points (on a 0-100 scale).**

## What the original code does, and where it departs from the definition

In plain terms, the code:

1. reads every source and its national, urban and rural water values, marking
   a source as an estimate where at least one value is not bracketed;
2. adds an empty row for every year and area (added in August 2021, "fill in
   missing years");
3. applies a **coverage rule**: if the highest value for an area reaches
   99.5%, every year counts as an estimate, because JMP carries such estimates
   forward indefinitely;
4. counts estimates in the 8-year window and scores 1, 0.5 or 0.

Two behaviours depart from the written definition:

- **D1, missing data treated as full coverage.** The coverage rule is written
  as "highest value at least 99.5 *or at most 0.5*", and an area with no data
  is coded -99, which is "at most 0.5". An area with no data therefore counts
  as if access were universal. Example: Nicaragua has no sources in its JMP
  file and scores 1.
- **D2, national values not read.** The code recognises national columns by
  the suffix `_n`; JMP now labels national totals `_t` (a few files still use
  `_n`). National-only estimates are therefore ignored, but because of D1
  every country receives national credit anyway, so every country scores at
  least 0.5.

D1 is what matters: correcting D2 alone changes 6 country-years beyond
Australia. Both behaviours have shaped every release since December 2021. The
first release (June 2021) had 24 countries at 0 in 2020; from December 2021
onward there were 0-5.

## Options

| Option | What it does |
|--------|--------------|
| **A. Original method, exact port** (new, recommended) | Automates the original code unchanged on today's workbooks |
| O1. Carry forward the 202511 input file | Reuses last year's file without a new download |
| O2. Strict definition | Counts only real estimates, no empty rows, no coverage rule; reads `_t` and `_n` national values |
| O3. Strict definition plus a 0.5 floor | O2, with every country given at least 0.5 |
| O4. Legacy-shaped approximation | Earlier attempt to imitate the original output; superseded by A, which reproduces it exactly |
| B. Original method with D1 and D2 corrected | Keeps the 99.5% coverage rule; no credit for missing data; reads `_t` and `_n` |

## Numerical impact compared with the 202511 release

SPI score and rank columns cover the 188 countries with an overall SPI score
in 2024.

| Option | Country-years changed, 2015-2024 (of 2,170) | Countries changed, 2024 (of 217) | 2024 values: 0 / 0.5 / 1 | SPI score change, 2024: mean / largest | Countries changing rank, 2024 (largest move) | 2025 values: 0 / 0.5 / 1 |
|--------|------|------|------|------|------|------|
| Published 202511 | - | - | 1 / 17 / 199 | - | - | - |
| **A. Exact port** | 10 (all Australia) | 1 | 0 / 18 / 199 | 0.01 / 2 | 11 (Australia up 10; 10 countries down 1) | 0 / 22 / 195 |
| O1. Carry forward | 0 | 0 | 1 / 17 / 199 | 0 / 0 | 0 | 1 / 21 / 195 |
| O2. Strict definition | 650 | 63 | 22 / 47 / 148 | 0.46 / 4 | 145 (15 places) | 25 / 49 / 143 |
| O3. Strict plus floor | 511 | 52 | 0 / 69 / 148 | 0.34 / 2 | 130 (15 places) | 0 / 74 / 143 |
| O4. Approximation | not computed | 18 | - | - | - | - |
| B. D1 and D2 corrected | 541 | 52 | 18 / 40 / 159 | 0.33 / 4 | 103 (13 places) | 20 / 42 / 155 |

Corrections under B fall mainly on small high-income economies and
territories (for example Aruba, Bahamas, Curacao, Faroe Islands, Hong Kong
SAR, Singapore), on some large high-income countries (Italy, Japan, Korea:
1 to 0.5), and on seven low- and middle-income countries with too few
estimates (Central African Republic, Congo Rep., Dominica, Equatorial Guinea,
Eritrea, Korea DPR, St. Vincent and the Grenadines: 0.5 to 0). The full lists
are in the appendix.

## Assessment against the two criteria

| Option | (i) Follows the indicator definition and documented method? | (ii) Comparable with past estimates; can produce a comparable series? |
|--------|------|------|
| **A** | As closely as every release since December 2021: the documented scoring rule and coverage rule, including D1 and D2 | **Yes.** Reproduces the published series; one method for 2015-2025; only a data error (Australia) is corrected |
| O1 | Same as A, but keeps Australia's failed download | Yes for past years, but it is a manual file kept outside the automated collection and does not fix Australia |
| O2 | Closest to the literal scoring text, but drops the coverage rule, which the SPI method uses to reflect JMP's forward imputation | **No.** 63 countries change in 2024; a new consistent series is possible, but it matches no published release |
| O3 | No: the floor has no basis in the definition | No: 52 countries change |
| O4 | No: not a documented rule | Partly (18 countries differ); superseded by A |
| B | **Yes**, fully: the written definition plus the coverage rule | Not with published releases (52 countries in 2024); a consistent back-cast to 2015 is possible because dimension 1.5 is recomputed for all years each release |

## Recommended way forward

1. **202611 release: Option A.** Collect the JMP "Data Summary" sheets
   automatically (recording each workbook's URL and SHA-256) and apply the
   original method unchanged. Announce one correction: Australia 0 to 0.5 in
   every year, from a failed download in the 202511 run (overall SPI score +2
   in 2024; up 10 rank places).
2. **Document D1 and D2** as known behaviours of the current method in the
   methodology notes.
3. **Decide on Option B separately.** Treat it as a methodology review before
   the next JMP release (expected 2027), with a full back-cast and a public
   note. If you prefer to adopt B in 202611, the collector can apply it
   through a parameter on the same parser, and the vintage-diff report would
   list every changed country for approval.

## Appendix: countries changed in 2024

- **A:** AUS (0 to 0.5).
- **B (D1 and D2 corrected):** ASM, BHR, BRB, BMU, BRN, CHI, PYF, GIB, GRL,
  GRD, GUM, HKG, IMN, ITA, JPN, KOR, KWT, LBN, LBY, LIE, MAC, MCO, NRU, NCL,
  MNP, QAT, SYC, SGP, SVN, MAF, VEN, VIR, FRO (1 to 0.5); ABW, BHS, VGB, CUW,
  FSM, NIC, KNA (1 to 0); CYM, CAF, COG, DMA, GNQ, ERI, PRK, SXM, VCT, TTO,
  TCA (0.5 to 0); AUS (0 to 0.5).
- **O2 (strict definition):** the B list plus AND, AUT, DNK, FIN, ISL, MLT,
  NLD, NZL, NOR, ARE, GBR (1 to 0.5 or 0), with BMU, GRL and FRO falling to 0.

Reproduction scripts and logs are kept with the work session
(`jmp-calibration/`); the calibration summary is
`01_raw_data/1.5_DUIO/collection/jmp_calibration_2025.md`.

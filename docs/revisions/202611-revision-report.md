# SPI 202611 revision report

[PRELIMINARY: subject to revision]
[UNPUBLISHED: DO NOT CIRCULATE]

- **Audience**: SPI Working Group (technical specialists)
- **Release**: 202611, reference year 2025 (years 2004-2025)
- **Status**: internal draft, reconciled on 25 October 2026 with the retained
  24 October `replication/spi-rep/preview-p0p1/` outputs and matching evidence
  in `docs/revisions/202611/preview/`. This snapshot precedes completed manual
  reviews, source attestations, and official ODIN. It does not certify the
  latest code or normal production gates. The current operational state is
  documented in [202611 status](../update-status-202611.md).
- **Previous release**: 202511 (reference year 2024),
  `01_raw_data/previous_vintages/SPI_data_2024.csv` and
  `SPI_index_2024.csv`.

## 1. Summary

The retained preliminary 202611 estimate covers reference years 2004–2025.
Compared with the published 202511 indicator history, it records **1,073
historical changes in refreshed dimensions** (D1.5: 706; D4.1: 362; D4.2: 5)
and **41 frozen-history changes awaiting decisions**: 40 new Andorra values
in D2.2/D4.3 for 2017–2021 and Colombia's D5.5 value in 2024 changing from
0 to 1. All must be explicitly approved or resolved before normal promotion.
D5.5 has zero index weight; this does not waive the history-approval rule.

For 2024, 188 economies have comparable overall scores and 98 scores change.
The mean absolute change is 0.95 points, the maximum is 8.00 points, with
159 rank changes and 16 quintile changes. Türkiye rises from 79.3 to 87.3,
from the fourth quintile to the top quintile. See the generated summary for
full definitions and all-year comparisons.

The matched E6 country-identification comparison changes 233 indicator cells
(66 child mortality, 167 LFP) across 12 economies in the 202611 snapshot.
The separate 2024 reconstruction comparison contains 157 E6 indicator cells
and must be interpreted within its documented replication exceptions.
These comparisons answer different questions and cannot be added together.

The source report still lists 17 missing attestations and a GSBP warning,
but it predates the latest run marker, which remains `started`. Source
reviews, the current collection gate, methodology decisions, normal
estimation, and final ODIN/release checks remain outstanding. The retained
preview is complete as a preliminary output set, not approved for release.

Older narrative figures of 845 refreshed changes, one frozen change, and
251 E6 preview cells belong to an earlier run. This report uses the retained
`preview-p0p1` evidence instead. No new estimates were computed for this
prose reconciliation.

## 2. Revision policy

Each SPI release adds a reference year and re-estimates the series. The
202611 release applies an explicit policy, adopted from how earlier releases
behaved (comparison of the 2023 and 2024 vintages for 2018-2022): dimensions
whose sources are revised by their producers are re-estimated for every year,
and dimensions whose history is a fixed record keep their published values.

| Dimensions | Sources | Policy | Changes to 2004-2024 |
|---|---|---|---|
| D1.5 Data use by international organizations | PIP, UN IGME, WDI metadata, JMP, ILOSTAT | Refresh | Reported |
| D4.1 Censuses and surveys | Country workbooks, economist review, microdata catalogues | Refresh | Reported |
| D4.2 Civil registration and vital statistics | UN SDG database | Refresh | Reported |
| D2 Data services, D3 Data products, D4.3 Geospatial data, D5 Data infrastructure | SDDS, ODIN, NADA, UN SDG database, IMF and other sources | Frozen: only the new year is added | Need an explicit approval |

The estimation enforces the policy. It compares every 2004-2024 value with
the previous release (`vintage_diff_2025.csv`), reports changes in refreshed
dimensions, and does not publish the outputs while a frozen value has changed
without a recorded approval (indicator, country, year, reason, approver).
D5.1 and D5.5 keep the legacy full-series download, so their history can
change when the UN revises it; each such change needs the same approval.

## 3. Revisions to published values, 2004–2024

The refresh-policy dimensions are recomputed from the designated sources.
Frozen-history additions are also revisions: Andorra's previously missing
values are not exempt from approval because they are new observations.

| Dimension | Changed cells | Economies | Up | Down | New | Years |
|---|---:|---:|---:|---:|---:|---|
| D1.5 Data use by international organizations | 706 | 121 | 248 | 458 | 0 | 2004–2024 |
| D4.1 Censuses and surveys | 362 | 78 | 231 | 110 | 21 | 2004–2024 |
| D4.2 Civil registration | 5 | 3 | 4 | 1 | 0 | 2015–2024 |
| D2.2 ODIN openness, Andorra | 30 | 1 | 0 | 0 | 30 | 2017–2021 |
| D4.3 ODIN geospatial, Andorra | 10 | 1 | 0 | 0 | 10 | 2017–2021 |
| D5.5 Fully funded statistical plan, Colombia | 1 | 1 | 1 | 0 | 0 | 2024–2024 |

D1.5 comprises 122 child-mortality revisions, 527 labour-force revisions,
39 poverty-comparability revisions, and 18 safely-managed-water revisions.
D4.1 comprises 197 health, 95 business, 29 household, 25 labour-force,
15 agricultural-survey, and one agricultural-census revision.
The complete cell-level record is [the vintage diff](202611/preview/vintage_diff_2025.csv).

The largest 2024 overall-score changes in the generated table begin with:

| Country | ISO3 | Previous | Revised | Change | Rank | Quintile |
|---|---|---|---|---|---|---|
| Turkiye | TUR | 79.3 | 87.3 | 8.0 | 68 to 33 | 4th Quintile to Top Quintile |
| Uganda | UGA | 68.7 | 75.0 | 6.3 | 96 to 81 | 3rd Quintile |
| Seychelles | SYC | 64.5 | 58.9 | -5.7 | 112 to 139 | 3rd Quintile to 2nd Quintile |
| Congo, Dem. Rep. | COD | 46.3 | 51.9 | 5.7 | 169 to 161 | Bottom 20% |
| Cote d'Ivoire | CIV | 70.2 | 74.9 | 4.7 | 93 to 82 | 3rd Quintile |

## 4. Effect on the overall SPI score and pillars

| Measure | Countries compared | Revised | Added | Dropped | Mean abs change | Max abs change | Rank changes |
|---|---|---|---|---|---|---|---|
| SPI.INDEX | 188 | 98 | 0 | 0 | 0.95 | 8.00 | 159 |
| SPI.INDEX.PIL1 | 217 | 58 | 0 | 0 | 4.24 | 40.00 | 160 |
| SPI.INDEX.PIL2 | 190 | 0 | 0 | 0 | 0.00 | 0.00 | 0 |
| SPI.INDEX.PIL3 | 215 | 0 | 0 | 0 | 0.00 | 0.00 | 0 |
| SPI.INDEX.PIL4 | 189 | 66 | 0 | 0 | 0.80 | 12.50 | 132 |
| SPI.INDEX.PIL5 | 191 | 0 | 0 | 0 | 0.00 | 0.00 | 0 |

This table is specifically the **2024** comparison. Pillar 1 reflects D1.5
source/window and implementation changes; Pillar 4 reflects D4.1/D4.2.
The Andorra frozen additions affect earlier years and should not be inferred
to have no effect from a table limited to 2024. Colombia's D5.5 change has
zero overall-index weight but remains subject to the historical-data rule.

## 5. Reference year 2025: how each indicator was produced

The reference-year coverage table is in `preview/revision_new_year_2025.csv`.
The main results are:

| Source group | Reference-year result |
|---|---|
| D1.5 poverty | 217 economies; 216 equal to 2024 and 1 changes |
| D1.5 child mortality | 217; 209 equal and 8 change |
| D1.5 debt reporting | 217; 213 equal and 4 change |
| D1.5 safely managed water | 217; all 217 equal to 2024 |
| D1.5 labour force | 217; 214 equal and 3 change |
| D2.1 GDDS and D2.4 NADA | 217 and 191 respectively; all values equal to 2024 |
| D2.2 ODIN openness | 197; all values equal to 2024, provisional |
| D3 SDG products | 215 for each scored series; values are updated from the 2025 SDG/OECD inputs |
| D4.1 population, agricultural and business censuses | 190 each; 10, 11 and 2 changes respectively |
| D4.1 household, agricultural, labour-force, health and business surveys | 190, 190, 196, 194 and 191; 0, 0, 1, 0 and 26 changes respectively |
| D4.2 CRVS | 217; all values equal to 2024 |
| D4.3 ODIN geospatial coverage | 197; all values equal to 2024, provisional |
| D5.1 and D5.2 | Updated from the configured 2025 files; CNIN, EMPL, FINA and GSBP are carried forward or unchanged where documented |

The 2025 values should not be treated as final until the manual review
workbooks and source attestations are complete. ODIN-dependent values remain
provisional until the approved official file and release record are installed.

## 6. Changes to methods and processes

The preview includes documented legacy corrections, source refreshes, and
validation changes. These can change estimates; they are not an unconditional
legacy-parity claim. Methodology acceptance and source approval remain
separate from implementation and are not established by this draft.

### 6.1 Corrections that change published values

| Change | Description | Effect on 2004-2024 |
|---|---|---|
| E4: labour force window | The legacy condition `else if (end_date - 1)` was always true, so the "five-year" window used for 2010-2022 covered six years. The pipeline applies the intended five years (approved September 2026, at the port of the legacy code). 202611 is the first release to publish it. | 478 attribution entries carry an E4 label: 383 E4-only, 94 overlapping E6, and 1 overlapping a source update; these are the current attribution labels, not a new approval |
| E5: catalogue country names | The catalogue evidence was joined to countries by name, using World Bank API names that differ from the catalogue's names for six economies (Cabo Verde, Czech Republic, Korea, Dem. People's Rep., Nauru, Tanzania and Yemen, Rep.), so their catalogue evidence was silently lost. Names are now normalized to CLASS.xlsx and joined by ISO3 code (approved by the technical lead on 24 October 2026, including Korea, Dem. People's Rep.). | 39 cells in the attribution; all are listed in the E5 exception fixture |
| E6: D1.5 country matching | The IGME and ILO readers previously joined by exact country name and silently dropped unmatched economies, scoring them as zero. IGME now uses `REF_AREA` with `RKS` mapped to `XKX`; ILO uses the reviewed name crosswalk and exclusions. Unknown names and codes stop the run. | 157 historical D1.5 cells in the 2024 replication (63 child mortality, 94 LFP); 233 D1.5 cells changed in the matched 202611 comparison (66 child mortality, 167 LFP) |

The current LFP accuracy component requires at least one valid
reported/modelled pair and a mean absolute gap no greater than 10 percentage
points. Missing comparators do not earn accuracy credit. The retained
attribution labels group effects according to the existing step definitions;
the E4-labelled count above is not a separate impact estimate for this
accuracy safeguard. Reconcile scorer changes and attribution scope before
final methodological sign-off.

#### E6 impact on country scores and aggregates

The two comparisons answer different questions. The 2024 replication isolates
the correction to published history. The 202611 comparison also includes
economies whose names changed in the 2026 ILO files.

| Comparison | Indicator cells | Economies with indicator changes | Corrected-index rows | Overall-score economy-years | Other rank side effects | Quintile changes | Aggregate values |
|---|---:|---:|---:|---:|---:|---:|---:|
| 2024 replication, historical correction | 157 | 8 (3 child mortality, 7 LFP) | 128 | 41 across 5 economies | 510 | 15 | 2,069 |
| 202611 matched preview comparison | 233 | 12 (3 child mortality, 11 LFP) | 201 | 88 across 9 economies | 915 | 29 | 2,697 |

The maximum overall-score change is +8.0 points in both comparisons. In the
2024 replication, Türkiye rises from 78.7 to 86.7 in the latest rankable
year; the Netherlands rises from 90.0 to 94.0, West Bank and Gaza from 76.3
to 80.3, Côte d'Ivoire from 65.9 to 69.9, and Congo, Dem. Rep. from 47.1 to
49.1. In the 202611 reference-year comparison, Türkiye rises from 79.4 to
87.4, the Netherlands from 87.0 to 91.0, and Cabo Verde from 55.8 to 59.8.

All 201 corrected-index rows in the 202611 comparison and all 128 in the
2024 comparison affect Pillar 1. The largest Pillar 1 change is 40 points,
from 20 to 60, for Türkiye in affected years. The remaining rank and
quintile changes are distributional side effects on other economies, not
additional indicator corrections.

The 202611 comparison includes the effect of matching renamed ILO economies
in the current source files. Use the matched before/after snapshots and the
233-cell table for this effect; an older pre-E6 run is not an interchangeable
comparison baseline. Country cells, index effects, side effects, and aggregates
are in the following evidence files:

- `e6_202611_indicator_cells.csv` and `e6_2024_replication_indicator_cells.csv`;
- `e6_202611_index.csv` and `e6_2024_replication_index.csv`;
- `e6_202611_side_effects.csv` and `e6_2024_replication_side_effects.csv`;
- `e6_202611_aggregates.csv` and `e6_2024_replication_aggregates.csv`.

### 6.2 Source updates (method unchanged)

| Indicator | 202511 input | 202611 input |
|---|---|---|
| D1.5 poverty comparability | PIP QA server extract | PIP production release `20260922_2021_01_02_PROD` (2021 PPPs) |
| D1.5 child mortality | UN IGME 2021 wealth-quintile extract | UN IGME 2025 database |
| D1.5 safely managed water | JMP file of May 2025 | JMP country workbooks downloaded October 2026, read with an exact port of the legacy reader |
| D1.5 labour force | ILOSTAT bulk files of 23 September 2025 | ILOSTAT bulk files of 6 October 2026 |
| D4.1 censuses and surveys | catalogue pull of October 2025; workbooks of 2024 | catalogue pull of 24 October 2026; 2025 workbooks |
| D4.2 CRVS, D5.1, D5.5 | UN SDG database (202511 pull) | UN SDG database, October 2026 (DataCSV endpoint, as in the script that produced the 202511 files) |
| D3 (2025 only) | n.a. | UN SDG database (352 Tier 1 series) and OECD SDG data, October 2026, scored with a port of the legacy method |

### 6.3 Production controls and aggregate handling

- **Collection gate**: manual files need a hash-bound attestation by the
  technical lead; collected files carry a release identifier and retrieval
  record; freshness comes from these records, not from file dates.
- **Revision policy enforcement**: the vintage diff (section 2) and the
  revision evidence in this report are produced with every estimation.
- **D4.1 catalogue refresh**: the legacy script requests 18,638 study pages
  one at a time and silently records a blank when a request fails. The
  responses are now fetched with retries, cached with their hashes and
  served to the unmodified script; every failure is logged and stops the
  refresh until it is retried. The 24 October refresh made 18,642 requests
  with no failure.
- **Databank aggregation order**: group means are now calculated after
  sorting members by ISO3 code. This prevents a country reorder from changing
  an unrelated aggregate at a two-decimal floating-point boundary. Country
  values are unchanged; the earlier aggregate-order differences are covered
  by the documented E3 exception. Current classification handling also removes
  exact duplicate country/group memberships and rejects conflicting group
  names. Those safeguards can affect aggregate counts/means and require
  current-code evidence; they are not a claim that every aggregate is unchanged.
- **Official ODIN update**: after provisional approval, a release lock records
  non-ODIN artifacts, provenance/control identities, and approved outputs.
  The transition validates the approved source release record and compares
  outputs with the archive. See the ODIN guide for the annual-file restriction.

### 6.4 Legacy behaviour kept and reported

- **Agricultural evidence (D4.1.2, D4.1.5)**: the catalogue script keeps
  only FAO studies catalogued in 2022 or earlier (a text comparison of the
  creation date with 2023), which now excludes 561 of the 1,713 considered
  FAO studies (571 of the 1,786 raw rows also includes 73 title-excluded
  studies). The
  agricultural census score reads a catalogue file last changed in February
  2024 (16 rows, 12 economies); the script writes the FAO agricultural census
  list (118 economies in the October 2026 pull, after the creation-date
  filter) to a file the estimation does not read. See section 7, items 3
  and 4.
- **Retired ILO Survey Catalog (D4.1.6)**: the ILO retired the catalogue in
  2026. Its final snapshot (1,705 studies, unchanged since October 2025) is
  used, so no recorded labour force survey is lost; the other two sources
  (World Bank microdata library and the ILO national sources catalogue)
  continue to add new surveys.
- **Child mortality (D1.5)**: current code filters to Total wealth, both
  sexes, included under-five mortality observations and nonmissing values.
  The dated review still records the observation-unit/methodology decision
  as open; the presence of a filter is not Working Group approval.
- **Safely managed water (D1.5)**: the legacy reader treats areas without
  JMP data as fully covered and reads national columns with an outdated
  suffix; both are kept for 202611 and documented in
  `docs/jmp-safely-managed-water-brief.md` (a correction would change 52
  countries in 2024).
- **Catalogue names**: the 24 October refresh added three World Bank API
  names to the name crosswalk (`Naoero`, `Curacao`, `Puerto Rico (US)`) and
  Somalia's formal name, and excluded `Cook Island` (not an economy) and
  `Serbia and Montenegro` (former union of two current economies, so its
  studies cannot be attributed to one).

## 7. Decisions requested from the Working Group

1. **Frozen-history revisions: Andorra and Colombia.** The Andorra mapping
   from the legacy ODIN code adds 30 D2.2 and 10 D4.3 values in 2017–2021.
   Review and approve those additions explicitly or retain approved history.
   **Colombia, D5.5 (statistical plan fully funded), 2024:** The UN SDG
   database now reports 1 for 2024 (0 in the 202511 release); 2022, 2023 and
   2025 are 1. D5 history is frozen, so the change is published only if it
   is approved. Options: approve the revision, or keep the published 0.
2. **CNIN and FINA, 2025.** The IMF Dissemination Standards Bulletin Board
   pages that the legacy scraper read are now generated in the browser and
   cannot be scraped, and the IMF compiled workbook holds only free-text
   notes. The 2025 values carry forward 2024 (including the documented 2024
   overrides for India and Somalia) and reviewers check the listed countries
   with evidence. The group is asked to endorse this approach for 202611 and
   to consider an IMF data API source for later releases.
3. **FAO studies catalogued after 2022 (D4.1.5).** Keep the legacy filter or
   use all FAO studies. Using all considered FAO studies would raise 89
   country-years for 24 economies, including 21 economies in 2024 and 22 in
   2025; no score decreases occur in the counterfactual.
4. **Agricultural census evidence (D4.1.2).** Keep the February 2024 file or
   use the FAO agricultural census list. Using the FAO list with the legacy
   date filter raises 47 country-years for 11 economies. Using all catalogue
   years raises 59 country-years for 14 economies and adds 110 country-years
   for five territories (ASM, GUM, MNP, PRI and VIR); no score decreases occur
   in either counterfactual.
5. **Safely managed water, 2027.** Adopt the corrected JMP reader (Option B in
   `docs/jmp-safely-managed-water-brief.md`) with a back-cast and a public
   note before the 2027 JMP release.
6. **Internal microdata library.** The D4.1 catalogue refresh reads the
   World Bank internal microdata library, which is not public; the group is
   asked whether to keep this source given the open-data principle.
7. **Retired ILO Survey Catalog.** Endorse the use of its final snapshot and
   decide whether ILOSTAT's national sources catalogue alone should replace
   it in later releases.

## 8. Steps before the release is final

1. Reviewers check the candidate countries
   (`01_raw_data/_collection/review_candidates_2025.csv`) and fill the 2025
   review workbooks for CNIN, FINA, GSBP and D4.1 with evidence.
2. The technical lead checks the evidence and attests the manual sources.
3. Collection and estimation are rerun; this report is updated from the
   final `revision_summary_2025.md` and `docs/revisions/202611/`.
4. The Working Group decides on section 7; all 41 frozen cells in item 1
   require an explicit decision or resolution before promotion.
5. After provisional approval, create the real release lock. Install the
   approved official ODIN files and `ODIN_release.json`, then follow the
   [ODIN guide](../odin-delayed-update.md), including its current annual-file
   hash restriction and output allowed-change checks.

## Annex A. Evidence and how to reproduce it

| Evidence | File |
|---|---|
| Every revised value, with the previous and new value and the approval status | `03_output_data/vintage_diff_2025.csv` (preview: `docs/revisions/202611/preview/`) |
| Revisions per indicator, index and reference year | `revision_indicators_2025.csv`, `revision_index_2025.csv`, `revision_new_year_2025.csv`, `revision_summary_2025.md` (same folders) |
| Cause of every revised value | `docs/revisions/202611/revision_attribution.csv` and `revision_attribution_summary.csv` |
| Agricultural catalogue variants | `docs/revisions/202611/agriculture_catalogue_evidence.csv` |
| D4.1 catalogue refresh | `01_raw_data/4.1_SOCS/collection/catalogue_refresh.json`, `catalogue_cache/catalogue_fetch_index.csv` (18,642 responses with SHA-256), `catalogue_fetch_failures.csv` |
| Retired ILO Survey Catalog | `01_raw_data/4.1_SOCS/retired/ilo_survey_catalog_final_2026-10-20.csv` and its `.provenance.json` |
| Review candidates sent to reviewers | `01_raw_data/_collection/review_candidates_2025.csv`; earlier lists in `review_candidates_history/` |

To check attribution against a deliberately regenerated `preview-next`
(repository root, recorded environment restored, temporary variables set as
in the [artifact guide](../../replication/README.md)):

```sh
Rscript docs/revisions/202611/attribute_revisions.R \
  --current replication/spi-rep/preview-next
Rscript docs/revisions/202611/agriculture_catalogue_evidence.R
```

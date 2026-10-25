# Collection Status Report

Generated: 2026-10-24 10:15:43 UTC

| Source | Dimension | Type | Status | Reason | Analyst action |
|---|---|---|---|---|---|
| d1_1_unavailable | 1.1 | unavailable | informational | source_unavailable_by_design | No established methodology; record as unavailable. |
| d1_2_unavailable | 1.2 | unavailable | informational | source_unavailable_by_design | No established methodology; record as unavailable. |
| d1_3_unavailable | 1.3 | unavailable | informational | source_unavailable_by_design | No established methodology; record as unavailable. |
| d1_4_unavailable | 1.4 | unavailable | informational | source_unavailable_by_design | No established methodology; record as unavailable. |
| d1_5_pip | 1.5 | api | informational | release_recorded | Refresh PIP data or document an external PIP release. |
| d2_1_sdds | 2.1 | manual | blocking | attestation_missing | Refresh the IMF dissemination source. |
| d2_2_odin | 2.2 | manual | informational | artifact_present | Download the current ODIN file. |
| d2_3_unavailable | 2.3 | unavailable | informational | source_unavailable_by_design | No established methodology; record as unavailable. |
| d2_4_nada | 2.4 | manual | informational | artifact_present | Run the NADA collection/check procedure. |
| d3_1_sdg | 3.1 | api | informational | release_recorded | Run the UN SDG series collection. |
| d3_2_sdg | 3.2 | api | informational | release_recorded | Run the UN SDG series collection. |
| d3_3_sdg | 3.3 | api | informational | release_recorded | Run the UN SDG series collection. |
| d3_4_sdg | 3.4 | api | informational | release_recorded | Run the UN SDG series collection. |
| d4_1_microdata | 4.1 | external | informational | artifact_present | Run the microdata library collection. |
| d4_2_crvs | 4.2 | api | informational | release_recorded | Run the UN SDG CRVS collection. |
| d4_3_odin | 4.3 | manual | informational | artifact_present | Download the current ODIN file. |
| d4_4_unavailable | 4.4 | unavailable | informational | source_unavailable_by_design | No established methodology; record as unavailable. |
| d5_1_legislation | 5.1 | api | informational | release_recorded | Run the UN SDG series collection. |
| d5_2_standards | 5.2 | manual | informational | artifact_present | Refresh WDI/IMF/manual standards inputs. |
| d5_3_unavailable | 5.3 | unavailable | informational | source_unavailable_by_design | No established methodology; record as unavailable. |
| d5_4_unavailable | 5.4 | unavailable | informational | source_unavailable_by_design | No established methodology; record as unavailable. |
| d5_5_finance | 5.5 | api | informational | release_recorded | Run the UN SDG series collection. |
| d2_4_nada_review | 2.4 | manual | informational | artifact_present | Complete and validate the current NADA manual review workbook. |
| d2_4_nada_url_evidence | 2.4 | external | informational | artifact_present | Refresh the cached NADA URL evidence or investigate collection errors. |
| d2_4_nada_manifest | 2.4 | external | informational | artifact_present | Validate the current NADA output, evidence, and provenance hashes. |
| d1_5_igme | 1.5 | manual | blocking | attestation_missing | Download the current UN IGME child mortality file. |
| d1_5_wdi | 1.5 | manual | informational | artifact_present | Download WDI metadata for end_date + 1. |
| d1_5_jmp | 1.5 | api | informational | release_recorded | Run the JMP API collector. |
| d1_5_ilo | 1.5 | manual | blocking | attestation_missing | Download the current ILO modelled and survey bulk files. |
| d3_sdg_indicator_list | 3.1 | manual | blocking | attestation_missing | Provide the frozen SPI SDG indicator list (methodology input defining scored series and goal mapping); do not refresh it per vintage. |
| d5_2_wdi_metadata | 5.2 | manual | informational | artifact_present | Download WDI metadata for end_date + 1. |
| d5_2_imf_workbook | 5.2 | manual | blocking | attestation_missing | Place the current IMF compiled workbook in 01_raw_data/5.2_DISM/. |
| d5_2_imf_workbook_2024 | 5.2 | manual | blocking | attestation_missing | Retain the 2025.10 IMF workbook for the 2024 reference-year observation. |
| d4_1_collection_manifest | 4.1 | external | informational | artifact_present | Run the D4.1 collection target and resolve manual-review, workbook (year text, coverage) or artifact validation failures; map unmatched catalogue names in config/d41_country_crosswalk.csv or record non-economies in config/d41_companion_exclusions.csv. |
| d4_1_input_population_census | 4.1 | manual | blocking | attestation_missing | Update and validate the current 4.1 source workbook. |
| d4_1_input_agriculture_census | 4.1 | manual | blocking | attestation_missing | Update and validate the current 4.1 source workbook. |
| d4_1_input_business_census | 4.1 | manual | blocking | attestation_missing | Update and validate the current 4.1 source workbook. |
| d4_1_input_household_survey | 4.1 | manual | blocking | attestation_missing | Update and validate the current 4.1 source workbook. |
| d4_1_input_agriculture_survey | 4.1 | manual | blocking | attestation_missing | Update and validate the current 4.1 source workbook. |
| d4_1_input_labor_survey | 4.1 | manual | blocking | attestation_missing | Update and validate the current 4.1 source workbook. |
| d4_1_input_health_survey | 4.1 | manual | blocking | attestation_missing | Update and validate the current 4.1 source workbook. |
| d4_1_input_business_survey | 4.1 | manual | blocking | attestation_missing | Update and validate the current 4.1 source workbook. |
| d4_1_manual_review | 4.1 | manual | informational | artifact_present | Complete country-economist review and save the current-vintage workbook. |
| d3_oecd_sdg | 3.1 | api | informational | release_recorded | Run the OECD SDG collection target (oecd_collection). |
| d5_2_ilo_catalogue | 5.2 | manual | blocking | attestation_missing | Download sources_en.csv from the ILOSTAT national sources catalogue, save it as 4.1_SOCS/ilo_sources_catalog.csv and attest it. |
| d5_2_empl | 5.2 | external | informational | artifact_present | Run the d5_2_empl collection target. |
| d5_2_cnin_review | 5.2 | manual | blocking | attestation_missing | Review the CNIN candidates in _collection/review_candidates_<end_date>.csv, record overrides with evidence in the workbook, then attest it. |
| d5_2_fina_review | 5.2 | manual | blocking | attestation_missing | Review the FINA candidates in _collection/review_candidates_<end_date>.csv, record overrides with evidence in the workbook, then attest it. |
| d5_2_cnin | 5.2 | external | informational | artifact_present | Run the d5_2_cnin collection target. |
| d5_2_fina | 5.2 | external | informational | artifact_present | Run the d5_2_fina collection target. |
| d5_2_10_gsbp | 5.2 | external | informational | artifact_present | Run the gsbp_output collection target. |
| d5_2_10_gsbp_desk_review | 5.2 | manual | warning | attestation_missing | Refresh the GSBPM desk review (5.2_DISM/raw/D1.12.MSC.csv) or confirm the carry-forward, then attest it. |
| d5_2_10_gsbp_review | 5.2 | manual | informational | artifact_present | Review the GSBP candidates and complete the current-vintage GSBP review workbook. |

## Counts

- `blocking`: 17
- `informational`: 35
- `warning`: 1

## Collection warnings

| Source | Warning |
|---|---|
| d5_2_10_gsbp_desk_review | GSBP desk review D1.12.MSC.csv is unchanged since the 2024 vintage (sha256 6567dfcdf0f3); refresh it or confirm the carry-forward. |
| d5_2_empl | ILO catalogue countries without an ISO3 code were dropped (as in the notebook): Bolivia, Plurinational State of; Faroe Islands; Republic of Korea; Republic of Moldova; Türkiye; United Kingdom of Great Britain and Northern Ireland; United States of America |

## Review candidates

Informational: countries to check before signing the review workbooks.

| Source | Reason | Countries |
|---|---|---|
| D4.1.1.CEN.POPU | latest census 1997 is more than 10 years before 2025 | 1 |
| D4.1.1.CEN.POPU | latest census 2001 is more than 10 years before 2025 | 1 |
| D4.1.1.CEN.POPU | latest census 2003 is more than 10 years before 2025 | 2 |
| D4.1.1.CEN.POPU | latest census 2004 is more than 10 years before 2025 | 2 |
| D4.1.1.CEN.POPU | latest census 2005 is more than 10 years before 2025 | 2 |
| D4.1.1.CEN.POPU | latest census 2006 is more than 10 years before 2025 | 2 |
| D4.1.1.CEN.POPU | latest census 2007 is more than 10 years before 2025 | 3 |
| D4.1.1.CEN.POPU | latest census 2008 is more than 10 years before 2025 | 3 |
| D4.1.1.CEN.POPU | latest census 2009 is more than 10 years before 2025 | 3 |
| D4.1.1.CEN.POPU | latest census 2010 is more than 10 years before 2025 | 2 |
| D4.1.1.CEN.POPU | latest census 2011 is more than 10 years before 2025 | 7 |
| D4.1.1.CEN.POPU | latest census 2012 is more than 10 years before 2025 | 4 |
| D4.1.1.CEN.POPU | latest census 2013 is more than 10 years before 2025 | 4 |
| D4.1.1.CEN.POPU | latest census 2014 is more than 10 years before 2025 | 8 |
| D4.1.1.CEN.POPU | no census recorded | 6 |
| D4.1.2.CEN.AGRI | latest census 2000 is more than 10 years before 2025 | 5 |
| D4.1.2.CEN.AGRI | latest census 2001 is more than 10 years before 2025 | 3 |
| D4.1.2.CEN.AGRI | latest census 2002 is more than 10 years before 2025 | 3 |
| D4.1.2.CEN.AGRI | latest census 2003 is more than 10 years before 2025 | 2 |
| D4.1.2.CEN.AGRI | latest census 2004 is more than 10 years before 2025 | 4 |
| D4.1.2.CEN.AGRI | latest census 2005 is more than 10 years before 2025 | 3 |
| D4.1.2.CEN.AGRI | latest census 2006 is more than 10 years before 2025 | 3 |
| D4.1.2.CEN.AGRI | latest census 2007 is more than 10 years before 2025 | 3 |
| D4.1.2.CEN.AGRI | latest census 2008 is more than 10 years before 2025 | 4 |
| D4.1.2.CEN.AGRI | latest census 2009 is more than 10 years before 2025 | 2 |
| D4.1.2.CEN.AGRI | latest census 2010 is more than 10 years before 2025 | 6 |
| D4.1.2.CEN.AGRI | latest census 2011 is more than 10 years before 2025 | 6 |
| D4.1.2.CEN.AGRI | latest census 2012 is more than 10 years before 2025 | 5 |
| D4.1.2.CEN.AGRI | latest census 2013 is more than 10 years before 2025 | 7 |
| D4.1.2.CEN.AGRI | latest census 2014 is more than 10 years before 2025 | 7 |
| D4.1.2.CEN.AGRI | no census recorded | 34 |
| D4.1.3.CEN.BIZZ | latest census 2001 is more than 10 years before 2025 | 1 |
| D4.1.3.CEN.BIZZ | latest census 2008 is more than 10 years before 2025 | 1 |
| D4.1.3.CEN.BIZZ | latest census 2010 is more than 10 years before 2025 | 1 |
| D4.1.3.CEN.BIZZ | latest census 2011 is more than 10 years before 2025 | 2 |
| D4.1.3.CEN.BIZZ | latest census 2012 is more than 10 years before 2025 | 1 |
| D4.1.3.CEN.BIZZ | latest census 2013 is more than 10 years before 2025 | 3 |
| D4.1.3.CEN.BIZZ | latest census 2014 is more than 10 years before 2025 | 2 |
| D4.1.3.CEN.BIZZ | no census recorded | 43 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2016 | 2 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2017 | 1 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2018 | 2 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2020 | 1 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2021 | 2 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2022 | 2 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2018 | 1 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2019 | 2 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2021 | 5 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2022 | 5 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2023 | 2 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2024 | 1 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2016 | 1 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2017, 2021 | 1 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2018, 2019 | 1 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2018, 2021 | 1 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2020 | 1 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2021 | 3 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2022 | 2 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2022, 2023 | 1 |
| D4.1.4.SVY.HOUS | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2023 | 2 |
| D4.1.4.SVY.HOUS | latest survey 1993 is outside the 12-year window for 2025 | 1 |
| D4.1.4.SVY.HOUS | latest survey 2003 is outside the 12-year window for 2025 | 1 |
| D4.1.4.SVY.HOUS | latest survey 2005 is outside the 12-year window for 2025 | 2 |
| D4.1.4.SVY.HOUS | latest survey 2006 is outside the 12-year window for 2025 | 1 |
| D4.1.4.SVY.HOUS | latest survey 2008 is outside the 12-year window for 2025 | 1 |
| D4.1.4.SVY.HOUS | latest survey 2009 is outside the 12-year window for 2025 | 1 |
| D4.1.4.SVY.HOUS | latest survey 2011 is outside the 12-year window for 2025 | 2 |
| D4.1.4.SVY.HOUS | latest survey 2012 is outside the 12-year window for 2025 | 2 |
| D4.1.4.SVY.HOUS | no survey recorded | 1 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2014 | 1 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2015 | 1 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2018 | 3 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2020 | 2 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2021 | 2 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2022 | 1 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2013, 2018 | 1 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2015, 2021 | 1 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2020, 2021 | 1 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2021, 2022 | 3 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2021, 2024 | 1 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0 to 1; catalogue-only years in the window: 2016, 2021, 2022 | 1 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0 to 1; catalogue-only years in the window: 2018, 2020, 2021 | 1 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0 to 1; catalogue-only years in the window: 2020, 2021, 2022 | 1 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0 to 1; catalogue-only years in the window: 2021, 2022, 2024 | 1 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2017 | 1 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2022 | 1 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2014, 2015, 2016, 2017, 2021 | 1 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2015, 2019, 2020 | 1 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2014, 2015, 2021, 2022 | 1 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2021, 2022 | 1 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2022 | 1 |
| D4.1.5.SVY.AGRI | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2023 | 1 |
| D4.1.5.SVY.AGRI | latest survey 2004 is outside the 12-year window for 2025 | 1 |
| D4.1.5.SVY.AGRI | latest survey 2005 is outside the 12-year window for 2025 | 1 |
| D4.1.5.SVY.AGRI | latest survey 2007 is outside the 12-year window for 2025 | 1 |
| D4.1.5.SVY.AGRI | latest survey 2008 is outside the 12-year window for 2025 | 2 |
| D4.1.5.SVY.AGRI | latest survey 2009 is outside the 12-year window for 2025 | 1 |
| D4.1.5.SVY.AGRI | latest survey 2011 is outside the 12-year window for 2025 | 2 |
| D4.1.5.SVY.AGRI | no survey recorded | 78 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2016 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2017 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2018 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2019 | 3 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2021 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2022 | 2 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2016, 2023 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2018, 2023 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2019, 2024 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0 to 1; catalogue-only years in the window: 2018, 2019, 2020, 2021, 2023 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0 to 1; catalogue-only years in the window: 2022, 2023, 2024 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2014 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2018 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2020 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2021 | 2 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2022 | 2 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2023 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2024 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2013, 2014, 2015, 2016, 2017, 2019, 2020, 2021, 2022, 2023 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2015, 2016, 2017, 2018, 2021, 2022, 2023 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2017, 2019, 2020, 2021, 2022, 2023, 2024 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2020, 2021 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2020, 2024 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2021, 2022 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2021, 2023, 2025 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2023, 2025 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2016, 2019 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2018, 2019, 2020, 2021, 2022, 2023, 2024 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2021 | 2 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2021, 2022, 2023, 2024 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2024 | 1 |
| D4.1.6.SVY.LABR | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2024, 2025 | 1 |
| D4.1.6.SVY.LABR | latest survey 1999 is outside the 12-year window for 2025 | 1 |
| D4.1.6.SVY.LABR | latest survey 2004 is outside the 12-year window for 2025 | 1 |
| D4.1.6.SVY.LABR | latest survey 2005 is outside the 12-year window for 2025 | 1 |
| D4.1.6.SVY.LABR | latest survey 2009 is outside the 12-year window for 2025 | 1 |
| D4.1.6.SVY.LABR | latest survey 2011 is outside the 12-year window for 2025 | 1 |
| D4.1.6.SVY.LABR | latest survey 2012 is outside the 12-year window for 2025 | 3 |
| D4.1.6.SVY.LABR | no survey recorded | 24 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2014 | 2 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2016 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2017 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2021 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2014, 2016 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0 to 1; catalogue-only years in the window: 2014, 2015, 2016, 2017, 2018, 2019, 2023 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0 to 1; catalogue-only years in the window: 2014, 2015, 2019 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0 to 1; catalogue-only years in the window: 2014, 2017, 2021 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0 to 1; catalogue-only years in the window: 2015, 2018, 2022 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2014 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2016 | 2 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2017 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2018 | 2 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2019 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2021 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2022 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2023 | 3 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2013, 2015, 2020, 2022 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2014, 2024 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2015, 2021 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2016, 2021 | 2 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2017, 2019, 2024 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2013 | 2 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2013, 2023, 2025 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2016, 2022 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2019, 2022 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2021 | 1 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2023 | 2 |
| D4.1.7.SVY.HLTH | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2024 | 1 |
| D4.1.7.SVY.HLTH | latest survey 2000 is outside the 12-year window for 2025 | 1 |
| D4.1.7.SVY.HLTH | latest survey 2002 is outside the 12-year window for 2025 | 1 |
| D4.1.7.SVY.HLTH | latest survey 2003 is outside the 12-year window for 2025 | 1 |
| D4.1.7.SVY.HLTH | latest survey 2004 is outside the 12-year window for 2025 | 1 |
| D4.1.7.SVY.HLTH | latest survey 2005 is outside the 12-year window for 2025 | 1 |
| D4.1.7.SVY.HLTH | latest survey 2006 is outside the 12-year window for 2025 | 1 |
| D4.1.7.SVY.HLTH | latest survey 2007 is outside the 12-year window for 2025 | 5 |
| D4.1.7.SVY.HLTH | latest survey 2008 is outside the 12-year window for 2025 | 1 |
| D4.1.7.SVY.HLTH | latest survey 2009 is outside the 12-year window for 2025 | 3 |
| D4.1.7.SVY.HLTH | latest survey 2010 is outside the 12-year window for 2025 | 5 |
| D4.1.7.SVY.HLTH | latest survey 2011 is outside the 12-year window for 2025 | 5 |
| D4.1.7.SVY.HLTH | latest survey 2012 is outside the 12-year window for 2025 | 7 |
| D4.1.7.SVY.HLTH | no survey recorded | 3 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2013 | 2 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2014 | 2 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2016 | 2 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2017 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2018 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2022 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2023 | 8 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2024 | 13 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.33; catalogue-only years in the window: 2025 | 10 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2013, 2022 | 2 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2013, 2023 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2013, 2024 | 2 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2013, 2025 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2014, 2024 | 2 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2014, 2025 | 2 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2016, 2023 | 2 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2016, 2024 | 3 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2016, 2025 | 2 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2017, 2022 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2017, 2025 | 2 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2018, 2023 | 2 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2018, 2024 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2018, 2025 | 2 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2019, 2020 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2021, 2024 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 0.67; catalogue-only years in the window: 2022, 2023 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 1; catalogue-only years in the window: 2013, 2016, 2019, 2021, 2025 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 1; catalogue-only years in the window: 2013, 2018, 2020, 2025 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 1; catalogue-only years in the window: 2013, 2019, 2022 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 1; catalogue-only years in the window: 2013, 2019, 2023 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 1; catalogue-only years in the window: 2013, 2019, 2024 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 1; catalogue-only years in the window: 2016, 2020, 2021, 2022, 2025 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 1; catalogue-only years in the window: 2017, 2020, 2025 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0 to 1; catalogue-only years in the window: 2019, 2021, 2024 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2017 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2019 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2023 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0.33 to 0.67; catalogue-only years in the window: 2025 | 3 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2013, 2015, 2023 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2013, 2024 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2014, 2019, 2024 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2014, 2025 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2015, 2024 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2015, 2025 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0.33 to 1; catalogue-only years in the window: 2016, 2023 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2014, 2016 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2015, 2022 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2019, 2020, 2024 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2021, 2023 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2023 | 1 |
| D4.1.8.SVY.BIZZ | catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2025 | 1 |
| D4.1.8.SVY.BIZZ | latest survey 2007 is outside the 12-year window for 2025 | 1 |
| D4.1.8.SVY.BIZZ | latest survey 2009 is outside the 12-year window for 2025 | 1 |
| D4.1.8.SVY.BIZZ | latest survey 2010 is outside the 12-year window for 2025 | 2 |
| D4.1.8.SVY.BIZZ | latest survey 2011 is outside the 12-year window for 2025 | 2 |
| D4.1.8.SVY.BIZZ | no survey recorded | 15 |
| d5_2_10_gsbp | no GSBPM evidence in the previous vintage or the desk review | 113 |
| d5_2_cnin | historical override in D5.2.3.CNIN.Manual.Review.xlsx | 2 |
| d5_2_cnin | value is not Rev.4 or NACE Rev.2 | 83 |
| d5_2_empl | ILO catalogue country not mapped to ISO3 (dropped, as in the notebook) | 7 |
| d5_2_fina | IMF GFS text mentions GFSM 2014 | 8 |
| d5_2_fina | IMF GFS text mentions GFSM 2014; value is blank, other or Not Found | 2 |
| d5_2_fina | value is blank, other or Not Found | 13 |

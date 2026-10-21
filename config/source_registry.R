# =============================================================================
# SPI source registry
# =============================================================================
# This registry covers all 22 framework dimensions. Indicator-level sources
# can share a source_id or path as collectors are implemented.
#
# Created: 2026-10-05
# =============================================================================

source_registry <- data.frame(
  source_id = c(
    "d1_1_unavailable", "d1_2_unavailable", "d1_3_unavailable",
    "d1_4_unavailable", "d1_5_pip",
    "d2_1_sdds", "d2_2_odin", "d2_3_unavailable", "d2_4_nada",
    "d3_1_sdg", "d3_2_sdg", "d3_3_sdg", "d3_4_sdg",
    "d4_1_microdata", "d4_2_crvs", "d4_3_odin", "d4_4_unavailable",
    "d5_1_legislation", "d5_2_standards", "d5_3_unavailable",
    "d5_4_unavailable", "d5_5_finance"
  ),
  dimension_id = c(
    "1.1", "1.2", "1.3", "1.4", "1.5",
    "2.1", "2.2", "2.3", "2.4",
    "3.1", "3.2", "3.3", "3.4",
    "4.1", "4.2", "4.3", "4.4",
    "5.1", "5.2", "5.3", "5.4", "5.5"
  ),
  source_type = c(
    "unavailable", "unavailable", "unavailable", "unavailable", "api",
    "manual", "manual", "unavailable", "manual",
    "api", "api", "api", "api",
    "external", "api", "manual", "unavailable",
    "api", "manual", "unavailable", "unavailable", "api"
  ),
  indicator_ids = c(
    NA, NA, NA, NA,
    "SPI.D1.5.POV",
    "SPI.D2.1.GDDS", "SPI.D2.2.Openness.subscore", NA, "SPI.D2.4.NADA",
    "SPI.D3.1.*", "SPI.D3.2.*", "SPI.D3.3.*", "SPI.D3.4.*",
    "SPI.D4.1.*", "SPI.D4.2.3.CRVS", "SPI.D4.3.GEO.*", NA,
    "SPI.D5.1.DILG", "SPI.D5.2.*", NA, NA, "SPI.D5.5.DIFI"
  ),
  source_url = c(
    NA, NA, NA, NA, "https://pip.worldbank.org/",
    "https://dsbb.imf.org/", "https://odin.opendatawatch.com/", NA,
    "https://www.nada.ihsn.org/",
    "https://unstats.un.org/SDGAPI/", "https://unstats.un.org/SDGAPI/",
    "https://unstats.un.org/SDGAPI/", "https://unstats.un.org/SDGAPI/",
    "https://microdata.worldbank.org/", "https://unstats.un.org/SDGAPI/",
    "https://odin.opendatawatch.com/", NA,
    "https://unstats.un.org/SDGAPI/", "https://datacatalog.worldbank.org/",
    NA, NA, "https://unstats.un.org/SDGAPI/"
  ),
  input_path = c(
    NA, NA, NA, NA, "1.5_DUIO/PIP_comparability_latest.csv",
    "2.1_DSDR/SCI_archived_data.csv", "2.2_DSOA/ODIN_<YEAR>.csv", NA,
    "2.4_DSDS/D2.4.NADA.<YEAR>.csv",
    "3_DP/sdg_data/<SERIES>.csv", "3_DP/sdg_data/<SERIES>.csv",
    "3_DP/sdg_data/<SERIES>.csv", "3_DP/sdg_data/<SERIES>.csv",
    "4.1_SOCS/raw/", "4.2_SOAD/SG_REG_BRTH90N.csv",
    "2.2_DSOA/ODIN_<YEAR>.csv", NA,
    "5.1_DILG/SG_STT_FPOS.csv", "5.2_DISM/D5.2.2.NABY_raw_metadata.csv", NA, NA,
    "5.5_DIFI/SG_STT_NSDSFND.csv"
  ),
  raw_path = c(
    NA, NA, NA, NA, "1.5_DUIO/raw/pip/",
    "2.1_DSDR/raw/", "2.2_DSOA/raw/", NA, "2.4_DSDS/raw/",
    "3_DP/sdg_data/raw/", "3_DP/sdg_data/raw/", "3_DP/sdg_data/raw/",
    "3_DP/sdg_data/raw/", "4.1_SOCS/raw/", "4.2_SOAD/raw/",
    "2.2_DSOA/raw/", NA, "5.1_DILG/raw/", "5.2_DISM/raw/", NA, NA,
    "5.5_DIFI/raw/"
  ),
  normalized_path = c(
    NA, NA, NA, NA, "1.5_DUIO/PIP_comparability_latest.csv",
    "2.1_DSDR/SCI_archived_data.csv", "2.2_DSOA/ODIN_<YEAR>.csv", NA,
    "2.4_DSDS/D2.4.NADA.<YEAR>.csv",
    "3_DP/collection/SPI_D3_UNSD_data_5yr.csv", "3_DP/collection/SPI_D3_UNSD_data_5yr.csv",
    "3_DP/collection/SPI_D3_UNSD_data_5yr.csv", "3_DP/collection/SPI_D3_UNSD_data_5yr.csv",
    "4.1_SOCS/raw/", "4.2_SOAD/SG_REG_BRTH90N.csv",
    "2.2_DSOA/ODIN_<YEAR>.csv", NA, "5.1_DILG/SG_STT_FPOS.csv",
    "5.2_DISM/D5.2.2.NABY_raw_metadata.csv", NA, NA, "5.5_DIFI/SG_STT_NSDSFND.csv"
  ),
  availability_path = c(
    NA, NA, NA, NA, NA, NA, NA, NA, NA,
    "3_DP/availability/", "3_DP/availability/", "3_DP/availability/",
    "3_DP/availability/", NA, "4.2_SOAD/availability/", NA, NA, NA, NA,
    NA, NA, NA
  ),
  expected_vintage_rule = c(
    "not_measured", "not_measured", "not_measured", "not_measured", "latest_release",
    "latest_release", "end_date", "not_measured", "end_date",
    "end_date", "end_date", "end_date", "end_date", "end_date",
    "end_date", "end_date", "not_measured", "end_date", "end_date_plus_one",
    "not_measured", "not_measured", "end_date"
  ),
  age_warning_days = rep(365, 22),
  status_if_missing = c(
    rep("informational", 4), "blocking", "blocking", "blocking", "informational", "blocking",
    rep("blocking", 4), "blocking", "blocking", "blocking", "informational",
    "blocking", "blocking", "informational", "informational", "blocking"
  ),
  analyst_action = c(
    "No established methodology; record as unavailable.",
    "No established methodology; record as unavailable.",
    "No established methodology; record as unavailable.",
    "No established methodology; record as unavailable.",
    "Refresh PIP data or document an external PIP release.",
    "Refresh the IMF dissemination source.",
    "Download the current ODIN file.",
    "No established methodology; record as unavailable.",
    "Run the NADA collection/check procedure.",
    "Run the UN SDG series collection.",
    "Run the UN SDG series collection.",
    "Run the UN SDG series collection.",
    "Run the UN SDG series collection.",
    "Run the microdata library collection.",
    "Run the UN SDG CRVS collection.",
    "Download the current ODIN file.",
    "No established methodology; record as unavailable.",
    "Run the UN SDG series collection.",
    "Refresh WDI/IMF/manual standards inputs.",
    "No established methodology; record as unavailable.",
    "No established methodology; record as unavailable.",
    "Run the UN SDG series collection."
  ),
  stringsAsFactors = FALSE
)

source_registry <- rbind(
  source_registry,
  data.frame(
    source_id = c("d1_5_igme", "d1_5_wdi", "d1_5_jmp", "d1_5_ilo"),
    dimension_id = rep("1.5", 4),
    source_type = c("manual", "manual", "api", "manual"),
    indicator_ids = c(
      "SPI.D1.5.CHLD.MORT",
      "SPI.D1.5.DT.TDS.DPPF.XP.ZS",
      "SPI.D1.5.SAFE.MAN.WATER",
      "SPI.D1.5.LFP"
    ),
    source_url = c(
      "https://childmortality.org/",
      "https://datacatalog.worldbank.org/int/search/dataset/0037712",
      "https://washdata.org/",
      "https://www.ilo.org/ilostat-files/"
    ),
    input_path = c(
      "1.5_DUIO/UN IGME 2025.csv",
      "metadata/WDI_metadata_<END_DATE_PLUS_ONE>.csv",
      "1.5_DUIO/Safely_Managed_Water_data.csv",
      "1.5_DUIO/EAP_2WAP_SEX_AGE_RT_A-<timestamp>.xlsx|EAP_DWAP_SEX_AGE_RT_A-<timestamp>.xlsx"
    ),
    raw_path = c(
      "1.5_DUIO/raw/igme/",
      "metadata/raw/",
      "1.5_DUIO/raw/jmp/",
      "1.5_DUIO/raw/ilo/"
    ),
    normalized_path = c(
      "1.5_DUIO/UN IGME 2025.csv",
      "metadata/WDI_metadata_<END_DATE_PLUS_ONE>.csv",
      "1.5_DUIO/Safely_Managed_Water_data.csv",
      "1.5_DUIO/EAP_2WAP_SEX_AGE_RT_A-<timestamp>.xlsx|EAP_DWAP_SEX_AGE_RT_A-<timestamp>.xlsx"
    ),
    availability_path = rep(NA, 4),
    expected_vintage_rule = c("latest_release", "end_date_plus_one", "latest_release", "latest_release"),
    age_warning_days = rep(365, 4),
    status_if_missing = rep("blocking", 4),
    analyst_action = c(
      "Download the current UN IGME child mortality file.",
      "Download WDI metadata for end_date + 1.",
      "Run the JMP API collector.",
      "Download the current ILO modelled and survey bulk files."
    ),
    stringsAsFactors = FALSE
  ),
  data.frame(
    source_id = "d3_sdg_indicator_list",
    dimension_id = "3.1",
    source_type = "manual",
    indicator_ids = "SDG indicator series list",
    source_url = "https://unstats.un.org/SDGAPI/",
    input_path = "metadata/SDG_indicator_list.csv",
    raw_path = NA_character_,
    normalized_path = "metadata/SDG_indicator_list.csv",
    availability_path = NA,
    expected_vintage_rule = "manual_attestation",
    # Frozen methodology input: file age is not a staleness signal.
    age_warning_days = Inf,
    status_if_missing = "blocking",
    analyst_action = paste(
      "Provide the frozen SPI SDG indicator list (methodology input defining",
      "scored series and goal mapping); do not refresh it per vintage."
    ),
    stringsAsFactors = FALSE
  ),
  data.frame(
    source_id = c("d5_2_wdi_metadata", "d5_2_imf_workbook", "d5_2_imf_workbook_2024"),
    dimension_id = c("5.2", "5.2", "5.2"),
    source_type = c("manual", "manual", "manual"),
    indicator_ids = c("SPI.D1.5.DT.TDS.DPPF.XP.ZS|SPI.D5.2.*", "SPI.D5.2.*", "SPI.D5.2.*"),
    source_url = c(
      "https://datacatalog.worldbank.org/int/search/dataset/0037712",
      "https://www.imf.org/en/Data",
      "https://www.imf.org/en/Data"
    ),
    input_path = c(
      "metadata/WDI_metadata_<END_DATE_PLUS_ONE>.csv",
      "5.2_DISM/2026.10_Compiled Data for World Bank - Sep 2026 - Final.xlsx",
      "5.2_DISM/2025.10_Compiled Data for World Bank.xlsx"
    ),
    raw_path = c("metadata/raw/", "5.2_DISM/raw/", "5.2_DISM/raw/"),
    normalized_path = c(
      "metadata/WDI_metadata_<END_DATE_PLUS_ONE>.csv",
      "5.2_DISM/2026.10_Compiled Data for World Bank - Sep 2026 - Final.xlsx",
      "5.2_DISM/2025.10_Compiled Data for World Bank.xlsx"
    ),
    availability_path = c(NA, NA, NA),
    expected_vintage_rule = c("end_date_plus_one", "latest_release", "latest_release"),
    age_warning_days = c(365, 365, 365),
    status_if_missing = c("blocking", "blocking", "blocking"),
    analyst_action = c(
      "Download WDI metadata for end_date + 1.",
      "Place the current IMF compiled workbook in 01_raw_data/5.2_DISM/.",
      "Retain the 2025.10 IMF workbook for the 2024 reference-year observation."
    ),
    stringsAsFactors = FALSE
  )
)

source_registry <- rbind(
  source_registry,
  data.frame(
    source_id = "d4_1_collection_manifest",
    dimension_id = "4.1",
    source_type = "external",
    indicator_ids = "SPI.D4.1.*",
    source_url = NA_character_,
    input_path = paste(
      "4.1_SOCS/raw/input/*.xlsx",
      "4.1_SOCS/raw/D4.1.Manual.Review.<END_DATE>.xlsx",
      sep = "|"
    ),
    raw_path = "4.1_SOCS/collection/",
    normalized_path = "4.1_SOCS/collection/D4.1_collection_manifest.json",
    availability_path = NA_character_,
    expected_vintage_rule = "end_date",
    age_warning_days = 365,
    status_if_missing = "blocking",
    analyst_action = "Run the D4.1 collection target and resolve manual-review or artifact validation failures.",
    stringsAsFactors = FALSE
  )
)

source_registry <- rbind(
  source_registry,
  data.frame(
    source_id = c(
      "d4_1_input_population_census",
      "d4_1_input_agriculture_census",
      "d4_1_input_business_census",
      "d4_1_input_household_survey",
      "d4_1_input_agriculture_survey",
      "d4_1_input_labor_survey",
      "d4_1_input_health_survey",
      "d4_1_input_business_survey",
      "d4_1_manual_review"
    ),
    dimension_id = rep("4.1", 9),
    source_type = rep("manual", 9),
    indicator_ids = c(
      "SPI.D4.1.1.POPU", "SPI.D4.1.2.AGRI", "SPI.D4.1.3.BIZZ",
      "SPI.D4.1.4.HOUS", "SPI.D4.1.5.AGSVY", "SPI.D4.1.6.LABR",
      "SPI.D4.1.7.HLTH", "SPI.D4.1.8.BZSVY", "SPI.D4.1.*"
    ),
    source_url = rep(NA_character_, 9),
    input_path = c(
      "4.1_SOCS/raw/input/D2.1.CEN.POPU.xlsx",
      "4.1_SOCS/raw/input/D2.2.CEN.AGRI.xlsx",
      "4.1_SOCS/raw/input/D2.3.CEN.BIZZ.xlsx",
      "4.1_SOCS/raw/input/D2.4.SVY.HOUS.xlsx",
      "4.1_SOCS/raw/input/D2.5.SVY.AGRI.xlsx",
      "4.1_SOCS/raw/input/D2.6.SVY.LABR.xlsx",
      "4.1_SOCS/raw/input/D2.7.SVY.HLTH.xlsx",
      "4.1_SOCS/raw/input/D2.8.SVY.BIZZ.xlsx",
      "4.1_SOCS/raw/D4.1.Manual.Review.<END_DATE>.xlsx"
    ),
    raw_path = c(
      rep("4.1_SOCS/raw/input/", 8),
      "4.1_SOCS/raw/"
    ),
    normalized_path = c(
      "4.1_SOCS/raw/input/D2.1.CEN.POPU.xlsx",
      "4.1_SOCS/raw/input/D2.2.CEN.AGRI.xlsx",
      "4.1_SOCS/raw/input/D2.3.CEN.BIZZ.xlsx",
      "4.1_SOCS/raw/input/D2.4.SVY.HOUS.xlsx",
      "4.1_SOCS/raw/input/D2.5.SVY.AGRI.xlsx",
      "4.1_SOCS/raw/input/D2.6.SVY.LABR.xlsx",
      "4.1_SOCS/raw/input/D2.7.SVY.HLTH.xlsx",
      "4.1_SOCS/raw/input/D2.8.SVY.BIZZ.xlsx",
      "4.1_SOCS/raw/D4.1.Manual.Review.<END_DATE>.xlsx"
    ),
    availability_path = rep(NA_character_, 9),
    expected_vintage_rule = c(rep("manual_attestation", 8), "end_date"),
    age_warning_days = rep(365, 9),
    status_if_missing = rep("blocking", 9),
    analyst_action = c(
      rep("Update and validate the current 4.1 source workbook.", 8),
      "Complete country-economist review and save the current-vintage workbook."
    ),
    stringsAsFactors = FALSE
  )
)

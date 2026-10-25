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
    "3_DP/sdg_data/raw/", "3_DP/sdg_data/raw/",
    "3_DP/sdg_data/raw/", "3_DP/sdg_data/raw/",
    "4.1_SOCS/raw/", "4.2_SOAD/SG_REG_BRTH90N.csv|4.2_SOAD/SG_REG_DETH75N.csv",
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
    "3_DP/<END_DATE>/SPI_D3_UNSD_data_5yr.csv", "3_DP/<END_DATE>/SPI_D3_UNSD_data_5yr.csv",
    "3_DP/<END_DATE>/SPI_D3_UNSD_data_5yr.csv", "3_DP/<END_DATE>/SPI_D3_UNSD_data_5yr.csv",
    "4.1_SOCS/raw/", "4.2_SOAD/SG_REG_BRTH90N.csv|4.2_SOAD/SG_REG_DETH75N.csv",
    "2.2_DSOA/ODIN_<YEAR>.csv", NA, "5.1_DILG/SG_STT_FPOS.csv",
    "5.2_DISM/D5.2.2.NABY_raw_metadata.csv", NA, NA, "5.5_DIFI/SG_STT_NSDSFND.csv"
  ),
  availability_path = c(
    NA, NA, NA, NA, NA, NA, NA, NA, NA,
    NA, NA, NA,
    NA, NA, "4.2_SOAD/availability/", NA, NA, NA, NA,
    NA, NA, NA
  ),
  # release_identifier: collected sources must carry provenance with the
  # observed release; manual_attestation: manual files need a hash-bound
  # attestation in _collection/source_attestations_<end_date>.csv.
  expected_vintage_rule = c(
    "not_measured", "not_measured", "not_measured", "not_measured", "release_identifier",
    "manual_attestation", "end_date", "not_measured", "end_date",
    "release_identifier", "release_identifier", "release_identifier", "release_identifier", "end_date",
    "release_identifier", "end_date", "not_measured", "release_identifier", "end_date_plus_one",
    "not_measured", "not_measured", "release_identifier"
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

source_registry$input_path[source_registry$source_id == "d2_4_nada"] <- paste(
  "2.4_DSDS/D2.4.NADA.<YEAR>.csv",
  "2.4_DSDS/D2.4.NADA.Manual.Review.<END_DATE>.xlsx",
  sep = "|"
)

source_registry <- rbind(
  source_registry,
  data.frame(
    source_id = c(
      "d2_4_nada_review",
      "d2_4_nada_url_evidence",
      "d2_4_nada_manifest"
    ),
    dimension_id = rep("2.4", 3),
    source_type = c("manual", "external", "external"),
    indicator_ids = rep("SPI.D2.4.NADA", 3),
    source_url = c(
      NA_character_,
      "https://www.nada.ihsn.org/",
      "https://www.nada.ihsn.org/"
    ),
    input_path = c(
      "2.4_DSDS/D2.4.NADA.Manual.Review.<END_DATE>.xlsx",
      "2.4_DSDS/collection/D2.4.NADA.url_evidence.<END_DATE>.csv",
      "2.4_DSDS/collection/D2.4.NADA_manifest_<END_DATE>.json"
    ),
    raw_path = c(
      "2.4_DSDS/",
      "2.4_DSDS/collection/",
      "2.4_DSDS/collection/"
    ),
    normalized_path = c(
      "2.4_DSDS/D2.4.NADA.Manual.Review.<END_DATE>.xlsx",
      "2.4_DSDS/collection/D2.4.NADA.url_evidence.<END_DATE>.csv",
      "2.4_DSDS/collection/D2.4.NADA_manifest_<END_DATE>.json"
    ),
    availability_path = rep(NA_character_, 3),
    expected_vintage_rule = rep("end_date", 3),
    age_warning_days = c(365, 30, 365),
    status_if_missing = c("blocking", "warning", "blocking"),
    analyst_action = c(
      "Complete and validate the current NADA manual review workbook.",
      "Refresh the cached NADA URL evidence or investigate collection errors.",
      "Validate the current NADA output, evidence, and provenance hashes."
    ),
    stringsAsFactors = FALSE
  )
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
      "1.5_DUIO/<UNIGME_FILE>",
      "metadata/WDI_metadata_<END_DATE_PLUS_ONE>.csv",
      "1.5_DUIO/Safely_Managed_Water_data.csv",
      "1.5_DUIO/<ILO_MODELLED_FILE>|1.5_DUIO/<ILO_SURVEY_FILE>"
    ),
    raw_path = c(
      "1.5_DUIO/raw/igme/",
      "metadata/raw/",
      "1.5_DUIO/raw/jmp/",
      "1.5_DUIO/raw/ilo/"
    ),
    normalized_path = c(
      "1.5_DUIO/<UNIGME_FILE>",
      "metadata/WDI_metadata_<END_DATE_PLUS_ONE>.csv",
      "1.5_DUIO/Safely_Managed_Water_data.csv",
      "1.5_DUIO/<ILO_MODELLED_FILE>|1.5_DUIO/<ILO_SURVEY_FILE>"
    ),
    availability_path = rep(NA, 4),
    expected_vintage_rule = c("manual_attestation", "end_date_plus_one", "release_identifier", "manual_attestation"),
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
      "5.2_DISM/<IMF_FILE>",
      "5.2_DISM/<IMF_FILE_2024>"
    ),
    raw_path = c("metadata/raw/", "5.2_DISM/raw/", "5.2_DISM/raw/"),
    normalized_path = c(
      "metadata/WDI_metadata_<END_DATE_PLUS_ONE>.csv",
      "5.2_DISM/<IMF_FILE>",
      "5.2_DISM/<IMF_FILE_2024>"
    ),
    availability_path = c(NA, NA, NA),
    expected_vintage_rule = c("end_date_plus_one", "manual_attestation", "manual_attestation"),
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
    analyst_action = "Run the D4.1 collection target and resolve manual-review, workbook (year text, coverage) or artifact validation failures; map unmatched catalogue names in config/d41_country_crosswalk.csv or record non-economies in config/d41_companion_exclusions.csv.",
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
    expected_vintage_rule = rep("manual_attestation", 9),
    age_warning_days = rep(365, 9),
    status_if_missing = rep("blocking", 9),
    analyst_action = c(
      rep("Update and validate the current 4.1 source workbook.", 8),
      "Complete country-economist review and save the current-vintage workbook."
    ),
    stringsAsFactors = FALSE
  )
)

# OECD SDG data blended into Pillar 3 (maximum of UN and OECD quality).
source_registry <- rbind(
  source_registry,
  data.frame(
    source_id = "d3_oecd_sdg",
    dimension_id = "3.1",
    source_type = "api",
    indicator_ids = "SPI.D3.*",
    source_url = "https://sdmx.oecd.org/public/rest/data/OECD.WISE.RSB,DSD_SDG@DF_SDG,1.0/all",
    input_path = "oecd_data/OECD_data_scored.csv",
    raw_path = "oecd_data/raw/",
    normalized_path = "oecd_data/OECD_data_scored.csv",
    availability_path = NA_character_,
    expected_vintage_rule = "release_identifier",
    age_warning_days = 365,
    status_if_missing = "blocking",
    analyst_action = "Run the OECD SDG collection target (oecd_collection).",
    stringsAsFactors = FALSE
  )
)

# D5.2 annual files built by the collection pipeline and their manual input.
source_registry <- rbind(
  source_registry,
  data.frame(
    source_id = c("d5_2_ilo_catalogue", "d5_2_empl"),
    dimension_id = c("5.2", "5.2"),
    source_type = c("manual", "external"),
    indicator_ids = c("SPI.D5.2.6.EMPL|SPI.D4.1.6.LABR", "SPI.D5.2.6.EMPL"),
    source_url = c("https://ilostat.ilo.org/data/national-sources-catalogue/", NA_character_),
    input_path = c("4.1_SOCS/ilo_sources_catalog.csv", "5.2_DISM/D5.2.6.EMPL.<END_DATE>.csv"),
    raw_path = c("4.1_SOCS/", "5.2_DISM/"),
    normalized_path = c("4.1_SOCS/ilo_sources_catalog.csv", "5.2_DISM/D5.2.6.EMPL.<END_DATE>.csv"),
    availability_path = c(NA_character_, NA_character_),
    expected_vintage_rule = c("manual_attestation", "end_date"),
    age_warning_days = c(365, 365),
    status_if_missing = c("blocking", "blocking"),
    analyst_action = c(
      "Download sources_en.csv from the ILOSTAT national sources catalogue, save it as 4.1_SOCS/ilo_sources_catalog.csv and attest it.",
      "Run the d5_2_empl collection target."
    ),
    stringsAsFactors = FALSE
  )
)

# CNIN and FINA: carried forward and reviewed per vintage (the review
# workbooks are created as blank templates by the collection run).
source_registry <- rbind(
  source_registry,
  data.frame(
    source_id = c("d5_2_cnin_review", "d5_2_fina_review", "d5_2_cnin", "d5_2_fina"),
    dimension_id = rep("5.2", 4),
    source_type = c("manual", "manual", "external", "external"),
    indicator_ids = c("SPI.D5.2.3.CNIN", "SPI.D5.2.8.FINA", "SPI.D5.2.3.CNIN", "SPI.D5.2.8.FINA"),
    source_url = rep(NA_character_, 4),
    input_path = c(
      "5.2_DISM/D5.2.3.CNIN.Manual.Review.<END_DATE>.xlsx",
      "5.2_DISM/D5.2.8.FINA.Manual.Review.<END_DATE>.xlsx",
      "5.2_DISM/D5.2.3.CNIN.<END_DATE>.csv",
      "5.2_DISM/D5.2.8.FINA.<END_DATE>.csv"
    ),
    raw_path = rep("5.2_DISM/", 4),
    normalized_path = c(
      "5.2_DISM/D5.2.3.CNIN.Manual.Review.<END_DATE>.xlsx",
      "5.2_DISM/D5.2.8.FINA.Manual.Review.<END_DATE>.xlsx",
      "5.2_DISM/D5.2.3.CNIN.<END_DATE>.csv",
      "5.2_DISM/D5.2.8.FINA.<END_DATE>.csv"
    ),
    availability_path = rep(NA_character_, 4),
    expected_vintage_rule = c("manual_attestation", "manual_attestation", "end_date", "end_date"),
    age_warning_days = rep(365, 4),
    status_if_missing = rep("blocking", 4),
    analyst_action = c(
      "Review the CNIN candidates in _collection/review_candidates_<end_date>.csv, record overrides with evidence in the workbook, then attest it.",
      "Review the FINA candidates in _collection/review_candidates_<end_date>.csv, record overrides with evidence in the workbook, then attest it.",
      "Run the d5_2_cnin collection target.",
      "Run the d5_2_fina collection target."
    ),
    stringsAsFactors = FALSE
  )
)

# GSBP (Steps 5-6 of the 2026-10-21 NADA/GSBP plan).
source_registry <- rbind(
  source_registry,
  data.frame(
    source_id = c("d5_2_10_gsbp", "d5_2_10_gsbp_desk_review", "d5_2_10_gsbp_review"),
    dimension_id = rep("5.2", 3),
    source_type = c("external", "manual", "manual"),
    indicator_ids = rep("SPI.D5.2.10.GSBP", 3),
    source_url = rep(NA_character_, 3),
    input_path = c(
      "5.2_DISM/D5.2.10.GSBP.<END_DATE>.csv",
      "5.2_DISM/raw/D1.12.MSC.csv",
      "5.2_DISM/D5.2.10.GSBP.Manual.Review.<END_DATE>.xlsx"
    ),
    raw_path = c("5.2_DISM/", "5.2_DISM/raw/", "5.2_DISM/"),
    normalized_path = c(
      "5.2_DISM/D5.2.10.GSBP.<END_DATE>.csv",
      "5.2_DISM/raw/D1.12.MSC.csv",
      "5.2_DISM/D5.2.10.GSBP.Manual.Review.<END_DATE>.xlsx"
    ),
    availability_path = rep(NA_character_, 3),
    expected_vintage_rule = c("end_date", "manual_attestation", "manual_attestation"),
    age_warning_days = c(365, 365, 365),
    status_if_missing = c("blocking", "warning", "blocking"),
    analyst_action = c(
      "Run the gsbp_output collection target.",
      "Refresh the GSBPM desk review (5.2_DISM/raw/D1.12.MSC.csv) or confirm the carry-forward, then attest it.",
      "Review the GSBP candidates and complete the current-vintage GSBP review workbook."
    ),
    stringsAsFactors = FALSE
  )
)

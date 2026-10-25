# =============================================================================
# D5.2 annual files: EMPL (5.2.6), CNIN (5.2.3) and FINA (5.2.8)
# =============================================================================
# Created: 2026-10-23
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "collection_provenance.R"))
source(file.path(here::here("R"), "collection_io.R"))
source(file.path(here::here("R"), "collection_cache.R"))
source(file.path(here::here("R"), "collection_attestation.R"))
source(file.path(here::here("R"), "collect_manual_review.R"))
source(file.path(here::here("R"), "collect_d5_2.R"))
source(file.path(here::here("R"), "dim5.R"))

repo_raw <- here::here("01_raw_data")

empl_reference <- function() {
  data.frame(
    ref_area = c("AAA", "BBB", "CCC"),
    ref_area.label = c("A land", "B land", "C land"),
    ref_area.sort = 1:3,
    stringsAsFactors = FALSE
  )
}

empl_catalogue <- function() {
  data.frame(
    `Source type` = c("Labour force survey", "Labour force survey", "Labour force survey", "Household income survey", "Labour force survey"),
    Country = c("A land", "B land", "B land", "C land", "Unknown land"),
    `International classifications` = c("ISCO-08; ICSE-93", "ISIC Rev.4", NA, "ICSE-18", "ICSE-93"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

empl_previous <- function() {
  data.frame(iso3c = c("AAA", "BBB", "CCC"), Country = c("A land", "B land", "C land"), ISCE = c(0, 1, 0))
}

# --- Step 12: EMPL -----------------------------------------------------------

test_that("EMPL keeps the higher of the previous flag and the ILO catalogue flag", {
  result <- build_empl_vintage(empl_previous(), empl_catalogue(), empl_reference())
  data <- result$data
  expect_equal(data$ISCE[data$iso3c == "AAA"], 1)
  expect_equal(data$ISCE[data$iso3c == "BBB"], 1)
  expect_equal(data$ISCE_catalogue[data$iso3c == "BBB"], 0)
  expect_equal(data$ISCE[data$iso3c == "CCC"], 0)
  expect_true(is.na(data$ISCE_catalogue[data$iso3c == "CCC"]))
  expect_false("EMPL" %in% names(data))
  expect_equal(result$unmatched, "Unknown land")
  expect_equal(result$changed, "AAA")
})

test_that("EMPL rebuilds the published 2024 file from the 2023 file and the 2024 catalogue", {
  skip_if_not(file.exists(file.path(repo_raw, "4.1_SOCS", "ilo_sources_catalog_2024.csv")))
  previous <- readr::read_csv(file.path(repo_raw, "5.2_DISM", "D5.2.6.EMPL.2023.csv"), show_col_types = FALSE)
  published <- readr::read_csv(file.path(repo_raw, "5.2_DISM", "D5.2.6.EMPL.2024.csv"), show_col_types = FALSE)
  result <- build_empl_vintage(
    previous,
    readr::read_csv(file.path(repo_raw, "4.1_SOCS", "ilo_sources_catalog_2024.csv"), show_col_types = FALSE),
    readr::read_csv(file.path(repo_raw, "metadata", "ILO_reference_area.csv"), show_col_types = FALSE)
  )
  joined <- merge(result$data, published[, c("iso3c", "ISCE")], by = "iso3c", suffixes = c(".new", ".published"))
  expect_equal(nrow(joined), 190)
  expect_equal(joined$ISCE.new, joined$ISCE.published)

  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "5.2_DISM"))
  file.copy(Sys.glob(file.path(repo_raw, "5.2_DISM", "D5.2.6.EMPL*.csv")), file.path(dir, "5.2_DISM"))
  original <- score_empl(list(raw_dir = repo_raw, end_date = 2024))
  readr::write_csv(result$data, file.path(dir, "5.2_DISM", "D5.2.6.EMPL.2024.csv"))
  rebuilt <- score_empl(list(raw_dir = dir, end_date = 2024))
  expect_equal(
    rebuilt[rebuilt$date == 2024, c("iso3c", "SPI.D5.2.6.EMPL")],
    original[original$date == 2024, c("iso3c", "SPI.D5.2.6.EMPL")]
  )
})

test_that("the EMPL collector writes only the current vintage", {
  dir <- withr::local_tempdir()
  for (sub in c("5.2_DISM", "4.1_SOCS", "metadata")) dir.create(file.path(dir, sub))
  readr::write_csv(empl_previous(), file.path(dir, "5.2_DISM", "D5.2.6.EMPL.2024.csv"))
  readr::write_csv(empl_catalogue(), file.path(dir, "4.1_SOCS", "ilo_sources_catalog.csv"))
  readr::write_csv(empl_reference(), file.path(dir, "metadata", "ILO_reference_area.csv"))

  expect_warning(
    result <- collect_empl_vintage(list(raw_dir = dir, end_date = 2025)),
    "without an ISO3 code were dropped"
  )
  expect_true(file.exists(file.path(dir, "5.2_DISM", "D5.2.6.EMPL.2025.csv")))
  expect_equal(result$unmatched, "Unknown land")
  expect_false("EMPL" %in% names(readr::read_csv(result$path, show_col_types = FALSE)))
  expect_false(is.null(read_artifact_provenance(result$path)))

  unlink(file.path(dir, "5.2_DISM", "D5.2.6.EMPL.2024.csv"))
  expect_error(collect_empl_vintage(list(raw_dir = dir, end_date = 2025)), "D5.2 PREVIOUS VINTAGE NOT FOUND")
})

# --- Step 13: CNIN and FINA ----------------------------------------------------

cnin_previous <- function() {
  data.frame(
    Code = c("AAA", "BBB", "CCC"), Country = c("A land", "B land", "C land"),
    `2020` = c("rev4", "rev3", NA), `2021` = c("rev4", "rev3", "na"), `2022` = c("rev4", "rev3", "na"),
    `2023` = c("rev4", "rev3", "na"), `2024` = c("rev4", "NACE REV2", "na"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
}

cnin_historical <- function() {
  data.frame(
    iso3c = c("AAA", "BBB", "CCC"), country = c("A land", "B land", "C land"),
    Evidence = c(NA, "Ministry note", "Historical review note"), `2023` = c(NA, "rev4", NA), `2024` = NA_character_,
    check.names = FALSE, stringsAsFactors = FALSE
  )
}

fina_previous <- function() {
  data.frame(Code = c("AAA", "BBB", "CCC", "DDD"), Country = c("A land", "B land", "C land", "D land"),
             FINA = c("2014", "2001", NA, "other"), stringsAsFactors = FALSE)
}

review_frame <- function(iso3c, value_column, values = NA_character_, evidence = NA_character_) {
  out <- data.frame(iso3c = iso3c, country = paste(iso3c, "land"), stringsAsFactors = FALSE)
  out[[value_column]] <- values
  out$Evidence <- evidence
  out
}

test_that("CNIN carries the previous year forward and applies the vintage review", {
  vocabulary <- cnin_vocabulary(cnin_previous(), cnin_historical())
  empty <- build_cnin_vintage(cnin_previous(), review_frame(c("AAA", "BBB", "CCC"), "CNIN"), 2025, vocabulary)
  expect_equal(empty$data[["2025"]], cnin_previous()[["2024"]])
  expect_equal(names(empty$data), c("Code", "Country", as.character(2020:2025)))
  expect_equal(nrow(empty$overrides), 0L)

  reviewed <- build_cnin_vintage(
    cnin_previous(),
    review_frame(c("AAA", "BBB", "CCC"), "CNIN", c(NA, NA, "rev4"), c(NA, NA, "NSO classification page")),
    2025, vocabulary
  )
  expect_equal(reviewed$data[["2025"]], c("rev4", "NACE REV2", "rev4"))
  expect_equal(reviewed$data[["2024"]], cnin_previous()[["2024"]])
  expect_equal(reviewed$overrides$iso3c, "CCC")

  expect_error(
    build_cnin_vintage(cnin_previous(), review_frame("AAA", "CNIN", "rev5", "x"), 2025, vocabulary),
    "INVALID VALUE"
  )
  expect_error(
    build_cnin_vintage(cnin_previous(), review_frame("ZZZ", "CNIN", "rev4", "x"), 2025, vocabulary),
    "UNKNOWN COUNTRY KEYS"
  )
})

test_that("CNIN carries a historical override of the previous year forward", {
  historical <- cnin_historical()
  historical$`2024` <- c(NA, NA, "rev4")
  built <- build_cnin_vintage(
    cnin_previous(), review_frame("AAA", "CNIN"), 2025,
    cnin_vocabulary(cnin_previous(), historical), historical
  )
  expect_equal(built$data[["2025"]], c("rev4", "NACE REV2", "rev4"))
  expect_equal(built$data[["2024"]], cnin_previous()[["2024"]])
  expect_equal(built$carried, "CCC")
})

test_that("CNIN historical review rejects overrides without evidence", {
  historical <- cnin_historical()
  historical$`2024`[[3]] <- "rev4"
  historical$Evidence[[3]] <- NA_character_
  expect_error(
    build_cnin_vintage(
      cnin_previous(),
      review_frame("AAA", "CNIN"),
      2025,
      cnin_vocabulary(cnin_previous(), historical),
      historical
    ),
    "REQUIRE EVIDENCE"
  )
})

test_that("FINA carries forward and accepts only documented review values", {
  empty <- build_fina_vintage(fina_previous(), review_frame(c("AAA", "BBB"), "FINA"))
  expect_equal(empty$data$FINA, fina_previous()$FINA)
  expect_equal(names(empty$data), c("Code", "Country", "FINA"))

  reviewed <- build_fina_vintage(fina_previous(), review_frame("BBB", "FINA", "2014", "GFS yearbook 2025"))
  expect_equal(reviewed$data$FINA[reviewed$data$Code == "BBB"], "2014")

  expect_error(build_fina_vintage(fina_previous(), review_frame("BBB", "FINA", "Not Found", "x")), "INVALID VALUE")
  expect_error(build_fina_vintage(fina_previous(), review_frame("BBB", "FINA", "2014", NA)), "REQUIRES EVIDENCE")
})

test_that("review candidates are deterministic", {
  cnin <- build_cnin_vintage(cnin_previous(), review_frame("AAA", "CNIN"), 2025, cnin_vocabulary(cnin_previous(), cnin_historical()))
  candidates <- cnin_candidates(cnin$data, 2025, cnin_historical())
  expect_equal(names(candidates), c("source_id", "iso3c", "country", "current_value", "reason", "evidence_hint"))
  expect_equal(candidates$iso3c, c("BBB", "CCC"))
  expect_match(candidates$reason[candidates$iso3c == "BBB"], "historical override")
  expect_match(candidates$reason[candidates$iso3c == "CCC"], "not Rev.4 or NACE Rev.2")

  previous_text <- data.frame(iso3c = c("AAA", "BBB", "CCC", "DDD"), common = c("x", "old", "y", "z"), all = c("x", "old", "y", "z"))
  current_text <- data.frame(iso3c = c("AAA", "BBB", "CCC", "DDD"), common = c("x", "new", "y", "z"), all = c("x", "new", "y GFSM 2014", "z"))
  fina <- fina_candidates(build_fina_vintage(fina_previous(), review_frame("AAA", "FINA"))$data, previous_text, current_text)
  expect_equal(fina$iso3c, c("BBB", "CCC", "DDD"))
  expect_match(fina$reason[fina$iso3c == "BBB"], "IMF GFS text changed")
  expect_match(fina$reason[fina$iso3c == "CCC"], "blank")
  expect_identical(fina, fina_candidates(build_fina_vintage(fina_previous(), review_frame("AAA", "FINA"))$data, previous_text, current_text))
})

test_that("review templates are created once and kept", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "5.2_DISM"))
  readr::write_csv(cnin_previous(), file.path(dir, "5.2_DISM", "D5.2.3.CNIN.2024.csv"), na = "")
  writexl::write_xlsx(cnin_historical(), file.path(dir, "5.2_DISM", "D5.2.3.CNIN.Manual.Review.xlsx"))
  params <- list(raw_dir = dir, end_date = 2025)

  first <- collect_cnin_vintage(params)
  template <- file.path(dir, "5.2_DISM", "D5.2.3.CNIN.Manual.Review.2025.xlsx")
  expect_true(file.exists(template))
  sheet <- readxl::read_xlsx(template)
  expect_equal(names(sheet), c("iso3c", "country", "CNIN", "Evidence"))
  expect_equal(sheet$iso3c, c("AAA", "BBB", "CCC"))
  expect_equal(readr::read_csv(first$path, show_col_types = FALSE)[["2025"]], c("rev4", "NACE REV2", "na"))

  sheet$CNIN[3] <- "rev4"
  sheet$Evidence[3] <- "NSO classification page"
  writexl::write_xlsx(sheet, template)
  second <- collect_cnin_vintage(params)
  expect_equal(readr::read_csv(second$path, show_col_types = FALSE)[["2025"]], c("rev4", "NACE REV2", "rev4"))
  expect_equal(readxl::read_xlsx(template)$CNIN[3], "rev4")
})

test_that("CNIN and FINA score for 2025 from the carried-forward repository files", {
  skip_if_not(file.exists(file.path(repo_raw, "5.2_DISM", "D5.2.3.CNIN.2024.csv")))
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "5.2_DISM"))
  file.copy(Sys.glob(file.path(repo_raw, "5.2_DISM", c("D5.2.3.CNIN*.csv", "D5.2.3.CNIN.Manual.Review.xlsx", "D5.2.8.FINA*.csv"))), file.path(dir, "5.2_DISM"))
  params <- list(raw_dir = dir, end_date = 2025)
  collect_cnin_vintage(params)
  collect_fina_vintage(params, imf_text = NULL)

  cnin <- score_cnin(params)
  expect_equal(
    cnin$SPI.D5.2.3.CNIN[cnin$date == 2025],
    cnin$SPI.D5.2.3.CNIN[cnin$date == 2024][match(cnin$iso3c[cnin$date == 2025], cnin$iso3c[cnin$date == 2024])]
  )
  fina <- score_fina(params)
  expect_gt(sum(fina$date == 2025), 0)
  expect_equal(
    fina$SPI.D5.2.8.FINA[fina$date == 2025],
    fina$SPI.D5.2.8.FINA[fina$date == 2024][match(fina$iso3c[fina$date == 2025], fina$iso3c[fina$date == 2024])]
  )
})

test_that("IMF GFS metadata text is read per ISO3 from the compiled workbook", {
  workbook <- file.path(repo_raw, "5.2_DISM", "2026.10_Compiled Data for World Bank - Sep 2026 - Final.xlsx")
  skip_if_not(file.exists(workbook))
  codes <- readr::read_csv(file.path(repo_raw, "metadata", "IMF_country_codes.csv"), show_col_types = FALSE)
  text <- read_imf_gfs_text(workbook, codes, common_columns = c("3.1", "3.2"))
  expect_equal(names(text), c("iso3c", "common", "all"))
  expect_false(anyDuplicated(text$iso3c) > 0)
  expect_true("AFG" %in% text$iso3c)
  expect_true(any(grepl("GFSM 2014", text$all)))
})

test_that("EMPL candidates list raised flags and unmapped catalogue countries", {
  result <- build_empl_vintage(empl_previous(), empl_catalogue(), empl_reference())
  candidates <- empl_candidates(result)
  expect_equal(names(candidates), c("source_id", "iso3c", "country", "current_value", "reason", "evidence_hint"))
  expect_equal(candidates$country, c("A land", "Unknown land"))
  expect_true(is.na(candidates$iso3c[candidates$country == "Unknown land"]))
})

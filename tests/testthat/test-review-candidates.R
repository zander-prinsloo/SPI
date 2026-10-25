# =============================================================================
# Review-candidate artifact
# =============================================================================
# Created: 2026-10-23
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "collection_report.R"))
source(file.path(here::here("R"), "review_candidates.R"))

candidate <- function(source_id, iso3c, reason) {
  data.frame(source_id = source_id, iso3c = iso3c, country = paste(iso3c, "land"), current_value = NA_character_,
             reason = reason, evidence_hint = "hint", stringsAsFactors = FALSE)
}

test_that("candidates are combined in a deterministic order", {
  a <- candidate(c("d5_2_fina", "d5_2_fina"), c("CCC", "AAA"), c("blank", "blank"))
  b <- candidate("d5_2_cnin", "BBB", "not Rev.4")
  path_one <- withr::local_tempfile(fileext = ".csv")
  path_two <- withr::local_tempfile(fileext = ".csv")
  assemble_review_candidates(list(a, NULL, b), path_one)
  assemble_review_candidates(list(b, a[2:1, ]), path_two)
  expect_identical(readLines(path_one), readLines(path_two))
  written <- readr::read_csv(path_one, show_col_types = FALSE)
  expect_equal(paste(written$source_id, written$iso3c), c("d5_2_cnin BBB", "d5_2_fina AAA", "d5_2_fina CCC"))
})

test_that("no candidates still writes the header", {
  path <- withr::local_tempfile(fileext = ".csv")
  assemble_review_candidates(list(NULL), path)
  expect_equal(readLines(path), "source_id,iso3c,country,current_value,reason,evidence_hint")
})

test_that("a candidate frame with the wrong columns stops", {
  path <- withr::local_tempfile(fileext = ".csv")
  expect_error(assemble_review_candidates(list(data.frame(iso3c = "AAA")), path), "REVIEW CANDIDATES SCHEMA MISMATCH")
})

test_that("a changed candidate list archives the previous list and logs the change", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "review_candidates_2025.csv")
  first <- list(candidate(c("d5_2_fina", "d5_2_fina"), c("AAA", "BBB"), "blank"), candidate("d5_2_cnin", "CCC", "not Rev.4"))
  assemble_review_candidates(first, path)
  first_hash <- digest::digest(path, algo = "sha256", file = TRUE)
  first_lines <- readLines(path)

  second <- list(candidate("d5_2_fina", "AAA", "blank"), candidate("d5_2_cnin", c("CCC", "DDD"), "not Rev.4"))
  assemble_review_candidates(second, path)

  history <- file.path(dir, "review_candidates_history")
  archived <- list.files(history, pattern = "^review_candidates_2025[.].*[.]csv$", full.names = TRUE)
  archived <- archived[!grepl("_changes[.]csv$", archived)]
  expect_length(archived, 1L)
  expect_match(basename(archived), paste0("[.]", substr(first_hash, 1, 8), "[.]csv$"))
  expect_identical(readLines(archived), first_lines)

  changes <- utils::read.csv(file.path(history, "review_candidates_2025_changes.csv"), colClasses = "character")
  expect_setequal(changes$source_id, c("d5_2_cnin", "d5_2_fina"))
  expect_identical(changes$added[changes$source_id == "d5_2_cnin"], "1")
  expect_identical(changes$removed[changes$source_id == "d5_2_fina"], "1")
  expect_true(all(changes$previous_sha256 == first_hash))
  expect_true(all(changes$current_sha256 == digest::digest(path, algo = "sha256", file = TRUE)))
  expect_true(all(changes$archived_as == basename(archived)))
})

test_that("an unchanged candidate list is not archived again", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "review_candidates_2025.csv")
  candidates <- list(candidate("d5_2_fina", "AAA", "blank"))
  assemble_review_candidates(candidates, path)
  assemble_review_candidates(candidates, path)
  expect_false(dir.exists(file.path(dir, "review_candidates_history")))
})

test_that("a list that is already archived is not archived twice", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "review_candidates_2025.csv")
  assemble_review_candidates(list(candidate("d5_2_fina", "AAA", "blank")), path)
  hash <- digest::digest(path, algo = "sha256", file = TRUE)
  history <- file.path(dir, "review_candidates_history")
  dir.create(history)
  file.copy(path, file.path(history, sprintf("review_candidates_2025.20261024T003052Z.%s.csv", substr(hash, 1, 8))))
  assemble_review_candidates(list(candidate("d5_2_fina", "BBB", "blank")), path)
  archived <- list.files(history, pattern = "^review_candidates_2025[.][0-9T]+Z[.]")
  expect_identical(archived, sprintf("review_candidates_2025.20261024T003052Z.%s.csv", substr(hash, 1, 8)))
  changes <- utils::read.csv(file.path(history, "review_candidates_2025_changes.csv"), colClasses = "character")
  expect_identical(unique(changes$archived_as), archived)
})

test_that("the status report summarises candidates without blocking", {
  status <- data.frame(source_id = "x", dimension_id = "1.5", source_type = "api", status = "informational",
                       reason = "artifact_present", analyst_action = "None", stringsAsFactors = FALSE)
  dir <- withr::local_tempdir()
  candidates <- rbind(candidate(c("d5_2_cnin", "d5_2_cnin"), c("AAA", "BBB"), "not Rev.4"), candidate("d5_2_fina", "CCC", "blank"))
  write_collection_status_report(status, file.path(dir, "s.csv"), file.path(dir, "s.md"), candidates = candidates)
  md <- paste(readLines(file.path(dir, "s.md")), collapse = "\n")
  expect_match(md, "## Review candidates")
  expect_match(md, "| d5_2_cnin | not Rev.4 | 2 |", fixed = TRUE)
  expect_equal(readr::read_csv(file.path(dir, "s.csv"), show_col_types = FALSE)$status, "informational")
})

# =============================================================================
# D4.1 economist-review candidates (202611 plan, Step 18)
# =============================================================================

source(file.path(here::here("R"), "collect_dim4_1.R"))
source(file.path(here::here("R"), "dim4.R"))

d41_stems <- c(
  D4.1.1.CEN.POPU = "POP.CENSUS", D4.1.2.CEN.AGRI = "AGRI.CENSUS",
  D4.1.3.CEN.BIZZ = "BIZZ.CENSUS", D4.1.4.SVY.HOUS = "HOUS.SURVEYS",
  D4.1.5.SVY.AGRI = "AGRI.SURVEYS", D4.1.6.SVY.LABR = "LABR.SURVEYS",
  D4.1.7.SVY.HLTH = "HLTH.SURVEYS", D4.1.8.SVY.BIZZ = "BIZZ.SURVEYS"
)

# Raw-data root for 2025 with workbook values, catalogue years and review
# values per stem; stems not given hold `filler` with recent years.
make_d41_candidate_root <- function(workbook = list(), catalogue = list(), review = list(),
                                    filler = c("AAA", "BBB", "CCC", "DDD", "EEE")) {
  raw <- withr::local_tempdir(.local_envir = parent.frame())
  dir.create(file.path(raw, "4.1_SOCS", "raw"), recursive = TRUE)
  dir.create(file.path(raw, "4.1_SOCS", "collection"), recursive = TRUE)
  review_frame <- tibble::tibble(iso3c = filler, country = filler)
  for (stem in names(d41_stems)) {
    column <- d41_stems[[stem]]
    values <- workbook[[stem]]
    if (is.null(values)) values <- stats::setNames(rep("2018, 2020, 2022", length(filler)), filler)
    derived <- tibble::tibble(iso3c = names(values), country = paste(names(values), "land"), date = 2025)
    derived[[column]] <- unname(values)
    readr::write_csv(derived, file.path(raw, "4.1_SOCS", "raw", sprintf("%s.2025.csv", stem)), na = "")
    years <- catalogue[[stem]]
    companion <- if (is.null(years)) {
      tibble::tibble(iso3c = character(), country = character(), indicator_date = numeric(),
                     nada_dates = character(), nada_title = character())
    } else {
      tibble::tibble(iso3c = years$iso3c, country = years$iso3c, indicator_date = years$year,
                     nada_dates = as.character(years$year), nada_title = "Catalogue study")
    }
    readr::write_csv(companion, file.path(raw, "4.1_SOCS", "collection", paste0(stem, "_NADA.iso3c.csv")), na = "")
    reviewed <- review[[stem]]
    review_frame[[column]] <- if (is.null(reviewed)) NA_character_ else unname(reviewed[review_frame$iso3c])
  }
  review_frame$Evidence <- NA_character_
  writexl::write_xlsx(review_frame, file.path(raw, "4.1_SOCS", "raw", "D4.1.Manual.Review.2025.xlsx"))
  list(raw_dir = raw, end_date = 2025)
}

candidates_for <- function(result, stem) {
  result[result$source_id == stem, , drop = FALSE]
}

test_that("census candidates follow the 10-year full-score window", {
  params <- make_d41_candidate_root(workbook = list(
    D4.1.1.CEN.POPU = c(AAA = "2015", BBB = "2014", CCC = "Register based census", DDD = NA, EEE = "2005, 2014")
  ))
  result <- d41_review_candidates(params)
  popu <- candidates_for(result, "D4.1.1.CEN.POPU")
  expect_setequal(popu$iso3c, c("BBB", "DDD", "EEE"))
  expect_match(popu$reason[popu$iso3c == "BBB"], "latest census 2014 is more than 10 years before 2025")
  expect_match(popu$reason[popu$iso3c == "DDD"], "no census recorded")
  expect_identical(popu$current_value[popu$iso3c == "EEE"], "2005, 2014")
  expect_true(all(c("source_id", "iso3c", "country", "current_value", "reason", "evidence_hint") %in% names(result)))
})

test_that("survey candidates follow the 12-year window and count all evidence", {
  params <- make_d41_candidate_root(
    workbook = list(D4.1.4.SVY.HOUS = c(AAA = "2013", BBB = "2012", CCC = NA, DDD = NA, EEE = NA)),
    catalogue = list(D4.1.4.SVY.HOUS = data.frame(iso3c = "CCC", year = 2016)),
    review = list(D4.1.4.SVY.HOUS = c(DDD = "2014"))
  )
  result <- d41_review_candidates(params)
  hous <- candidates_for(result, "D4.1.4.SVY.HOUS")
  hous <- hous[!grepl("catalogue evidence", hous$reason), , drop = FALSE]
  expect_setequal(hous$iso3c, c("BBB", "EEE"))
  expect_match(hous$reason[hous$iso3c == "BBB"], "latest survey 2012 is outside the 12-year window for 2025")
  expect_match(hous$reason[hous$iso3c == "EEE"], "no survey recorded")
})

test_that("catalogue evidence that changes the score is listed", {
  params <- make_d41_candidate_root(
    workbook = list(D4.1.7.SVY.HLTH = c(AAA = "2016, 2020", BBB = "2010", CCC = "2019", DDD = NA, EEE = "2016, 2020")),
    catalogue = list(D4.1.7.SVY.HLTH = data.frame(
      iso3c = c("AAA", "AAA", "BBB", "DDD", "EEE", "EEE", "EEE"),
      year = c(2016, 2018, 2005, 2019, 2016, 2020, 2001)
    ))
  )
  result <- d41_review_candidates(params)
  hlth <- candidates_for(result, "D4.1.7.SVY.HLTH")
  changed <- hlth[grepl("catalogue evidence", hlth$reason), , drop = FALSE]
  expect_setequal(changed$iso3c, c("AAA", "DDD"))
  expect_match(
    changed$reason[changed$iso3c == "AAA"],
    "catalogue evidence changes the 2025 score from 0.67 to 1; catalogue-only years in the window: 2018"
  )
  expect_match(changed$reason[changed$iso3c == "DDD"], "from 0 to 0.33")
})

test_that("catalogue census evidence is scored with the census windows", {
  params <- make_d41_candidate_root(
    workbook = list(D4.1.1.CEN.POPU = c(AAA = "2008", BBB = "Register based census", CCC = "2020", DDD = "2001", EEE = "2020")),
    catalogue = list(D4.1.1.CEN.POPU = data.frame(
      iso3c = c("AAA", "BBB", "CCC", "DDD"),
      year = c(2016, 2016, 2010, 2006)
    ))
  )
  popu <- candidates_for(d41_review_candidates(params), "D4.1.1.CEN.POPU")
  changed <- popu[grepl("catalogue evidence", popu$reason), , drop = FALSE]
  expect_identical(changed$iso3c, c("AAA", "DDD"))
  expect_match(changed$reason[changed$iso3c == "AAA"], "from 0.5 to 1")
  expect_match(changed$reason[changed$iso3c == "DDD"], "from 0 to 0.5")
})

test_that("D4.1 candidates appear in the shared review-candidate artifact", {
  params <- make_d41_candidate_root(workbook = list(
    D4.1.2.CEN.AGRI = c(AAA = "2001", BBB = "2019", CCC = "2019", DDD = "2019", EEE = "2019")
  ))
  path <- withr::local_tempfile(fileext = ".csv")
  assemble_review_candidates(list(NULL, d41_review_candidates(params)), path)
  written <- readr::read_csv(path, show_col_types = FALSE)
  expect_true(any(written$source_id == "D4.1.2.CEN.AGRI" & written$iso3c == "AAA"))
})

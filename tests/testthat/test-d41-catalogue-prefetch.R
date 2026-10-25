# =============================================================================
# D4.1 catalogue prefetch: concurrent, cached, fail-loud fetching of the URLs
# requested by the legacy microdata_library_pull.Rmd. No network: every test
# uses an injected fetcher.
# =============================================================================
# Created: 2026-10-24
# =============================================================================

library(testthat)

source(file.path(here::here("R"), "collect_dim4_1.R"))
prefetch_path <- file.path(here::here("R"), "collect_dim4_1_prefetch.R")
if (file.exists(prefetch_path)) {
  source(prefetch_path)
}

# A fake catalogue answering the legacy URLs. `script` holds per-URL response
# sequences that are consumed before the steady-state `responses`.
fake_catalogue <- function(internal = c("AAA_2019_LSMS_v01_M", "BBB_2020_DHS_v01_M"),
                           fao = c(11, 12), public = c("PUB_1", "PUB_2"),
                           found_extra = 0L) {
  sources <- dim4_1_catalogue_sources()
  search_body <- function(rows) {
    charToRaw(jsonlite::toJSON(
      list(result = list(found = nrow(rows) + found_extra, total = nrow(rows), rows = rows)),
      auto_unbox = TRUE,
      dataframe = "rows"
    ))
  }
  env <- new.env()
  env$sources <- sources
  env$internal_url <- function(id) paste0(sources$internal$detail_prefix, id)
  env$fao_url <- function(id) paste0(sources$fao$detail_prefix, id, sources$fao$detail_suffix)
  responses <- list()
  responses[[sources$internal$search_url]] <- list(status = 200L, body = search_body(
    data.frame(idno = internal, title = paste("Study", internal), nation = "Aland", year_start = 2019)
  ))
  responses[[sources$fao$search_url]] <- list(status = 200L, body = search_body(
    data.frame(id = fao, title = paste("FAO study", fao), created = "2020/01/01 00:00:00")
  ))
  responses[[sources$public$search_url]] <- list(status = 200L, body = search_body(
    data.frame(idno = public, title = paste("Public", public))
  ))
  for (id in internal) {
    responses[[env$internal_url(id)]] <- list(status = 200L, body = charToRaw(sprintf(
      '{"status":"success","dataset":{"idno":"%s","metadata":{"study_desc":{"series_statement":{"series_name":"Series %s [hh/lsms]"},"study_info":{"geog_coverage":"National"}}}}}',
      id, id
    )))
  }
  for (id in fao) {
    responses[[env$fao_url(id)]] <- list(status = 200L, body = charToRaw(sprintf(
      '{"study_desc":{"series_statement":{"series_name":"Agricultural Census [ag/census] %s"},"study_info":{"geog_coverage":"National"}}}',
      id
    )))
  }
  env$responses <- responses
  env$script <- list()
  env$calls <- character()
  env$fetch <- function(urls) {
    env$calls <- c(env$calls, urls)
    out <- lapply(urls, function(url) {
      if (length(env$script[[url]]) > 0L) {
        response <- env$script[[url]][[1]]
        env$script[[url]] <- env$script[[url]][-1]
        return(response)
      }
      response <- env$responses[[url]]
      if (is.null(response)) list(status = 404L, body = charToRaw("<html>404 Page Not Found</html>")) else response
    })
    list(
      url = urls,
      status_code = vapply(out, function(r) if (is.null(r$status)) NA_integer_ else as.integer(r$status), integer(1)),
      error = vapply(out, function(r) if (is.null(r$error)) NA_character_ else r$error, character(1)),
      body = lapply(out, function(r) if (is.null(r$body)) raw() else r$body)
    )
  }
  env
}

new_cache <- function() {
  raw_root <- withr::local_tempdir(.local_envir = parent.frame())
  dim4_1_catalogue_cache_paths(raw_root)
}

read_index <- function(cache) {
  utils::read.csv(cache$index, colClasses = "character", na.strings = "")
}

run_prefetch <- function(cache, fake, ...) {
  dim4_1_catalogue_prefetch(cache, fetcher = fake$fetch, retry_wait_seconds = 0, progress = FALSE, ...)
}

test_that("the prefetch requests every search and detail URL once and records each response", {
  cache <- new_cache()
  fake <- fake_catalogue()
  summary <- run_prefetch(cache, fake)

  expected <- c(
    fake$sources$internal$search_url, fake$sources$fao$search_url, fake$sources$public$search_url,
    fake$internal_url(c("AAA_2019_LSMS_v01_M", "BBB_2020_DHS_v01_M")),
    "https://microdata.fao.org/index.php/metadata/export/11/json",
    "https://microdata.fao.org/index.php/metadata/export/12/json"
  )
  expect_setequal(fake$calls, expected)
  expect_identical(anyDuplicated(fake$calls), 0L)

  index <- read_index(cache)
  expect_setequal(index$url, expected)
  expect_true(all(index$status == "ok"))
  row <- index[index$url == fake$internal_url("AAA_2019_LSMS_v01_M"), ]
  body <- fake$responses[[row$url]]$body
  expect_identical(row$sha256, digest::digest(body, algo = "sha256", serialize = FALSE))
  expect_identical(dim4_1_read_cached_body(file.path(cache$bodies, row$body_file)), body)

  expect_identical(summary$failed, 0L)
  expect_identical(summary$sources$internal$found, 2L)
  expect_identical(summary$sources$internal$ok, 2L)
  expect_identical(summary$sources$fao$ok, 2L)
  expect_identical(summary$sources$public$found, 2L)
  expect_identical(summary$fetched, 7L)
  expect_identical(nrow(utils::read.csv(cache$failures)), 0L)
})

test_that("a catalogue search that returns fewer rows than it found stops the refresh", {
  cache <- new_cache()
  fake <- fake_catalogue(found_extra = 1L)
  expect_error(
    run_prefetch(cache, fake),
    "D4.1 CATALOGUE SEARCH INCOMPLETE.*found 3.*returned 2"
  )
})

test_that("an empty answer from a search that feeds no companion is documented, not blocking", {
  cache <- new_cache()
  fake <- fake_catalogue()
  # The public library answers page sizes above its cap with an empty success.
  fake$responses[[fake$sources$public$search_url]] <- list(
    status = 200L,
    body = charToRaw('{"status":"success","found":0,"rows":[]}')
  )
  fake$responses[[fake$sources$public$probe_url]] <- list(
    status = 200L,
    body = charToRaw('{"status":"success","result":{"found":7141,"total":7141,"rows":[{"idno":"PUB_1"}]}}')
  )
  summary <- run_prefetch(cache, fake)
  expect_identical(summary$failed, 0L)
  expect_identical(summary$sources$public$returned, 0L)
  expect_identical(summary$sources$public$probe_found, 7141L)
  failures <- utils::read.csv(cache$failures, colClasses = "character")
  expect_identical(failures$url, fake$sources$public$search_url)
  expect_identical(failures$blocking, "FALSE")
  expect_match(failures$message, "returned 0 rows.*7141.*does not feed the D4.1 companions")
  expect_length(summary$anomalies, 1L)

  # The same answer from a search that feeds the companions stops the refresh.
  fake$responses[[fake$sources$internal$search_url]] <- list(
    status = 200L,
    body = charToRaw('{"status":"success","found":0,"rows":[]}')
  )
  expect_error(run_prefetch(cache, fake, max_age_days = -1), "D4.1 CATALOGUE SEARCH INCOMPLETE.*microdatalib")
})

test_that("transient failures are retried and persistent failures stop with a documented log", {
  cache <- new_cache()
  fake <- fake_catalogue()
  transient <- fake$internal_url("AAA_2019_LSMS_v01_M")
  persistent <- "https://microdata.fao.org/index.php/metadata/export/12/json"
  fake$script[[transient]] <- list(list(status = NA, body = raw(), error = "Timeout was reached"))
  fake$responses[[persistent]] <- list(status = 503L, body = charToRaw("Service Unavailable"))

  expect_error(
    run_prefetch(cache, fake, max_attempts = 3L),
    "D4.1 CATALOGUE PREFETCH FAILED: 1 request.*catalogue_fetch_failures.csv"
  )
  expect_identical(sum(fake$calls == persistent), 3L)
  failures <- utils::read.csv(cache$failures, colClasses = "character")
  expect_identical(failures$url, persistent)
  expect_identical(failures$attempts, "3")
  expect_match(failures$message, "HTTP 503")

  index <- read_index(cache)
  recovered <- index[index$url == transient, ]
  expect_identical(recovered$status, "ok")
  expect_identical(recovered$attempts, "2")
  expect_match(recovered$message, "Timeout was reached")

  # A rerun retries only the failed request; everything else comes from the cache.
  fake$responses[[persistent]] <- list(status = 200L, body = charToRaw('{"study_desc":{}}'))
  fake$calls <- character()
  summary <- run_prefetch(cache, fake, max_attempts = 3L)
  expect_identical(fake$calls, persistent)
  expect_identical(summary$failed, 0L)
  expect_identical(summary$fetched, 1L)
  expect_identical(nrow(utils::read.csv(cache$failures)), 0L)
})

test_that("studies the catalogue cannot find are confirmed, listed and not blocking", {
  cache <- new_cache()
  fake <- fake_catalogue()
  internal_missing <- fake$internal_url("BBB_2020_DHS_v01_M")
  fao_missing <- "https://microdata.fao.org/index.php/metadata/export/12/json"
  fake$responses[[internal_missing]] <- list(
    status = 400L,
    body = charToRaw('{"status":"failed","message":"IDNO-NOT-FOUND"}')
  )
  fake$responses[[fao_missing]] <- NULL

  summary <- run_prefetch(cache, fake)
  index <- read_index(cache)
  expect_identical(index$status[index$url == internal_missing], "not_found")
  expect_identical(index$status[index$url == fao_missing], "not_found")
  expect_identical(sum(fake$calls == internal_missing), 2L)
  expect_identical(sum(fake$calls == fao_missing), 2L)
  expect_identical(summary$not_found, 2L)
  expect_identical(summary$failed, 0L)
})

test_that("a successful response that is not JSON is a failure, not data", {
  cache <- new_cache()
  fake <- fake_catalogue()
  login <- fake$internal_url("AAA_2019_LSMS_v01_M")
  fake$responses[[login]] <- list(status = 200L, body = charToRaw("<html>Sign in</html>"))
  expect_error(run_prefetch(cache, fake, max_attempts = 2L), "D4.1 CATALOGUE PREFETCH FAILED: 1 request")
  failures <- utils::read.csv(cache$failures, colClasses = "character")
  expect_match(failures$message, "not JSON")
})

test_that("cached responses older than the maximum age are fetched again", {
  cache <- new_cache()
  fake <- fake_catalogue()
  run_prefetch(cache, fake)
  index <- read_index(cache)
  stale <- fake$internal_url("AAA_2019_LSMS_v01_M")
  index$fetched_at[index$url == stale] <- format(Sys.time() - 30 * 86400, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  utils::write.csv(index, cache$index, row.names = FALSE, na = "")
  fake$calls <- character()
  summary <- run_prefetch(cache, fake, max_age_days = 7)
  expect_identical(fake$calls, stale)
  expect_identical(summary$fetched, 1L)
})

test_that("the cached fromJSON serves cached responses and reproduces legacy failures", {
  cache <- new_cache()
  fake <- fake_catalogue()
  missing <- fake$internal_url("BBB_2020_DHS_v01_M")
  fake$responses[[missing]] <- list(status = 400L, body = charToRaw('{"status":"failed","message":"IDNO-NOT-FOUND"}'))
  run_prefetch(cache, fake)
  offline <- function(txt, ...) stop("offline: ", txt, call. = FALSE)
  cached <- dim4_1_cached_fromjson(cache$index, cache$bodies, fallback = offline)

  found <- fake$internal_url("AAA_2019_LSMS_v01_M")
  expect_identical(cached(found), jsonlite::fromJSON(rawToChar(fake$responses[[found]]$body)))
  expect_identical(
    cached(fake$sources$internal$search_url)$result$rows$idno,
    c("AAA_2019_LSMS_v01_M", "BBB_2020_DHS_v01_M")
  )
  expect_error(cached(missing), "cannot open the connection")
  expect_identical(purrr::possibly(cached, otherwise = "legacy blank")(missing), "legacy blank")
  expect_identical(cached('{"a":1}'), list(a = 1L))

  expect_error(cached("https://example.org/not-cached"), "offline")
  log <- attr(cached, "log")
  expect_identical(log$served[["ok"]], 2L)
  expect_identical(log$served[["not_found"]], 2L)
  expect_identical(log$passthrough, "https://example.org/not-cached")
  expect_identical(log$passthrough_failures$url, "https://example.org/not-cached")
})

test_that("tampered cached bodies are rejected and refetched", {
  cache <- new_cache()
  fake <- fake_catalogue()
  run_prefetch(cache, fake)
  index <- read_index(cache)
  row <- index[index$status == "ok" & index$kind == "detail", , drop = FALSE][1L, , drop = FALSE]
  body_path <- file.path(cache$bodies, row$body_file)
  .d41_write_cached_body(charToRaw("{\"tampered\":true}"), body_path)

  cached <- dim4_1_cached_fromjson(cache$index, cache$bodies, fallback = function(...) {
    stop("unexpected passthrough")
  })
  expect_error(cached(row$url), "CACHE BODY HASH MISMATCH")

  calls_before <- length(fake$calls)
  run_prefetch(cache, fake)
  expect_gt(length(fake$calls), calls_before)
  repaired <- dim4_1_read_cached_body(body_path)
  expect_identical(digest::digest(repaired, algo = "sha256", serialize = FALSE), row$sha256)
})

adapter_params <- function(raw_root) {
  list(raw_dir = raw_root, end_date = 2024, d41_catalogue_budget_minutes = 5)
}

new_staging <- function() {
  root <- withr::local_tempdir(.local_envir = parent.frame())
  staging <- file.path(root, "staging", "01_raw_data", "4.1_SOCS")
  dir.create(staging, recursive = TRUE)
  staging
}

legacy_like_code <- c(
  "library(jsonlite)",
  "base_url <- 'http://microdatalib.worldbank.org/index.php/api/catalog'",
  "ids <- fromJSON(paste(base_url, '/search', '?ps=20000', sep = ''))$result$rows$idno",
  "info <- function(id) fromJSON(paste('http://microdatalib.worldbank.org/index.php/api/catalog/', id, sep = ''))$dataset$metadata$study_desc$series_statement$series_name",
  "series <- purrr::map_chr(ids, purrr::possibly(info, otherwise = NA_character_))",
  "writeLines(ifelse(is.na(series), 'blank', series), paste(here(), '01_raw_data', '4.1_SOCS', 'series.txt', sep = '/'))"
)

test_that("the adapter serves the cached catalogue to the unmodified script code", {
  raw_root <- withr::local_tempdir()
  staging <- new_staging()
  fake <- fake_catalogue()
  missing <- fake$internal_url("BBB_2020_DHS_v01_M")
  fake$responses[[missing]] <- list(status = 400L, body = charToRaw('{"status":"failed","message":"IDNO-NOT-FOUND"}'))

  result <- dim4_1_legacy_catalogue_adapter(
    adapter_params(raw_root), staging, legacy_like_code,
    budget_seconds = 300, fetcher = fake$fetch, retry_wait_seconds = 0,
    passthrough = function(txt, ...) stop("offline: ", txt, call. = FALSE)
  )
  expect_identical(
    readLines(file.path(staging, "series.txt")),
    c("Series AAA_2019_LSMS_v01_M [hh/lsms]", "blank")
  )
  expect_identical(result$legacy_requests$served_ok, 2L)
  expect_identical(result$legacy_requests$served_not_found, 1L)
  expect_length(result$legacy_requests$passthrough, 0L)
  expect_identical(result$prefetch$not_found, 1L)
})

test_that("a failed request outside the cache stops the refresh even inside possibly()", {
  raw_root <- withr::local_tempdir()
  staging <- new_staging()
  fake <- fake_catalogue()
  code <- c(
    legacy_like_code,
    "extra <- purrr::possibly(fromJSON, otherwise = NULL)('https://example.org/not-cached')"
  )
  expect_error(
    dim4_1_legacy_catalogue_adapter(
      adapter_params(raw_root), staging, code,
      budget_seconds = 300, fetcher = fake$fetch, retry_wait_seconds = 0,
      passthrough = function(txt, ...) stop("offline: ", txt, call. = FALSE)
    ),
    "D4.1 CATALOGUE REQUEST FAILED OUTSIDE THE CACHE.*example.org/not-cached"
  )
  failures <- utils::read.csv(dim4_1_catalogue_cache_paths(raw_root)$failures, colClasses = "character")
  expect_identical(failures$url, "https://example.org/not-cached")
  expect_identical(failures$source, "legacy_passthrough")
})

test_that("the prefetch matches the URLs the legacy script builds", {
  code <- dim4_1_legacy_catalogue_code(dim4_1_catalogue_script_path())
  expect_silent(dim4_1_check_catalogue_sources(code))
  changed <- gsub("microdatalib.worldbank.org", "microdatalib2.worldbank.org", code, fixed = TRUE)
  expect_error(dim4_1_check_catalogue_sources(changed), "LEGACY CATALOGUE SCRIPT NO LONGER MATCHES")
  changed <- gsub("?ps=20000", "?ps=500", code, fixed = TRUE)
  expect_error(dim4_1_check_catalogue_sources(changed), "LEGACY CATALOGUE SCRIPT NO LONGER MATCHES")
})

test_that("the curl fetcher keeps no more requests in flight than connections", {
  # libcurl starts a request's connect timer when the request joins the pool,
  # so queuing a whole batch behind a few connections times requests out.
  in_flight <- 0L
  max_in_flight <- 0L
  queue <- list()
  local_mocked_bindings(
    new_pool = function(...) "pool",
    new_handle = function(...) list(),
    handle_setheaders = function(handle, ...) handle,
    curl_fetch_multi = function(url, done, fail, pool, handle) {
      in_flight <<- in_flight + 1L
      max_in_flight <<- max(max_in_flight, in_flight)
      queue[[length(queue) + 1L]] <<- list(url = url, done = done, fail = fail)
      invisible(NULL)
    },
    multi_run = function(...) {
      while (length(queue) > 0L) {
        item <- queue[[1]]
        queue <<- queue[-1]
        in_flight <<- in_flight - 1L
        if (grepl("/13$", item$url)) {
          item$fail("Timeout was reached")
        } else {
          item$done(list(status_code = 200L, content = charToRaw(sprintf('{"url":"%s"}', item$url))))
        }
      }
      invisible(NULL)
    },
    .package = "curl"
  )
  urls <- sprintf("https://example.org/%d", 1:50)
  result <- dim4_1_catalogue_curl_fetcher(connections = 4L)(urls)
  expect_identical(result$url, urls)
  expect_lte(max_in_flight, 4L)
  expect_identical(sum(result$status_code == 200L, na.rm = TRUE), 49L)
  expect_identical(result$error[[13]], "Timeout was reached")
  expect_identical(rawToChar(result$body[[50]]), '{"url":"https://example.org/50"}')
})

# --- Retired catalogue sources ------------------------------------------------

retired_snapshot <- function(n) {
  path <- withr::local_tempfile(.local_envir = parent.frame(), fileext = ".csv")
  readr::write_excel_csv(
    data.frame(id = seq_len(n), idno = sprintf("ILO_%03d", seq_len(n)), title = "LFS", nation = "Aland",
               year_start = 2000L + (seq_len(n) %% 20L)),
    path
  )
  path
}
ilo_source <- function(snapshot) {
  source <- dim4_1_retired_sources(tempdir())$ilo_survey_catalog
  source$snapshot <- snapshot
  source
}
ilo_page_url <- function(page) {
  sprintf("https://www.ilo.org/surveyLib/index.php/catalog/export/csv?page=%d&ps=100&collection[]=LFS", page)
}
notice <- function(urls) {
  list(url = urls, status_code = 200L, error = NA_character_,
       body = list(charToRaw("<html><title>410 Gone | ILO Survey Catalog Retired</title></html>")))
}

test_that("a retired catalogue is replayed page by page from its final snapshot", {
  replay <- dim4_1_snapshot_download_file(
    list(ilo_survey_catalog = ilo_source(retired_snapshot(250L))),
    fallback = function(url, destfile, ...) stop("offline: ", url, call. = FALSE)
  )
  pages <- list()
  rows <- 100L
  while (rows == 100L) {
    destination <- tempfile(fileext = ".csv")
    replay(ilo_page_url(length(pages) + 1L), destination)
    pages[[length(pages) + 1L]] <- readr::read_csv(destination, show_col_types = FALSE)
    rows <- nrow(pages[[length(pages)]])
  }
  expect_identical(vapply(pages, nrow, integer(1)), c(100L, 100L, 50L))
  expect_identical(dplyr::bind_rows(pages)$idno, sprintf("ILO_%03d", 1:250))
  expect_error(replay("https://example.org/other.csv", tempfile()), "offline")
  log <- attr(replay, "log")
  expect_identical(log$served, 3L)
  expect_identical(log$passthrough, "https://example.org/other.csv")
  expect_identical(log$passthrough_failures$url, "https://example.org/other.csv")
})

test_that("a retired source is replayed only while its endpoint shows the retirement notice", {
  source <- ilo_source(retired_snapshot(10L))
  checked <- dim4_1_check_retired_source(source, notice)
  expect_identical(checked$status, "retired")
  expect_identical(checked$snapshot_rows, 10L)
  revived <- function(urls) {
    list(url = urls, status_code = 200L, error = NA_character_,
         body = list(charToRaw("id,idno,title,nation\n1,X,LFS,Aland\n")))
  }
  expect_error(dim4_1_check_retired_source(source, revived), "AVAILABLE AGAIN")
  broken <- function(urls) {
    list(url = urls, status_code = NA_integer_, error = "Could not resolve host", body = list(raw()))
  }
  expect_error(dim4_1_check_retired_source(source, broken), "COULD NOT CONFIRM")
  missing <- source
  missing$snapshot <- file.path(tempdir(), "no-such-snapshot.csv")
  expect_error(dim4_1_check_retired_source(missing, notice), "SNAPSHOT NOT FOUND")
})

test_that("the adapter replays a retired catalogue to the script and records it", {
  raw_root <- withr::local_tempdir()
  staging <- new_staging()
  fake <- fake_catalogue()
  source <- ilo_source(retired_snapshot(150L))
  fetch <- function(urls) if (identical(urls, source$probe_url)) notice(urls) else fake$fetch(urls)
  code <- c(
    legacy_like_code,
    "pull <- function(page) { temp <- tempfile(); download.file(paste('https://www.ilo.org/surveyLib/index.php/catalog/export/csv?page=', page, '&ps=100&collection[]=LFS', sep = ''), temp); readr::read_csv(temp, show_col_types = FALSE) }",
    "n <- 100; i <- 1; all <- NULL",
    "while (n == 100) { page <- pull(i); n <- nrow(page); all <- rbind(all, page); i <- i + 1 }",
    "writeLines(as.character(nrow(all)), paste(here(), '01_raw_data', '4.1_SOCS', 'ilo_rows.txt', sep = '/'))"
  )
  result <- dim4_1_legacy_catalogue_adapter(
    adapter_params(raw_root), staging, code,
    budget_seconds = 300, fetcher = fetch, retry_wait_seconds = 0,
    passthrough = function(txt, ...) stop("offline: ", txt, call. = FALSE),
    retired = list(ilo_survey_catalog = source)
  )
  expect_identical(readLines(file.path(staging, "ilo_rows.txt")), "150")
  expect_identical(result$retired_sources$ilo_survey_catalog$status, "retired")
  expect_identical(result$legacy_requests$retired_pages_served, 2L)
})

# --- Other requests the script makes ---------------------------------------------

pip_url <- "https://api.worldbank.org/pip/v1/survey-metadata"

test_that("extra requests are cached, retried and served to readLines()", {
  cache <- new_cache()
  fake <- fake_catalogue()
  fake$script[[pip_url]] <- list(list(status = 502L, body = charToRaw("<html>Bad gateway</html>")))
  fake$responses[[pip_url]] <- list(status = 200L, body = charToRaw('[{"country_code":"AAA","reporting_year":2020}]\n'))
  summary <- run_prefetch(cache, fake, extra_urls = c(pip_survey_metadata = pip_url))
  expect_identical(sum(fake$calls == pip_url), 2L)
  index <- read_index(cache)
  expect_identical(index$status[index$url == pip_url], "ok")
  expect_identical(index$kind[index$url == pip_url], "extra")

  offline <- function(con, ...) stop("offline: ", con, call. = FALSE)
  lines <- dim4_1_cached_readlines(cache$index, cache$bodies, fallback = offline)
  expect_identical(lines(pip_url, warn = FALSE), '[{"country_code":"AAA","reporting_year":2020}]')
  expect_error(lines("https://example.org/other"), "offline")
  expect_identical(attr(lines, "log")$served, 1L)
  expect_identical(attr(lines, "log")$passthrough, "https://example.org/other")
})

test_that("an extra request that keeps failing stops the prefetch and is documented", {
  cache <- new_cache()
  fake <- fake_catalogue()
  fake$responses[[pip_url]] <- list(status = 502L, body = charToRaw("<html>Bad gateway</html>"))
  expect_error(
    run_prefetch(cache, fake, max_attempts = 2L, extra_urls = c(pip_survey_metadata = pip_url)),
    "D4.1 CATALOGUE PREFETCH FAILED: 1 request"
  )
  failures <- utils::read.csv(cache$failures, colClasses = "character")
  expect_identical(failures$url, pip_url)
  expect_match(failures$message, "HTTP 502")
})

test_that("an error inside the script is documented in the failure log", {
  raw_root <- withr::local_tempdir()
  staging <- new_staging()
  fake <- fake_catalogue()
  expect_error(
    dim4_1_legacy_catalogue_adapter(
      adapter_params(raw_root), staging, c(legacy_like_code, "stop('wb_countries() could not connect')"),
      budget_seconds = 300, fetcher = fake$fetch, retry_wait_seconds = 0,
      passthrough = function(txt, ...) stop("offline: ", txt, call. = FALSE)
    ),
    "could not connect"
  )
  failures <- utils::read.csv(dim4_1_catalogue_cache_paths(raw_root)$failures, colClasses = "character")
  expect_identical(failures$source, "legacy_script")
  expect_match(failures$message, "could not connect")
  expect_identical(failures$blocking, "TRUE")
})

test_that("cached readLines() returns exactly what readLines() reads, invalid bytes included", {
  cache <- new_cache()
  fake <- fake_catalogue()
  body <- c(charToRaw('[{"survey_title":"Inqu'), as.raw(0xe9), charToRaw('rito"}]'), as.raw(0x0a))
  fake$responses[[pip_url]] <- list(status = 200L, body = body)
  run_prefetch(cache, fake, extra_urls = c(pip_survey_metadata = pip_url))
  lines <- dim4_1_cached_readlines(cache$index, cache$bodies)
  direct <- tempfile()
  writeBin(body, direct)
  expect_identical(lines(pip_url, warn = FALSE), readLines(direct, warn = FALSE))
  expect_false(anyNA(iconv(lines(pip_url, warn = FALSE), from = "", to = "UTF-8", sub = "")))
})

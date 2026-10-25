# =============================================================================
# D4.1 catalogue prefetch
# =============================================================================
# The legacy microdata_library_pull.Rmd requests one metadata page per study
# in the internal World Bank microdata library (16,852 studies in October
# 2026) and in the FAO library, one request at a time (about 8.5 hours), and
# wraps each request in purrr::possibly(): a failed request silently becomes
# a blank series label and the survey drops out of the D4.1 companions.
#
# The prefetch requests exactly the URLs the script builds (the three
# catalogue searches and every detail page they list) concurrently, before the
# script runs. Each response body is cached gzip-compressed (local, not
# versioned) and indexed in catalogue_fetch_index.csv (versioned) with its
# HTTP status, attempts and SHA-256. The unmodified script then runs with
# fromJSON() served from the cache. Response classes:
#   - ok: valid JSON, served as the script would have received it;
#   - not_found: the catalogue does not hold the study (HTTP 400
#     IDNO-NOT-FOUND, HTTP 404). Confirmed once, listed in the index and
#     served as the error the legacy request raises, so possibly() yields the
#     legacy blank;
#   - failed: anything else (network error, other HTTP status, a 200 response
#     that is not JSON). Retried; if it persists, the refresh stops before the
#     script runs and catalogue_fetch_failures.csv lists every failed URL. A
#     rerun requests only what is missing, failed or older than the maximum
#     age.
# Requests the script makes outside the cache are logged; a failure there
# stops the refresh even when possibly() swallowed it.
#
# Each search must return every study it reports. The public library answers
# page sizes above its cap (between 5,000 and 7,141 in October 2026) with
# {"status":"success","found":0,"rows":[]}; a one-row probe then records the
# true count. The public list feeds no D4.1 companion (only a diagnostic join
# that is not run), so for it the gap is documented as a non-blocking anomaly
# and the script receives the server's answer; an incomplete internal or FAO
# search stops the refresh.
#
# Created: 2026-10-24
# =============================================================================

#' Catalogue endpoints requested by the legacy microdata_library_pull.Rmd.
#'
#' @return A named list (internal, fao, public) of endpoint descriptions.
#' @export
dim4_1_catalogue_sources <- function() {
  list(
    internal = list(
      label = "World Bank microdata library (internal)",
      base_url = "http://microdatalib.worldbank.org/index.php/api/catalog",
      page_size = "?ps=20000",
      search_url = "http://microdatalib.worldbank.org/index.php/api/catalog/search?ps=20000",
      probe_url = "http://microdatalib.worldbank.org/index.php/api/catalog/search?ps=1",
      feeds_companions = TRUE,
      id_field = "idno",
      detail_prefix = "http://microdatalib.worldbank.org/index.php/api/catalog/",
      detail_suffix = ""
    ),
    fao = list(
      label = "FAO microdata catalogue",
      base_url = "https://microdata.fao.org/index.php/api/catalog",
      page_size = "?ps=20000",
      search_url = "https://microdata.fao.org/index.php/api/catalog/search?ps=20000",
      probe_url = "https://microdata.fao.org/index.php/api/catalog/search?ps=1",
      feeds_companions = TRUE,
      id_field = "id",
      detail_prefix = "https://microdata.fao.org/index.php/metadata/export/",
      detail_suffix = "/json"
    ),
    public = list(
      label = "World Bank microdata library (public)",
      base_url = "http://microdata.worldbank.org/index.php/api/catalog",
      page_size = "?ps=10000",
      search_url = "http://microdata.worldbank.org/index.php/api/catalog/search?ps=10000",
      probe_url = "http://microdata.worldbank.org/index.php/api/catalog/search?ps=1",
      feeds_companions = FALSE,
      id_field = NA_character_,
      detail_prefix = NA_character_,
      detail_suffix = NA_character_
    )
  )
}

#' Other requests of the legacy script served from the cache.
#'
#' The script reads PIP survey metadata with readLines(); it is fetched
#' with the catalogue responses so that an outage is retried and documented.
#'
#' @return A named character vector of URLs.
#' @export
dim4_1_catalogue_extra_urls <- function() {
  c(pip_survey_metadata = "https://api.worldbank.org/pip/v1/survey-metadata")
}

#' Check that the legacy script still builds the URLs the prefetch requests.
#'
#' @param code Code lines from dim4_1_legacy_catalogue_code().
#' @param sources Endpoint descriptions from dim4_1_catalogue_sources().
#' @return Invisibly TRUE; stops when a URL fragment is missing.
#' @export
dim4_1_check_catalogue_sources <- function(code, sources = dim4_1_catalogue_sources(),
                                           extra_urls = dim4_1_catalogue_extra_urls()) {
  text <- paste(code[!grepl("^[[:space:]]*#", code)], collapse = "\n")
  fragments <- unique(c(unlist(lapply(sources, function(source) {
    parts <- c(source$base_url, "/search", source$page_size, source$detail_prefix)
    if (!is.na(source$detail_suffix) && nzchar(source$detail_suffix)) {
      parts <- c(parts, source$detail_suffix)
    }
    sprintf('"%s"', parts[!is.na(parts)])
  })), sprintf('"%s"', unname(extra_urls))))
  missing <- fragments[!vapply(fragments, grepl, logical(1), x = text, fixed = TRUE)]
  if (length(missing) > 0L) {
    stop(
      "D4.1 LEGACY CATALOGUE SCRIPT NO LONGER MATCHES THE PREFETCH: ",
      paste(missing, collapse = ", "),
      " not found in microdata_library_pull.Rmd. Update dim4_1_catalogue_sources() ",
      "to the URLs the script builds.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Locations of the catalogue response cache.
#'
#' @param raw_dir Root raw-data directory.
#' @return A list with `dir`, `bodies`, `index` and `failures` paths.
#' @export
dim4_1_catalogue_cache_paths <- function(raw_dir) {
  dir <- file.path(raw_dir, "4.1_SOCS", "collection", "catalogue_cache")
  list(
    dir = dir,
    bodies = file.path(dir, "responses"),
    index = file.path(dir, "catalogue_fetch_index.csv"),
    failures = file.path(dir, "catalogue_fetch_failures.csv")
  )
}

#' Read a cached response body.
#'
#' @param path Path of a `.json.gz` body file.
#' @return A raw vector.
#' @export
dim4_1_read_cached_body <- function(path) {
  con <- gzfile(path, "rb")
  on.exit(close(con), add = TRUE)
  chunks <- list()
  repeat {
    chunk <- readBin(con, "raw", n = 1048576L)
    if (length(chunk) == 0L) break
    chunks[[length(chunks) + 1L]] <- chunk
  }
  if (length(chunks) == 0L) raw() else do.call(c, chunks)
}

.d41_write_cached_body <- function(body, path) {
  con <- gzfile(path, "wb")
  on.exit(close(con), add = TRUE)
  writeBin(body, con)
  invisible(path)
}

.d41_cached_body_matches <- function(body, row, url) {
  expected <- row$sha256[[1]]
  if (is.na(expected) || !nzchar(expected)) {
    stop("D4.1 CATALOGUE CACHE HAS NO HASH for ", url, call. = FALSE)
  }
  expected_bytes <- suppressWarnings(as.integer(row$bytes[[1]]))
  if (!is.na(expected_bytes) && length(body) != expected_bytes) {
    return(FALSE)
  }
  identical(digest::digest(body, algo = "sha256", serialize = FALSE), expected)
}

.d41_index_columns <- c(
  "url", "source", "kind", "id", "status", "http_status", "message",
  "attempts", "fetched_at", "bytes", "sha256", "body_file"
)

.d41_failure_columns <- c("url", "source", "kind", "id", "blocking", "attempts", "message", "last_attempt_at")

.d41_timestamp <- function(time = Sys.time()) {
  format(time, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

.d41_read_index <- function(path) {
  if (!file.exists(path)) {
    empty <- as.data.frame(
      stats::setNames(rep(list(character()), length(.d41_index_columns)), .d41_index_columns),
      stringsAsFactors = FALSE
    )
    return(empty)
  }
  index <- utils::read.csv(path, colClasses = "character", na.strings = "")
  missing <- setdiff(.d41_index_columns, names(index))
  if (length(missing) > 0L) {
    stop("D4.1 CATALOGUE FETCH INDEX IS MALFORMED: missing ", paste(missing, collapse = ", "), call. = FALSE)
  }
  index[, .d41_index_columns, drop = FALSE]
}

.d41_write_table <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  temporary <- paste0(path, ".tmp")
  utils::write.csv(data, temporary, row.names = FALSE, na = "")
  if (!file.rename(temporary, path)) {
    stop("D4.1 CATALOGUE CACHE COULD NOT WRITE ", path, call. = FALSE)
  }
  invisible(path)
}

.d41_body_text <- function(body) {
  if (length(body) == 0L) {
    return("")
  }
  text <- tryCatch(rawToChar(body), error = function(error) NA_character_)
  if (!is.na(text)) Encoding(text) <- "UTF-8"
  text
}

.d41_snippet <- function(text) {
  if (is.na(text)) {
    return("<binary body>")
  }
  substr(gsub("[[:space:]]+", " ", text), 1L, 120L)
}

# ok, not_found or failed, with the reason.
.d41_classify_response <- function(status_code, body, error) {
  if (!is.na(error) || is.na(status_code)) {
    return(list(status = "failed", message = if (is.na(error)) "no HTTP response" else error))
  }
  text <- .d41_body_text(body)
  if (status_code == 200L) {
    clean <- if (is.na(text)) NA_character_ else iconv(text, from = "", to = "UTF-8", sub = "")
    if (!is.na(clean) && isTRUE(jsonlite::validate(clean))) {
      return(list(status = "ok", message = NA_character_))
    }
    return(list(status = "failed", message = paste("HTTP 200 but the body is not JSON:", .d41_snippet(text))))
  }
  not_found <- status_code == 404L ||
    (status_code == 400L && !is.na(text) && grepl("IDNO-NOT-FOUND", text, fixed = TRUE))
  list(
    status = if (not_found) "not_found" else "failed",
    message = sprintf("HTTP %d: %s", status_code, .d41_snippet(text))
  )
}

# The legacy script reads the study ids back from the CSV it wrote, so ids go
# through the same write_excel_csv()/read_csv() round trip before they are
# pasted into URLs (for example, FAO ids become doubles).
.d41_legacy_ids <- function(values) {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  readr::write_excel_csv(data.frame(id = values, stringsAsFactors = FALSE), path)
  readr::read_csv(path, show_col_types = FALSE, progress = FALSE)$id
}

.d41_needs_fetch <- function(index, urls, max_age_days, bodies) {
  row <- match(urls, index$url)
  known <- !is.na(row)
  status <- index$status[row]
  fetched_at <- as.POSIXct(index$fetched_at[row], format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  age_days <- as.numeric(difftime(Sys.time(), fetched_at, units = "days"))
  stale <- is.na(age_days) | age_days > max_age_days
  body_valid <- rep(FALSE, length(urls))
  candidates <- which(
    known &
      status == "ok" &
      !is.na(index$body_file[row]) &
      file.exists(file.path(bodies, index$body_file[row]))
  )
  for (position in candidates) {
    body <- tryCatch(
      dim4_1_read_cached_body(file.path(bodies, index$body_file[[row[[position]]]])),
      error = function(error) NULL
    )
    if (!is.null(body)) {
      body_valid[[position]] <- .d41_cached_body_matches(
        body,
        index[row[[position]], , drop = FALSE],
        urls[[position]]
      )
    }
  }
  body_missing_or_invalid <- status == "ok" & !body_valid
  !known | status == "failed" | stale | body_missing_or_invalid
}

#' Fetch the catalogue responses the legacy script requests.
#'
#' Requests the three catalogue searches, checks that each returned every
#' study it found, then requests every detail page the script builds from
#' them. Cached responses younger than `max_age_days` are reused.
#'
#' @param cache Paths from dim4_1_catalogue_cache_paths().
#' @param sources Endpoint descriptions from dim4_1_catalogue_sources().
#' @param fetcher `function(urls)` returning a list with `url`,
#'   `status_code`, `error` and `body` (raw vectors), for example
#'   dim4_1_catalogue_curl_fetcher().
#' @param max_attempts Attempts per failing request.
#' @param retry_wait_seconds Pauses before successive retry rounds.
#' @param max_age_days Maximum age of a reusable cached response.
#' @param batch_size Requests per fetcher call (the index is saved after each).
#' @param deadline Time after which no new batch starts.
#' @param progress Print progress messages.
#' @param extra_urls Other URLs the script requests (named), cached with the
#'   catalogue responses; a not-found answer counts as a failure.
#' @return A summary list; stops when a request still fails.
#' @export
dim4_1_catalogue_prefetch <- function(cache, sources = dim4_1_catalogue_sources(), fetcher,
                                      max_attempts = 4L, retry_wait_seconds = c(5, 30, 120),
                                      max_age_days = 7, batch_size = 500L, deadline = Inf,
                                      progress = TRUE, extra_urls = character()) {
  started <- Sys.time()
  dir.create(cache$bodies, recursive = TRUE, showWarnings = FALSE)
  index <- .d41_read_index(cache$index)
  requested <- character()
  needed_retry <- character()
  attempts_in_run <- new.env(hash = TRUE, parent = emptyenv())

  run_attempts <- function(urls) {
    vapply(urls, function(url) get0(url, envir = attempts_in_run, inherits = FALSE, ifnotfound = 0L), integer(1))
  }

  record <- function(entries, response) {
    urls <- response$url
    outcomes <- lapply(seq_along(urls), function(position) {
      .d41_classify_response(
        response$status_code[[position]],
        response$body[[position]],
        response$error[[position]]
      )
    })
    status <- vapply(outcomes, `[[`, character(1), "status")
    message <- vapply(outcomes, `[[`, character(1), "message")
    extra <- entries$kind[match(urls, entries$url)] == "extra"
    status[extra & status == "not_found"] <- "failed"
    sizes <- lengths(response$body)
    body_files <- paste0(vapply(urls, digest::digest, character(1), algo = "sha1", serialize = FALSE), ".json.gz")
    for (position in which(sizes > 0L)) {
      .d41_write_cached_body(response$body[[position]], file.path(cache$bodies, body_files[[position]]))
    }
    attempts <- run_attempts(urls) + 1L
    for (position in seq_along(urls)) assign(urls[[position]], attempts[[position]], envir = attempts_in_run)
    earlier <- index$message[match(urls, index$url)]
    recovered <- status == "ok" & attempts > 1L & !is.na(earlier)
    message[recovered] <- sprintf("ok after %d attempts; earlier: %s", attempts[recovered], earlier[recovered])
    entry <- entries[match(urls, entries$url), , drop = FALSE]
    hashes <- vapply(response$body, digest::digest, character(1), algo = "sha256", serialize = FALSE)
    rows <- data.frame(
      url = urls,
      source = entry$source,
      kind = entry$kind,
      id = entry$id,
      status = status,
      http_status = as.character(response$status_code),
      message = message,
      attempts = as.character(attempts),
      fetched_at = .d41_timestamp(),
      bytes = as.character(sizes),
      sha256 = ifelse(sizes > 0L, hashes, NA_character_),
      body_file = ifelse(sizes > 0L, body_files, NA_character_),
      stringsAsFactors = FALSE
    )
    index <<- rbind(index[!index$url %in% urls, , drop = FALSE], rows)
  }

  fetch_entries <- function(entries) {
    pending <- entries$url[.d41_needs_fetch(index, entries$url, max_age_days, cache$bodies)]
    total <- length(pending)
    for (url in pending) assign(url, 0L, envir = attempts_in_run)
    sent <- 0L
    round <- 0L
    while (length(pending) > 0L) {
      round <- round + 1L
      if (round > 1L) {
        needed_retry <<- union(needed_retry, pending)
        wait <- retry_wait_seconds[[min(round - 1L, length(retry_wait_seconds))]]
        if (wait > 0) Sys.sleep(wait)
      }
      batches <- split(pending, ceiling(seq_along(pending) / batch_size))
      for (batch in batches) {
        if (Sys.time() > deadline) {
          .d41_write_table(index, cache$index)
          stop(
            "D4.1 CATALOGUE PREFETCH REACHED ITS TIME BUDGET; the responses fetched so far are cached ",
            "and a rerun continues from there.",
            call. = FALSE
          )
        }
        record(entries, fetcher(batch))
        requested <<- union(requested, batch)
        sent <- sent + length(batch)
        .d41_write_table(index, cache$index)
        if (progress) {
          state <- index$status[match(entries$url, index$url)]
          message(sprintf(
            "D4.1 catalogue prefetch (%s, round %d): %d requests sent for %d pending; %d ok, %d not found, %d failed; %.1f min",
            entries$kind[[1]], round, sent, total,
            sum(state == "ok", na.rm = TRUE),
            sum(state == "not_found", na.rm = TRUE),
            sum(state == "failed", na.rm = TRUE),
            as.numeric(difftime(Sys.time(), started, units = "mins"))
          ))
        }
      }
      current <- index[match(pending, index$url), , drop = FALSE]
      attempts <- run_attempts(current$url)
      pending <- current$url[
        (current$status == "failed" & attempts < max_attempts) |
          (current$status == "not_found" & attempts < 2L)
      ]
    }
  }

  stop_on_failures <- function(urls) {
    current <- index[match(urls, index$url), , drop = FALSE]
    failed <- current[current$status == "failed", , drop = FALSE]
    failures <- data.frame(
      url = failed$url,
      source = failed$source,
      kind = failed$kind,
      id = failed$id,
      blocking = rep("TRUE", nrow(failed)),
      attempts = failed$attempts,
      message = failed$message,
      last_attempt_at = failed$fetched_at,
      stringsAsFactors = FALSE
    )
    .d41_write_table(rbind(failures, anomalies), cache$failures)
    if (nrow(failed) > 0L) {
      stop(
        sprintf(
          "D4.1 CATALOGUE PREFETCH FAILED: %d request(s) still failing after %d attempts (%s); documented in %s. Nothing was refreshed; a rerun retries only the missing and failed requests.",
          nrow(failed),
          max_attempts,
          paste(utils::head(failed$url, 3L), collapse = ", "),
          cache$failures
        ),
        call. = FALSE
      )
    }
  }

  anomalies <- as.data.frame(
    stats::setNames(rep(list(character()), length(.d41_failure_columns)), .d41_failure_columns),
    stringsAsFactors = FALSE
  )
  searches <- data.frame(
    url = vapply(sources, `[[`, character(1), "search_url"),
    source = names(sources),
    kind = "search",
    id = NA_character_,
    stringsAsFactors = FALSE
  )
  fetch_entries(searches)
  stop_on_failures(searches$url)

  details <- list()
  search_counts <- list()
  for (name in names(sources)) {
    source <- sources[[name]]
    row <- index[match(source$search_url, index$url), , drop = FALSE]
    text <- .d41_body_text(dim4_1_read_cached_body(file.path(cache$bodies, row$body_file)))
    parsed <- jsonlite::fromJSON(text)
    result <- parsed$result
    reported <- suppressWarnings(as.integer(result$found))
    rows <- result$rows
    returned <- if (is.data.frame(rows)) nrow(rows) else length(rows)
    complete <- length(reported) == 1L && !is.na(reported) && returned == reported
    probe_found <- NA_integer_
    if (!complete) {
      probe <- fetcher(source$probe_url)
      probe_text <- .d41_body_text(probe$body[[1]])
      if (identical(probe$status_code[[1]], 200L) && isTRUE(jsonlite::validate(probe_text))) {
        probe_found <- suppressWarnings(as.integer(jsonlite::fromJSON(probe_text)$result$found))
        if (length(probe_found) != 1L) probe_found <- NA_integer_
      }
      detail <- sprintf(
        "%s reported %s but returned %d rows; a one-row search reports %s",
        source$search_url,
        if (length(reported) == 1L && !is.na(reported)) sprintf("found %d studies", reported) else "no study count",
        returned,
        if (is.na(probe_found)) "an unknown number of studies" else sprintf("%d studies", probe_found)
      )
      if (isTRUE(source$feeds_companions)) {
        stop(
          "D4.1 CATALOGUE SEARCH INCOMPLETE: ", detail,
          ". The legacy script would miss studies; nothing was refreshed.",
          call. = FALSE
        )
      }
      anomalies <- rbind(anomalies, data.frame(
        url = source$search_url,
        source = name,
        kind = "search",
        id = NA_character_,
        blocking = "FALSE",
        attempts = row$attempts,
        message = paste0(
          "Search incomplete: ", detail,
          ". This list does not feed the D4.1 companions; the script receives the server's answer."
        ),
        last_attempt_at = row$fetched_at,
        stringsAsFactors = FALSE
      ))
    }
    search_counts[[name]] <- list(reported = reported, returned = returned, probe_found = probe_found)
    if (!is.na(source$detail_prefix)) {
      ids <- .d41_legacy_ids(rows[[source$id_field]])
      details[[name]] <- data.frame(
        url = paste(source$detail_prefix, ids, source$detail_suffix, sep = ""),
        source = name,
        kind = "detail",
        id = as.character(ids),
        stringsAsFactors = FALSE
      )
    }
  }
  details <- do.call(rbind, details)
  details <- details[!duplicated(details$url), , drop = FALSE]
  fetch_entries(details)
  extras <- data.frame(
    url = unname(extra_urls),
    source = names(extra_urls),
    kind = rep("extra", length(extra_urls)),
    id = rep(NA_character_, length(extra_urls)),
    stringsAsFactors = FALSE
  )
  if (nrow(extras) > 0L) fetch_entries(extras)
  current_urls <- c(searches$url, details$url, extras$url)
  stop_on_failures(current_urls)

  index <- index[index$url %in% current_urls, , drop = FALSE]
  .d41_write_table(index, cache$index)
  kept <- index$body_file[!is.na(index$body_file)]
  stale_bodies <- setdiff(list.files(cache$bodies, pattern = "[.]json[.]gz$"), kept)
  unlink(file.path(cache$bodies, stale_bodies))

  per_source <- lapply(names(sources), function(name) {
    rows <- index[index$source == name & index$kind == "detail", , drop = FALSE]
    counts <- search_counts[[name]]
    list(
      label = sources[[name]]$label,
      search_url = sources[[name]]$search_url,
      feeds_companions = isTRUE(sources[[name]]$feeds_companions),
      found = if (length(counts$reported) == 1L) counts$reported else NA_integer_,
      returned = counts$returned,
      probe_found = counts$probe_found,
      details = nrow(rows),
      ok = sum(rows$status == "ok"),
      not_found = sum(rows$status == "not_found")
    )
  })
  names(per_source) <- names(sources)
  finished <- Sys.time()
  list(
    sources = per_source,
    requests = nrow(index),
    ok = sum(index$status == "ok"),
    not_found = sum(index$status == "not_found"),
    not_found_ids = index$id[index$status == "not_found"],
    failed = 0L,
    extra_requests = nrow(extras),
    anomalies = anomalies$message,
    fetched = length(requested),
    reused = nrow(index) - length(intersect(requested, index$url)),
    retried = length(needed_retry),
    max_attempts = as.integer(max_attempts),
    max_age_days = max_age_days,
    index = list(
      path = dim4_1_project_relative_path(cache$index),
      sha256 = digest::digest(cache$index, algo = "sha256", file = TRUE)
    ),
    failures = list(
      path = dim4_1_project_relative_path(cache$failures),
      sha256 = digest::digest(cache$failures, algo = "sha256", file = TRUE),
      blocking_rows = 0L,
      documented_rows = nrow(anomalies)
    ),
    started_at = .d41_timestamp(started),
    finished_at = .d41_timestamp(finished),
    elapsed_seconds = round(as.numeric(difftime(finished, started, units = "secs")), 1)
  )
}

#' Concurrent HTTP fetcher for the catalogue prefetch.
#'
#' Sends the same Accept header as jsonlite::fromJSON() and follows
#' redirects (the legacy URLs redirect from http to https). Requests join
#' the pool one at a time as earlier ones finish: libcurl starts a request's
#' connect timer when it joins the pool, so queuing a whole batch behind a few
#' connections would time requests out before they are sent.
#'
#' @param connections Concurrent connections (requests in flight).
#' @param timeout_seconds Per-request timeout.
#' @return `function(urls)` for dim4_1_catalogue_prefetch().
#' @export
dim4_1_catalogue_curl_fetcher <- function(connections = 8L, timeout_seconds = 120) {
  force(connections)
  force(timeout_seconds)
  function(urls) {
    results <- vector("list", length(urls))
    names(results) <- urls
    pool <- curl::new_pool(total_con = connections, host_con = connections)
    next_position <- 0L
    add_next <- function() {
      if (next_position >= length(urls)) {
        return(invisible(FALSE))
      }
      next_position <<- next_position + 1L
      request_url <- urls[[next_position]]
      handle <- curl::new_handle(followlocation = TRUE, timeout = timeout_seconds, connecttimeout = 30)
      curl::handle_setheaders(handle, Accept = "application/json, text/*, */*")
      curl::curl_fetch_multi(
        request_url,
        done = function(response) {
          results[[request_url]] <<- list(
            status_code = as.integer(response$status_code),
            body = response$content,
            error = NA_character_
          )
          add_next()
        },
        fail = function(message) {
          results[[request_url]] <<- list(status_code = NA_integer_, body = raw(), error = message)
          add_next()
        },
        pool = pool,
        handle = handle
      )
      invisible(TRUE)
    }
    for (slot in seq_len(min(connections, length(urls)))) add_next()
    curl::multi_run(pool = pool)
    missing <- vapply(results, is.null, logical(1))
    results[missing] <- list(list(status_code = NA_integer_, body = raw(), error = "no response recorded"))
    list(
      url = urls,
      status_code = vapply(results, `[[`, integer(1), "status_code"),
      error = vapply(results, `[[`, character(1), "error"),
      body = lapply(results, `[[`, "body")
    )
  }
}

#' A fromJSON() replacement that serves the catalogue cache.
#'
#' Self-contained (base R, utils and jsonlite only) so it can run in the
#' separate R process that executes the legacy script. Cached `ok` URLs are
#' parsed from the cached body; cached `not_found` URLs raise the error the
#' legacy request raises; other URLs go to `fallback` and are logged, with
#' failures recorded before the error is raised again.
#'
#' @param index_path Path of catalogue_fetch_index.csv.
#' @param body_dir Directory of the cached bodies.
#' @param fallback Function used for URLs that are not cached.
#' @return A function with a `log` attribute (an environment).
#' @export
dim4_1_cached_fromjson <- function(index_path, body_dir, fallback = jsonlite::fromJSON) {
  index <- utils::read.csv(index_path, colClasses = "character", na.strings = "")
  index <- index[
    (index$status == "ok" & !is.na(index$body_file)) | index$status == "not_found", ,
    drop = FALSE
  ]
  lookup <- new.env(hash = TRUE, parent = emptyenv())
  for (row in seq_len(nrow(index))) assign(index$url[[row]], row, envir = lookup)
  read_body <- function(path) {
    con <- gzfile(path, "rb")
    on.exit(close(con), add = TRUE)
    chunks <- list()
    repeat {
      chunk <- readBin(con, "raw", n = 1048576L)
      if (length(chunk) == 0L) break
      chunks[[length(chunks) + 1L]] <- chunk
    }
    if (length(chunks) == 0L) raw() else do.call(c, chunks)
  }
  cache_matches <- function(body, row, url) {
    expected <- row$sha256[[1]]
    if (is.na(expected) || !nzchar(expected)) {
      stop("D4.1 CATALOGUE CACHE HAS NO HASH for ", url, call. = FALSE)
    }
    expected_bytes <- suppressWarnings(as.integer(row$bytes[[1]]))
    !(!is.na(expected_bytes) && length(body) != expected_bytes) &&
      identical(digest::digest(body, algo = "sha256", serialize = FALSE), expected)
  }
  log <- new.env(parent = emptyenv())
  log$served <- c(ok = 0L, not_found = 0L)
  log$passthrough <- character()
  log$passthrough_failures <- data.frame(url = character(), message = character(), stringsAsFactors = FALSE)
  cached <- function(txt, ...) {
    if (is.character(txt) && length(txt) == 1L && !is.na(txt) && grepl("^https?://", txt)) {
      if (exists(txt, envir = lookup, inherits = FALSE)) {
        row <- get(txt, envir = lookup, inherits = FALSE)
        if (identical(index$status[[row]], "not_found")) {
          log$served[["not_found"]] <- log$served[["not_found"]] + 1L
          stop(sprintf("cannot open the connection to '%s'", txt), call. = FALSE)
        }
        log$served[["ok"]] <- log$served[["ok"]] + 1L
        body <- read_body(file.path(body_dir, index$body_file[[row]]))
        if (!cache_matches(body, index[row, , drop = FALSE], txt)) {
          stop("D4.1 CATALOGUE CACHE BODY HASH MISMATCH: ", txt, call. = FALSE)
        }
        text <- rawToChar(body)
        Encoding(text) <- "UTF-8"
        return(jsonlite::fromJSON(text, ...))
      }
      log$passthrough <- c(log$passthrough, txt)
      return(tryCatch(fallback(txt, ...), error = function(error) {
        log$passthrough_failures <- rbind(
          log$passthrough_failures,
          data.frame(url = txt, message = conditionMessage(error), stringsAsFactors = FALSE)
        )
        stop(error)
      }))
    }
    jsonlite::fromJSON(txt, ...)
  }
  attr(cached, "log") <- log
  cached
}

.d41_append_failures <- function(cache, failures, source = "legacy_passthrough") {
  existing <- if (file.exists(cache$failures)) {
    utils::read.csv(cache$failures, colClasses = "character", na.strings = "")
  } else {
    NULL
  }
  added <- data.frame(
    url = failures$url,
    source = source,
    kind = "legacy",
    id = NA_character_,
    blocking = "TRUE",
    attempts = "1",
    message = failures$message,
    last_attempt_at = .d41_timestamp(),
    stringsAsFactors = FALSE
  )
  .d41_write_table(rbind(existing[, .d41_failure_columns, drop = FALSE], added), cache$failures)
}

# Optional numeric parameter with a documented default.
.d41_param <- function(params, name, default) {
  value <- params[[name]]
  if (is.null(value)) default else value
}

#' A readLines() replacement that serves cached extra requests.
#'
#' Self-contained (base R and utils only) for the process that executes the
#' legacy script. Cached `extra` URLs return base readLines() of the cached
#' bytes; other URLs go to `fallback` and are logged.
#'
#' @param index_path Path of catalogue_fetch_index.csv.
#' @param body_dir Directory of the cached bodies.
#' @param fallback Function used for anything that is not cached.
#' @return A function with a `log` attribute (an environment).
#' @export
dim4_1_cached_readlines <- function(index_path, body_dir, fallback = base::readLines) {
  index <- utils::read.csv(index_path, colClasses = "character", na.strings = "")
  index <- index[index$kind == "extra" & index$status == "ok" & !is.na(index$body_file), , drop = FALSE]
  log <- new.env(parent = emptyenv())
  log$served <- 0L
  log$passthrough <- character()
  read_body <- function(path) {
    con <- gzfile(path, "rb")
    on.exit(close(con), add = TRUE)
    chunks <- list()
    repeat {
      chunk <- readBin(con, "raw", n = 1048576L)
      if (length(chunk) == 0L) break
      chunks[[length(chunks) + 1L]] <- chunk
    }
    if (length(chunks) == 0L) raw() else do.call(c, chunks)
  }
  cache_matches <- function(body, row, url) {
    expected <- row$sha256[[1]]
    if (is.na(expected) || !nzchar(expected)) {
      stop("D4.1 CATALOGUE CACHE HAS NO HASH for ", url, call. = FALSE)
    }
    expected_bytes <- suppressWarnings(as.integer(row$bytes[[1]]))
    !(!is.na(expected_bytes) && length(body) != expected_bytes) &&
      identical(digest::digest(body, algo = "sha256", serialize = FALSE), expected)
  }
  cached <- function(con = stdin(), ...) {
    if (is.character(con) && length(con) == 1L && con %in% index$url) {
      log$served <- log$served + 1L
      # The bytes go through base readLines() itself, so the lines (including
      # bytes that are not valid UTF-8) are exactly those of the live request.
      path <- tempfile()
      on.exit(unlink(path), add = TRUE)
      row <- match(con, index$url)
      body <- read_body(file.path(body_dir, index$body_file[[row]]))
      if (!cache_matches(body, index[row, , drop = FALSE], con)) {
        stop("D4.1 CATALOGUE CACHE BODY HASH MISMATCH: ", con, call. = FALSE)
      }
      writeBin(body, path)
      return(base::readLines(path, ...))
    }
    if (is.character(con) && length(con) == 1L && grepl("^https?://", con)) {
      log$passthrough <- c(log$passthrough, con)
    }
    fallback(con, ...)
  }
  attr(cached, "log") <- log
  cached
}

# --- Retired catalogue sources -------------------------------------------------
# The ILO Survey Catalog (NADA), one of the three labour force survey sources
# of the legacy script, was permanently retired in 2026 (HTTP 410 notice;
# ILO points to ILOSTAT). Its final snapshot (byte-identical in October 2025
# and October 2026) is kept in 4.1_SOCS/retired/ and replayed to the
# unmodified script page by page, as the script requests it, so no recorded
# survey is lost. The replay runs only while the endpoint still shows the
# retirement notice; if it serves data again, the refresh stops so that the
# live catalogue is used.

#' Catalogue sources the legacy script requests that have been retired.
#'
#' @param raw_dir Root raw-data directory.
#' @return A named list of retired sources with their snapshot.
#' @export
dim4_1_retired_sources <- function(raw_dir) {
  list(
    ilo_survey_catalog = list(
      label = "ILO Survey Catalog (NADA), LFS collection",
      url_pattern = "^https://www[.]ilo[.]org/surveyLib/index[.]php/catalog/export/csv[?]page=([0-9]+)&ps=([0-9]+)&collection\\[\\]=LFS$",
      probe_url = "https://www.ilo.org/surveyLib/index.php/catalog/export/csv?page=1&ps=100&collection[]=LFS",
      retired_marker = "Survey Catalog Retired",
      snapshot = file.path(raw_dir, "4.1_SOCS", "retired", "ilo_survey_catalog_final_2026-10-20.csv")
    )
  )
}

#' Confirm that a retired source is still retired.
#'
#' @param source One entry of dim4_1_retired_sources().
#' @param fetcher Fetcher as for dim4_1_catalogue_prefetch().
#' @return A record of the check; stops when the source serves data again,
#'   the check fails, or the snapshot is missing.
#' @export
dim4_1_check_retired_source <- function(source, fetcher) {
  if (!file.exists(source$snapshot)) {
    stop("D4.1 RETIRED CATALOGUE SNAPSHOT NOT FOUND: ", source$snapshot, call. = FALSE)
  }
  response <- fetcher(source$probe_url)
  status <- response$status_code[[1]]
  text <- .d41_body_text(response$body[[1]])
  if (!is.na(response$error[[1]]) || is.na(status)) {
    stop(
      sprintf(
        "D4.1 COULD NOT CONFIRM THAT THE %s IS STILL RETIRED (%s); rerun the refresh when the site answers.",
        source$label,
        if (is.na(response$error[[1]])) "no HTTP response" else response$error[[1]]
      ),
      call. = FALSE
    )
  }
  if (!is.na(text) && grepl(source$retired_marker, text, fixed = TRUE)) {
    snapshot <- readr::read_csv(source$snapshot, col_types = readr::cols(.default = "c"), progress = FALSE)
    return(list(
      status = "retired",
      label = source$label,
      probe_url = source$probe_url,
      http_status = as.integer(status),
      checked_at = .d41_timestamp(),
      snapshot = dim4_1_project_relative_path(source$snapshot),
      snapshot_sha256 = digest::digest(source$snapshot, algo = "sha256", file = TRUE),
      snapshot_rows = nrow(snapshot)
    ))
  }
  first_line <- if (is.na(text)) "" else strsplit(text, "\n", fixed = TRUE)[[1]][[1]]
  if (identical(as.integer(status), 200L) && grepl("idno", first_line, fixed = TRUE)) {
    stop(
      sprintf(
        "D4.1 %s IS AVAILABLE AGAIN: %s returns data. Remove it from dim4_1_retired_sources() so the refresh uses the live catalogue.",
        source$label, source$probe_url
      ),
      call. = FALSE
    )
  }
  stop(
    sprintf(
      "D4.1 COULD NOT CONFIRM THAT THE %s IS STILL RETIRED: unexpected answer (HTTP %s: %s).",
      source$label, status, .d41_snippet(text)
    ),
    call. = FALSE
  )
}

#' A download.file() replacement that replays retired catalogues.
#'
#' Self-contained (base R and readr only) so it can run in the process that
#' executes the legacy script. URLs of a retired source are answered with the
#' requested page of its snapshot (page size from the URL); other URLs go to
#' `fallback` and are logged, with failures recorded before the error is
#' raised again.
#'
#' @param sources Retired sources (from dim4_1_retired_sources()).
#' @param fallback Function used for other URLs.
#' @return A function with a `log` attribute (an environment).
#' @export
dim4_1_snapshot_download_file <- function(sources, fallback = utils::download.file) {
  snapshots <- lapply(sources, function(source) {
    readr::read_csv(source$snapshot, col_types = readr::cols(.default = "c"), na = character(), progress = FALSE)
  })
  log <- new.env(parent = emptyenv())
  log$served <- 0L
  log$passthrough <- character()
  log$passthrough_failures <- data.frame(url = character(), message = character(), stringsAsFactors = FALSE)
  replay <- function(url, destfile, ...) {
    for (name in names(sources)) {
      match <- regmatches(url, regexec(sources[[name]]$url_pattern, url))[[1]]
      if (length(match) == 3L) {
        page <- as.integer(match[[2]])
        size <- as.integer(match[[3]])
        rows <- snapshots[[name]]
        first <- (page - 1L) * size + 1L
        index <- if (first > nrow(rows)) integer() else seq.int(first, min(nrow(rows), page * size))
        readr::write_csv(rows[index, , drop = FALSE], destfile, na = "")
        log$served <- log$served + 1L
        return(invisible(0L))
      }
    }
    log$passthrough <- c(log$passthrough, url)
    tryCatch(fallback(url, destfile, ...), error = function(error) {
      log$passthrough_failures <- rbind(
        log$passthrough_failures,
        data.frame(url = url, message = conditionMessage(error), stringsAsFactors = FALSE)
      )
      stop(error)
    })
  }
  attr(replay, "log") <- log
  replay
}

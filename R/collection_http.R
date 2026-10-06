# =============================================================================
# Shared HTTP retry helper
# =============================================================================
# Created: 2026-10-06
# =============================================================================

#' Execute an HTTP request with bounded retries for transient failures.
#'
#' @param request_fn Zero-argument function returning an httr response.
#' @param attempts Maximum attempts.
#' @param delay_fn Injectable delay function for tests.
#' @param retry_status HTTP statuses considered transient.
#' @return An httr response.
#' @export
with_http_retry <- function(request_fn, attempts = 3,
                            delay_fn = function(seconds) Sys.sleep(seconds),
                            retry_status = c(408, 429, 500, 502, 503, 504)) {
  last_error <- NULL
  for (attempt in seq_len(attempts)) {
    response <- tryCatch(
      request_fn(),
      error = function(error) {
        last_error <<- error
        NULL
      }
    )
    if (!is.null(response)) {
      status <- httr::status_code(response)
      if (!(status %in% retry_status) || attempt == attempts) {
        return(response)
      }
    } else if (attempt == attempts) {
      stop(last_error)
    }
    delay_fn(2 ^ (attempt - 1))
  }
  stop("HTTP RETRY FAILED", call. = FALSE)
}

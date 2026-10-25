# =============================================================================
# Enumerated replication exceptions (cell level)
# =============================================================================
# Approved methodology changes that alter individual published cells are
# enumerated in tests/fixtures/exceptions/*.csv (file, key, column, baseline,
# new). The stage and vintage comparisons blank exactly those cells in both
# frames, so every other cell must still match.
#
# Created: 2026-10-24
# =============================================================================

read_exception_cells <- function(file) {
  paths <- list.files(
    here::here("tests", "fixtures", "exceptions"),
    pattern = "[.]csv$",
    full.names = TRUE
  )
  if (length(paths) == 0L) {
    stop("NO EXCEPTION CELL FIXTURES FOUND in tests/fixtures/exceptions", call. = FALSE)
  }
  cells <- do.call(rbind, lapply(paths, function(path) {
    data <- readr::read_csv(
      path,
      col_types = readr::cols(.default = readr::col_character()),
      progress = FALSE,
      na = c("", "NA")
    )
    required <- c("file", "key", "column", "baseline", "new")
    if (!identical(names(data), required)) {
      stop(
        "EXCEPTION CELL FIXTURE SCHEMA MISMATCH in ", path,
        "; expected exactly ", paste(required, collapse = ", "),
        call. = FALSE
      )
    }
    data
  }))
  cells <- cells[cells$file == file, , drop = FALSE]
  if (nrow(cells) == 0L) {
    return(cells)
  }
  if (anyNA(cells[c("key", "column", "baseline", "new")]) ||
      any(!nzchar(trimws(cells$key))) ||
      any(!nzchar(trimws(cells$column)))) {
    stop(
      "EXCEPTION CELL FIXTURE HAS BLANK KEY, COLUMN, BASELINE OR NEW VALUE for ",
      file,
      call. = FALSE
    )
  }
  if (anyDuplicated(paste(cells$key, cells$column, sep = "\r")) > 0L) {
    stop("EXCEPTION CELL FIXTURE HAS DUPLICATE KEY/COLUMN ROWS for ", file, call. = FALSE)
  }
  parsed <- strsplit(cells$key, ";", fixed = TRUE)
  parts <- lapply(parsed, function(key) strsplit(key, "=", fixed = TRUE))
  if (any(vapply(parts, function(key) any(lengths(key) != 2L), logical(1)))) {
    stop("EXCEPTION CELL FIXTURE HAS MALFORMED KEY(S) for ", file, call. = FALSE)
  }
  fields <- lapply(parts, function(key) vapply(key, `[[`, character(1), 1L))
  if (length(unique(vapply(fields, paste, character(1), collapse = "\r"))) != 1L) {
    stop("EXCEPTION CELL FIXTURE MIXES KEY SCHEMAS for ", file, call. = FALSE)
  }
  cells
}

# Set the enumerated exception cells of `file` to NA in `df` after checking
# that the observed value matches the fixture's baseline or new value.
mask_exception_cells <- function(df, file, side = c("baseline", "new")) {
  side <- match.arg(side)
  cells <- read_exception_cells(file)
  if (nrow(cells) == 0L) {
    return(df)
  }
  fields <- vapply(
    strsplit(strsplit(cells$key[[1]], ";", fixed = TRUE)[[1]], "=", fixed = TRUE),
    `[[`,
    character(1),
    1L
  )
  if (!all(fields %in% names(df))) {
    stop(
      sprintf(
        "EXCEPTION CELL KEYS (%s) NOT IN THE COMPARED FRAME FOR %s",
        paste(fields, collapse = ", "),
        file
      ),
      call. = FALSE
    )
  }
  row_key <- do.call(
    paste,
    c(lapply(fields, function(field) paste0(field, "=", df[[field]])), sep = ";")
  )
  same_value <- function(actual, expected) {
    actual_numeric <- suppressWarnings(as.numeric(actual))
    expected_numeric <- suppressWarnings(as.numeric(expected))
    if (!is.na(actual_numeric) && !is.na(expected_numeric)) {
      return(abs(actual_numeric - expected_numeric) <=
        1e-9 * max(1, abs(actual_numeric), abs(expected_numeric)))
    }
    identical(as.character(actual), as.character(expected))
  }
  for (index in seq_len(nrow(cells))) {
    column <- cells$column[[index]]
    if (!column %in% names(df)) {
      stop(
        "EXCEPTION CELL COLUMN NOT IN COMPARED FRAME: ",
        column, " for ", file,
        call. = FALSE
      )
    }
    hit <- row_key == cells$key[[index]]
    if (sum(hit) != 1L) {
      stop(
        "EXCEPTION CELL KEY DOES NOT MATCH EXACTLY ONE ROW: ",
        cells$key[[index]], " for ", file,
        call. = FALSE
      )
    }
    expected <- cells[[side]][[index]]
    actual <- df[[column]][hit][[1]]
    if (!same_value(actual, expected)) {
      stop(
        "EXCEPTION CELL ", file, " ", cells$key[[index]], " ", column,
        " has ", side, " value '", actual,
        "' but fixture records '", expected, "'.",
        call. = FALSE
      )
    }
    df[[column]][hit] <- NA
  }
  df
}

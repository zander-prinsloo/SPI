# =============================================================================
# Synthetic JMP country workbooks for test-jmp-collection.R
# =============================================================================
# Writes small .xlsx files (no real JMP data) with the layout of a JMP country
# file: label rows 1-4, machine codes in row 5, numeric year/value cells and
# bracketed text cells below. Numeric cells sit under text cells in the same
# column, which writexl cannot produce, so the OOXML parts are written
# directly. Needs a `zip` command on the PATH; the .xlsx files are committed,
# so tests do not run this script.
#
#   Rscript tests/fixtures/jmp/make_jmp_fixtures.R
#
# Created: 2026-10-23
# =============================================================================

out_dir <- file.path("tests", "fixtures", "jmp")

col_letter <- function(i) {
  out <- ""
  while (i > 0) {
    r <- (i - 1) %% 26
    out <- paste0(LETTERS[r + 1], out)
    i <- (i - 1) %/% 26
  }
  out
}

xml_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE)
}

write_workbook <- function(path, sheets) {
  strings <- character()
  string_index <- function(x) {
    i <- match(x, strings)
    if (is.na(i)) {
      strings <<- c(strings, x)
      i <- length(strings)
    }
    i - 1L
  }
  sheet_xml <- vapply(sheets, function(rows) {
    row_xml <- vapply(seq_along(rows), function(r) {
      cells <- rows[[r]]
      cell_xml <- vapply(seq_along(cells), function(k) {
        value <- cells[[k]]
        ref <- paste0(col_letter(k), r)
        if (is.null(value) || (length(value) == 1L && is.na(value))) {
          return("")
        }
        if (is.numeric(value)) {
          return(sprintf('<c r="%s"><v>%s</v></c>', ref, sprintf("%.17g", value)))
        }
        sprintf('<c r="%s" t="s"><v>%d</v></c>', ref, string_index(value))
      }, character(1))
      sprintf('<row r="%d">%s</row>', r, paste(cell_xml, collapse = ""))
    }, character(1))
    paste0(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
      paste(row_xml, collapse = ""), "</sheetData></worksheet>"
    )
  }, character(1))

  dir <- tempfile("jmp-xlsx-")
  dir.create(file.path(dir, "_rels"), recursive = TRUE)
  dir.create(file.path(dir, "xl", "_rels"), recursive = TRUE)
  dir.create(file.path(dir, "xl", "worksheets"), recursive = TRUE)
  ns_rel <- "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  ct <- "application/vnd.openxmlformats-officedocument.spreadsheetml"
  n <- length(sheets)
  writeLines(paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
    '<Default Extension="xml" ContentType="application/xml"/>',
    sprintf('<Override PartName="/xl/workbook.xml" ContentType="%s.sheet.main+xml"/>', ct),
    paste(sprintf('<Override PartName="/xl/worksheets/sheet%d.xml" ContentType="%s.worksheet+xml"/>', seq_len(n), ct), collapse = ""),
    sprintf('<Override PartName="/xl/sharedStrings.xml" ContentType="%s.sharedStrings+xml"/>', ct),
    "</Types>"
  ), file.path(dir, "[Content_Types].xml"), useBytes = TRUE)
  writeLines(paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    sprintf('<Relationship Id="rId1" Type="%s/officeDocument" Target="xl/workbook.xml"/>', ns_rel),
    "</Relationships>"
  ), file.path(dir, "_rels", ".rels"), useBytes = TRUE)
  writeLines(paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    sprintf('<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="%s"><sheets>', ns_rel),
    paste(sprintf('<sheet name="%s" sheetId="%d" r:id="rId%d"/>', xml_escape(names(sheets)), seq_len(n), seq_len(n)), collapse = ""),
    "</sheets></workbook>"
  ), file.path(dir, "xl", "workbook.xml"), useBytes = TRUE)
  writeLines(paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    paste(sprintf('<Relationship Id="rId%d" Type="%s/worksheet" Target="worksheets/sheet%d.xml"/>', seq_len(n), ns_rel, seq_len(n)), collapse = ""),
    sprintf('<Relationship Id="rId%d" Type="%s/sharedStrings" Target="sharedStrings.xml"/>', n + 1L, ns_rel),
    "</Relationships>"
  ), file.path(dir, "xl", "_rels", "workbook.xml.rels"), useBytes = TRUE)
  for (i in seq_len(n)) {
    writeLines(sheet_xml[[i]], file.path(dir, "xl", "worksheets", sprintf("sheet%d.xml", i)), useBytes = TRUE)
  }
  writeLines(paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    sprintf('<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="%d" uniqueCount="%d">', length(strings), length(strings)),
    paste(sprintf('<si><t xml:space="preserve">%s</t></si>', xml_escape(enc2utf8(strings))), collapse = ""),
    "</sst>"
  ), file.path(dir, "xl", "sharedStrings.xml"), useBytes = TRUE)

  target <- file.path(normalizePath(dirname(path)), basename(path))
  unlink(target)
  old <- setwd(dir)
  on.exit(setwd(old), add = TRUE)
  status <- utils::zip(target, files = ".", flags = "-X -r -q")
  if (!identical(as.integer(status), 0L)) stop("zip failed for ", path)
  invisible(target)
}

labels <- function(...) list(...)
intro <- list(labels("Introduction"), labels(NULL), labels("Updated August 2025"), labels("Estimates (2000-2024)"))

aaa <- list(
  labels("Summary of data from national surveys, censuses and regulators"),
  labels("[values in square brackets not used]", NULL, NULL, "Drinking water"),
  labels(NULL, NULL, NULL, "Total", NULL, "Urban", NULL, "Rural", NULL, "Urban", "Sanitation"),
  labels("Source", "Type", "Year", "Improved", "Piped", "Improved", "Piped", "Improved", "Piped", "Accessible on premises", "Improved"),
  labels("source", "type", "year", "w_imp_t", "w_pip_t", "w_imp_u", "w_pip_u", "w_imp_r", "w_pip_r", "w_premises_u", "s_imp_t"),
  labels("AAA_1997_MICS", "Survey", 1997, 50, 20, 60, 30, 40, 10, NULL, 33),
  labels("AAA_2003_MICS", "Survey", 2003, 45, NULL, 56.7, "[21.1]", 40, NULL, NULL, 33),
  labels("AAA_2008_DHS", "Survey with microdata", 2008, "[44]", "[8]", "[60]", "[30]", NULL, NULL, "[45]", 12),
  labels("AAA_2012_CEN", "Census", 2012, 70, 60, 80, 70, 64.451185778814406, 2.6450649313964001, 75, 50),
  labels("AAA_2016_DHS", "Survey", 2016, 80, 70, 90, 80, 70, 60, 85, 55),
  labels("AAA_2021_MICS", "Survey", 2021, 85, 75, 95, 85, 75, 65, 90, 60),
  labels("AAA_2025_MICS", "Survey", 2025, 88, 78, 96, 88, 78, 68, 92, 61),
  labels(NULL),
  labels("Note: bracketed values were not used in the estimates")
)

bbb <- list(
  labels("Summary of data from national surveys, censuses and regulators"),
  labels("[values in square brackets not used]", NULL, NULL, "Drinking water"),
  labels(NULL, NULL, NULL, "National", NULL, "Urban", NULL, "Rural"),
  labels("Source", "Type", "Year", "Improved", "Surface water", "Improved", "Surface water", "Improved", "Surface water"),
  labels("source", "type", "year", "w_imp_n", "w_sur_n", "w_imp_u", "w_sur_u", "w_imp_r", "w_sur_r"),
  labels("BBB_2005_CEN", "Census", 2005, 99, 0.2, 100, 0, "[97]", "[1]"),
  labels("BBB_2015_REG", "Regulator data", 2015, 99.6, NULL, 100, NULL, NULL, NULL),
  labels("BBB_2019_REG", "Regulator data", 2019, 99.7, NULL, 99.9, NULL, NULL, NULL)
)

ccc <- list(
  labels("Summary of data from national surveys, censuses and regulators"),
  labels("[values in square brackets not used]"),
  labels(NULL, NULL, NULL, "Total", "Urban", "Rural"),
  labels("Source", "Type", "Year", "Improved", "Improved", "Improved"),
  labels("source", "type", "year", "w_imp_t", "w_imp_u", "w_imp_r"),
  labels("[Unique code]", "[Type]", NULL, NULL, NULL, NULL)
)

write_workbook(file.path(out_dir, "AAA.xlsx"), list(Introduction = intro, `Data Summary` = aaa))
write_workbook(file.path(out_dir, "BBB.xlsx"), list(Introduction = intro[c(1, 2, 4)], `Data Summary` = bbb))
write_workbook(file.path(out_dir, "CCC.xlsx"), list(`Data Summary` = ccc))

# =============================================================================
# build_availability.R — matrix workbook -> ccw_availability.csv
#
# Re-run when CMS publishes a revised availability matrix. Reshapes the
# workbook's two wide sheets (MAX, TAF) into one long state-year table.
#
#   Rscript references/build_availability.R
# =============================================================================

if (!requireNamespace("readxl", quietly = TRUE)) {
  stop("Needs the 'readxl' package: install.packages('readxl')", call. = FALSE)
}
suppressPackageStartupMessages(library(data.table))

.root <- if (nzchar(Sys.getenv("BLUEPRINT_ROOT"))) Sys.getenv("BLUEPRINT_ROOT") else getwd()
src <- file.path(.root, "references", "max-taf-availability-matrix.xlsx")
dst <- file.path(.root, "references", "ccw_availability.csv")
stopifnot("workbook not found" = file.exists(src))

# The workbook carries the same states on both sheets, with overlapping year
# columns. Reading both and de-duplicating on (state, year) is deliberate: the
# TAF sheet is authoritative for the transition years it covers.
long <- rbindlist(lapply(readxl::excel_sheets(src), function(sh) {
  w <- setDT(readxl::read_excel(src, sheet = sh))
  yr_cols <- grep("^Medicaid Data Source for", names(w), value = TRUE)
  m <- melt(w, id.vars = c("State Name", "FIPS_ALPHA", "FIPS_NUM",
                           "First T-MSIS Submission Date"),
            measure.vars = yr_cols, variable.name = "col",
            value.name = "data_source", variable.factor = FALSE)
  # "...for 2017 and Later Years" -> 2017, expanded below
  m[, year := as.integer(sub(".*for (\\d{4}).*", "\\1", col))][, col := NULL]
  m[, sheet := sh]
  m[]
}), use.names = TRUE)

setnames(long, c("State Name", "FIPS_ALPHA", "FIPS_NUM",
                 "First T-MSIS Submission Date"),
         c("state_name", "state_cd", "fips", "first_tmsis_submission"))
long <- long[!is.na(data_source) & nzchar(data_source)]

# TAF sheet wins where the two disagree on a shared year.
setorder(long, state_cd, year, -sheet)
long <- unique(long, by = c("state_cd", "year"))

# Expand "2017 and later years" through the panel end.
LAST_YEAR <- 2023L
tail_rows <- long[year == 2017L]
if (nrow(tail_rows)) {
  extra <- rbindlist(lapply(2018:LAST_YEAR, function(y) copy(tail_rows)[, year := y]))
  long  <- unique(rbind(long, extra), by = c("state_cd", "year"))
}

long[, first_tmsis_submission := as.character(as.Date(
  as.integer(first_tmsis_submission), origin = "1899-12-30"))]
setorder(long, state_cd, year)

fwrite(long[, .(state_name, state_cd, fips, first_tmsis_submission,
                year, data_source)], dst)

message(sprintf("wrote %d state-year rows, %d states, %d-%d",
                nrow(long), uniqueN(long$state_cd),
                min(long$year), max(long$year)))
print(long[, .N, by = data_source][order(-N)])

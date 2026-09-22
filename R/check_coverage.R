# =============================================================================
# check_coverage.R — Fail before you write
#
# Call this inside every "format an output file" step of the generator, AFTER
# the columns are assembled and BEFORE the file is written. If a canonical
# column is missing or misspelled, the run aborts in seconds with a message
# naming the file and the field — instead of the next pipeline step silently
# inheriting the typo, or the bug surfacing three weeks later on real data.
#
# This is a ten-line function. It is also, empirically, the single highest-
# yield thing in this repo: it catches at least one real bug per refactor.
# =============================================================================


# ---------------------------------------------------------------------------
# check_coverage()
#
# Args:
#   out       the data.frame / data.table about to be written
#   cols      list or character vector of expected column names —
#             e.g. TAF$OT$HEADER (list keys are ignored, values are used)
#   label     short string for the error message, e.g. "TAF OT HEADER"
#   strict    if TRUE, also error on columns OUTSIDE the canonical set.
#             Default FALSE: extras are allowed, because generators often
#             carry scratch columns that get dropped at write time.
#             Turn it on once the formatter is stable.
#
# Errors:  stop() naming the missing (or extra) columns.
# Returns: `out`, invisibly — so it can be used inline in a pipeline.
# ---------------------------------------------------------------------------
check_coverage <- function(out, cols, label, strict = FALSE) {
  expected <- unname(unlist(cols))
  miss <- setdiff(expected, names(out))
  if (length(miss) > 0L) {
    stop(sprintf("[%s] missing canonical columns (%d): %s",
                 label, length(miss), paste(miss, collapse = ", ")),
         call. = FALSE)
  }
  if (isTRUE(strict)) {
    extra <- setdiff(names(out), expected)
    if (length(extra) > 0L) {
      stop(sprintf("[%s] unexpected columns outside canonical set (%d): %s",
                   label, length(extra), paste(extra, collapse = ", ")),
           call. = FALSE)
    }
  }
  invisible(out)
}


# ---------------------------------------------------------------------------
# order_canonical()
#
# Reorder `out` so canonical columns come first, in registry order, with any
# extras trailing. Real files have a column ORDER as well as a column set;
# matching it costs nothing and makes side-by-side diffs of a synthetic file
# against a real one readable.
# ---------------------------------------------------------------------------
order_canonical <- function(out, cols) {
  expected <- unname(unlist(cols))
  keep <- c(intersect(expected, names(out)), setdiff(names(out), expected))
  if (inherits(out, "data.table")) {
    data.table::setcolorder(out, keep)
    out
  } else {
    out[, keep, drop = FALSE]
  }
}

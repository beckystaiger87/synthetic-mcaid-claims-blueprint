# =============================================================================
# suppression.R — Cell suppression for enclave output review
#
# Small aggregated tables are the only thing that leaves a secure enclave, and
# they leave only after a disclosure review. These helpers apply the standard
# small-cell rule BEFORE you request review, which does two things:
#
#   1. Your export request passes on the first try instead of the third.
#   2. The same aggregates can be computed locally on synthetic data, giving
#      you a synth-vs-real comparison in a common schema — which is the
#      calibration loop in docs/06-calibration-loop.md.
#
# THE THRESHOLD BELOW IS A DEFAULT, NOT A RULE FOR YOUR PROJECT. Suppression
# requirements are set by your data-use agreement and your enclave's review
# board, they differ across CMS, state, and all-payer data, and they change.
# Read your DUA, confirm with your review board, and set `threshold`
# accordingly. Passing these functions does not mean an output is cleared —
# only the review board clears an output.
# =============================================================================

library(data.table)

# CMS/CCW's published small-cell threshold at time of writing: counts of 1-10
# are suppressed. Verify against your own agreement before relying on it.
DEFAULT_THRESHOLD <- 11L


# ---------------------------------------------------------------------------
# mask_small_cells()
#
# Applies two layers:
#
#   PRIMARY        cells with count in [1, threshold-1] are masked.
#   COMPLEMENTARY  within each `group_cols` grouping, if EXACTLY ONE cell was
#                  primary-masked, the smallest surviving non-zero cell is
#                  masked too. Otherwise the masked value is recoverable by
#                  subtracting the visible cells from the group total — which
#                  is the mistake that gets an export rejected.
#
# Zero cells are kept: a count of zero discloses nothing.
#
# Args:
#   dt          one row per cell
#   count_col   the count column to test
#   value_cols  derived columns (means, shares, sums) to mask alongside it.
#               FORGETTING THESE IS THE COMMON LEAK: masking n while leaving
#               a share computed from n publishes n.
#   group_cols  grouping within which complementary suppression applies —
#               normally whatever a reader could total across. NULL disables it.
#   threshold   see the note at the top of this file.
#
# Returns: a copy with masked cells set to NA plus a logical `suppressed` flag,
#          so a downstream reader can tell a redaction from a true missing.
# ---------------------------------------------------------------------------
mask_small_cells <- function(dt,
                             count_col  = "n",
                             value_cols = character(0),
                             group_cols = character(0),
                             threshold  = DEFAULT_THRESHOLD) {
  dt <- if (!is.data.table(dt)) as.data.table(dt) else copy(dt)
  stopifnot(count_col %in% names(dt))

  dt[, .__n__ := as.numeric(get(count_col))]
  dt[, suppressed := !is.na(.__n__) & .__n__ > 0 & .__n__ < threshold]

  if (length(group_cols) > 0L) {
    dt[, .__row_id__ := .I]
    flagged <- dt[, {
      n_primary <- sum(suppressed)
      cand <- !suppressed & !is.na(.__n__) & .__n__ > 0
      if (n_primary == 1L && any(cand)) {
        list(comp_row = .__row_id__[cand][which.min(.__n__[cand])])
      } else {
        list(comp_row = NA_integer_)
      }
    }, by = group_cols]
    comp <- flagged$comp_row[!is.na(flagged$comp_row)]
    if (length(comp) > 0L) dt[comp, suppressed := TRUE]
    dt[, .__row_id__ := NULL]
  }
  dt[, .__n__ := NULL]

  if (any(dt$suppressed)) {
    idx <- which(dt$suppressed)
    for (col in c(count_col, intersect(value_cols, names(dt)))) {
      set(dt, i = idx, j = col,
          value = if (is.numeric(dt[[col]])) NA_real_ else NA)
    }
  }
  dt[]
}


# ---------------------------------------------------------------------------
# write_diagnostic()
#
# mask_small_cells() + write CSV to <out_dir>/diagnostics/<step>/<name>.csv.
#
# Call the SAME line of code locally on synthetic data and inside the enclave
# on real data. Same script, same schema, same filename — the difference
# between the two files is the calibration signal.
# ---------------------------------------------------------------------------
write_diagnostic <- function(dt, name, step, out_dir,
                             count_col  = "n",
                             value_cols = character(0),
                             group_cols = character(0),
                             threshold  = DEFAULT_THRESHOLD) {
  stopifnot(!missing(out_dir), is.character(out_dir), nzchar(out_dir))
  dir <- file.path(out_dir, "diagnostics", step)
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)

  masked <- mask_small_cells(dt, count_col, value_cols, group_cols, threshold)
  path <- file.path(dir, paste0(name, ".csv"))
  fwrite(masked, path)

  message(sprintf("  [diag] %s/%s: %d cells, %d suppressed (threshold %d)",
                  step, name, nrow(masked), sum(masked$suppressed), threshold))
  invisible(path)
}


# ---------------------------------------------------------------------------
# age_bin() — coarse age bands.
#
# Publishing exact ages invites a re-identification question that publishing
# bands does not. Bin at the point of tabulation, not afterwards.
# ---------------------------------------------------------------------------
age_bin <- function(age) {
  cut(age,
      breaks = c(-Inf, 18, 24, 34, 44, 54, 64, Inf),
      labels = c("<19", "19-24", "25-34", "35-44", "45-54", "55-64", "65+"),
      right = TRUE)
}

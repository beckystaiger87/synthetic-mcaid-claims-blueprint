# =============================================================================
# dq_inject.R — Break the data on purpose
#
# The point of a synthetic generator is NOT to produce clean data. Clean data
# tests nothing. Every known defect in the real files gets a matching injector
# here, so the cleaner has something to catch and you can prove it caught it.
#
# Design rules for this file:
#   * Every rate is an ARGUMENT, never a global. These run across projects.
#   * Every function returns a NEW data.table; nothing is mutated by reference.
#   * Every function is deterministic given set.seed() upstream.
#   * Injection happens LAST, after the row is otherwise complete, so the
#     corruption is the only difference between a good row and a bad one.
#
# See docs/04-dq-injection-catalog.md for what to inject and at what rate.
# =============================================================================

library(data.table)


# ---------------------------------------------------------------------------
# inject_missing_id() — the most important injector
#
# Real claims are missing the servicing provider identifier at high and
# state-varying rates. Two distinct real-world causes produce two distinct
# repair paths in the cleaner, so inject BOTH:
#
#   half the affected rows -> "" (blank)          -> cleaner must DROP them
#   half the affected rows -> a state-assigned    -> cleaner must RESOLVE them
#                             legacy id (LPI)        through an LPI->NPI xwalk
#
# A generator that only blanks the field leaves the entire crosswalk branch
# untested. That branch is usually where the bugs are.
#
# Args:
#   dt         data.table to corrupt
#   id_col     column to corrupt, e.g. "SRVC_PRVDR_NPI"
#   rate       scalar, OR a named vector of per-state rates
#              e.g. c(CA = 0.05, NY = 0.13)
#   state_col  column holding the state, required for per-state rates
#   lpi_col    where to write the legacy id. If the real layout carries the
#              legacy id in its own column (TAF does: SRVC_PRVDR_ID), name it
#              here and the NPI is blanked while the LPI is populated —
#              which is what the real files actually look like.
#              If NULL, the LPI string is written into id_col itself.
#   keep_truth if TRUE, adds `.true_npi` holding the pre-corruption value, so
#              tests can verify the cleaner recovered the RIGHT id, not just
#              some id. Drop this column before writing the file.
# ---------------------------------------------------------------------------
inject_missing_id <- function(dt, id_col, rate, state_col = NULL,
                              lpi_col = NULL, keep_truth = TRUE) {
  dt <- copy(dt)
  if (keep_truth && !".true_npi" %in% names(dt)) {
    dt[, .true_npi := NA_character_]
  }

  .corrupt <- function(dt, idx) {
    n <- length(idx)
    if (n == 0L) return(dt)
    n_lpi <- round(n * 0.50)                       # half legacy-id, half blank
    if (n_lpi > 0L) {
      lpi_idx <- idx[seq_len(n_lpi)]
      if (keep_truth) dt[lpi_idx, .true_npi := as.character(get(id_col))]
      # LPI format is deliberately NOT NPI-shaped, so a wrong-column bug is
      # visible on sight rather than silently plausible.
      lpi_val <- sprintf("LPI%08d", seq_along(lpi_idx))
      if (is.null(lpi_col)) {
        dt[lpi_idx, (id_col) := lpi_val]
      } else {
        dt[lpi_idx, (lpi_col) := lpi_val]
        dt[lpi_idx, (id_col)  := ""]
      }
    }
    if (n_lpi < n) {
      blank_idx <- idx[(n_lpi + 1L):n]
      if (keep_truth) dt[blank_idx, .true_npi := as.character(get(id_col))]
      dt[blank_idx, (id_col) := ""]
    }
    dt
  }

  if (is.null(state_col) || !state_col %in% names(dt)) {
    r <- if (length(rate) == 1L) rate else mean(rate)
    n_miss <- round(nrow(dt) * r)
    if (n_miss > 0L) dt <- .corrupt(dt, sample(nrow(dt), n_miss))
    return(dt)
  }

  states <- if (!is.null(names(rate))) names(rate) else unique(dt[[state_col]])
  for (st in states) {
    idx <- which(dt[[state_col]] == st)
    if (length(idx) == 0L) next
    r <- if (!is.null(names(rate))) rate[[st]] else rate
    if (is.null(r) || is.na(r)) next
    n_miss <- round(length(idx) * r)
    if (n_miss > 0L) dt <- .corrupt(dt, sample(idx, n_miss))
  }
  dt
}


# ---------------------------------------------------------------------------
# inject_offyear_dates()
#
# Real claim files routinely contain rows whose service date is outside the
# file's nominal year: late-filed prior-year claims (the common case) and
# forward-dated data-entry errors (rarer). Split 70/30 to match.
#
# What this tests: that your cleaner derives year from the DATE COLUMN and not
# from the FILENAME. Almost every first-draft pipeline gets this wrong, and it
# is invisible until someone asks why 2019 has claims from 2018.
#
# Preserves the column's original type — writing a character date into a Date
# column coerces to NA, which would make the cleaner drop the row as missing
# and never exercise the off-year path at all.
# ---------------------------------------------------------------------------
inject_offyear_dates <- function(dt, date_cols, file_year, rate = 0.01,
                                 verbose = TRUE) {
  dt <- copy(dt)
  if (nrow(dt) == 0L) return(dt)
  n_shift <- max(1L, round(nrow(dt) * rate))
  shift_idx <- sample(nrow(dt), n_shift)
  n_back <- round(n_shift * 0.70)
  n_fwd  <- n_shift - n_back

  for (col in date_cols) {
    if (!col %in% names(dt)) next
    orig_is_char <- is.character(dt[[col]])
    vals <- as.Date(dt[[col]][shift_idx])
    if (n_back > 0L) vals[1:n_back] <- vals[1:n_back] - 365L
    if (n_fwd  > 0L) vals[(n_back + 1L):n_shift] <- vals[(n_back + 1L):n_shift] + 365L
    set(dt, i = shift_idx, j = col,
        value = if (orig_is_char) format(vals, "%Y-%m-%d") else vals)
  }
  if (verbose) {
    message(sprintf("  [dq] off-year dates: year=%d n=%d (back=%d, fwd=%d)",
                    file_year, n_shift, n_back, n_fwd))
  }
  dt
}


# ---------------------------------------------------------------------------
# inject_duplicate_rows()
#
# Resubmitted claims and file regenerations produce exact duplicate rows.
# Tests that the cleaner de-duplicates on the natural key rather than assuming
# the source file is unique.
# ---------------------------------------------------------------------------
inject_duplicate_rows <- function(dt, rate = 0.01, verbose = TRUE) {
  if (nrow(dt) == 0L) return(dt)
  n_dup <- max(1L, round(nrow(dt) * rate))
  if (verbose) message(sprintf("  [dq] duplicate rows: n=%d", n_dup))
  rbind(dt, dt[sample(nrow(dt), n_dup, replace = TRUE)])
}


# ---------------------------------------------------------------------------
# inject_near_duplicate_rows()
#
# The nastier sibling of the above: same natural key, one trivial field
# different (an adjudication timestamp, an adjustment indicator). `unique()`
# will NOT collapse these — the cleaner needs an explicit rule about which
# copy wins. If your project never injects these, that rule is untested.
# ---------------------------------------------------------------------------
inject_near_duplicate_rows <- function(dt, jitter_col, rate = 0.01,
                                       jitter_fn = NULL, verbose = TRUE) {
  if (nrow(dt) == 0L || !jitter_col %in% names(dt)) return(dt)
  n_dup <- max(1L, round(nrow(dt) * rate))
  dups <- copy(dt[sample(nrow(dt), n_dup, replace = TRUE)])
  if (is.null(jitter_fn)) {
    jitter_fn <- function(x) {
      if (inherits(x, "Date")) x + 1L
      else if (is.numeric(x))  x + 1
      else paste0(as.character(x), "R")     # "R" for resubmission
    }
  }
  set(dups, j = jitter_col, value = jitter_fn(dups[[jitter_col]]))
  if (verbose) message(sprintf("  [dq] near-duplicate rows: n=%d (differ on %s)",
                               n_dup, jitter_col))
  rbind(dt, dups)
}


# ---------------------------------------------------------------------------
# mask_person_id()
#
# A share of real rows carry no cross-source person identifier at all — the
# state-id-to-CCW-id linkage failed. These rows still have a state-assigned id
# and a state code, which together form a usable fallback key.
#
# Pass the set of person ids chosen upstream (in the cohort/universe step), not
# a rate — so the SAME people are unlinked in every file, which is what makes
# the fallback key testable across a join.
#
# The downstream rule this exercises is a real analytic decision, not a
# formatting one: bene-level analyses must DROP these rows (no stable person
# identifier means within-person change is not measurable), while provider- and
# market-level counts must KEEP them (dropping them systematically understates
# volume). See docs/04-dq-injection-catalog.md § Unlinked person ids.
# ---------------------------------------------------------------------------
mask_person_id <- function(dt, unlinked_ids, id_col = "BENE_ID") {
  if (length(unlinked_ids) == 0L || !id_col %in% names(dt)) return(dt)
  dt <- copy(dt)
  hit <- dt[[id_col]] %chin% unlinked_ids
  if (any(hit)) dt[hit, (id_col) := NA_character_]
  dt
}


# ---------------------------------------------------------------------------
# inject_code_length_drift()
#
# Codes that are nominally fixed-width arrive at other widths: NDCs at 9/11/13
# characters, ZIPs at 5/9, ids zero-padded or not. Tests that the cleaner
# normalizes width instead of assuming it.
# ---------------------------------------------------------------------------
inject_code_length_drift <- function(dt, code_col, rate = 0.10, suffix = "00",
                                     verbose = TRUE) {
  if (nrow(dt) == 0L || !code_col %in% names(dt)) return(dt)
  dt <- copy(dt)
  n_mixed <- round(nrow(dt) * rate)
  if (n_mixed > 0L) {
    idx <- sample(nrow(dt), n_mixed)
    dt[idx, (code_col) := paste0(get(code_col), suffix)]
    if (verbose) message(sprintf("  [dq] code-length drift on %s: n=%d",
                                 code_col, n_mixed))
  }
  dt
}


# ---------------------------------------------------------------------------
# inject_placeholder_value()
#
# One submitter reports a constant sentinel ("999999999", "UNKNOWN", "00000")
# for a field instead of the real value. This is a per-source defect, not a
# random one, so it is invisible to a national rate check and only shows up in
# a by-submitter tabulation.
#
# Injecting it is what makes "tabulate this field BY STATE AND PLAN before you
# trust it" a lesson your pipeline teaches you locally, rather than one you
# learn from a referee.
# ---------------------------------------------------------------------------
inject_placeholder_value <- function(dt, col, where, value = "999999999",
                                     verbose = TRUE) {
  if (nrow(dt) == 0L || !col %in% names(dt)) return(dt)
  dt <- copy(dt)
  hit <- where(dt)
  if (any(hit)) {
    dt[hit, (col) := value]
    if (verbose) message(sprintf("  [dq] placeholder '%s' in %s: n=%d rows",
                                 value, col, sum(hit)))
  }
  dt
}


# ---------------------------------------------------------------------------
# inject_id_reassignment()
#
# Person ids are not always stable across a data-era boundary — a share of
# people are assigned a new id when the source system changes. Build the
# crosswalk once in the cohort step, then apply it to every later-era file.
#
# Tests: whether your cross-era linkage silently loses those people. It will,
# unless someone wrote code that says otherwise.
# ---------------------------------------------------------------------------
apply_id_reassignment <- function(dt, xwalk, id_col = "BENE_ID") {
  stopifnot(is.data.frame(xwalk),
            all(c("old_id", "new_id") %in% names(xwalk)),
            id_col %in% names(dt))
  dt <- copy(dt)
  m <- match(dt[[id_col]], xwalk$old_id)
  hit <- !is.na(m)
  if (any(hit)) dt[hit, (id_col) := xwalk$new_id[m[hit]]]
  dt
}

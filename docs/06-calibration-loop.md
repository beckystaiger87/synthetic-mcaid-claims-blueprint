# The calibration loop

How to make synthetic distributions match real ones **without any microdata leaving the enclave**.

Tier 3 in [03-fidelity-tiers.md](03-fidelity-tiers.md). Most projects do not need it. Build it when a *magnitude* matters for a decision — whether a restriction leaves enough power, whether an outcome is common enough to study, whether a submitter's fill rate makes their data unusable.

---

## The loop

```
   LOCAL (synthetic)                    ENCLAVE (real)
   ─────────────────                    ──────────────
   cleaning pipeline                    cleaning pipeline
          │                                    │
          ▼                                    ▼
   _output/intermediate/                _output/intermediate/
          │                                    │
          ▼                                    ▼
   moment scripts  ◄─── same code ───►  moment scripts
          │                                    │
          ▼                                    ▼
   diagnostics/calibration/             diagnostics/calibration/
                                               │
                                        disclosure review
                                               │
                                               ▼
                              _data/calibration_moments/<yyyy-mm-dd>/
                                               │
                                               ▼
                                  generator's .apply_calibration()
                                               │
                                               ▼
                                     regenerate, and verify
```

Same script both sides. Same output schema. **The difference between the two files is the calibration signal.**

Nothing but suppression-compliant aggregates ever crosses the boundary.

---

## What makes a good moment, and which parameters deserve one

Both lists are in [`SYNTHETIC-DATA-BLUEPRINT.md`](../SYNTHETIC-DATA-BLUEPRINT.md) §5. One requirement that matters operationally and is not in the short version: **a moment must tolerate a missing input**, stopping with a clear message when its input intermediate is absent rather than failing obscurely halfway through a batch.

When in doubt about whether to add one: *would a mismatch between synthetic and real mask a real bug, or invalidate a downstream decision?* If yes, add the moment.

---

## Cell suppression

`R/suppression.R` implements the standard two layers:

- **Primary** — cells with a count in [1, threshold−1] are masked.
- **Complementary** — within each grouping, if exactly one cell was primary-masked, the smallest surviving non-zero cell is masked too. Otherwise the masked value is recoverable by subtracting the visible cells from the group total, which is what gets an export rejected.
- Zero cells are kept: a count of zero discloses nothing.

```r
write_diagnostic(dt, name, step, out_dir,
                 count_col  = "n",
                 value_cols = c("share", "mean"),   # do not omit these
                 group_cols = "STATE_CD")
```

**The threshold in this repository is a default, not a rule for your project.** Suppression requirements come from your data-use agreement and your review board, they differ across CMS, state, and all-payer data, and they change. Read your DUA and confirm before relying on any number. Passing these functions does not mean an output is cleared — only the review board clears an output.

**The most common leak** is masking `n` while publishing a share computed from `n`. That publishes `n`. Every derived column goes in `value_cols`.

**For single-row aggregates** with no group to suppress within, direct writing is sometimes defensible — but only when the value is inherently public, and document the call.

---

## Wiring feedback into the generator

At the top of the generator, after the default parameter list:

```r
.apply_calibration <- function(synth, config) {
  root <- file.path(config$project_root, "_data", "calibration_moments")
  if (!dir.exists(root)) return(synth)
  snaps <- list.dirs(root, recursive = FALSE)
  if (!length(snaps)) return(synth)
  latest <- snaps[which.max(basename(snaps))]     # dated dirs sort correctly

  f <- file.path(latest, "<topic>_<grain>.csv")
  if (file.exists(f)) {
    m <- fread(f)
    if (all(c(<expected_cols>) %in% names(m))) {   # validate before trusting
      m <- m[suppressed == FALSE]                  # drop masked rows first
      old <- synth$<param>
      synth$<param> <- <derive from m>
      message(sprintf("[synth] override: <param> %s -> %s", old, synth$<param>))
    }
  }
  synth
}
synth <- .apply_calibration(synth, config)
```

Four rules:

- **Log every override.** Provenance has to be visible in the run log, or you cannot tell a calibrated run from a defaulted one when something looks odd.
- **Fall back silently** when a snapshot or a file is missing. The pipeline must always run without calibration — a new collaborator with no snapshot should still get working synthetic data.
- **Validate the snapshot schema** before reading. Do not assume a column is there.
- **Drop suppressed rows** before computing shares or weights. They contain `NA`s and will skew any average.

---

## Pitfalls

**Weighted means.** Aggregating a national rate from per-state rates means weighting by cell count: `weighted.mean(m$pct, w = m$n)`, not `mean(m$pct)`. Small states otherwise count as much as large ones.

**Era splits.** If a parameter differs by era, the moment must group by era and the override must respect it. Use one consistent era label everywhere.

**Moments computed downstream of the thing they measure.** A "did the pipeline normalize X?" moment reads zero from a cleaned intermediate, because the pipeline already normalized away the signal. Run it upstream of the normalization, or document the caveat in the header. Do not silently report zero and call it parity.

**Snapshot freshness.** Name snapshot directories by date (`2026-03-15/`) so the natural sort matches the semantics. Picking by modification time eventually picks the wrong directory.

---

## Expect the first pass to be embarrassing

On one project here, the first end-to-end calibration run found an embedded utilization effect at **+53%** and **+98%** against a design of **+20%** and **+10%**. The baseline rates for the comparison arm had been set far too low — a wrong number that had been sitting in the generator for weeks, invisible because there was nothing to compare it against.

The same run surfaced a prior-Medicaid prevalence 10 percentage points below target for one subgroup, and two unrelated bugs in the cleaner: a column referenced by the wrong name, and a state missing from a FIPS-to-alpha lookup, which had been producing blank state codes for eleven thousand people.

**That is the loop working.** If your first calibration run matches everything, be suspicious of the moments rather than pleased with the generator.

---

## Checklist for a new moment

- [ ] Reads only from cleaned intermediates — never from raw files
- [ ] Header documents inputs, outputs, and which generator parameters it recalibrates
- [ ] Uses the suppression helper for every grouped tabulation
- [ ] Derived columns passed in `value_cols`
- [ ] Suppression grouping set to match what a reader could total across
- [ ] Stops with a clear message when its input is missing
- [ ] Registered in the calibration master script
- [ ] Runs end to end on synthetic data before it ever runs in the enclave
- [ ] Has a matching override in `.apply_calibration()`, or a note saying why not

A template is in [`templates/calibration_moment.R`](../templates/calibration_moment.R).

# The defect catalog

**The catalog itself — the defect table, the injection rules, and the per-injector notes — is in [`SYNTHETIC-DATA-BLUEPRINT.md`](../SYNTHETIC-DATA-BLUEPRINT.md) §4.** This note covers what is not in there: where your own catalog should come from, and how it grows.

---

## Yours should not be this one

The catalog in the blueprint is a starting point drawn from Medicaid claims. **It is not a specification, and it is not authoritative for your project.**

Yours should come from two places:

**Your data provider's documentation.** For Medicaid that is the [DQ Atlas](https://www.medicaid.gov/dq-atlas/), which will tell you which states have unusable data in which years for which measures — and that is exactly what your injection rates should be calibrated to. Every provider has an equivalent; find it before you write the first injector.

**What you find on first contact with the real files.** No documentation is complete. The defects you discover yourself are the ones most worth encoding, because nobody else has written them down.

---

## Why keep it as a table

Maintaining the defect-to-handler mapping as an explicit table is the point, not bureaucracy. It is a written, executable record of what you believe about the data, and it replaces the version that usually lives in one person's head and leaves when they graduate.

Three properties follow from keeping it:

- **The generator becomes an executable statement of those beliefs.** Beliefs in prose drift silently; beliefs in code that must run break loudly.
- **Every handler has a stated reason to exist.** A cleaner full of defensive branches nobody can justify is a cleaner nobody dares simplify.
- **A new person can read what the data does to you** without waiting to be surprised by it.

---

## Adding to the catalog

When real data surprises you — and it will — the fix is **two commits, not one**:

1. Fix the cleaner.
2. **Add the injector**, so the fix has a regression test and the next person inherits the knowledge.

Step 2 is the one that gets skipped under deadline. It is also the one that compounds: a catalog that grows every time the data surprises someone is an asset that outlives everyone who built it.

The same applies when a defect turns out **not** to exist, or to have been fixed by the provider. Remove the injector, and say in the commit message why — otherwise the next person re-adds it from the documentation you were working around.

---

## Where the rates come from

Two sources, and they answer different questions.

**Published data-quality documentation** gives you the real prevalence. Use it for anything where the magnitude affects a decision — whether a state is usable, whether a field is worth requesting.

**The calibration loop** ([06-calibration-loop.md](06-calibration-loop.md)) gives you *your* prevalence, in your states and years, measured on the real files and exported as suppression-compliant aggregates. This is the authoritative version, and it is also the expensive one. Reach for it when a rate matters enough to justify an enclave round trip.

In both cases: **rates are arguments, never globals**, because they are the target of that loop.

---

Next: [05-known-truth.md](05-known-truth.md) — scenarios and encoded effects.

# Synthetic Medicaid claims: a blueprint for secure-enclave research

**How to build a synthetic mirror of TAF and MAX, so you can develop, test, and validate your entire pipeline outside the enclave, and port finished code in.**

**Author:** Becky Staiger, UC Berkeley ([@beckystaiger87](https://github.com/beckystaiger87))  
**Last updated:** 15 September 2026

---

## Start here: generate your own synthetic data

**Download [`SYNTHETIC-DATA-BLUEPRINT.md`](SYNTHETIC-DATA-BLUEPRINT.md), open the folder with Claude (or any AI coding assistant), and tell it to follow the blueprint.** That one file carries the whole method — the generation spec, the defect catalog with rates, the known-truth encoding, and the contract your reader has to satisfy.

Take three files, into one folder:

| Download | Why |
|---|---|
| **[`SYNTHETIC-DATA-BLUEPRINT.md`](SYNTHETIC-DATA-BLUEPRINT.md)** | The method. This is the one you point your assistant at. |
| **[`references/ccw_availability.csv`](references/ccw_availability.csv)** | Which state was on MAX vs TAF in which year. There is no national cutover date, and hardcoding one produces wrong data for most states. |
| **[`references/`](references/) record layouts** (3 workbooks) | The authoritative column names. The blueprint deliberately contains none, because they must be read rather than recalled. Three workbooks is ResDAC's packaging — inside are the five analytic file types per era (PS/DE, IP, LT, OT, RX), plus TAF's seven DE subsegments. |

Then say to your assistant:

> Read `SYNTHETIC-DATA-BLUEPRINT.md` in this folder. Follow it to build a synthetic TAF/MAX generator for my project.
>
> My scope: **[states]**, **[years]**, **[what your analysis is about]**.
>
> Before writing any code, read the record layouts in `references/` and build the column registry from them. Do not write a column name you have not read out of a layout file.

Everything else in this repository is supporting material: the reusable helpers in `R/`, and the longer-form documentation in `docs/` that the blueprint condenses.

---

## What this is, and what it is not

**It is a blueprint.** The pattern, the reusable helper code, and a written record of the traps.

**It is not a synthetic dataset.** There is no claims-shaped data to download here, and that is deliberate. A synthetic file is calibrated to one project's states, years, cohort, and questions, and it goes stale the moment CMS revises a layout. Handed to someone else, it is a plausible-looking file whose provenance nobody can reconstruct — which is worse than no file. What travels well is the *recipe*, because you regenerate it for your own project and know exactly what went into it.

**No synthetic observation is derived from restricted data.** Every row is a random draw. Nothing real is copied, perturbed, or reconstructed, and nothing here is a way to approximate data you are not authorized to see. The values are meaningless on their own. Their only job is to have the same *shape* as the real files so your code can be written against them.

**Distributions can still be calibrated to the real data, through disclosure review rather than around it.** When a magnitude matters, run the same moment script on both sides of the enclave wall and let the generator reshape its draws to match. What crosses the boundary is a suppression-compliant table of aggregates, and only after your review board clears it; `R/suppression.R` applies the small-cell rule before you file the request, and `templates/calibration_moment.R` is the starting point for a moment script. See [docs/06-calibration-loop.md](docs/06-calibration-loop.md), and Tier 3 in [docs/03-fidelity-tiers.md](docs/03-fidelity-tiers.md).

---

## Overview

Working directly inside a secure server (e.g., the VRDC or your institution's secure data enclave) can be slow: no internet, gated output review, multi-GB files, shared compute, and no AI coding assistants. Writing your pipeline in there can take a lot of time, even when running on a 1% sample.

Instead, build a synthetic dataset that matches the real files **column for column, file for file, defect for defect**. Develop against it locally with full tooling. Then transfer code onto the secure server that already works.

Six ingredients to make it work:

| | | |
|---|---|---|
| **1** | **Variable names from public data dictionaries** | The synthetic columns *are* the real columns. One canonical registry, sourced by both the generator and the pipeline, and a check that aborts the run before any file is written if a name drifted. Dictionaries are public, but naming differs by vintage and by provider, so the check flags a mismatch and you fix it by hand against the files you actually have. |
| **2** | **Mirror the file structure, including the annoying parts** | Header/line splits, 12 monthly columns, slot×month grids, `BENE_ID` *and* `MSIS_ID`. Every simplification is a code path that goes untested until it runs on real data. |
| **3** | **Harmonize the eras in the reader, not in every script** | One pipeline reads both MAX and TAF. They differ in names, structure, state-code format, and month-suffix padding, and states crossed the boundary in different years. |
| **4** | **Inject the known data-quality issues on purpose** | Missing NPIs, off-year service dates, duplicate rows, sentinel values, unlinked and reassigned `BENE_ID`s. The cleaner needs something to catch; clean data tests nothing. |
| **5** | **Calibrate to real moments** | Public sources first, then suppression-compliant CMS aggregates, so the magnitudes you reason from are not invented. |
| **6** | **Encode truths about the data-generating process** | Hand-built scenarios validate the *cleaning* code. An encoded treatment effect validates the *analysis* code, before it ever touches real data. |

And one reader function that absorbs both of the differences a pipeline script should never have to care about: **which environment you are in** (synthetic CSVs on your laptop, real SAS files on the secure server) and **which era a file is from** (MAX or TAF). A script asks for a state-year, and the reader works out where that file lives, how to read it, and how to normalize its column names, state codes, and month suffixes into one convention.

The result is a property you can check by eye. A cleaning script can read six years across both eras, in two states that changed era in different years, and contain **no `if (env == ...)` and no `if (era == "MAX")`**. It never learns the answer to either question. If a branch on either one shows up anywhere outside the reader, that is the bug, and the fix is to push it back down into the reader. This is what lets the same script run unchanged in both places, which is the whole portability claim.

**The takeaway.** The synthetic files are not uniform, and that is the point. On disk they differ from each other exactly the way real MAX and real TAF differ, and the local CSVs differ again from the enclave's SAS files. One function absorbs all of it, so nothing downstream can tell the VRDC from your laptop, or MAX from TAF. Make the synthetic files *tidier* than the real ones and the harmonization code never runs against anything hard until the day it runs on real data.

*The principle above is the part that ports. The specific normalizations depend on which eras and providers you span, so the reader is the one component you should expect to write yourself; §7 of the blueprint states the contract it has to satisfy.*

---

## What this looks like in practice

The three results below are the argument for the whole method. They come from a pipeline built exactly as this blueprint describes: it generates MAX- and TAF-shaped files for 2 states × 6 years across a per-state era boundary — using **CMS's real availability matrix**, so CA is on MAX through 2015 and FL moves to TAF in 2014 — cleans them through one code path, links people whose `BENE_ID` changed at the boundary, and checks whether a difference-in-differences recovers the effect the generator encoded. It runs in about ten seconds on R and `data.table`.

Three outputs are worth watching for.

**The era boundary is not national.** FL moves to TAF in 2014, CA not until 2016 — so CA's 2015 is a MAX-format file spanning the 2015-10-01 ICD-10 cutover, containing *both* code systems:

```
  diagnosis code system by file era and service year:
      era srvc_year icd10  icd9
1:    MAX      2015  1726   5364     <- both, inside a MAX-format file
2:    TAF      2015  4282  12988     <- both, inside a TAF file
```

**Cross-era linkage is the quietest failure in the pipeline.** A share of people got a new `BENE_ID` at the boundary. Nothing errors if you miss it:

```
  before linking: 3883 apparent people, 2946 observed in both eras
  after linking:  3704 people (179 pairs collapsed), 3099 observed in both eras
  affected people: mean enrolled months 55.7 linked vs 30.0 unlinked
                   (46% of the panel lost)
```

**The validation step catches an analysis bug that runs clean:**

```
  [bene-month] estimate: -0.1425 (SE 0.0050)   95% CI [-0.1523, -0.1327]
  encoded:  -0.1500
  PASS - CI covers the encoded effect.

  [claims-file months] estimate: -0.1667 (SE 0.0076)   95% CI [-0.1817, -0.1518]
  encoded:  -0.1500
  rows: 91998 of 207694 enrolled bene-months (56% of the panel is gone)
  FAIL - off by 11%.
```

The generator encodes: losing your usual provider cuts P(any E&M visit in an enrolled bene-month) by 0.15. The setting is taken from [Staiger (2022), *J. Health Econ.* 81:102574](https://doi.org/10.1016/j.jhealeco.2021.102574), which estimates −3.7pp on a 0.679 pre-exit base per bene-quarter; the synthetic magnitude is deliberately larger, for the same reason the injected defect rates are. The effect is a probability **per enrolled bene-month**, so months with no claim belong in the denominator — and those months exist only in the enrollment file, never in the claims file.

Build the panel from claims, as most pipelines do because claims are what you pulled, and 56% of the panel disappears. Both specifications run without error, both are significant and correctly signed. One is wrong by 11%.

(The test is CI *coverage*, not an exact match — synthetic data is a finite sample, and a check demanding an exact hit would fail constantly and teach you to ignore it.)

On real data there is nothing to compare against, so the second one goes into a table and stays there.

---

## What is in here

```
R/                      Reusable helpers — copy these into your project
  ccw_columns.R           canonical registry, TAF and MAX, era-stable concept keys
  check_coverage.R        abort before writing if a column drifted
  dq_inject.R             the defect injectors
  suppression.R           small-cell suppression for enclave output review

references/             The CMS inputs the generator depends on
  ccw_availability.csv    796 state-years, 58 states, 2010-2023, as a flat table
  max-taf-availability-matrix.xlsx   the source workbook
  record-layout-{taf-claims,taf-demographic-eligibility,max}.xlsx
  build_availability.R    rebuild the CSV when CMS revises the workbook
  README.md               provenance, and what is linked rather than copied

docs/
  01-why.md                     the case, and the honest costs
  02-the-blueprint.md           the full how-to
  03-fidelity-tiers.md          how much realism a given job needs
  04-dq-injection-catalog.md    what to inject, at what rate, caught by what
  05-known-truth.md             scenarios and encoded effects
  06-calibration-loop.md        matching synthetic moments to real ones

templates/              Starting points to copy
slides/                 The MDLN talk
```

**[`SYNTHETIC-DATA-BLUEPRINT.md`](SYNTHETIC-DATA-BLUEPRINT.md) is the single source of truth for the method.** The `docs/` notes do not restate it; each one covers the depth that does not fit in a working specification — [`02`](docs/02-the-blueprint.md) maps the build order, [`03`](docs/03-fidelity-tiers.md) is how much realism your job actually needs, and [`06`](docs/06-calibration-loop.md) is the full calibration machinery.

---

## Adapting this to other data

The setting here is Medicaid because that is the MDLN audience, but nothing in the method is Medicaid-specific. The same structure has been used against Medicare RIFs, Part D, and MA encounter files, and it applies to HCUP, all-payer claims databases, state enclaves, and EHR extracts. The six ingredients do not change; only the column registry, the defect catalog, and the moments you calibrate to do.

Swapping data sources means: replace `R/ccw_columns.R` with your own registry built from **your** data provider's record layouts, and rewrite the injection catalog from **your** provider's known-issues documentation. The rest carries over.

One caution on the column registry. `R/ccw_columns.R` is a small illustrative subset, it is not authoritative, and it will drift from the real layouts. Download the current ones from the [CCW data dictionaries](https://www2.ccwdata.org/web/guest/data-dictionaries) — public, no login — and reconcile against them. **When the official layout and anything in this repository disagree, the layout wins.**

---

## Citing

If this is useful in your work, a pointer back to this repository is welcome. The underlying ideas are not novel — they are ordinary software-testing practice (fixtures, unit tests, known-answer tests) applied to empirical research. The contribution is the translation, and the specific catalog of what goes wrong in Medicaid claims data.

## License

MIT. See [LICENSE](LICENSE).

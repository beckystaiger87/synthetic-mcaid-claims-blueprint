# Synthetic Medicaid claims — generation blueprint

**A self-contained specification for building a synthetic mirror of CMS TAF and MAX claims data.**

This file is written to be handed to an AI coding assistant. It contains the full method, the defect catalog with rates, the known-truth encoding, and the contract your reader must satisfy. It does **not** contain column names, because those must be read from the record layouts rather than recalled — see §1.

Companion repository: <https://github.com/beckystaiger87/synthetic-mcaid-claims-blueprint>

---

## What to download

Three things. The blueprint plus two reference inputs it tells your assistant to read.

| File | Why you need it |
|---|---|
| **`SYNTHETIC-DATA-BLUEPRINT.md`** (this file) | The method, the defect catalog, the truth encoding, the reader contract |
| **`references/ccw_availability.csv`** | Which state was on MAX vs TAF in which year. There is no national cutover date, and hardcoding one produces wrong data for most states. |
| **`references/record-layout-*.xlsx`** | The authoritative column names, types, and value sets. Three **workbooks** — TAF claims, TAF demographic-eligibility, MAX — carrying one sheet per analytic file between them. |

Download all three into one folder. The layouts are also published, publicly and without a login, at the [CCW data dictionaries](https://www2.ccwdata.org/web/guest/data-dictionaries) page — and **the CCW copy wins** if it is newer than the one in this repository.

### What is inside the layout workbooks

Three workbooks is ResDAC's packaging, not a taxonomy of the data. **Each source has five analytic file types** — person/eligibility, inpatient, long-term care, other services, pharmacy — plus ancillary files:

| Workbook | Sheets |
|---|---|
| `record-layout-max.xlsx` | `PS` · `IP` · `LT` · `OT` · `RX` |
| `record-layout-taf-claims.xlsx` | `IP` · `LT` · `OT` · `RX` (+ revision log) |
| `record-layout-taf-demographic-eligibility.xlsx` | `Base` · `Dates` · `Managed Care` · `Waiver` · `MFP` · `Health Home` · `Disability & Need` |

MAX ships all five in one workbook. TAF splits the claim files from demographic-eligibility, and subdivides DE into seven subsegments that are **separate files on the VRDC** — generate the subsegments you actually read, under the real split.

**Long-term care is in the layouts and is not in this blueprint's worked structure.** The `§ What you are building` tree below covers DE/PS, IP, OT, and RX, matching the illustrative registry in the companion repository. If your analysis touches institutional or waiver LTC, add `LT` from the layout sheet the same way — it is an omission of scope, not a claim that the file does not matter.

### Then say this to your assistant

> Read `SYNTHETIC-DATA-BLUEPRINT.md` in this folder. Follow it to build a synthetic TAF/MAX generator for my project.
>
> My scope: **[states]**, **[years]**, **[what your analysis is about]**.
>
> Before writing any code, read the record layouts in `references/` and build the column registry from them. Do not write a column name you have not read out of a layout file. When you are unsure whether a field exists in an era, say so instead of guessing.

Then work through the sections in order. Sections 1 through 6 are the six ingredients; §7 is what a correct reader must do; §8 is how you know it worked.

---

## Rules for the assistant reading this

These are the failure modes specific to this task. They matter more than anything else in this file.

**Column names are looked up, never recalled.** You will be able to produce a confident, well-formatted, entirely fictional CMS column name that matches the real naming convention closely enough to look right. This is the single most damaging thing you can do here, because it is silent — the generator writes it, the pipeline reads it, and nothing errors until it meets real data. Read every name out of a record layout. When a layout and this file disagree, **the layout wins**.

**Do not simplify the structure to get something running.** Every simplification is a code path that goes untested until it runs on real data, in an enclave, on files large enough that debugging costs a day. §2 lists the specific shortcuts and what each one costs. The instinct to flatten a header/line join "for now" is exactly the instinct to suppress.

**Do not invent defect rates, effect sizes, or value sets.** The rates in §4 are a starting catalog with stated provenance. If the user needs rates for their states and years, the source is the [DQ Atlas](https://www.medicaid.gov/dq-atlas/), not your estimate.

**Say when you are unsure.** "MAX may not have this field, check the layout" is useful. A plausible guess is worse than nothing, because it arrives looking verified.

**The generated data is meaningless by construction.** Its values are random draws. Its only job is to have the same *shape* as the real files. Never present synthetic output as though it described anything about Medicaid.

---

## What you are building

A set of files that match the real ones **column for column, file for file, defect for defect** — generated locally, containing no restricted data, and shaped so that a pipeline written against them runs unchanged inside the enclave.

```
_data/synthetic/
  MAX/<year>/maxps_<state>.csv        person summary       (flat)
            maxot_<state>.csv         other services       (flat)
            maxip_<state>.csv         inpatient            (flat)
            maxrx_<state>.csv         pharmacy             (flat)
  TAF/<year>/tafdebse_base_<state>.csv        demographic-eligibility
            tafdebse_mngd_care_<state>.csv    managed care (slot x month)
            tafoth_<state>.csv        other services  HEADER
            tafotl_<state>.csv        other services  LINE
            tafiph_<state>.csv        inpatient       HEADER
            tafipl_<state>.csv        inpatient       LINE
            tafrxl_<state>.csv        pharmacy
  _truth.csv   the answer key, machine-readable
  _truth.md    the answer key, for a human
```

**Long-term care (`LT`) is deliberately absent from this tree**, along with the DE subsegments past Base and Managed Care. Both are in the record layouts. Add them if your analysis needs them, following the same pattern — the tree above is a worked scope, not the full file set.

Which era a given state-year lands in comes from `ccw_availability.csv`, never from a hardcoded rule.

Six ingredients, and skipping any one of them is where projects come unstuck.

---

## 1. Variable names from public data dictionaries

Build **one registry file** mapping a project-friendly concept key to the real column name, organized by era, file, and segment:

```
CCW$TAF$OT$HEADER$billing_npi    ->  (read the TAF claims layout)
CCW$MAX$OT$billing_lpi           ->  (read the MAX layout)
```

Both the generator and the pipeline source it. **Neither ever types a real column name inline.** When CMS revises a layout, one file changes and both ends move together.

Four properties that matter:

**Concept keys stay stable across eras even when the underlying names differ.** The same concept has different SAS names in MAX and TAF — claim type is one example, the payment amount is another, the diagnosis fields are a third. If both eras map to the same concept key, calling code stays era-agnostic and you avoid an `if (era == ...)` in every script. Read both layouts side by side and map them onto shared keys.

**Concept keys are zero-padded in both eras even where the real name is not.** TAF monthly columns are suffixed `_01`…`_12`; the MAX equivalents are `_1`…`_12`. Keep the *key* padded in both, so a consumer asks for month 3 without knowing the era. The key is the stable interface; the SAS name is the thing that varies.

**Wide families are generated in a loop, never typed.** Twelve monthly columns typed out is eleven monthly columns, eventually. A loop is right by construction and the loop bound documents the count. Same for slot × month grids.

**A concept that an era genuinely lacks must raise, not return empty.** MAX has no billing-side NPI — it carries a state-assigned billing id and two separate servicing-provider fields. Asking for a billing NPI in MAX is a bug in the caller, and a lookup that returns nothing propagates as a missing column three steps later, or worse, as a column quietly dropped from a projection. Make the lookup fail loudly, naming the era and the concept.

That last point generalizes: **where two fields look interchangeable, read the layout on which role each one plays.** Provider identifiers on MAX claims are the classic trap — billing versus servicing, NPI versus state-assigned, with fill rates that vary by state and by year. Get this wrong and you have built a provider analysis on the wrong provider.

### A validator that fires before anything is written

Write a small function that checks the assembled columns against the registry, and call it inside every format-and-write step — **after** the columns are assembled, **before** the file lands on disk. If a name drifted, the run aborts in seconds naming the file and the field.

It is roughly ten lines and it is the highest-yield thing in this method. It catches bugs at the point of failure rather than three steps downstream, where the symptom is a merge rate that looks "a bit low."

Keep it permissive about extra scratch columns while the generator is in flux; tighten it once the format is stable.

---

## 2. Mirror the file structure, including the annoying parts

| Tempting shortcut | What it costs you |
|---|---|
| Flatten a header/line claim file into one table | The join is untested. On real data it is a join over multi-GB files. |
| Use one person identifier where the real data has two | Every linkage and fallback path is untested; conflating them hides a whole class of bug |
| Generate 1 of N repeated slots (diagnoses, plans, months) | A cleaner that handles slot 1 correctly silently ignores slots 2+ |
| Simplify dates to years | Hides off-year claims, leap years, SAS numeric dates, sentinel values |
| Generate one year | Hides every year-boundary bug there is |
| Pre-reshape wide files to long | The reshape is a real step your cleaner must do, and people get it wrong |

**The one legitimate simplification is depth, not kind.** Real TAF managed-care enrollment is 16 slots × 12 months. Generating 4 slots is fine — the cleaner is still forced to make an explicit choice about which slots count, which is the thing being tested. Generating 1 is not fine, because there is no choice to make. Generate enough that the decision is forced; past that you are storing zeros.

The structural differences you must preserve:

- **TAF claims split header and line; MAX claims are flat.** No `CLM_ID` join exists in MAX.
- **TAF state codes are two-character alpha; MAX state codes are numeric FIPS.**
- **TAF monthly suffixes are zero-padded; MAX monthly suffixes are not.**
- **Both `BENE_ID` and `MSIS_ID` exist**, they behave differently, and a share of rows are missing the first.
- **TAF demographic-eligibility is split across subsegment files** on the VRDC. Generate the segments you actually read, under the real split.

### Build a cohort step, even for one file

One script produces the **person universe**: one row per person, holding every attribute that must agree across files — identifiers in each system, demographics, coverage windows, era-routing flags, treatment assignment, and which people carry which defects. Every downstream generator reads that file and emits claims or enrollment for the rows it cares about.

For a single-file project this looks like overhead. Do it anyway. The alternative for a multi-source project is keeping several generators aligned by matching random-seed positions, which breaks silently the first time anyone adds a draw to the first script: every downstream universe shifts, nothing errors, and the debugging session is long.

**Pick the anchor to match how the real sample will be built.** If the real analysis starts with Medicare beneficiaries and looks back for Medicaid history, the cohort is Medicare-anchored and Medicaid presence is a covariate. Getting it backwards means the synthetic pipeline tests a sample construction you will never use.

---

## 3. Era boundaries, driven by the availability matrix

Read `ccw_availability.csv`. One row per state-year, with columns `state_name, state_cd, fips, first_tmsis_submission, year, data_source`, where `data_source` is `MAX`, `MAX-T`, `TAF`, or `N/A`.

**There is no national cutover date.** States crossed from MAX to TAF anywhere from 2014 to 2016, and some sat on MAX-T through 2015. Hardcoding one boundary produces wrong data for every state that does not match it.

**`MAX-T` is a MAX-format file, not a third format.** Map both `MAX` and `MAX-T` to the MAX shape, while keeping the distinction in your table — the provenance matters for data-quality expectations even though the layout does not differ.

**`N/A` means the state-year has no file.** Generate nothing, and make sure your pipeline handles the gap rather than assuming a rectangular state × year grid.

### Code systems are date-driven, not era-driven

ICD-9 is used for service dates before 2015-10-01 and ICD-10 on or after, **regardless of which file era the claim sits in**. Calendar 2015 contains both. A state still on MAX in 2015 has a MAX-format file spanning the transition, containing both code systems.

Any function shaped like `icd_for_year(year)` is wrong for 2015. You want `icd_for_date(service_date)`. The companion code-system indicator column moves in lockstep with the code itself.

This is the single most commonly botched thing in cross-era Medicaid work, and generating it correctly is what lets you catch it locally.

---

## 4. Inject the known data-quality issues

Clean data tests nothing. Every defect gets an injector in the generator and a handler in the cleaner, and the mapping is kept as a table — a written, executable record of what you believe about the data, replacing the version that usually lives in one person's head and leaves when they graduate.

**This catalog is a starting point, not a specification.** Yours should come from the [DQ Atlas](https://www.medicaid.gov/dq-atlas/) and from what you find on first contact with the real files.

| Defect | Real-world cause | Injected rate | Caught by |
|---|---|---|---|
| Missing servicing provider id | Legacy id submitted instead of NPI; field unfilled | 5–25%, varies by state and era | Crosswalk lookup, then drop remaining blanks |
| Off-year service dates | Late-filed prior-year claims; entry errors | ~1% *(above real)* | Derive year from the date column, never the filename |
| Exact duplicate rows | Resubmissions, file regenerations | ~1% *(above real)* | Deduplicate on the natural key |
| Near-duplicate rows | Resubmission with a new adjudication stamp | ~0.5% *(above real)* | An explicit which-copy-wins rule |
| Duplicate person-years on enrollment | Cross-state moves (~60%), corrections (~40%) | ~0.5% | Drop all rows for affected person-years |
| Unlinked person id | Cross-source linkage failed | ~1–5% | Fallback key; keep or drop by analysis level |
| Person id reassigned across eras | Ids reassigned at the system transition | ~5% | Era crosswalk applied per submitter |
| Mixed code lengths | 11- vs 13-character NDC; 5- vs 9-digit ZIP | ~10% | Normalize width on read |
| Missing discharge date | Still admitted at extract; degenerate records | ~2% | Fall back to service end date |
| Constant sentinel value | One submitter reports a placeholder always | 1 plan / 1 state | Tabulate the field **by submitter** |
| Partial-year enrollment | Ordinary churn | ~30% of people | Month-level enrollment logic |
| Restricted-benefit enrollment | Emergency-only, family-planning-only coverage | ~5% | Explicit inclusion/exclusion rule |

Rates marked *(above real)* are deliberately inflated so smoke tests can detect them at small sample sizes.

### Five rules for injection

**Apply injection last**, after the row is otherwise complete, so a corrupted row differs from a good one in exactly the injected way.

**Rates are arguments, never globals.** They are the target of the calibration loop in §5.

**Inflate below-threshold rates, and say so in a comment where the rate is set.** A defect at its true 0.1% prevalence in a 600-person sample produces zero corrupted rows and a smoke test that passes because it found nothing. Bump it to 1% and write *rate higher than real (~0.1%) so smoke tests can detect it* — or someone will later "fix" it to match reality and quietly disable your tests.

**Mix corruption modes within one injection.** If a missing provider id can be either blank or a legacy state-assigned id, inject half of each. A one-sided injection leaves half the cleaner untested, and the crosswalk branch is usually the half with the bugs.

**Vary by submitter where the real data varies by submitter.** One state at 6% and another at 14% is not noise — it may mean one state is unusable for a servicing-provider analysis, which is a finding. A national average of 10% describes neither state.

### Notes on specific injectors

**Missing provider id — the important one.** Two real causes produce two repair paths: blank means the cleaner must drop the row; a legacy state-assigned id means the cleaner must resolve it through a crosswalk. Make the legacy id visibly not NPI-shaped (`LPI00000042`, not another ten-digit number) so a wrong-column bug is obvious on sight. Keep the pre-corruption value in a scratch column so tests can verify the cleaner recovered the *right* id, not merely some id — then drop the scratch column before writing. The payoff to watch for: the cleaner's unresolvable rate should come out at roughly *half* the injected rate, because the crosswalk recovered the legacy half. Watching the halving is how you know that branch ran.

**Off-year dates.** Shift a fraction of service dates outside the file's nominal year, split roughly 70/30 backward/forward — late filing is common, forward-dated errors rarer. **Preserve the column's type.** Writing a character date into a date column coerces to missing, the cleaner drops the row, and the off-year path is never exercised at all.

**Near-duplicates.** Exact duplicates collapse under a deduplicate on the natural key. Near-duplicates share the key and differ on one trivial field, so they *also* collapse — silently, keeping whichever copy came first. That is a decision, and the dedup call made it instead of you. Injecting near-duplicates is what makes you notice you had a rule you never stated.

**Unlinked person ids take a set of people, not a rate.** Choose them in the cohort step so the same people are unlinked in *every* file. That consistency is what makes the fallback key testable across a join.

The downstream rule is an analytic decision, not a formatting one:

| Analysis level | Treatment |
|---|---|
| **Person-level** — outcomes, exposure duration, event studies on person-time | **Drop.** A person whose id could not be recovered is effectively a different person between periods, so including them biases within-person change. Report the count and share. |
| **Provider- or market-level** — distinct patients treated, enrollment counts | **Keep**, counting distinct fallback keys. Dropping them understates provider volume, especially where linkage fails most. |
| **Pull and prep scripts** | **Keep.** Let person-level scripts filter at their own top. |

Common bugs: filtering the cohort on the raw id (drops every unlinked row at the front door); asserting uniqueness on the raw id when missing values are present (multiple blanks register as duplicates and the assertion fires); computing coverage metrics on the raw id.

**Constant sentinel values are per-submitter defects.** One plan reporting a placeholder regardless of the true value is invisible in a national rate check and appears only in a by-submitter tabulation. Injecting it turns "tabulate this field by state and plan before you trust it" into a lesson your own pipeline teaches you, instead of one a referee teaches you later.

**Id reassignment across eras.** Build the crosswalk once in the cohort step, apply it to every later-era file. This tests whether your cross-era linkage silently loses those people. It will, unless someone wrote code that says otherwise.

---

## 5. Calibrate to real moments

Random magnitudes are fine for testing code paths and misleading for anything else. If a *magnitude* matters for a decision — whether a restriction leaves enough power, whether an outcome is common enough to study, whether a submitter's fill rate makes their data unusable — calibrate.

**Public sources first.** DQ Atlas fill rates, published enrollment counts, and the layouts' own value sets will get most parameters close without any enclave interaction at all. Do this before anything else.

**Then suppression-compliant aggregates, if you still need them.** Run the same moment script on both sides of the enclave wall. The difference between the two outputs is the calibration signal, and only the aggregate table crosses the boundary — never microdata, and only after your review board clears it.

What makes a moment usable:

1. **Aggregate only.** Output rows are cells, never people or claims.
2. **Identical shape on both sides.** Same script, same columns, same grouping. If behavior must differ, branch on the environment flag *inside* the script, never fork it into two files that drift.
3. **Cell-suppressed before you request review.** Apply your threshold, and apply complementary suppression: if exactly one cell in a group was masked, mask the next-smallest too, or the masked value is recoverable by subtraction. That recoverability is what gets an export rejected.
4. **A documented target.** The header names the generator parameter it recalibrates. If it recalibrates nothing, it belongs in QC, not calibration.

**Suppression thresholds are set by your data-use agreement and your review board**, they differ across CMS, state, and all-payer data, and they change. Read your DUA. Passing a suppression check does not mean an output is cleared — only the review board clears an output.

Which parameters deserve a moment: first, anything affecting a pipeline-level decision (sample restrictions, claim-type filters, missing-id rates, era splits), because getting these wrong changes who is in the sample. Second, anything affecting descriptive volume (claims per person, panel size, participation rates), because wrong values here make the data misleading to reason from. Skip structural parameters from fixed reference tables, and anything downstream of scenarios, which are synthetic by definition.

---

## 6. Encode truths about the data-generating process

Two constructions, validating different halves of the work.

| | Scenarios | Encoded effects |
|---|---|---|
| **Validates** | Cleaning code | Analysis code |
| **Shape** | Hand-built trajectories, reserved ids | A DGP with a known parameter |
| **Checked by** | Assertions in the generator's smoke tests | A validation script that recovers the estimate |
| **Cost** | An hour each | A day or two |

### Scenarios

Five to ten hand-built trajectories with predictable pipeline output. Examples:

- *Enrolled in exactly one month, December, at a year boundary.* Catches off-by-one errors in month-span logic.
- *Switches managed-care plan in April.* Catches cleaners that take one plan per person-year instead of per person-month.
- *No cross-source identifier for the whole panel.* Catches every place that filters or joins on the raw id instead of the fallback key.
- *A claim with a service date in the prior year, filed late.* Catches year-from-filename bugs.

Four rules:

- **Reserved identifiers** (`SCEN0000001`) that no random draw can produce, so a scenario can never be silently contaminated.
- **Self-contained** — every row the scenario needs is inserted as a block. Never rely on random data happening to produce the right combination, because next seed it will not.
- **Documented inline** — a comment stating the expected pipeline output.
- **Asserted** — a matching check in the smoke tests. **A scenario with no assertion is a comment.** This is the rule that gets broken.

When a refactor breaks the cleaner, a named scenario failing tells you *which logic broke*. "Row counts changed, why?" tells you nothing and costs an afternoon.

### Encoded effects

Set a true treatment effect in the DGP, record it, and check that your estimator recovers it.

A concrete instance: a share of providers stop billing Medicaid on one date. For people whose usual provider is one of them, the probability of an E&M visit in an enrolled beneficiary-month drops by 0.15. Everyone else is a control.

The setting is drawn from [Staiger (2022), *J. Health Econ.* 81:102574](https://doi.org/10.1016/j.jhealeco.2021.102574), which estimates −3.7 percentage points on a 0.679 pre-exit base per beneficiary-quarter. **The synthetic magnitude is deliberately larger**, for the same reason the defect rates are: a few-thousand-person sample cannot show a 3.7pp effect the way a 700,000-observation panel can. Say which number is real and which is inflated, wherever both appear.

**Record the unit alongside the parameter.** "A reduction of 0.15" is not a complete statement of an effect; "0.15 fewer per enrolled beneficiary-month" is.

**The truth file is an answer key.** Two sidecars — `_truth.csv` for programmatic assertions, `_truth.md` for a human. Record the parameter, the treated units, the dates, realized rates, and the sample sizes that form the denominators. **Analysis code must never read either file.** Only the validation script opens it, and only after the estimate exists. Say so in a comment in both files, because someone will eventually be tempted to "just check" mid-analysis.

### Why this is the step that pays

Cleaning bugs announce themselves: a merge rate collapses, an assertion fires, a row count is absurd. Analysis bugs do not.

Run the same difference-in-differences twice, varying only where the panel comes from:

```
  [bene-month]          estimate: -0.1425 (SE 0.0050)   PASS
  [claims-file months]  estimate: -0.1667 (SE 0.0076)   FAIL — off by 11%
                        91,998 of 207,694 bene-months (56% of the panel gone)
```

Both run without error. Both are significant, correctly signed, and plausible.

The effect is a probability per **enrolled** beneficiary-month, so months with no claim belong in the denominator — and those months exist only in the enrollment file, because a month with no claim generates no claim row. Build the panel from the claims extract, which is what most pipelines do because claims are what you pulled, and the denominator silently changes from "enrolled" to "enrolled and using care." The second one is itself affected by the treatment.

The direction of that bias is not a general rule; it depends on how the treatment moves non-E&M use relative to E&M use. On real data there is nothing to compare against, so it goes into a table and stays there.

Test **CI coverage, not an exact match.** Synthetic data is a finite sample, and a check demanding an exact hit will fail constantly and teach you to ignore it.

### What a synthetic pass does and does not establish

**Does:** this estimator, on data from a known process, recovers a known parameter — and a plausible-looking variant does not. A real check on the code, cheap, runs on a laptop.

**Does not:** anything about whether the design identifies something real. The generator makes its own assumptions true. If treated and control outcomes are drawn from the same process until the shock date, parallel trends holds by construction, and no synthetic dataset will tell you otherwise.

**A synthetic pass means the code does what you meant. Whether what you meant is identified is a question about the world.** Keep that distinction sharp in writing, especially in a pre-analysis plan or an appendix.

---

## 7. The reader contract

The generator is only half of it. The pipeline that consumes these files must satisfy the contract below, or the portability claim does not hold.

**This section is a specification, not an implementation.** Write the reader for your own project against these requirements.

### What the reader must absorb

**One function** stands between the pipeline and the files, and every difference below is resolved inside it:

| Axis | What differs | What the caller must see |
|---|---|---|
| **Environment** | Local synthetic CSVs vs enclave SAS files; different paths, naming, read calls, projection mechanics | Identical column names and types from both |
| **Era** | MAX flat vs TAF header/line; FIPS vs alpha state codes; unpadded vs padded month suffixes; different SAS names for the same concept | One convention, whichever era the file came from |

The normalization direction is a choice; normalizing MAX to look like TAF is the usual one, because TAF is where the data is going.

### The property that proves it works

A cleaning script should be able to read several years spanning both eras, in states that changed era in different years, and contain **no branch on environment and no branch on era**. It never learns the answer to either question.

If a branch on either one appears anywhere outside the reader, that is the bug, and the fix is to push it back down into the reader. That single property is what lets the same script run unchanged on a laptop and inside the enclave.

### Four requirements that are easy to miss

**Detect the environment, do not configure it.** A flag someone has to remember to flip is a flag that eventually ships wrong. Detect from a filesystem fact true in exactly one place — does the enclave's data library exist?

**Force code-shaped columns to character, explicitly.** Left to guess, a CSV reader parses `"00"` and `"01"` as the integers 0 and 1. The leading zero is gone, every comparison against the code fails, and **nothing errors**. Hold the rule as *patterns* rather than an enumerated list, because the wide families run to hundreds of columns. Rule of thumb: if you would never take its mean, it is not a number. This is not hypothetical — it is the bug that broke a smoke test during development of a pipeline built this way, and nothing else in the run indicated a problem.

**Project columns at the I/O layer.** On real data this is the difference between reading 40 columns and reading 400. Where raw enclave files are large SAS datasets, both `haven::read_sas()` and `pandas.read_sas()` materialize the whole file before subsetting. SAS itself projects at the I/O layer with `KEEP=` / `DROP=` / PROC SQL. The convention that works: SAS touches the raw files, projects, filters to the analytic universe, and writes small intermediates; R or Python picks up from there. **Then generate files shaped like the intermediates**, not like the raw files — so the downstream pipeline is identical in both environments and only the SAS layer is enclave-only.

**Build the fallback person key once, at the read boundary.** Two identifiers are two identifiers. Filter cohorts on the fallback key, not the raw id, and never re-derive the key downstream — two derivations eventually disagree.

---

## 8. How you know it worked

### Smoke tests at the end of the generator

The generator's last section re-reads **its own output through the pipeline's reader** and asserts invariants. Reading the in-memory objects tests nothing — the question is whether what landed on disk is what the pipeline will see.

Assert that:

- File count matches expectation
- Canonical columns survive the read
- Wide families have the right number of columns
- Identifiers came back as character
- Each scenario produces its expected value at its expected date
- Each injection is visible at roughly its expected rate
- Code systems align with calendar dates, not file eras

**Failures are warnings, not errors**, so one broken thing does not hide the other four. Make them loud.

### Three results that tell you the mirror is faithful

If your generator is working, these fall out of it — and each one is a bug class you have now made visible locally:

1. **A single calendar year containing both ICD-9 and ICD-10**, inside a MAX-format file, for a state that had not yet moved to TAF.
2. **A cross-era linkage that loses people** when the id crosswalk is skipped, with no error raised — and a measurable difference in mean enrolled months between the linked and unlinked groups.
3. **Two specifications of the same effect that both run clean**, where only the one built on the enrollment spine recovers the encoded parameter.

---

## The traps that cost the most time

**Date-driven, not era-driven.** Code-system transitions happen on calendar dates, not file boundaries. Any function shaped like `icd_for_year(year)` is wrong for 2015.

**Era boundaries vary by submitter.** Drive them from the availability matrix. There is no national cutover.

**Identifier reassignment across eras.** A share of people get a new id at the transition, and your cross-era linkage silently loses them unless someone wrote code that says otherwise.

**Off-year service dates are real claims.** Late-filed claims carry prior-year service dates. Do not drop them — assign them to the year the service happened, derived from the date column and never from the filename.

**Two identifiers are two identifiers.** Build the fallback key once at the read boundary; filter on it, not the raw id. Person-level analyses drop unlinked rows; provider- and market-level counts keep them. Record the counts either way.

**State codes.** Alpha in one era, FIPS in the other. Normalize inside the reader so nothing downstream branches on it.

**The layout is the contract.** When the layout, your code, a colleague's email, a slide deck, and your own memory disagree, the layout wins. Every time.

---

## The boundary that makes AI assistance safe

**Restricted data never enters a model context. Ever. No exceptions, no "just this one row."**

That is not a preference, it is a term of your data-use agreement. Pasting a claim line into a chat window to ask why a parse failed is a disclosure. So is pasting an error message that contains data values. So is a screenshot.

| | Outside the enclave | Inside the enclave |
|---|---|---|
| **Data** | Synthetic. Random draws. | Real. Restricted. |
| **AI assistance** | Yes | No — usually unavailable anyway |
| **What happens here** | Writing, testing, debugging, iterating | Running finished code |
| **What crosses in** | Code, reviewed by you | — |
| **What crosses out** | — | Suppression-compliant aggregates, after review |

Because the synthetic files have the same shape as the real ones, essentially all debugging happens on the left. When something fails on the right, the first move is to reproduce it on the left — which usually means the generator was missing a defect, and the fix is to add it.

**Watch what your tools upload.** An editor with an AI extension, a notebook with a cloud backend, a terminal assistant that reads scrollback — several of these send file contents or command output to a remote service by default. Inside an enclave that is a disclosure. Know which of your tools do what, and configure them per environment rather than trusting yourself to remember.

---

## Adapting this to other data

Nothing in the method is Medicaid-specific. The same structure applies to Medicare RIFs, Part D, MA encounter files, HCUP, all-payer claims databases, state enclaves, and EHR extracts.

Swapping data sources means: build the column registry from **your** provider's record layouts, and rewrite the defect catalog from **your** provider's known-issues documentation. The six ingredients do not change; only the registry, the catalog, and the moments you calibrate to do.

---

## Credits and license

Becky Staiger, UC Berkeley. MIT licensed.

Companion repository, with the reusable helper code and the longer-form documentation: <https://github.com/beckystaiger87/synthetic-mcaid-claims-blueprint>

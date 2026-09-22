# The blueprint

**The canonical statement of the method is [`SYNTHETIC-DATA-BLUEPRINT.md`](../SYNTHETIC-DATA-BLUEPRINT.md) in the repository root.** That file is self-contained, written to be handed to an AI coding assistant, and it is the one to read if you want the method itself.

This note is the orientation map: the order you build things in, and where each step is written up in depth.

---

## The order you build it

| # | Step | Canonical | Deeper |
|---|---|---|---|
| **0** | Read the record layouts and the known-issues documentation. Nothing else starts until these are on disk. | blueprint, "Rules for the assistant" | [CCW layouts](https://www2.ccwdata.org/web/guest/data-dictionaries), [DQ Atlas](https://www.medicaid.gov/dq-atlas/) |
| **1** | One canonical column registry, sourced by both the generator and the pipeline | blueprint §1 | `R/ccw_columns.R` |
| **2** | A coverage validator that fires before anything is written | blueprint §1 | `R/check_coverage.R` |
| **3** | Mirror the real structure, including the annoying parts | blueprint §2 | — |
| **4** | A cohort step, even for one file | blueprint §2 | — |
| **5** | Inject the defects | blueprint §4 | [04-dq-injection-catalog.md](04-dq-injection-catalog.md) |
| **6** | Encode known truths — scenarios and an effect | blueprint §6 | [05-known-truth.md](05-known-truth.md) |
| **7** | One environment toggle, one reader | blueprint §7 | — |
| **8** | Heavy I/O in the enclave's native tool | blueprint §7 | — |
| **9** | Smoke tests that re-read the generator's own output | blueprint §8 | — |
| **10** | Calibrate from the enclave, without moving microdata | blueprint §5 | [06-calibration-loop.md](06-calibration-loop.md) |

How much of this a given project needs is the subject of [03-fidelity-tiers.md](03-fidelity-tiers.md). Most projects do not need all of it, and building tier 3 when tier 0 would do is the most common way to waste a month.

---

## The three things people skip

Worth naming separately, because they are the ones that get dropped under deadline and they are each load-bearing.

**The validator (step 2).** Ten lines, called before every write. It catches at least one real bug per refactor, at the point of failure rather than three steps downstream where the symptom is a merge rate that looks "a bit low."

**The encoded effect (step 6).** This is the step most projects skip, and it is the one that catches wrong-unit-of-analysis, wrong-comparison-group, and wrong-window bugs — the ones that run clean and return a plausible number. Cleaning bugs announce themselves; analysis bugs do not.

**The injector that follows a fix (step 5).** When real data surprises you, the fix is two commits, not one: fix the cleaner, *then* add the injector, so the fix has a regression test and the next person inherits the knowledge. The second commit is the one that gets skipped, and it is the one that compounds.

---

Next: [03-fidelity-tiers.md](03-fidelity-tiers.md) — how much realism a given job actually needs.

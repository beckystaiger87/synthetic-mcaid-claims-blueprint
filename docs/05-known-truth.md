# Known truths: scenarios and encoded effects

**The constructions themselves — what a scenario is, the four rules, the encoded effect, the truth file, and what a synthetic pass does and does not establish — are in [`SYNTHETIC-DATA-BLUEPRINT.md`](../SYNTHETIC-DATA-BLUEPRINT.md) §6.** This note covers what is not in there: how to choose scenarios, and the three other jobs a truth file turns out to do.

---

## Choosing scenarios

Five to ten. Fewer and you miss corner cases; more and they become a maintenance burden nobody keeps current.

Pick them by asking: *what does this pipeline need to demonstrate it handles correctly?* Then write one scenario per answer. The question is about your pipeline, not about the data in general — a scenario testing a code path you do not have is a maintenance cost with no return.

Scenarios drawn from real projects, as a sense of the right grain:

- *"Enrolled in exactly one month, December, at a year boundary."* Catches off-by-one errors in month-span logic, which are otherwise invisible.
- *"Switches managed-care plans in April 2019. Person-months before April show plan A, after show plan B."* Catches cleaners that take one plan per person-year instead of per person-month.
- *"This person has no cross-source identifier for the whole panel."* Catches every place that filters or joins on the raw id instead of the fallback key.

Note what these have in common: each one names an **expected output**, not merely an input. A scenario you cannot state the expected result for is not yet a scenario.

### Why they beat row counts

When a refactor breaks the cleaner, a named scenario failing tells you **which logic broke**. "Row counts changed, why?" tells you nothing and costs an afternoon.

---

## Three other jobs the truth file does

The validation use is the obvious one. These three are why the file keeps earning its cost after the estimator is working.

**Onboarding.** An RA can be given the synthetic data, the pipeline, and the truth file, and asked to recover the encoded effect — a real task with a checkable answer that can be done while their access is still being arranged. One project here used exactly this as an RA's first assignment; the answer key made it possible to give specific feedback without either party having data access.

**Handoff.** When a project changes hands, the scenarios and the truth file document what the pipeline is supposed to do far better than prose does, **because they fail when they stop being true.** A handoff document goes stale silently. A failing assertion does not.

**Refereeing your own work.** Before an arc is finished, running the pipeline end to end on synthetic data and confirming every scenario and the encoded effect still pass is a cheap regression test over the whole thing — and it runs on a laptop, in seconds, as often as you like.

---

## The sentence to be careful with

Worth repeating from the blueprint, because it is the one a referee will press on:

**A synthetic pass means the code does what you meant. Whether what you meant is identified is a question about the world.**

"The estimator recovers the encoded effect in synthetic data" is a statement about code correctness. It is not evidence for the design, and a reader skimming quickly may take it as such if the sentence is loose. Keep the distinction sharp in a pre-analysis plan or an appendix, where the reader is looking for exactly this kind of slippage.

---

Next: [06-calibration-loop.md](06-calibration-loop.md) — making the numbers realistic, without moving microdata.

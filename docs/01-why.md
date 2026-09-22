# Why bother

## The problem

Restricted-data enclaves — the CMS VRDC, HCUP's environment, a state Medicaid enclave, a university VDI — are built for confidentiality, and they achieve it by making almost everything else harder:

- **No internet.** No documentation lookup, no package installs without a ticket, no AI coding assistant.
- **Output review is gated.** Every file you want to remove is reviewed for disclosure risk, often with a multi-day turnaround. A typo in a table costs a round trip.
- **The files are enormous.** Multi-GB SAS datasets mean a mistake costs minutes per iteration, sometimes hours.
- **Compute is shared and capped.** Your job queues behind everyone else's.
- **Session state is fragile.** Long sessions time out, VPNs drop, and work in progress is lost.

None of this is a complaint about enclave design. The constraints exist because the data is genuinely sensitive. But they mean that *writing code* inside the enclave is roughly an order of magnitude slower than writing the same code outside it, and the work is identical either way — the cleaning logic that reshapes a wide enrollment file does not care whether the values are real.

## The move

Separate **code development** from **data access**.

Build a synthetic dataset that mirrors the real files in structure, naming, and defects. Develop and test the entire pipeline against it locally. Then port code that already works into the enclave and run it on real data.

The payoffs, in rough order of how much time they save:

**1. Iteration speed.** Local runs take seconds. You get a real edit-run-inspect loop, version control that works, an IDE, a debugger, and — outside the enclave, on data that is not real — AI coding assistance.

**2. Testing the failure paths.** You cannot easily test that your cleaner handles missing provider identifiers using real data, because you do not know which rows are affected until you have already written the code that finds them. In synthetic data you inject the defect yourself, so you know exactly which rows should be caught and can assert it.

**3. Preparing code regardless of access.** Pipeline work does not have to wait on paperwork. An RA can be productive on day one — running the full pipeline, reading real code, making real contributions — while they are being signed onto the project, and a student can build and test their analysis code while their own access is still being arranged. The data-use agreement, the training, and the enclave account all proceed exactly as they normally would; what changes is that the waiting period, frequently two to three months, stops being dead time. On one project here, an RA's first month of work was done entirely against synthetic data, and the first day of enclave access was spent running an already-tested pipeline rather than learning what a claim file looks like.

**4. Reproducibility that survives the access boundary.** This one is underrated. Nobody can rerun your analysis without a DUA, which means nobody checks it. But anyone can run your *generator plus your pipeline*, end to end, and see the code execute. A referee, a coauthor, a student, or you in three years can verify that the pipeline does what the paper says it does, even if they can never see a single real row.

**5. Documentation that cannot rot silently.** The generator is an executable statement of what you believe the data looks like — every column, every defect, every rate. Beliefs written in prose drift from the code. Beliefs written in a generator that must run break loudly when they stop being true.

## The honest costs

**It is code, and code rots.** A neglected generator is worse than none, because pipeline code written against stale assumptions breaks against real data in confusing ways. Budget for maintaining it.

**It only contains defects you already know about.** The generator encodes your current beliefs. Real data will surprise you with something not in the catalog. Synthetic development shortens the loop; it does not close it. Plan on discovering new defects on first contact with real data, and then adding them to the generator so the cleaner has a regression test.

**Realism is bounded, and pretending otherwise is dangerous.** Synthetic numbers are meaningless. Nobody should run an analysis on synthetic data and interpret the coefficient — except as a check that the estimator recovers what was encoded. See [05-known-truth.md](05-known-truth.md).

**A passing analysis does not validate a design.** If the generator draws treated and control units from the same process until a shock date, parallel trends is true by construction, and recovering the encoded effect proves only that the estimator works on data satisfying its own assumptions. That is worth knowing. It is not evidence about the real world.

**There is an upfront cost.** Building a first generator for a new data source is on the order of a week. It pays back quickly on any project lasting more than a couple of months, and not at all on a two-week descriptive job. See [03-fidelity-tiers.md](03-fidelity-tiers.md) for how to scale the investment.

## When to skip it

Be honest about proportionality:

| Situation | Verdict |
|---|---|
| Multi-year project, complex cleaning, RAs cycling through | **Build it.** Highest return there is. |
| Linking several data sources across eras | **Build it**, cohort-anchored. The alternative is misery. |
| Enclave access still pending | **Build it.** It is the only work available. |
| A handful of descriptive tabulations from one clean file | **Skip.** Write it in the enclave. |
| One-off replication of a published result | **Skip**, probably. |
| Analysis code only; the cleaned panel already exists and is trusted | **[Tier 0](03-fidelity-tiers.md#tier-0--hand-built-fixtures)** — hand-built fixtures for the estimator, inline in the test file. No file mirror, no generator. |

---

Next: [02-the-blueprint.md](02-the-blueprint.md) — the method.

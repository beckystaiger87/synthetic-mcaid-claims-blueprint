# Data-quality catalog — <project>

The contract between the generator and the cleaner. One row per known defect.

**Update this whenever you add an injector or discover a new defect in real
data.** When real data surprises you, that is two commits: fix the cleaner,
and add the injector so the fix has a regression test.

Sources for rates: <DQ Atlas / provider errata / observed on VRDC yyyy-mm-dd>

| # | Defect | Real-world cause | Real rate | Injected rate | Injector | Caught by | Verified |
|---|---|---|---|---|---|---|---|
| 1 | Missing servicing NPI | Legacy id submitted instead of NPI | 5-25% by state/era | same | `inject_missing_id()` | claims-pull xwalk, then drop | smoke test |
| 2 | Off-year service dates | Late-filed claims | ~0.3% | 1.5% (above real) | `inject_offyear_dates()` | year derived from date col | smoke test |
| 3 | | | | | | | |

## Rates deliberately set above real

| Defect | Real | Injected | Why |
|---|---|---|---|
| | | | too rare to detect at synth sample size |

Anyone "fixing" one of these to match reality silently disables a test. That is
why they are listed here as well as commented at the point of injection.

## Defects known but NOT yet injected

| Defect | Why not yet | Blocks what |
|---|---|---|
| | | |

## Discovered on real data (add to the catalog above)

| Date | Defect | How found | Injector added? |
|---|---|---|---|
| | | | |

# Encoded truths — <project>

Written by `<generator>.R`. **Analysis code must never read this file or its
CSV companion as an input.** It is an answer key, and an answer key in the
training data is not a test. Only the validation script opens it, and only
after the estimate exists.

## Headline effects

| Quantity | Symbol | Encoded value | Recovered by |
|---|---|---|---|
| Treatment effect, intensive margin | β | | `validate` step |
| Treatment effect, extensive margin | τ | | |
| Spillover | γ | | |

## Treatment assignment

| Unit | Treated from | Notes |
|---|---|---|
| | | |

Controls: <which units, and why they are valid controls BY CONSTRUCTION>

## Realized quantities (not designed — recorded from the run)

| Quantity | Value |
|---|---|
| N people | |
| N claims | |
| Share treated | |

## What this does not establish

The generator makes its own assumptions true. Treated and control units were
drawn from the same process until the shock date, so parallel trends holds by
construction. Recovering the encoded effect shows the estimator works on data
satisfying its assumptions. It is not evidence that the real-world design
identifies anything.

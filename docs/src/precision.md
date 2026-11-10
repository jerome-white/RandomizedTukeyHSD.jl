# How precise is a p-value?

A p-value from `trials` trials estimates the exact permutation p-value (every
within-block arrangement counted), and more trials sharpen the estimate
without changing the data. [`MonteCarloPValue`](@ref) holds a p-value together
with the number of trials it came from, and [`hdi`](@ref) and
[`probability_below`](@ref) describe its Monte Carlo error. The result of
`solve` is unchanged; build the type from a result's `pvalue` and `trials`, or
from the counts.

```@example precision
using Random, RandomizedTukeyHSD

responses = [0.10 0.40 0.70
             0.20 0.50 0.60
             0.15 0.45 0.80
             0.25 0.35 0.65]
problem = RandomizedTukeyProblem(responses)
results = solve(problem, FixedTrials(10_000); rng=Xoshiro(1))
p = MonteCarloPValue(results[2].pvalue, 10_000)
```

```@example precision
pvalue(p)                         # the p-value, exceeding / trials
```

```@example precision
hdi(p)                            # (lower, upper) for the exact p-value
```

```@example precision
hdi(p; level=0.9)
```

```@example precision
hdi(p; prior=(0.5, 0.5))          # Jeffreys' prior instead of the uniform
```

```@example precision
probability_below(p, 0.05)        # probability the exact p-value < 0.05
```

```@example precision
MonteCarloPValue(49, 1000)        # from the counts: 49 of 1000 trials
```

- The trials that reached a pair's difference are binomial in the exact
  p-value. A `prior=(a, b)` is a Beta(`a`, `b`) distribution for it, uniform by
  default, and its distribution afterwards is a Beta distribution too. `hdi` is
  that distribution's highest density interval: the shortest one holding
  `level` (0.95 by default) of the probability. Read it as "given these trials
  and the prior, the exact p-value is in here with 95% probability".
- It is a Bayesian credible interval, not a confidence interval, and has no
  coverage guarantee. The prior is a choice and matters only for small counts;
  at zero exceedances the upper end is 3.0 / `trials` for the uniform prior and
  1.9 / `trials` for Jeffreys'. Only Beta priors are supported.
- A p-value of 0 gives an interval from 0 to about `3 / trials`: the trials
  rule out little more than that.
- `probability_below(p, alpha)` is the chance that the exact p-value is below
  `alpha`, which shows whether more trials could put the p-value on the other
  side of it. For an observed 0.049 it is 0.52 at 1000 trials, 0.67 at 10 000
  and 0.93 at 100 000. The library takes no `alpha` of its own; the decision is
  yours.
- The interval covers the Monte Carlo error only: not the assumptions of the
  test, the floating-point ties ([Known limitation: floating-point ties](@ref)),
  or that many pairs are tested (the range statistic already accounts for
  that). The intervals of different pairs are not simultaneous.
- Decide `trials` and the seed before looking at the results. Running again
  until a p-value falls below a level, or until its interval does, is not a
  valid procedure; the interval does not make it one.
- `pvalue` is the generic function of
  [StatsAPI](https://github.com/JuliaStats/StatsAPI.jl), which the Julia
  statistics packages share, so it is the same function after
  `using HypothesisTests`. `hdi` is not `confint`, which is a confidence
  interval.

## Choosing the number of trials

[`trials_for`](@ref) turns a precision target into a number of trials, for
[`FixedTrials`](@ref). It is decided before the run, from the precision wanted,
so it does not depend on the results.

```jldoctest; setup = :(using RandomizedTukeyHSD)
julia> trials_for(StandardError(0.001))
250000

julia> trials_for(StandardError(0.001); p=0.05)
47500

julia> trials_for(HDIWidth(0.002); p=0.05)
182473
```

```@example precision
trials_for(HDIWidth(0.002; level=0.9, prior=(0.5, 0.5)); p=0.05)
```

Then `solve(problem, FixedTrials(trials_for(HDIWidth(0.002); p=0.05)))`.

- [`StandardError`](@ref)`(se)`: the standard error of a p-value is at most
  `se`. It is `sqrt(p * (1 - p) / trials)`, the standard deviation of a
  binomial proportion, which holds without assuming a normal distribution.
- [`HDIWidth`](@ref)`(width; level=0.95, prior=(1, 1))`: the `hdi` of a
  p-value is at most `width` wide, for the same `level` and `prior` as `hdi`.
  It assumes the count that `p` implies. For many trials it agrees with
  `StandardError` at `width / 3.92` (95% level); they differ in what they say.
- The precision depends on the exact p-value, which is not known before the
  run. `p=0.5` (the default) is the worst case and meets the target for every
  pair; a `p` near the level you will judge pairs at, like 0.05, needs fewer
  trials, and meets the target for p-values near it.
- A pilot run can suggest `p`, but its trials are not part of the final run.
- A new kind of target is a type with a method `trials_for(target, p)`.

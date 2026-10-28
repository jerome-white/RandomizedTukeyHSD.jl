import CommonSolve

"""
    FixedTrials(trials)

The rule that runs exactly `trials` trials. In each trial the responses are
shuffled across treatments within every block, and the largest minus the
smallest treatment mean is recorded.

Throws an `ArgumentError` if `trials` is not positive.
"""
struct FixedTrials
    trials::Int

    function FixedTrials(trials::Integer)
        if trials <= 0
            throw(ArgumentError("trials must be positive, got $trials"))
        end

        return new(trials)
    end
end

"""
    RandomizedTukeyRun

A [`RandomizedTukeyProblem`](@ref) together with the rule and the random
number generator it is to be solved with, as returned by `init`. Pass it to
`solve!` to run it.
"""
struct RandomizedTukeyRun{P<:RandomizedTukeyProblem,L,G<:AbstractRNG}
    problem::P
    rule::L
    rng::G
end

"""
    init(problem::RandomizedTukeyProblem, rule; rng=Random.default_rng())

Prepare to solve `problem` with `rule` (for now [`FixedTrials`](@ref)), drawing
the trials from `rng`. Returns a [`RandomizedTukeyRun`](@ref) for `solve!`.
"""
function CommonSolve.init(problem::RandomizedTukeyProblem,
                          rule::FixedTrials;
                          rng::AbstractRNG=Random.default_rng())
    return RandomizedTukeyRun(problem, rule, rng)
end

"""
    solve!(run::RandomizedTukeyRun)
    solve(problem::RandomizedTukeyProblem, rule; rng=Random.default_rng())

Randomized Tukey HSD test over all pairs of treatments. `solve` is
`solve!(init(problem, rule; rng))`.

A pair's p-value is the fraction of trials whose range is at least the pair's
observed absolute difference in means. A p-value of 0 means no trial reached
the difference, that is, p < 1/`trials`. `rng` is the random number generator
the trials are drawn from (the global one if left out). With the same `rng`
state, `trials`, responses and Julia version the p-values are the same at any
number of threads.

Returns one named tuple per pair of treatments, in the order (1,2), (1,3),
..., (n-1,n), with fields `treatment1`, `treatment2`, `mean1`, `mean2`,
`difference` (`mean1 - mean2`) and `pvalue`. A vector of named tuples is a
Tables.jl table.

# Example

```julia
using Random
responses = [0.10 0.40 0.70; 0.20 0.50 0.60; 0.15 0.45 0.80; 0.25 0.35 0.65]
problem = RandomizedTukeyProblem(responses; treatments=["A", "B", "C"])
results = solve(problem, FixedTrials(10_000); rng=Xoshiro(1))
results[2].pvalue   # A against C
```
"""
function CommonSolve.solve!(run::RandomizedTukeyRun{P,FixedTrials}) where P
    problem = run.problem

    return _randomized_tukey_hsd(run.rng, problem.responses,
                                 run.rule.trials, problem.treatments)
end

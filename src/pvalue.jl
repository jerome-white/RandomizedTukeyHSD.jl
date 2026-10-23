import StatsAPI

"""
    MonteCarloPValue(exceeding, trials)
    MonteCarloPValue(pvalue, trials)

A Monte Carlo p-value that keeps what it was estimated from: `exceeding`
of `trials` trials reached the observed difference. The p-value is
`exceeding / trials`, and with the count kept, its Monte Carlo error can be
described (see [`hdi`](@ref) and [`probability_below`](@ref)) without being
passed `trials` again.

The first form takes the count, an `Integer`. The second takes a result's
`pvalue`, an `AbstractFloat`, and recovers the count from it; the two are
told apart by type, so `MonteCarloPValue(1, 100)` is one trial out of 100
and `MonteCarloPValue(1.0, 100)` is all of them.

`float(p)` and `pvalue(p)` give `exceeding / trials`.

Throws an `ArgumentError` if `trials` is not positive, if `exceeding` is not
between 0 and `trials`, or if `pvalue` is not between 0 and 1 and a multiple
of `1 / trials`.

# Example

```julia
results = randomized_tukey_hsd(responses; trials=10_000)
p = MonteCarloPValue(results[1].pvalue, 10_000)
```
"""
struct MonteCarloPValue
    exceeding::Int
    trials::Int

    function MonteCarloPValue(exceeding::Integer, trials::Integer)
        trials > 0 ||
            throw(ArgumentError("trials must be positive, got $trials"))
        if !(0 <= exceeding <= trials)
            msg = "exceeding must be between 0 and $trials, got $exceeding"
            throw(ArgumentError(msg))
        end

        return new(exceeding, trials)
    end
end

function MonteCarloPValue(pvalue::AbstractFloat, trials::Integer)
    trials > 0 || throw(ArgumentError("trials must be positive, got $trials"))

    scaled = pvalue * trials
    exceeding = round(Int, scaled)
    if !(0 <= pvalue <= 1) || !isapprox(scaled, exceeding;
                                        atol=1e-6, rtol=1e-12)
        msg = "pvalue $pvalue is not a count out of $trials trials"
        throw(ArgumentError(msg))
    end

    return MonteCarloPValue(exceeding, trials)
end

Base.float(p::MonteCarloPValue) = p.exceeding / p.trials

StatsAPI.pvalue(p::MonteCarloPValue) = float(p)

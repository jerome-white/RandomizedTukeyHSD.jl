import StatsAPI
using SpecialFunctions: beta_inc, beta_inc_inv

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

"""
    hdi(p::MonteCarloPValue; level=0.95, prior=(1, 1))

Interval for the exact permutation p-value that `p` estimates, as a tuple
`(lower, upper)`: the highest density interval of its posterior
distribution, which is the shortest interval holding probability `level`.
Read it as "given these trials and the prior, the exact p-value is in the
interval with probability `level`".

The `exceeding` trials out of `trials` are binomial in the exact p-value. A
`prior` of `(a, b)` is a Beta(`a`, `b`) distribution for it, and the
posterior is then Beta(`a + exceeding`, `b + trials - exceeding`). The
default `(1, 1)` is the uniform distribution on [0, 1]; `(0.5, 0.5)` is
Jeffreys' prior. The prior matters only for small counts. Both numbers must
be positive.

This is a Bayesian credible interval, not a confidence interval, and has no
coverage guarantee. When the posterior density is highest at 0 (as with no
trial reaching the difference) or at 1, the interval is one-sided and runs
from 0, or to 1. It describes the Monte Carlo error only: not the
assumptions of the test, floating-point ties, or that many pairs are tested.

Throws an `ArgumentError` if `level` is not between 0 and 1 or `prior` is
not two positive numbers.

# Example

```julia
hdi(MonteCarloPValue(490, 10_000))               # about (0.0449, 0.0533)
hdi(MonteCarloPValue(0, 1_000))                  # about (0, 0.003)
hdi(MonteCarloPValue(490, 10_000); level=0.9)
hdi(MonteCarloPValue(490, 10_000); prior=(0.5, 0.5))
```
"""
function hdi(p::MonteCarloPValue; level::Real=0.95, prior=(1, 1))
    0 < level < 1 ||
        throw(ArgumentError("level must be between 0 and 1, got $level"))
    (a, b) = _posterior(p, prior)

    return _hdi(a, b, level)
end

"""
    probability_below(p::MonteCarloPValue, alpha; prior=(1, 1))

Probability that the exact permutation p-value that `p` estimates is below
`alpha`, under the same posterior as [`hdi`](@ref). It answers whether more
trials could take the p-value across `alpha`; it is not a test, and `alpha`
is the caller's.

Throws an `ArgumentError` if `alpha` is not between 0 and 1 or `prior` is
not two positive numbers.

# Example

```julia
probability_below(MonteCarloPValue(49, 1_000), 0.05)        # about 0.52
probability_below(MonteCarloPValue(4_900, 100_000), 0.05)   # about 0.93
```
"""
function probability_below(p::MonteCarloPValue, alpha::Real; prior=(1, 1))
    0 <= alpha <= 1 ||
        throw(ArgumentError("alpha must be between 0 and 1, got $alpha"))
    (a, b) = _posterior(p, prior)

    return _below(a, b, alpha)
end

# The Beta parameters of the posterior after `p`, from a Beta prior.
function _posterior(p, prior)
    if length(prior) != 2 || !all(x -> x > 0, prior)
        msg = "prior must be two positive numbers, got $prior"
        throw(ArgumentError(msg))
    end
    (a, b) = prior

    return (a + p.exceeding, b + p.trials - p.exceeding)
end

# Everything below works on the Beta(a, b) posterior alone, so that it can be
# used on counts that are still growing.

# P(exact p-value < x).
function _below(a, b, x)
    (below, _) = beta_inc(a, b, x)

    return below
end

# The point with probability `probability` below it.
function _quantile(a, b, probability)
    (x, _) = beta_inc_inv(a, b, probability)

    return x
end

# Highest density interval of probability `level`. A density that is highest
# at 0 (a <= 1) or at 1 (b <= 1) is monotone, so the interval is one-sided.
# Otherwise it has a single mode and the interval is the one of least width,
# found by searching for the lower tail probability that minimises it. (A
# and b cannot both be at most 1 for a posterior after at least one trial.)
function _hdi(a, b, level)
    tail = 1 - level

    if a <= 1
        return (0.0, _quantile(a, b, level))
    elseif b <= 1
        return (_quantile(a, b, tail), 1.0)
    end

    width(lower) = _quantile(a, b, lower + level) - _quantile(a, b, lower)
    lower = _minimise(width, 0.0, tail)

    return (_quantile(a, b, lower), _quantile(a, b, lower + level))
end

# Golden-section search for the minimiser of a function that decreases and
# then increases on [low, high].
function _minimise(f, low, high; tolerance=1e-10)
    ratio = (sqrt(5) - 1) / 2

    left = high - ratio * (high - low)
    right = low + ratio * (high - low)
    fleft = f(left)
    fright = f(right)

    while high - low > tolerance
        if fleft < fright
            high = right
            right = left
            fright = fleft
            left = high - ratio * (high - low)
            fleft = f(left)
        else
            low = left
            left = right
            fleft = fright
            right = low + ratio * (high - low)
            fright = f(right)
        end
    end

    return (low + high) / 2
end

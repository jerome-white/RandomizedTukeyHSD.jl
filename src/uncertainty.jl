using SpecialFunctions: beta_inc, beta_inc_inv

# The count of trials that reached a pair's difference is binomial with the
# exact permutation p-value as its probability. With a uniform prior on that
# probability, the posterior after `exceeding` of `trials` is
# Beta(exceeding + 1, trials - exceeding + 1). The functions below work on
# the counts so that they can be used while the trials are still running.

"""
    pvalue_interval(pvalue, trials; level=0.95)

Interval for the exact permutation p-value behind a Monte Carlo `pvalue`
(a result's `pvalue`) from `trials` trials, as a tuple `(lower, upper)`.

The `exceeding = pvalue * trials` trials that reached the observed
difference are binomial in the exact p-value. Starting from a uniform prior,
the exact p-value then has a Beta(`exceeding + 1`, `trials - exceeding + 1`)
distribution, and the interval is its highest density interval: the shortest
one holding probability `level`. The exact p-value is in the interval with
that probability, given the trials and the prior. This is not a confidence
interval and carries no coverage guarantee.

With no trial reaching the difference (`pvalue == 0`) the interval is
`(0, upper)` with `upper = 1 - (1 - level)^(1 / (trials + 1))`, about
`3 / trials` at the default level; with every trial reaching it, the interval
is the mirror image. It describes the Monte Carlo error only, not the
assumptions of the test, floating-point ties, or the multiple pairs.

Throws an `ArgumentError` if `pvalue` is not a multiple of `1 / trials`
between 0 and 1, if `trials` is not positive, or if `level` is not between 0
and 1.

# Example

```julia
pvalue_interval(0.049, 10_000)   # about (0.0449, 0.0533)
```
"""
function pvalue_interval(pvalue::Real, trials::Integer; level::Real=0.95)
    exceeding = _exceeding(pvalue, trials)
    0 < level < 1 ||
        throw(ArgumentError("level must be between 0 and 1, got $level"))

    return _interval(exceeding, trials, level)
end

"""
    probability_below(pvalue, trials, alpha)

Probability that the exact permutation p-value behind a Monte Carlo `pvalue`
from `trials` trials is below `alpha`, under the same Beta posterior as
[`pvalue_interval`](@ref). It answers whether more trials could take the
p-value across `alpha`; it is not a test, and `alpha` is the caller's.

Throws an `ArgumentError` for the same `pvalue` and `trials` as
`pvalue_interval`, and if `alpha` is not between 0 and 1.

# Example

```julia
probability_below(0.049, 1_000, 0.05)    # about 0.52
probability_below(0.049, 100_000, 0.05)  # about 0.93
```
"""
function probability_below(pvalue::Real, trials::Integer, alpha::Real)
    exceeding = _exceeding(pvalue, trials)
    0 <= alpha <= 1 ||
        throw(ArgumentError("alpha must be between 0 and 1, got $alpha"))

    return _below(exceeding, trials, alpha)
end

# The number of trials behind a p-value, which must be one of the values
# `count / trials` can take.
function _exceeding(pvalue, trials)
    trials > 0 || throw(ArgumentError("trials must be positive, got $trials"))

    scaled = pvalue * trials
    exceeding = round(Int, scaled)
    if !(0 <= pvalue <= 1) || abs(scaled - exceeding) > 1e-6 * max(1, trials)
        msg = "pvalue $pvalue is not a count out of $trials trials"
        throw(ArgumentError(msg))
    end

    return exceeding
end

# P(exact p-value < alpha) after `exceeding` of `trials`.
function _below(exceeding, trials, alpha)
    (below, _) = beta_inc(exceeding + 1, trials - exceeding + 1, alpha)

    return below
end

# The point with posterior probability `probability` below it.
function _quantile(exceeding, trials, probability)
    (x, _) = beta_inc_inv(exceeding + 1, trials - exceeding + 1, probability)

    return x
end

# Highest density interval of the posterior. At either end of the counts the
# density is monotone, so the interval is one-sided and has a closed form;
# otherwise it is the interval of probability `level` of least width, found
# by searching for the lower tail probability that minimises it.
function _interval(exceeding, trials, level)
    tail = 1 - level

    if exceeding == 0
        return (0.0, 1 - tail^(1 / (trials + 1)))
    elseif exceeding == trials
        return (tail^(1 / (trials + 1)), 1.0)
    end

    width(lower) = _quantile(exceeding, trials, lower + level) -
                   _quantile(exceeding, trials, lower)
    lower = _minimise(width, 0.0, tail)

    return (_quantile(exceeding, trials, lower),
            _quantile(exceeding, trials, lower + level))
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

"""
    trials_for(target; p=0.5)

Number of trials that meet a precision `target`, if the exact permutation
p-value is `p`. A target is a [`StandardError`](@ref) or an
[`HDIWidth`](@ref); the answer is the smallest number of trials that meets
it, to give to [`FixedTrials`](@ref).

The precision of a p-value depends on the p-value, which is not known before
the run. The default, `p=0.5`, is the worst case: no p-value is estimated
less precisely, so the target is met for every pair. A `p` near the level
you will judge the pairs at (say 0.05) needs fewer trials, and meets the
target for p-values near it. `p` must be strictly between 0 and 1.

The target is a choice made before the run, from the precision wanted and
not from the results. A pilot run to find `p` is possible (pass its
p-value), but its trials are not part of the final run.

Throws an `ArgumentError` if `p` is not strictly between 0 and 1, or if the
target needs more trials than a run can count.

# Example

```julia
trials_for(StandardError(0.001))                 # 250000
trials_for(StandardError(0.001); p=0.05)         # 47500
trials_for(HDIWidth(0.002); p=0.05)

solve(problem, FixedTrials(trials_for(HDIWidth(0.002); p=0.05)))
```

# Defining a target

A new kind of target is a type with a method `trials_for(target, p)` that
returns the number of trials, an `Int`, for the exact p-value `p`.
"""
function trials_for(target; p::Real=0.5)
    if !(0 < p < 1)
        msg = "p must be strictly between 0 and 1, got $p"
        throw(ArgumentError(msg))
    end

    return trials_for(target, p)
end

"""
    StandardError(se)

A precision target: the Monte Carlo standard error of a p-value is at most
`se`. A p-value estimated from `trials` trials has standard error
`sqrt(p * (1 - p) / trials)` for an exact p-value `p`. This is the standard
deviation of a binomial proportion, and holds without assuming a normal
distribution; the normal distribution only comes in if the error is turned
into an interval.

For [`trials_for`](@ref) that is `p * (1 - p) / se^2` trials, rounded up:
250000 for `se=0.001` in the worst case. (Floating-point error can make it
one more than the exact count: `0.1 * 0.9 / 0.01^2` is 900.0000000000001,
which rounds up to 901.)

Throws an `ArgumentError` if `se` is not positive.
"""
struct StandardError
    se::Float64

    function StandardError(se::Real)
        if !(se > 0)
            throw(ArgumentError("se must be positive, got $se"))
        end

        return new(se)
    end
end

function trials_for(target::StandardError, p)
    trials = p * (1 - p) / target.se^2
    if !(trials < typemax(Int))
        throw(ArgumentError("the target needs too many trials"))
    end

    return max(1, ceil(Int, trials))
end

"""
    HDIWidth(width; level=0.95, prior=(1, 1))

A precision target: the highest density interval [`hdi`](@ref) reports for a
p-value, with the same `level` and `prior`, is at most `width` wide.

The width depends on the number of trials that reach the observed
difference, which is not known before the run. [`trials_for`](@ref) takes
the number to expect if the exact p-value is `p`, that is `trials * p`, and
looks for the least number of trials whose interval is no wider than
`width`. For many trials this is close to `StandardError` at `width / 3.92`
(for `level=0.95`), since the posterior is then nearly normal; the two differ
in what they say, not in the count.

Throws an `ArgumentError` if `width` is not positive, `level` is not between
0 and 1 or `prior` is not two positive numbers.
"""
struct HDIWidth
    width::Float64
    level::Float64
    prior::Tuple{Float64, Float64}

    function HDIWidth(width::Real; level::Real=0.95, prior=(1, 1))
        if !(width > 0)
            throw(ArgumentError("width must be positive, got $width"))
        end
        if !(0 < level < 1)
            msg = "level must be between 0 and 1, got $level"
            throw(ArgumentError(msg))
        end
        _check_prior(prior)

        return new(width, level, (prior[1], prior[2]))
    end
end

function trials_for(target::HDIWidth, p)
    # grow the number of trials until the target is met, then narrow down
    # to the least that meets it
    high = 1
    while _width(target, high, p) > target.width
        if high > div(typemax(Int), 2)
            throw(ArgumentError("$(target.width) needs too many trials"))
        end
        high *= 2
    end

    low = div(high, 2)
    while high - low > 1
        middle = low + div(high - low, 2)
        if _width(target, middle, p) > target.width
            low = middle
        else
            high = middle
        end
    end

    return high
end

# Width of the interval after `trials` trials, `trials * p` of them
# exceeding. The Beta parameters need not be integers.
function _width(target, trials, p)
    (a, b) = target.prior
    a += trials * p
    b += trials * (1 - p)
    (lower, upper) = _hdi(a, b, target.level)

    return upper - lower
end

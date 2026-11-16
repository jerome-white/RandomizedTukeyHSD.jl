"""
    RandomizedTukeyHSD

The randomized Tukey HSD test for comparing many treatments (systems, models,
methods) over a shared set of blocks (topics, datasets, folds).

```julia
using Random, RandomizedTukeyHSD

problem = RandomizedTukeyProblem(responses; treatments=["A", "B", "C"])
results = solve(problem, FixedTrials(10_000); rng=Xoshiro(1))
```

`responses` has blocks in rows and treatments in columns. `results` has one
named tuple per pair of treatments, with the fields `treatment1`,
`treatment2`, `mean1`, `mean2`, `difference` and `pvalue`.

See [`RandomizedTukeyProblem`](@ref), [`FixedTrials`](@ref) and
[`solve`](@ref CommonSolve.solve!) to start, and the documentation at
https://jerome-white.github.io/RandomizedTukeyHSD.jl for the rest.
"""
module RandomizedTukeyHSD

using Random
using Tables
using Base.Threads
using CommonSolve: init, solve, solve!, step!
using StatsAPI: pvalue

export RandomizedTukeyProblem, FixedTrials
export init, solve, solve!, step!
export trials, pvalues
export emit, Checkpoint, NoMonitor, LogMonitor
export MonteCarloPValue, pvalue, hdi, probability_below
export trials_for, StandardError, HDIWidth

include("input.jl")
include("problem.jl")
include("pvalue.jl")
include("target.jl")
include("monitor.jl")
include("shuffle.jl")
include("solve.jl")

# All pairs (j, k) with j < k, in the order (1,2), (1,3), ..., (n-1,n).
function _pairs(n)
    pairs = Tuple{Int,Int}[]
    sizehint!(pairs, binomial(n, 2))

    for j in 1:n-1
        for k in j+1:n
            push!(pairs, (j, k))
        end
    end

    return pairs
end

# Output `n` (1, 2, ...) of the SplitMix64 generator seeded with `seed`
# (Steele, Lea and Flood, "Fast Splittable Pseudorandom Number Generators",
# 2014, with the constants of Vigna's `splitmix64.c`). The generator adds a
# constant to a counter and scrambles the counter, so an output is computed
# from its number, without the outputs before it.
function _splitmix64(seed::UInt64, n::UInt64)
    z = seed + n * 0x9e3779b97f4a7c15
    z = xor(z, z >> 30) * 0xbf58476d1ce4e5b9
    z = xor(z, z >> 27) * 0x94d049bb133111eb

    return xor(z, z >> 31)
end

# The random stream of trial `i` (1, 2, ...): a `Xoshiro` whose state, four
# 64-bit numbers, is outputs `4i - 3` to `4i` of the SplitMix64 generator
# seeded with `base`. Filling the state from SplitMix64 is what the authors
# of xoshiro recommend for a 64-bit seed; here one SplitMix64 generator
# fills the states of all the trials, four numbers each. So a stream
# depends on `base` and `i` alone, not on how trials are cut into chunks,
# and no two trials of a run share a number of that generator.
#
# The state is made here, and not by Julia's seeding (`Xoshiro(seed)`),
# for speed: Julia hashes the seed, which took more than half of a small
# trial. It also fixes the state by this function and not by the version of
# Julia.
function _stream(base::UInt64, i)
    n = 4 * (UInt64(i) - 1)

    return Xoshiro(
        _splitmix64(base, n + 1),
        _splitmix64(base, n + 2),
        _splitmix64(base, n + 3),
        _splitmix64(base, n + 4),
    )
end

# The mean of each row of `data` (treatments x blocks), adding the blocks
# in order. `sum` and `mean` do not fix the order of the additions, and the
# observed means and the trial means must round identically.
function _row_means!(means, data)
    (ntreatments, nblocks) = size(data)

    for t in 1:ntreatments
        total = 0.0
        for b in 1:nblocks
            total += data[t, b]
        end
        means[t] = total / nblocks
    end

    return means
end

# Fill `ranges` with the range of the treatment means of that many trials,
# which are trials `first`, `first + 1`, ... of the run. `observed` holds
# the responses as observed, treatments x blocks; `data` and `means` are
# scratch space of the caller, a matrix of that size and a vector of one
# number per treatment. Every trial shuffles the responses as observed, not
# the arrangement the trial before left, so that a trial depends on its own
# stream alone.
function _trials!(ranges, data, means, observed, base, first)
    for i in eachindex(ranges)
        rng = _stream(base, first + i - 1)
        copyto!(data, observed)
        for col in eachcol(data)
            _shuffle!(rng, col)
        end

        _row_means!(means, data)
        (low, high) = extrema(means)
        ranges[i] = high - low
    end

    return nothing
end

end # module

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

# The random stream of trial `i`: a generator seeded with `base + i`. Seeding
# goes through a cryptographic hash (see `?Random.seed!`), so neighbouring
# seeds give unrelated streams, and a stream depends on `base` and `i` alone,
# not on how trials are cut into chunks.
function _stream(base::UInt64, i)
    return Xoshiro(base + UInt64(i))
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
# which are trials `first`, `first + 1`, ... of the run. Every trial shuffles
# the responses as observed, not the arrangement the trial before left, so
# that a trial depends on its own stream alone.
function _trials!(ranges, responses, base, first)
    (nblocks, ntreatments) = size(responses)

    observed = Matrix{Float64}(undef, ntreatments, nblocks)
    observed .= transpose(responses)
    data = similar(observed)
    means = Vector{Float64}(undef, ntreatments)

    for i in eachindex(ranges)
        rng = _stream(base, first + i - 1)
        copyto!(data, observed)
        for col in eachcol(data)
            shuffle!(rng, col)
        end

        _row_means!(means, data)
        ranges[i] = maximum(means) - minimum(means)
    end

    return nothing
end

end # module

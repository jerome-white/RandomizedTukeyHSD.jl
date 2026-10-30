module RandomizedTukeyHSD

using Random
using Statistics
using Tables
using Base.Threads
using CommonSolve: init, solve, solve!, step!
using StatsAPI: pvalue

export RandomizedTukeyProblem, FixedTrials
export init, solve, solve!, step!
export trials, pvalues
export MonteCarloPValue, pvalue, hdi, probability_below

include("input.jl")
include("problem.jl")
include("solve.jl")
include("pvalue.jl")

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

# Fill `ranges` with the range of the treatment means of that many trials,
# which are trials `first`, `first + 1`, ... of the run. Every trial shuffles
# the responses as observed, not the arrangement the trial before left, so
# that a trial depends on its own stream alone.
function _trials!(ranges, responses, base, first)
    (nblocks, ntreatments) = size(responses)

    observed = Matrix{Float64}(undef, ntreatments, nblocks)
    observed .= transpose(responses)
    data = similar(observed)
    sums = Matrix{Float64}(undef, ntreatments, 1)

    for i in eachindex(ranges)
        rng = _stream(base, first + i - 1)
        copyto!(data, observed)
        for col in eachcol(data)
            shuffle!(rng, col)
        end

        sum!(sums, data)
        sums ./= nblocks
        ranges[i] = maximum(sums) - minimum(sums)
    end

    return nothing
end

end # module

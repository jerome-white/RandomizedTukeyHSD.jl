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

# Fill `ranges` with the range of the treatment means of that many trials.
function _trials!(ranges, responses, seed)
    (nblocks, ntreatments) = size(responses)
    rng = Xoshiro(seed)

    data = Matrix{Float64}(undef, ntreatments, nblocks)
    data .= transpose(responses)
    sums = Matrix{Float64}(undef, ntreatments, 1)

    for i in eachindex(ranges)
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

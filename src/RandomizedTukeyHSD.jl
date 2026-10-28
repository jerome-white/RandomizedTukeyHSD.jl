module RandomizedTukeyHSD

using Random
using Statistics
using Tables
using Base.Threads
using CommonSolve: init, solve, solve!, step!
using StatsAPI: pvalue

export RandomizedTukeyProblem, FixedTrials
export init, solve, solve!, step!
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

# `chunk` is the number of trials per task. The random stream depends on
# it, so changing it changes the results for a fixed `rng` state.
function _randomized_tukey_hsd(rng, responses, trials, treatments, chunk=64)
    ntreatments = size(responses, 2)

    #
    # treatment means
    #
    means = vec(mean(responses; dims=1))
    comparisons = _pairs(ntreatments)

    #
    # largest minus smallest treatment mean of every trial; trials are cut
    # into chunks that depend only on `trials`, each with its own seed drawn
    # from `rng`, so the ranges do not depend on the number of threads
    #
    nchunks = cld(trials, chunk)
    seeds = rand(rng, UInt64, nchunks)
    ranges = Vector{Float64}(undef, trials)

    @sync for c in 1:nchunks
        start = (c - 1) * chunk + 1
        stop = min(c * chunk, trials)
        @spawn _trials!(view(ranges, start:stop), responses, seeds[c])
    end
    sort!(ranges)

    #
    # report
    #
    results = map(comparisons) do (j, k)
        difference = means[j] - means[k]
        exceeding = trials - searchsortedfirst(ranges, abs(difference)) + 1
        pvalue = exceeding / trials

        (treatment1=treatments[j],
         treatment2=treatments[k],
         mean1=means[j],
         mean2=means[k],
         difference=difference,
         pvalue=pvalue)
    end

    return results
end

end # module

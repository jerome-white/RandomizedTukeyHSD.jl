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

# The output function of SplitMix64: the state is a counter, and this scrambles
# it so that neighbouring counters give unrelated values. Every step is
# invertible, so different states give different outputs. The shifts and the
# two multipliers are those of Sebastiano Vigna's public-domain splitmix64.c
# (https://prng.di.unimi.it/splitmix64.c), a fixed-increment version of Java 8's
# SplittableRandom (Steele, Lea and Flood, "Fast splittable pseudorandom number
# generators", OOPSLA 2014, doi 10.1145/2714064.2660195). The multipliers were
# found by search; they have no closed form. The xoshiro authors suggest
# SplitMix to fill the state of one of their generators from a seed
# (https://prng.di.unimi.it/).
function _mix(state::UInt64)
    z = (state ⊻ (state >> 30)) * 0xbf58476d1ce4e5b9
    z = (z ⊻ (z >> 27)) * 0x94d049bb133111eb

    return z ⊻ (z >> 31)
end

# The random stream of trial `i`: the four words of a generator's state are
# consecutive outputs of a SplitMix64 sequence that starts at `base`. Each
# trial takes its own four, so the streams of different trials do not overlap
# and depend on `base` and `i` alone, not on how trials are cut into chunks.
# The segments of four per trial are this package's arrangement, not Vigna's.
function _stream(base::UInt64, i)
    # the counter's increment, floor(2^64 / golden ratio): it is odd, so the
    # counter visits every 64-bit value before it repeats
    gamma = 0x9e3779b97f4a7c15
    state = base + UInt64(4 * (i - 1)) * gamma

    return Xoshiro(
        _mix(state + gamma),
        _mix(state + 2 * gamma),
        _mix(state + 3 * gamma),
        _mix(state + 4 * gamma),
    )
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

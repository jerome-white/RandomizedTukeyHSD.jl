module RandomizedTukeyHSD

using Random
using Statistics
using Base.Threads

export randomized_tukey_hsd

"""
    randomized_tukey_hsd(scores; B, systems=axes(scores, 2))

Randomized Tukey HSD test over all pairs of systems.

`scores` is a topics × systems matrix. In each of `B` trials the scores
are shuffled across systems within every topic, and the largest minus
the smallest system mean is recorded. A pair's p-value is the fraction
of trials whose range is at least the pair's observed absolute
difference in means.

`systems` names the columns of `scores`. Returns one named tuple per
pair of systems, in the order (1,2), (1,3), ..., (n-1,n), with fields
`system1`, `system2`, `mean1`, `mean2`, `difference` (`mean1 - mean2`)
and `pvalue`. A vector of named tuples is a Tables.jl table.

Throws an `ArgumentError` if `scores` contains `NaN`: one `NaN` makes
every p-value meaningless, including those of pairs that do not involve
its system.
"""
function randomized_tukey_hsd(scores::AbstractMatrix{<:Real};
                              B::Integer,
                              systems::AbstractVector=axes(scores, 2))
    nsystems = size(scores, 2)

    B > 0 || throw(ArgumentError("B must be positive, got $B"))
    nsystems > 1 || throw(ArgumentError("need at least two systems"))
    if length(systems) != nsystems
        msg = "$(length(systems)) system names for $nsystems systems"
        throw(DimensionMismatch(msg))
    end

    nans = count(isnan, scores)
    nans == 0 || throw(ArgumentError("scores contain $nans NaN values"))

    return _randomized_tukey_hsd(scores, B, systems)
end

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

# Trials per task. The random stream depends on this value, so changing
# it changes the results for a fixed seed.
const CHUNK = 64

# Fill `ranges` with the range of the system means of that many trials.
function _trials!(ranges, scores, seed)
    (ntopics, nsystems) = size(scores)
    rng = Xoshiro(seed)

    data = Matrix{Float64}(undef, nsystems, ntopics)
    data .= transpose(scores)
    sums = Matrix{Float64}(undef, nsystems, 1)

    for i in eachindex(ranges)
        for col in eachcol(data)
            shuffle!(rng, col)
        end

        sum!(sums, data)
        sums ./= ntopics
        ranges[i] = maximum(sums) - minimum(sums)
    end

    return nothing
end

function _randomized_tukey_hsd(scores, B, systems)
    nsystems = size(scores, 2)

    #
    # system means
    #
    sysmeans = vec(mean(scores; dims=1))
    comparisons = _pairs(nsystems)

    #
    # largest minus smallest system mean of every trial; trials are cut
    # into chunks that depend only on B, each with its own seed, so the
    # ranges do not depend on the number of threads
    #
    nchunks = cld(B, CHUNK)
    seeds = rand(UInt64, nchunks)
    ranges = Vector{Float64}(undef, B)

    @sync for chunk in 1:nchunks
        start = (chunk - 1) * CHUNK + 1
        stop = min(chunk * CHUNK, B)
        @spawn _trials!(view(ranges, start:stop), scores, seeds[chunk])
    end
    sort!(ranges)

    #
    # report
    #
    results = map(comparisons) do (j, k)
        difference = sysmeans[j] - sysmeans[k]
        trials = B - searchsortedfirst(ranges, abs(difference)) + 1
        pvalue = trials / B

        (system1=systems[j],
         system2=systems[k],
         mean1=sysmeans[j],
         mean2=sysmeans[k],
         difference=difference,
         pvalue=pvalue)
    end

    return results
end

end # module

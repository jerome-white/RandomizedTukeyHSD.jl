module RandomizedTukeyHSD

using Random
using Statistics
using Base.Threads

export randomized_tukey_hsd

include("input.jl")

"""
    randomized_tukey_hsd([rng,] scores; trials, systems=axes(scores, 2))

Randomized Tukey HSD test over all pairs of systems.

`scores` is a topics × systems matrix. In each of `trials` trials the scores
are shuffled across systems within every topic, and the largest minus
the smallest system mean is recorded. A pair's p-value is the fraction
of trials whose range is at least the pair's observed absolute
difference in means. A p-value of 0 means no trial reached the
difference, that is, p < 1/`trials`.

`systems` names the columns of `scores`. `rng` is the random number
generator the trials are drawn from (the global one if left out). With
the same `rng` state, `trials`, `scores` and Julia version the p-values are
the same at any number of threads.

Returns one named tuple per pair of systems, in the order (1,2), (1,3),
..., (n-1,n), with fields `system1`, `system2`, `mean1`, `mean2`,
`difference` (`mean1 - mean2`) and `pvalue`. A vector of named tuples is
a Tables.jl table.

Throws an `ArgumentError` if `trials` is not positive, if there are fewer than
two systems, or if `scores` contains `NaN` (one `NaN` makes every p-value
meaningless, including those of pairs that do not involve its system),
and a `DimensionMismatch` if `systems` does not have one name per column.

# Example

```julia
using Random
scores = [0.10 0.40 0.70; 0.20 0.50 0.60; 0.15 0.45 0.80; 0.25 0.35 0.65]
results = randomized_tukey_hsd(Xoshiro(1), scores; trials=10_000,
                               systems=["A", "B", "C"])
results[2].pvalue   # A against C
```
"""
function randomized_tukey_hsd(scores::AbstractMatrix{<:Real}; kwargs...)
    return randomized_tukey_hsd(Random.default_rng(), scores; kwargs...)
end

function randomized_tukey_hsd(rng::AbstractRNG,
                              scores::AbstractMatrix{<:Real};
                              trials::Integer,
                              systems::AbstractVector=axes(scores, 2))
    nsystems = size(scores, 2)

    trials > 0 || throw(ArgumentError("trials must be positive, got $trials"))
    nsystems > 1 || throw(ArgumentError("need at least two systems"))
    if length(systems) != nsystems
        msg = "$(length(systems)) system names for $nsystems systems"
        throw(DimensionMismatch(msg))
    end

    nans = count(isnan, scores)
    nans == 0 || throw(ArgumentError("scores contain $nans NaN values"))

    return _randomized_tukey_hsd(rng, scores, trials, systems)
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

# `chunk` is the number of trials per task. The random stream depends on
# it, so changing it changes the results for a fixed `rng` state.
function _randomized_tukey_hsd(rng, scores, trials, systems, chunk=64)
    nsystems = size(scores, 2)

    #
    # system means
    #
    sysmeans = vec(mean(scores; dims=1))
    comparisons = _pairs(nsystems)

    #
    # largest minus smallest system mean of every trial; trials are cut
    # into chunks that depend only on `trials`, each with its own seed drawn
    # from `rng`, so the ranges do not depend on the number of threads
    #
    nchunks = cld(trials, chunk)
    seeds = rand(rng, UInt64, nchunks)
    ranges = Vector{Float64}(undef, trials)

    @sync for c in 1:nchunks
        start = (c - 1) * chunk + 1
        stop = min(c * chunk, trials)
        @spawn _trials!(view(ranges, start:stop), scores, seeds[c])
    end
    sort!(ranges)

    #
    # report
    #
    results = map(comparisons) do (j, k)
        difference = sysmeans[j] - sysmeans[k]
        exceeding = trials - searchsortedfirst(ranges, abs(difference)) + 1
        pvalue = exceeding / trials

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

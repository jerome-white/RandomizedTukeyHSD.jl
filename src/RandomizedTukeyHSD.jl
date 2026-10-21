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

function _randomized_tukey_hsd(scores, B, systems)
    (ntopics, nsystems) = size(scores)

    #
    # system means and observed differences
    #
    sysmeans = vec(mean(scores; dims=1))
    comparisons = _pairs(nsystems)
    observed = Dict(
        (j, k) => abs(sysmeans[j] - sysmeans[k]) for (j, k) in comparisons
    )

    #
    # initialize counts
    #
    # threadid() can exceed nthreads() (the interactive thread comes
    # first), so size the per-thread state by the largest possible id
    workers = Threads.maxthreadid()
    counts = zeros(Int, nsystems, nsystems, workers)

    #
    # create views of the data
    #
    data = Array{Float64}(undef, nsystems, ntopics, workers)
    data .= transpose(scores)

    @threads for i in 1:B
        this = threadid()
        ptr = view(data, :, :, this)

        for col in eachcol(ptr)
            shuffle!(col)
        end

        m = mean(ptr; dims=2)
        d = maximum(m) - minimum(m)
        for (j, k) in comparisons
            if d >= observed[(j, k)]
                counts[j,k,this] += 1
            end
        end
    end

    #
    # report
    #
    results = map(comparisons) do (j, k)
        difference = sysmeans[j] - sysmeans[k]
        pvalue = sum(counts[j,k,:]) / B

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

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
    (ntopics, nsystems) = size(scores)

    B > 0 || throw(ArgumentError("B must be positive, got $B"))
    nsystems > 1 || throw(ArgumentError("need at least two systems"))
    length(systems) == nsystems ||
        throw(DimensionMismatch("$(length(systems)) system names for $nsystems systems"))

    #
    # system means and observed differences
    #
    sysmeans = vec(mean(scores; dims=1))
    pairs = [ (j, k) for j in 1:nsystems-1 for k in j+1:nsystems ]
    observed = Dict(p => abs(sysmeans[p[1]] - sysmeans[p[2]]) for p in pairs)

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

        data[:,:,this] = mapslices(shuffle!, ptr; dims=1)

        m = mean(ptr; dims=2)
        d = maximum(m) - minimum(m)
        for (j, k) in pairs
            if d >= observed[(j, k)]
                counts[j,k,this] += 1
            end
        end
    end

    return [
        (system1=systems[j],
         system2=systems[k],
         mean1=sysmeans[j],
         mean2=sysmeans[k],
         difference=sysmeans[j] - sysmeans[k],
         pvalue=sum(counts[j,k,:]) / B)
        for (j, k) in pairs
    ]
end

end

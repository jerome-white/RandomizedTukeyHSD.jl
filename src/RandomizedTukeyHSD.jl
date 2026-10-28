module RandomizedTukeyHSD

using Random
using Statistics
using Tables
using Base.Threads
using CommonSolve: init, solve, solve!, step!
using StatsAPI: pvalue

export randomized_tukey_hsd
export RandomizedTukeyProblem, FixedTrials
export init, solve, solve!, step!
export MonteCarloPValue, pvalue, hdi, probability_below

include("input.jl")
include("problem.jl")
include("solve.jl")
include("pvalue.jl")

"""
    randomized_tukey_hsd([rng,] responses; trials,
                         treatments=axes(responses, 2))

Randomized Tukey HSD test over all pairs of treatments.

`responses` is a blocks × treatments matrix. In each of `trials` trials the
responses are shuffled across treatments within every block, and the
largest minus the smallest treatment mean is recorded. A pair's p-value is
the fraction of trials whose range is at least the pair's observed
absolute difference in means. A p-value of 0 means no trial reached the
difference, that is, p < 1/`trials`.

`treatments` names the columns of `responses`. `rng` is the random number
generator the trials are drawn from (the global one if left out). With the
same `rng` state, `trials`, `responses` and Julia version the p-values are
the same at any number of threads.

Returns one named tuple per pair of treatments, in the order (1,2), (1,3),
..., (n-1,n), with fields `treatment1`, `treatment2`, `mean1`, `mean2`,
`difference` (`mean1 - mean2`) and `pvalue`. A vector of named tuples is
a Tables.jl table.

Throws an `ArgumentError` if `trials` is not positive, if there are fewer
than two treatments, or if `responses` contains `NaN` (one `NaN` makes
every p-value meaningless, including those of pairs that do not involve
its treatment), and a `DimensionMismatch` if `treatments` does not have
one name per column.

# Example

```julia
using Random
responses = [0.10 0.40 0.70; 0.20 0.50 0.60; 0.15 0.45 0.80; 0.25 0.35 0.65]
results = randomized_tukey_hsd(Xoshiro(1), responses; trials=10_000,
                               treatments=["A", "B", "C"])
results[2].pvalue   # A against C
```
"""
function randomized_tukey_hsd(responses::AbstractMatrix{<:Real}; kwargs...)
    return randomized_tukey_hsd(Random.default_rng(), responses; kwargs...)
end

function randomized_tukey_hsd(rng::AbstractRNG,
                              responses::AbstractMatrix{<:Real};
                              trials::Integer,
                              treatments::AbstractVector=axes(responses, 2))
    ntreatments = size(responses, 2)

    if trials <= 0
        throw(ArgumentError("trials must be positive, got $trials"))
    end
    if ntreatments <= 1
        throw(ArgumentError("need at least two treatments"))
    end
    if length(treatments) != ntreatments
        msg = "$(length(treatments)) treatment names for " *
              "$ntreatments treatments"
        throw(DimensionMismatch(msg))
    end

    nans = count(isnan, responses)
    if nans != 0
        throw(ArgumentError("responses contain $nans NaN values"))
    end

    return _randomized_tukey_hsd(rng, responses, trials, treatments)
end

"""
    randomized_tukey_hsd([rng,] table; trials, block, treatment, response)

The same test on a [Tables.jl](https://tables.juliadata.org) table, such as
a `DataFrame`, so that the names of the treatments come with the data. The
shape is told by which of `block`, `treatment` and `response` are given; each
is the name of a column, as a `Symbol` or a `String`.

- **Wide**, with none given: each column is a treatment and each row a
  block. The result names the treatments by the column names, as `Symbol`s,
  as the table gives them.
  Pass only `block` to leave out a column that identifies the rows.
- **Tidy**, with all three given: one row per block and treatment, with the
  block in column `block`, the treatment in `treatment` and the response in
  `response`. The treatments are named by the values of the `treatment`
  column, and blocks and treatments are taken in the order they first
  appear.

A `missing` response, and a pair of block and treatment with no row, become
`NaN` and are rejected like any other `NaN`. A matrix with real elements
takes the matrix method instead; there is no `treatments` argument here.

Throws an `ArgumentError` if `table` is not a table, if a column does not
exist, if the roles are given partly, or for the reasons of the matrix
method.

# Example

```julia
table = (block=["b1", "b1", "b2", "b2", "b3", "b3"],
         treatment=["A", "B", "A", "B", "A", "B"],
         response=[0.1, 0.4, 0.2, 0.5, 0.15, 0.45])
randomized_tukey_hsd(table; trials=1_000, block=:block, treatment=:treatment,
                     response=:response)
```
"""
function randomized_tukey_hsd(rng::AbstractRNG,
                              table;
                              trials::Integer,
                              block=nothing,
                              treatment=nothing,
                              response=nothing)
    (responses, treatments) = _table_responses(table, block, treatment,
                                               response)

    return randomized_tukey_hsd(rng, responses;
                                trials=trials,
                                treatments=treatments)
end

function randomized_tukey_hsd(table; kwargs...)
    return randomized_tukey_hsd(Random.default_rng(), table; kwargs...)
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

# Support code for the tests: solving with a fixed number of trials, reading
# the tidy fixtures and computing exact p-values by enumerating every
# within-block permutation.

using Random
using Statistics

# Solves with `trials` trials. `input` is a matrix or a table and the other
# keywords are those of RandomizedTukeyProblem. The generator may come first,
# as in `rand(rng, ...)`.
function tukey(rng::AbstractRNG, input; trials, kwargs...)
    problem = RandomizedTukeyProblem(input; kwargs...)

    return solve(problem, FixedTrials(trials); rng=rng)
end

function tukey(input; kwargs...)
    return tukey(Random.default_rng(), input; kwargs...)
end

# Reads a tidy CSV (block,treatment,response) into a blocks x treatments
# matrix, with blocks and treatments in order of first appearance.
function read_responses(path)
    rows = [ split(line, ',') for line in readlines(path)[2:end] ]
    blocks = unique(first.(rows))
    treatments = unique([ r[2] for r in rows ])

    responses = zeros(length(blocks), length(treatments))
    for (block, treatment, response) in rows
        i = findfirst(==(block), blocks)
        j = findfirst(==(treatment), treatments)
        responses[i, j] = parse(Float64, response)
    end

    return (responses, treatments)
end

# Reads a reference table (treatment1,treatment2,difference,p), as written by
# test/reference/sakai_reference.sh, into a Dict mapping
# (treatment1, treatment2) to (difference, pvalue).
function read_reference(path)
    reference = Dict{Tuple{String,String},Tuple{Float64,Float64}}()
    for line in readlines(path)[2:end]
        (a, b, difference, pvalue) = split(line, ',')
        reference[(a, b)] = (parse(Float64, difference), parse(Float64, pvalue))
    end

    return reference
end

# All permutations of 1:n.
function permutations_of(n)
    n == 1 && return [[1]]

    return [
        insert!(copy(p), i, n)
        for p in permutations_of(n - 1) for i in 1:n
    ]
end

# The exact p-value of every pair, in the order of the results of solve:
# the fraction of all equally likely within-block arrangements whose range
# of treatment means is at least the pair's observed absolute difference.
# Ranges within `tol` below the observed difference count as equal to it,
# so the result is the mathematical value, not one that depends on how the
# floating-point sums happened to round (see issue #17).
function exact_pvalues(responses; tol=1e-9)
    (nblocks, ntreatments) = size(responses)
    means = vec(mean(responses; dims=1))
    pairs = [ (j, k) for j in 1:ntreatments-1 for k in j+1:ntreatments ]
    observed = [ abs(means[j] - means[k]) for (j, k) in pairs ]

    arrangements = permutations_of(ntreatments)
    counts = zeros(Int, length(pairs))
    total = 0

    for choice in Iterators.product(ntuple(_ -> arrangements, nblocks)...)
        shuffled = [
            responses[t, choice[t][s]] for t in 1:nblocks, s in 1:ntreatments
        ]
        m = vec(mean(shuffled; dims=1))
        d = maximum(m) - minimum(m)
        counts .+= d .>= observed .- tol
        total += 1
    end

    return counts ./ total
end

# Support code for the tests: reading the tidy fixtures and computing exact
# p-values by enumerating every within-topic permutation.

using Statistics

# Reads a tidy CSV (topic,system,score) into a topics x systems matrix, with
# topics and systems in order of first appearance.
function read_scores(path)
    rows = [ split(line, ',') for line in readlines(path)[2:end] ]
    topics = unique(first.(rows))
    systems = unique([ r[2] for r in rows ])

    scores = zeros(length(topics), length(systems))
    for (topic, system, score) in rows
        scores[findfirst(==(topic), topics), findfirst(==(system), systems)] =
            parse(Float64, score)
    end

    return (scores, systems)
end

# Reads a reference table (system1,system2,difference,p), as written by
# test/reference/sakai_reference.sh, into a Dict mapping
# (system1, system2) to (difference, pvalue).
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

# The exact p-value of every pair, in the order of randomized_tukey_hsd:
# the fraction of all equally likely within-topic arrangements whose range
# of system means is at least the pair's observed absolute difference.
# Ranges within `tol` below the observed difference count as equal to it,
# so the result is the mathematical value, not one that depends on how the
# floating-point sums happened to round (see issue #17).
function exact_pvalues(scores; tol=1e-9)
    (ntopics, nsystems) = size(scores)
    means = vec(mean(scores; dims=1))
    pairs = [ (j, k) for j in 1:nsystems-1 for k in j+1:nsystems ]
    observed = [ abs(means[j] - means[k]) for (j, k) in pairs ]

    arrangements = permutations_of(nsystems)
    counts = zeros(Int, length(pairs))
    total = 0

    for choice in Iterators.product(ntuple(_ -> arrangements, ntopics)...)
        shuffled = [
            scores[t, choice[t][s]] for t in 1:ntopics, s in 1:nsystems
        ]
        m = vec(mean(shuffled; dims=1))
        d = maximum(m) - minimum(m)
        counts .+= d .>= observed .- tol
        total += 1
    end

    return counts ./ total
end

# Writes every within-topic arrangement of a tidy CSV (topic,system,score)
# in the permuted-matrix format that Sakai's permmat2maxmin reads: one line
# per topic, "<arrangement> <score for system 1> <score for system 2> ...",
# with scores printed to six decimals as his Random-test does. Prints the
# number of arrangements.
#
#   julia --project=. arrangements.jl ../data/ties.csv arrangements.txt

using Printf

include(joinpath(@__DIR__, "..", "helpers.jl"))

function main(path, output)
    (scores, _) = read_scores(path)
    (ntopics, nsystems) = size(scores)
    arrangements = permutations_of(nsystems)

    count = 0
    open(output, "w") do io
        for choice in Iterators.product(ntuple(_ -> arrangements, ntopics)...)
            count += 1
            for t in 1:ntopics
                row = [ @sprintf("%f", scores[t, choice[t][s]])
                        for s in 1:nsystems ]
                println(io, count, " ", join(row, " "), " ")
            end
        end
    end

    println(count)
end

main(ARGS[1], ARGS[2])

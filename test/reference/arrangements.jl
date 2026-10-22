# Writes every within-block arrangement of a tidy CSV
# (block,treatment,response) in the permuted-matrix format that Sakai's
# permmat2maxmin reads (his tool calls blocks topics and treatments systems):
# one line per block, "<arrangement> <response of treatment 1> <response of
# treatment 2> ...", with responses printed to six decimals as his
# Random-test does. Prints the
# number of arrangements.
#
#   julia --project=. arrangements.jl ../data/ties.csv arrangements.txt

using Printf

include(joinpath(@__DIR__, "..", "helpers.jl"))

function main(path, output)
    (responses, _) = read_responses(path)
    (nblocks, ntreatments) = size(responses)
    arrangements = permutations_of(ntreatments)

    count = 0
    open(output, "w") do io
        for choice in Iterators.product(ntuple(_ -> arrangements, nblocks)...)
            count += 1
            for t in 1:nblocks
                row = [ @sprintf("%f", responses[t, choice[t][s]])
                        for s in 1:ntreatments ]
                println(io, count, " ", join(row, " "), " ")
            end
        end
    end

    println(count)
end

main(ARGS[1], ARGS[2])

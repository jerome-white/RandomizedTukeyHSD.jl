# Prints p-values for the test fixtures and two random matrices under a fixed
# seed. The output is deterministic and does not depend on the number of
# threads; diff it before and after a change that should only affect speed.

using Random
using RandomizedTukeyHSD

include(joinpath(@__DIR__, "..", "test", "helpers.jl"))

const DATA = joinpath(@__DIR__, "..", "test", "data")

function main()
    for name in ("tiny", "ties", "distinct")
        (responses, treatments) = read_responses(joinpath(DATA, "$name.csv"))

        problem = RandomizedTukeyProblem(responses; treatments=treatments)

        Random.seed!(42)
        for r in solve(problem, FixedTrials(5000))
            println(name, " ", r.treatment1, " ", r.treatment2, " ",
                    repr(r.mean1), " ", repr(r.mean2), " ", repr(r.pvalue))
        end
    end

    for (nblocks, ntreatments) in ((100, 8), (50, 20))
        responses = rand(Xoshiro(7), nblocks, ntreatments)
        problem = RandomizedTukeyProblem(responses)

        Random.seed!(42)
        for r in solve(problem, FixedTrials(2000))
            println(nblocks, "x", ntreatments, " ", r.treatment1, " ",
                    r.treatment2, " ", repr(r.pvalue))
        end
    end
end

main()

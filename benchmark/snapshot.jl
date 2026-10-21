# Prints p-values for the test fixtures and two random matrices under a fixed
# seed. The output is deterministic and does not depend on the number of
# threads; diff it before and after a change that should only affect speed.

using Random
using RandomizedTukeyHSD

include(joinpath(@__DIR__, "..", "test", "helpers.jl"))

const DATA = joinpath(@__DIR__, "..", "test", "data")

function main()
    for name in ("tiny", "ties", "distinct")
        (scores, systems) = read_scores(joinpath(DATA, "$name.csv"))

        Random.seed!(42)
        for r in randomized_tukey_hsd(scores; trials=5000, systems=systems)
            println(name, " ", r.system1, " ", r.system2, " ",
                    repr(r.mean1), " ", repr(r.mean2), " ", repr(r.pvalue))
        end
    end

    for (ntopics, nsystems) in ((100, 8), (50, 20))
        scores = rand(Xoshiro(7), ntopics, nsystems)

        Random.seed!(42)
        for r in randomized_tukey_hsd(scores; trials=2000)
            println(ntopics, "x", nsystems, " ", r.system1, " ", r.system2,
                    " ", repr(r.pvalue))
        end
    end
end

main()

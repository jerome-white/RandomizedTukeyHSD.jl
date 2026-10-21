# Checks randomized_tukey_hsd against two independent references on small
# problems where the full permutation distribution can be enumerated:
#
# - the exact p-values, computed by enumerating every within-topic
#   arrangement (helpers.jl), which have no Monte Carlo error;
# - the p-values of the Python RandomisedTukey implementation, stored in
#   data/*_python.csv (see reference/python_reference.py).
#
# Both implementations are randomized, so they are compared within a
# multiple of the Monte Carlo standard error.

using Random

const DATA = joinpath(@__DIR__, "data")
const TRIALS = 200_000
const PYTHON_TRIALS = 1_000_000
const Z = 5  # tolerance, in standard errors

# Standard error of a p-value estimated from `B` trials, plus 1 / B so that
# p-values of exactly 0 or 1 still get a tolerance.
tolerance(p, B) = Z * sqrt(p * (1 - p) / B) + 1 / B

@testset "exact enumeration" begin
    @test sort(permutations_of(3)) == [
        [1, 2, 3], [1, 3, 2], [2, 1, 3], [2, 3, 1], [3, 1, 2], [3, 2, 1],
    ]
    @test length(permutations_of(4)) == 24

    # two topics where A always beats B by 1: the range is 1 when both or
    # neither topic is swapped, and 0 otherwise
    @test exact_pvalues([1.0 0.0; 1.0 0.0]) == [0.5]
end

@testset "fixtures" begin
    @test read_scores(joinpath(DATA, "tiny.csv"))[1] == [
        0.10 0.40 0.70
        0.20 0.50 0.60
        0.15 0.45 0.80
        0.25 0.35 0.65
    ]
end

@testset "reference: $name" for name in ("generic", "ties")
    (scores, systems) = read_scores(joinpath(DATA, "$name.csv"))
    python = read_reference(joinpath(DATA, "$(name)_python.csv"))
    exact = exact_pvalues(scores)

    Random.seed!(1)
    results = randomized_tukey_hsd(scores; B=TRIALS, systems=systems)

    @test length(results) == length(exact) == length(python)

    for (r, p) in zip(results, exact)
        pair = (r.system1, r.system2)
        (py_difference, py_pvalue) = python[pair]

        @testset "$(join(pair, " vs "))" begin
            @test r.difference ≈ py_difference
            @test abs(r.pvalue - p) <= tolerance(p, TRIALS)
            @test abs(py_pvalue - p) <= tolerance(p, PYTHON_TRIALS)
            @test abs(r.pvalue - py_pvalue) <=
                tolerance(p, TRIALS) + tolerance(p, PYTHON_TRIALS)
        end
    end
end

# tiny.csv has scores on a 0.05 grid, so 12 of its 1296 arrangements have a
# range that equals the observed A-B difference mathematically but not in
# floating point. The exact (mathematical) p-value of that pair is 0.4028;
# the library converges to 0.3935, as does the Python implementation.
# Fixing issue #17 turns this into an unexpected pass.
@testset "floating-point ties (issue #17)" begin
    (scores, systems) = read_scores(joinpath(DATA, "tiny.csv"))
    exact = exact_pvalues(scores)

    B = 4 * TRIALS
    Random.seed!(1)
    results = randomized_tukey_hsd(scores; B=B, systems=systems)

    @test exact[1] ≈ 0.40277777777777777
    @test_broken abs(results[1].pvalue - exact[1]) <= tolerance(exact[1], B)
end

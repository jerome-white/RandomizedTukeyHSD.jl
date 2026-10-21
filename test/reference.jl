# Checks randomized_tukey_hsd against references that do not share its code,
# on small problems where the full permutation distribution can be
# enumerated:
#
# - the exact p-values, computed by enumerating every within-topic
#   arrangement (helpers.jl), which have no Monte Carlo error;
# - the p-values of Sakai's own implementation (Discpower), applied to every
#   arrangement, stored in data/*_sakai.csv (see reference/README.md).
#
# The library is randomized, so it is compared within a multiple of the
# Monte Carlo standard error. The two references are deterministic and are
# compared with each other to the precision Sakai's code prints.

using Random

const DATA = joinpath(@__DIR__, "data")
const TRIALS = 200_000
const Z = 5  # tolerance, in standard errors
const PRINTED = 1e-5  # Sakai's code prints six significant digits

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

@testset "reference: $name" for name in ("ties", "distinct")
    (scores, systems) = read_scores(joinpath(DATA, "$name.csv"))
    sakai = read_reference(joinpath(DATA, "$(name)_sakai.csv"))
    exact = exact_pvalues(scores)

    Random.seed!(1)
    results = randomized_tukey_hsd(scores; B=TRIALS, systems=systems)

    @test length(results) == length(exact) == length(sakai)

    for (r, p) in zip(results, exact)
        pair = (r.system1, r.system2)
        (sakai_difference, sakai_pvalue) = sakai[pair]

        @testset "$(join(pair, " vs "))" begin
            @test abs(r.difference) ≈ sakai_difference atol=PRINTED
            @test sakai_pvalue ≈ p atol=PRINTED
            @test abs(r.pvalue - sakai_pvalue) <= tolerance(p, TRIALS)
            @test abs(r.pvalue - p) <= tolerance(p, TRIALS)
        end
    end
end

# tiny.csv has scores on a 0.05 grid, so 12 of its 1296 arrangements have a
# range that equals the observed A-B difference mathematically but not in
# floating point. They have to count: Sakai's code does (its README says
# equality counts, and it prints ranges to six decimals), and the exact
# p-value is 0.4028. Without a tolerance the library gave 0.3935 (issue #17).
@testset "floating-point ties (issue #17)" begin
    (scores, systems) = read_scores(joinpath(DATA, "tiny.csv"))
    sakai = read_reference(joinpath(DATA, "tiny_sakai.csv"))
    exact = exact_pvalues(scores)

    @test sakai[("A", "B")][2] ≈ exact[1] atol=PRINTED
    @test exact[1] ≈ 0.40277777777777777

    B = 4 * TRIALS
    Random.seed!(1)
    results = randomized_tukey_hsd(scores; B=B, systems=systems)

    for (r, p) in zip(results, exact)
        @test abs(r.pvalue - p) <= tolerance(p, B)
    end
end

# p-values do not depend on the unit the scores are in, so the tolerance has
# to scale with them. A fixed absolute tolerance would treat every pair of
# scores of order 1e-9 as equal, and be negligible next to ones of order 1e9.
@testset "scale invariance" for scale in (1e-9, 1e9)
    (scores, systems) = read_scores(joinpath(DATA, "tiny.csv"))
    exact = exact_pvalues(scores)

    Random.seed!(1)
    results = randomized_tukey_hsd(scale .* scores; B=TRIALS, systems=systems)

    for (r, p) in zip(results, exact)
        @test abs(r.pvalue - p) <= tolerance(p, TRIALS)
    end
end

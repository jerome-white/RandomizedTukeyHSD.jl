using Random
using SpecialFunctions: beta_inc

# log density of Beta(k + 1, n - k + 1), up to a constant
logdensity(x, k, n) = k * log(x) + (n - k) * log1p(-x)

# posterior probability between two points
mass(lower, upper, k, n) =
    beta_inc(k + 1, n - k + 1, upper)[1] - beta_inc(k + 1, n - k + 1, lower)[1]

@testset "pvalue_interval" begin
    @testset "values" begin
        # computed independently, by a grid search over the Beta posterior
        for (k, n, lower, upper) in ((49, 1000, 0.03675, 0.06356),
                                     (490, 10_000, 0.04488, 0.05335),
                                     (4900, 100_000, 0.04767, 0.05035),
                                     (3, 1000, 0.00071, 0.00792))
            (lo, hi) = pvalue_interval(k / n, n)
            @test lo ≈ lower atol=1e-5
            @test hi ≈ upper atol=1e-5
        end
    end

    @testset "it is the highest density interval" begin
        for (k, n) in ((1, 10), (5, 10), (49, 1000), (900, 1000), (7, 100))
            for level in (0.5, 0.9, 0.95, 0.99)
                (lo, hi) = pvalue_interval(k / n, n; level=level)

                # holds the probability asked for
                @test mass(lo, hi, k, n) ≈ level atol=1e-8

                # equal density at both ends, the condition for the
                # shortest interval
                @test logdensity(lo, k, n) ≈ logdensity(hi, k, n) atol=1e-5

                # no interval of that probability on a grid is shorter
                shortest = Inf
                for tail in range(0, 1 - level, length=2001)[2:end-1]
                    a = RandomizedTukeyHSD._quantile(k, n, tail)
                    b = RandomizedTukeyHSD._quantile(k, n, tail + level)
                    shortest = min(shortest, b - a)
                end
                @test hi - lo <= shortest + 1e-9
            end
        end
    end

    @testset "no trial reached the difference" begin
        for n in (10, 1000, 100_000)
            (lo, hi) = pvalue_interval(0.0, n)
            @test lo == 0
            @test hi ≈ 1 - 0.05^(1 / (n + 1))
            @test mass(lo, hi, 0, n) ≈ 0.95

            # about 3 / trials, the rule of three
            n >= 1000 && @test hi * n ≈ 3 atol=0.02
        end
    end

    @testset "every trial reached the difference" begin
        for n in (10, 1000)
            (lo, hi) = pvalue_interval(1.0, n)
            @test hi == 1
            @test lo ≈ 0.05^(1 / (n + 1))
        end
    end

    @testset "it is symmetric in successes and failures" begin
        (lo, hi) = pvalue_interval(0.3, 1000)
        (flipped_lo, flipped_hi) = pvalue_interval(0.7, 1000)
        @test flipped_lo ≈ 1 - hi
        @test flipped_hi ≈ 1 - lo
    end

    @testset "the interval narrows with trials and widens with level" begin
        width(p, n; level=0.95) = -(-(pvalue_interval(p, n; level=level)...))
        @test width(0.05, 100_000) < width(0.05, 10_000) < width(0.05, 1000)
        @test width(0.5, 1000; level=0.9) < width(0.5, 1000) <
              width(0.5, 1000; level=0.99)
    end

    @testset "it contains the pvalue and stays within [0, 1]" begin
        for n in (1, 2, 50, 1000), k in 0:min(n, 20)
            (lo, hi) = pvalue_interval(k / n, n)
            @test 0 <= lo <= k / n <= hi <= 1
        end
    end

    @testset "it takes the pvalue of a result" begin
        results = randomized_tukey_hsd(Xoshiro(1), [0.1 0.4 0.7; 0.2 0.5 0.6;
                                                    0.15 0.45 0.8];
                                       trials=3000)
        for r in results
            (lo, hi) = pvalue_interval(r.pvalue, 3000)
            @test lo <= r.pvalue <= hi
        end
    end

    @testset "argument checks" begin
        @test_throws ArgumentError pvalue_interval(0.5, 0)
        @test_throws ArgumentError pvalue_interval(-0.1, 100)
        @test_throws ArgumentError pvalue_interval(1.1, 100)
        @test_throws ArgumentError pvalue_interval(0.5, 100; level=0)
        @test_throws ArgumentError pvalue_interval(0.5, 100; level=1)

        # not a count out of that many trials
        @test_throws ArgumentError pvalue_interval(0.123, 100)
        @test_throws r"not a count out of 100" pvalue_interval(0.123, 100)
    end
end

@testset "probability_below" begin
    @testset "values" begin
        # uniform prior; Beta(50, 952), Beta(491, 9511), Beta(4901, 95_101)
        @test probability_below(0.049, 1000, 0.05) ≈ 0.5231 atol=1e-4
        @test probability_below(0.049, 10_000, 0.05) ≈ 0.6673 atol=1e-4
        @test probability_below(0.049, 100_000, 0.05) ≈ 0.9260 atol=1e-4
    end

    @testset "it is the posterior distribution function" begin
        (lo, hi) = pvalue_interval(0.3, 500)
        @test probability_below(0.3, 500, hi) -
              probability_below(0.3, 500, lo) ≈ 0.95 atol=1e-8

        # no trial reached the difference: closed form 1 - (1 - alpha)^(n + 1)
        @test probability_below(0.0, 1000, 0.003) ≈ 1 - 0.997^1001
    end

    @testset "limits and order" begin
        @test probability_below(0.3, 500, 0) == 0
        @test probability_below(0.3, 500, 1) == 1
        alphas = 0:0.05:1
        p = [ probability_below(0.3, 500, a) for a in alphas ]
        @test issorted(p)
    end

    @testset "argument checks" begin
        @test_throws ArgumentError probability_below(0.5, 0, 0.05)
        @test_throws ArgumentError probability_below(0.123, 100, 0.05)
        @test_throws ArgumentError probability_below(0.5, 100, -0.01)
        @test_throws ArgumentError probability_below(0.5, 100, 1.01)
    end
end

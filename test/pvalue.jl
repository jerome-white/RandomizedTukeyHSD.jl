using Random
using SpecialFunctions: beta_inc
using StatsAPI

# log density of Beta(a, b), up to a constant
logdensity(x, a, b) = (a - 1) * log(x) + (b - 1) * log1p(-x)

# posterior probability between two points
mass(lower, upper, a, b) = beta_inc(a, b, upper)[1] - beta_inc(a, b, lower)[1]

@testset "MonteCarloPValue" begin
    @testset "from a count" begin
        p = MonteCarloPValue(49, 1000)
        @test (p.exceeding, p.trials) == (49, 1000)
        @test float(p) == 0.049
        @test pvalue(p) == 0.049
        @test StatsAPI.pvalue(p) === pvalue(p)

        # the ends
        @test float(MonteCarloPValue(0, 10)) == 0
        @test float(MonteCarloPValue(10, 10)) == 1
    end

    @testset "from a p-value" begin
        @test MonteCarloPValue(0.049, 1000) == MonteCarloPValue(49, 1000)
        @test MonteCarloPValue(0.0, 10) == MonteCarloPValue(0, 10)
        @test MonteCarloPValue(1.0, 10) == MonteCarloPValue(10, 10)
        @test MonteCarloPValue(Float32(0.5), 2) == MonteCarloPValue(1, 2)

        # an integer is a count, a float is a p-value
        @test MonteCarloPValue(1, 100).exceeding == 1
        @test MonteCarloPValue(1.0, 100).exceeding == 100

        # every value count / trials can take comes back, at large counts too
        for n in (1, 7, 64, 1000, 10_007, 1_000_000, 100_000_000)
            for k in unique((0, 1, n ÷ 3, n - 1, n))
                @test MonteCarloPValue(k / n, n) == MonteCarloPValue(k, n)
            end
        end
    end

    @testset "the pvalue of a result" begin
        trials = 3000
        responses = [0.1 0.4 0.7; 0.2 0.5 0.6; 0.15 0.45 0.8]
        results = randomized_tukey_hsd(Xoshiro(1), responses; trials=trials)
        for r in results
            p = MonteCarloPValue(r.pvalue, trials)
            @test p.trials == trials
            @test float(p) == r.pvalue
        end
    end

    @testset "argument checks" begin
        @test_throws ArgumentError MonteCarloPValue(1, 0)
        @test_throws ArgumentError MonteCarloPValue(-1, 10)
        @test_throws ArgumentError MonteCarloPValue(11, 10)
        @test_throws ArgumentError MonteCarloPValue(0.5, 0)
        @test_throws ArgumentError MonteCarloPValue(-0.1, 10)
        @test_throws ArgumentError MonteCarloPValue(1.1, 10)

        # not a count out of that many trials, however many trials there are
        @test_throws ArgumentError MonteCarloPValue(0.123, 100)
        @test_throws r"not a count out of 100" MonteCarloPValue(0.123, 100)
        @test_throws ArgumentError MonteCarloPValue(0.5 + 1e-7, 1_000_000)
    end
end

@testset "hdi" begin
    P = MonteCarloPValue

    @testset "values" begin
        # computed independently, by a grid search over the Beta posterior
        for (k, n, lower, upper) in ((49, 1000, 0.03675, 0.06356),
                                     (490, 10_000, 0.04488, 0.05335),
                                     (4900, 100_000, 0.04767, 0.05035),
                                     (3, 1000, 0.00071, 0.00792))
            (lo, hi) = hdi(P(k, n))
            @test lo ≈ lower atol=1e-5
            @test hi ≈ upper atol=1e-5
        end
    end

    @testset "it is the highest density interval" begin
        priors = ((1, 1), (0.5, 0.5), (2, 5), (1, 3))
        for (k, n) in ((1, 10), (5, 10), (49, 1000), (900, 1000), (7, 100))
            for level in (0.5, 0.9, 0.95, 0.99), prior in priors
                (lo, hi) = hdi(P(k, n); level=level, prior=prior)
                a = prior[1] + k
                b = prior[2] + n - k

                # holds the probability asked for
                @test mass(lo, hi, a, b) ≈ level atol=1e-8

                # equal density at both ends, the condition for the
                # shortest interval
                @test logdensity(lo, a, b) ≈ logdensity(hi, a, b) atol=1e-5

                # no interval of that probability on a grid is shorter
                shortest = Inf
                for tail in range(0, 1 - level, length=2001)[2:end-1]
                    x = RandomizedTukeyHSD._quantile(a, b, tail)
                    y = RandomizedTukeyHSD._quantile(a, b, tail + level)
                    shortest = min(shortest, y - x)
                end
                @test hi - lo <= shortest + 1e-9
            end
        end
    end

    @testset "no trial reached the difference" begin
        for n in (10, 1000, 100_000)
            (lo, hi) = hdi(P(0, n))
            @test lo == 0
            @test hi ≈ 1 - 0.05^(1 / (n + 1))
            @test mass(lo, hi, 1, n + 1) ≈ 0.95

            # about 3 / trials, the rule of three
            n >= 1000 && @test hi * n ≈ 3 atol=0.02
        end
    end

    @testset "every trial reached the difference" begin
        for n in (10, 1000)
            (lo, hi) = hdi(P(n, n))
            @test hi == 1
            @test lo ≈ 0.05^(1 / (n + 1))
        end
    end

    @testset "the prior" begin
        # Jeffreys' prior, from the same computation as the table in #55
        (lo, hi) = hdi(P(0, 1000); prior=(0.5, 0.5))
        @test lo == 0
        @test hi ≈ 0.00192 atol=1e-5
        (lo, hi) = hdi(P(49, 1000); prior=(0.5, 0.5))
        @test lo ≈ 0.03636 atol=1e-5
        @test hi ≈ 0.06305 atol=1e-5

        # the default is the uniform prior, and a prior moves the interval
        @test hdi(P(5, 100)) == hdi(P(5, 100); prior=(1, 1))
        @test hdi(P(5, 100); prior=(2, 8)) != hdi(P(5, 100))

        # a prior of (a, b) is the same as a - 1 more exceeding trials and
        # b - 1 more failing ones, from a uniform prior
        @test all(hdi(P(5, 100); prior=(3, 4)) .≈ hdi(P(7, 105)))

        # it matters less as the trials grow
        a = hdi(P(5000, 100_000); prior=(0.5, 0.5))
        b = hdi(P(5000, 100_000))
        @test all(isapprox.(a, b; atol=1e-5))
    end

    @testset "it is symmetric in successes and failures" begin
        (lo, hi) = hdi(P(300, 1000))
        (flipped_lo, flipped_hi) = hdi(P(700, 1000))
        @test flipped_lo ≈ 1 - hi
        @test flipped_hi ≈ 1 - lo
    end

    @testset "the interval narrows with trials and widens with level" begin
        width(p; level=0.95) = -(-(hdi(p; level=level)...))
        @test width(P(5000, 100_000)) < width(P(500, 10_000)) <
              width(P(50, 1000))
        @test width(P(500, 1000); level=0.9) < width(P(500, 1000)) <
              width(P(500, 1000); level=0.99)
    end

    @testset "it contains the pvalue and stays within [0, 1]" begin
        for n in (1, 2, 50, 1000), k in 0:min(n, 20)
            (lo, hi) = hdi(P(k, n))
            @test 0 <= lo <= k / n <= hi <= 1
        end
    end

    @testset "argument checks" begin
        @test_throws ArgumentError hdi(P(5, 100); level=0)
        @test_throws ArgumentError hdi(P(5, 100); level=1)
        @test_throws ArgumentError hdi(P(5, 100); prior=(0, 1))
        @test_throws ArgumentError hdi(P(5, 100); prior=(1, -1))
        @test_throws ArgumentError hdi(P(5, 100); prior=(1, 1, 1))
        @test_throws r"two positive numbers" hdi(P(5, 100); prior=1)
    end
end

@testset "probability_below" begin
    P = MonteCarloPValue

    @testset "values" begin
        # uniform prior; Beta(50, 952), Beta(491, 9511), Beta(4901, 95_101)
        @test probability_below(P(49, 1000), 0.05) ≈ 0.5231 atol=1e-4
        @test probability_below(P(490, 10_000), 0.05) ≈ 0.6673 atol=1e-4
        @test probability_below(P(4900, 100_000), 0.05) ≈ 0.9260 atol=1e-4

        # Jeffreys' prior gives 0.55 at 1000 trials
        @test probability_below(P(49, 1000), 0.05; prior=(0.5, 0.5)) ≈
              0.5492 atol=1e-4
    end

    @testset "it is the posterior distribution function" begin
        (lo, hi) = hdi(P(150, 500))
        @test probability_below(P(150, 500), hi) -
              probability_below(P(150, 500), lo) ≈ 0.95 atol=1e-8

        # no trial reached the difference: closed form 1 - (1 - alpha)^(n + 1)
        @test probability_below(P(0, 1000), 0.003) ≈ 1 - 0.997^1001
    end

    @testset "limits and order" begin
        p = P(150, 500)
        @test probability_below(p, 0) == 0
        @test probability_below(p, 1) == 1
        @test issorted([ probability_below(p, a) for a in 0:0.05:1 ])
    end

    @testset "argument checks" begin
        @test_throws ArgumentError probability_below(P(5, 100), -0.01)
        @test_throws ArgumentError probability_below(P(5, 100), 1.01)
        @test_throws ArgumentError probability_below(P(5, 100), 0.05;
                                                     prior=(0, 1))
    end
end

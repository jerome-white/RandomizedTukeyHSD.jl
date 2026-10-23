using Random
using StatsAPI

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

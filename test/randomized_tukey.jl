using Random

# 4 blocks x 3 treatments: the same values as data/tiny.csv
const RESPONSES = [
    0.10 0.40 0.70
    0.20 0.50 0.60
    0.15 0.45 0.80
    0.25 0.35 0.65
]
const TREATMENTS = ["A", "B", "C"]
const NTRIALS = 2000

@testset "_pairs" begin
    @test RandomizedTukeyHSD._pairs(2) == [(1, 2)]
    @test RandomizedTukeyHSD._pairs(4) ==
        [(1, 2), (1, 3), (1, 4), (2, 3), (2, 4), (3, 4)]
end

@testset "solve" begin
    Random.seed!(1)
    results = tukey(RESPONSES; trials=NTRIALS,
                    treatments=TREATMENTS)

    @testset "pairs" begin
        @test length(results) == 3
        @test [ (r.treatment1, r.treatment2) for r in results ] ==
            [("A", "B"), ("A", "C"), ("B", "C")]
    end

    @testset "deterministic columns" begin
        # A: 0.175, B: 0.425, C: 0.6875
        @test isapprox([ r.mean1 for r in results ], [0.175, 0.175, 0.425])
        @test isapprox([ r.mean2 for r in results ], [0.425, 0.6875, 0.6875])
        @test isapprox([ r.difference for r in results ],
                       [-0.25, -0.5125, -0.2625])
    end

    @testset "p-values" begin
        p = [ r.pvalue for r in results ]
        @test all(0 .<= p .<= 1)
        # counts are integers out of the number of trials
        @test all(x -> isinteger(x * NTRIALS), p)
        # same trial statistics for every pair, so a larger observed
        # difference can never have a larger p-value
        @test p[2] <= p[3] <= p[1]
        # (A,C) is truly rare (about 0.005): well below 0.05 for 2000 trials
        @test p[2] < 0.05
        @test p[1] > 0.1
    end

    @testset "identical treatments always get p = 1" begin
        X = hcat(RESPONSES, RESPONSES[:, 1])
        r = tukey(X; trials=100,
                  treatments=["A", "B", "C", "A2"])
        i = findfirst(x -> (x.treatment1, x.treatment2) == ("A", "A2"), r)
        @test r[i].difference == 0
        @test r[i].pvalue == 1
    end

    # with one block both arrangements of two treatments have the observed
    # range, so every one of the trials counts, at the lowest and highest
    # trial count alike
    @testset "a single block always gives p = 1" for trials in (1, 2, 100)
        r = tukey([0.1 0.3]; trials=trials)
        @test r[1].pvalue == 1
    end

    @testset "rng" begin
        run(rng) = tukey(rng, RESPONSES; trials=500)

        # the same state gives the same p-values; another seed does not
        @test run(Xoshiro(1)) == run(Xoshiro(1))
        @test run(Xoshiro(1)) != run(Xoshiro(2))
        @test run(MersenneTwister(1)) == run(MersenneTwister(1))

        # the default is the global generator
        Random.seed!(3)
        expected = tukey(RESPONSES; trials=500)
        Random.seed!(3)
        @test tukey(Random.default_rng(), RESPONSES;
                    trials=500) == expected

        # an explicit rng leaves the global one alone; before Julia 1.10
        # creating a task advances the creator's generator, whatever `rng`
        if VERSION >= v"1.10"
            Random.seed!(3)
            before = rand()
            Random.seed!(3)
            run(Xoshiro(1))
            @test rand() == before
        end
    end

    @testset "chunk size" begin
        run(chunk; trials=100) = tukey_chunked(
            Xoshiro(1), RESPONSES, trials, TREATMENTS, chunk
        )

        # the size only says how the trials are scheduled: every trial has
        # its own stream, so every size gives the results of the default,
        # from one trial per task to one task for all the trials and more
        reference = tukey(Xoshiro(1), RESPONSES; trials=500,
                          treatments=TREATMENTS)
        for chunk in (1, 7, 50, 64, 100, 499, 500, 501)
            @test run(chunk; trials=500) == reference
        end

        # whatever the size, p-values are counts out of the number of trials
        for chunk in (1, 7, 100, 101)
            p = [ r.pvalue for r in run(chunk) ]
            @test all(x -> 0 <= x <= 1 && isinteger(x * 100), p)
        end
    end

    @testset "default treatment names are column numbers" begin
        r = tukey(RESPONSES; trials=10)
        @test (r[1].treatment1, r[1].treatment2) == (1, 2)
    end

    @testset "input is not modified" begin
        X = copy(RESPONSES)
        tukey(X; trials=50)
        @test X == RESPONSES
    end

    @testset "NaN responses are rejected" begin
        X = copy(RESPONSES)
        X[2, 2] = NaN
        @test_throws ArgumentError tukey(X; trials=10)
        @test_throws r"1 NaN" tukey(X; trials=10)
    end

    @testset "argument checks" begin
        @test_throws ArgumentError tukey(RESPONSES; trials=0)
        @test_throws ArgumentError tukey(RESPONSES[:, 1:1];
                                         trials=10)
        @test_throws DimensionMismatch tukey(
            RESPONSES; trials=10, treatments=["A", "B"]
        )
    end
end

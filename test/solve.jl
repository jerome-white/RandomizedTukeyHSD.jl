using CommonSolve
using Random
using Tables

@testset "RandomizedTukeyProblem" begin
    responses = [0.10 0.40 0.70; 0.20 0.50 0.60; 0.15 0.45 0.80]

    @testset "from a matrix" begin
        problem = RandomizedTukeyProblem(responses; treatments=["A", "B", "C"])
        @test problem.responses === responses
        @test problem.treatments == ["A", "B", "C"]

        # the treatments default to the column numbers
        @test RandomizedTukeyProblem(responses).treatments == 1:3
    end

    @testset "from a table" begin
        wide = (a=responses[:, 1], b=responses[:, 2], c=responses[:, 3])
        problem = RandomizedTukeyProblem(wide)
        @test problem.responses == responses
        @test problem.treatments == [:a, :b, :c]

        tidy = (block=repeat(["b1", "b2", "b3"], 3),
                treatment=repeat(["A", "B", "C"], inner=3),
                response=vec(responses))
        problem = RandomizedTukeyProblem(tidy; block=:block,
                                         treatment=:treatment,
                                         response=:response)
        @test problem.responses == responses
        @test problem.treatments == ["A", "B", "C"]
    end

    @testset "it cannot be invalid" begin
        @test_throws ArgumentError RandomizedTukeyProblem(responses[:, 1:1])
        @test_throws r"at least two treatments" RandomizedTukeyProblem(
            responses[:, 1:1]
        )
        @test_throws DimensionMismatch RandomizedTukeyProblem(
            responses; treatments=["A", "B"]
        )

        nan = copy(responses)
        nan[2, 2] = NaN
        @test_throws r"1 NaN" RandomizedTukeyProblem(nan)

        # the positional form checks as well
        @test_throws ArgumentError RandomizedTukeyProblem(nan, 1:3)
    end
end

@testset "FixedTrials" begin
    @test FixedTrials(500).trials == 500
    @test FixedTrials(UInt8(5)).trials == 5
    @test_throws ArgumentError FixedTrials(0)
    @test_throws r"trials must be positive, got -3" FixedTrials(-3)
end

@testset "init, solve! and solve" begin
    responses = [0.10 0.40 0.70; 0.20 0.50 0.60; 0.15 0.45 0.80;
                 0.25 0.35 0.65]
    treatments = ["A", "B", "C"]
    problem = RandomizedTukeyProblem(responses; treatments=treatments)
    rule = FixedTrials(300)

    # what the computation gives for the same generator state
    expected = RandomizedTukeyHSD._randomized_tukey_hsd(
        Xoshiro(1), responses, 300, treatments
    )

    @testset "solve is solve!(init(...))" begin
        @test solve(problem, rule; rng=Xoshiro(1)) == expected
        @test solve!(init(problem, rule; rng=Xoshiro(1))) == expected
    end

    @testset "init keeps what it was given" begin
        rng = Xoshiro(1)
        run = init(problem, rule; rng=rng)
        @test run.problem === problem
        @test run.rule === rule
        @test run.rng === rng
    end

    @testset "the generator is advanced, the problem is not changed" begin
        rng = Xoshiro(1)
        first = solve(problem, rule; rng=rng)
        second = solve(problem, rule; rng=rng)
        @test first == expected
        @test second != first
        @test problem.responses == responses
    end

    @testset "the default generator is the global one" begin
        Random.seed!(3)
        seeded = solve(problem, rule; rng=Random.default_rng())
        Random.seed!(3)
        @test solve(problem, rule) == seeded
    end

    @testset "the result is a table" begin
        results = solve(problem, rule; rng=Xoshiro(1))
        @test Tables.istable(results)
        @test keys(first(results)) ==
              (:treatment1, :treatment2, :mean1, :mean2, :difference, :pvalue)
    end

    @testset "a table gives the same results as the matrix" begin
        table = (A=responses[:, 1], B=responses[:, 2], C=responses[:, 3])
        results = solve(RandomizedTukeyProblem(table), rule; rng=Xoshiro(1))
        @test [ r.pvalue for r in results ] == [ r.pvalue for r in expected ]
    end
end

@testset "the CommonSolve verbs are re-exported" begin
    @test RandomizedTukeyHSD.init === CommonSolve.init
    @test RandomizedTukeyHSD.solve === CommonSolve.solve
    @test RandomizedTukeyHSD.solve! === CommonSolve.solve!
    @test RandomizedTukeyHSD.step! === CommonSolve.step!

    # loading both, as with another package that re-exports them, does not
    # make the names ambiguous
    probe = Module()
    Core.eval(probe, :(using CommonSolve, RandomizedTukeyHSD))
    @test Core.eval(probe, :(solve)) === CommonSolve.solve
    @test Core.eval(probe, :(init)) === CommonSolve.init
end

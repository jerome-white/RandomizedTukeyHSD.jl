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
    expected = tukey_chunked(Xoshiro(1), responses, 300, treatments, 64)

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

@testset "step!, trials and pvalues" begin
    responses = [0.10 0.40 0.70; 0.20 0.50 0.60; 0.15 0.45 0.80;
                 0.25 0.35 0.65]
    problem = RandomizedTukeyProblem(responses; treatments=["A", "B", "C"])
    rule = FixedTrials(300)    # 4 full chunks of 64 and one of 44

    # counts of the whole run, in one go
    whole = init(problem, rule; rng=Xoshiro(1))
    solve!(whole)
    counts = [ p.exceeding for p in pvalues(whole) ]

    @testset "nothing is done at first" begin
        run = init(problem, rule; rng=Xoshiro(1))
        @test trials(run) == 0
        @test_throws ArgumentError pvalues(run)
        @test_throws r"no trials" pvalues(run)
    end

    @testset "step! advances by chunks" begin
        run = init(problem, rule; rng=Xoshiro(1))
        @test step!(run) === run
        @test trials(run) == 64
        step!(run, 2)
        @test trials(run) == 192
        step!(run, 2)
        @test trials(run) == 300    # the last chunk is shorter
    end

    @testset "in pieces or at once, the counts are the same" begin
        for pieces in ([5], [1, 4], [2, 3], [1, 1, 1, 1, 1], [4, 1])
            run = init(problem, rule; rng=Xoshiro(1))
            for n in pieces
                step!(run, n)
            end
            @test [ p.exceeding for p in pvalues(run) ] == counts
        end
    end

    @testset "solve! finishes what step! began" begin
        run = init(problem, rule; rng=Xoshiro(1))
        step!(run, 2)
        @test solve!(run) == solve(problem, rule; rng=Xoshiro(1))
        @test trials(run) == 300

        # nothing is left, so asking again changes nothing
        @test solve!(run) == solve(problem, rule; rng=Xoshiro(1))
        @test trials(run) == 300
    end

    @testset "pvalues are MonteCarloPValues that keep their trials" begin
        ps = pvalues(whole)
        @test ps isa Vector{MonteCarloPValue}
        @test length(ps) == 3
        @test all(p -> p.trials == 300, ps)

        results = solve(problem, rule; rng=Xoshiro(1))
        @test [ pvalue(p) for p in ps ] == [ r.pvalue for r in results ]

        # part way through, they carry the trials so far
        run = init(problem, rule; rng=Xoshiro(1))
        step!(run, 2)
        @test all(p -> p.trials == 128, pvalues(run))
    end

    @testset "one base seed is drawn by init" begin
        rng = Xoshiro(1)
        init(problem, rule; rng=rng)
        reference = Xoshiro(1)
        rand(reference, UInt64)
        @test rng == reference

        # stepping does not touch the generator
        rng = Xoshiro(1)
        run = init(problem, rule; rng=rng)
        state = copy(rng)
        solve!(run)
        @test rng == state
    end

    @testset "step! checks its argument" begin
        run = init(problem, rule; rng=Xoshiro(1))
        @test_throws ArgumentError step!(run, 0)
        @test_throws r"nchunks must be positive, got -1" step!(run, -1)
        @test_throws ArgumentError step!(run, 6)
        @test_throws r"6 chunks asked for, but 5 left" step!(run, 6)

        # a refused step leaves the run as it was
        @test trials(run) == 0
        step!(run, 4)
        @test_throws r"2 chunks asked for, but 1 left" step!(run, 2)
        @test trials(run) == 256
    end
end

# The buffers of a trial are made once, in `init`, and each task of a step
# uses its own (issue #97).
@testset "the scratch space of a run" begin
    # What a trial allocates is its random stream, a few hundred bytes. A
    # matrix made for every chunk of 64 trials would add 5000 bytes a trial
    # here (two 100 x 200 matrices of 8-byte numbers, over 64).
    @testset "a trial allocates no matrix" begin
        problem = RandomizedTukeyProblem(rand(Xoshiro(97), 200, 100))
        allocated(n) = @allocated solve(problem, FixedTrials(n);
                                        rng=Xoshiro(1))
        allocated(64)

        per_trial = (allocated(1280) - allocated(640)) / 640
        @test per_trial < 1500
    end

    # Steps reuse the scratch space of the steps before, and a step of one
    # chunk uses one task: the counts are those of a run made in one step.
    @testset "steps of any size give the counts of one step" begin
        problem = RandomizedTukeyProblem(rand(Xoshiro(98), 30, 6))
        whole = init(problem, FixedTrials(1000); rng=Xoshiro(3))
        step!(whole, 16)

        pieces = init(problem, FixedTrials(1000); rng=Xoshiro(3))
        for nchunks in (1, 1, 2, 5, 7)
            step!(pieces, nchunks)
        end

        @test trials(pieces) == trials(whole) == 1000
        @test pieces.exceeding == whole.exceeding
    end

    # A step with too few trials to give every thread a chunk is shared in
    # smaller pieces (issue #105), and the last chunk of a rule can have
    # fewer trials than there are threads. The counts are those of the same
    # trials taken as one chunk of 67.
    @testset "a short step gives the counts of a long one" begin
        problem = RandomizedTukeyProblem(rand(Xoshiro(105), 30, 6))
        rule = FixedTrials(67)    # a chunk of 64 and one of 3

        short = init(problem, rule; rng=Xoshiro(5))
        step!(short)
        step!(short)

        long = RandomizedTukeyHSD._init(problem, rule, Xoshiro(5), 67)
        step!(long)

        @test trials(short) == trials(long) == 67
        @test short.exceeding == long.exceeding
    end

    # The responses are kept as 64-bit floats, whatever they arrive as.
    @testset "integer responses" begin
        responses = rand(Xoshiro(99), 0:9, 12, 4)
        asis = solve(RandomizedTukeyProblem(responses), FixedTrials(500);
                     rng=Xoshiro(4))
        floats = solve(RandomizedTukeyProblem(Float64.(responses)),
                       FixedTrials(500); rng=Xoshiro(4))

        @test asis == floats
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

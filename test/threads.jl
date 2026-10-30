using Random

# p-values for a fixed seed, computed in a fresh Julia with `threads` threads
function pvalues_with(threads)
    code = """
    using Random, RandomizedTukeyHSD
    responses = rand(Xoshiro(7), 30, 6)
    Random.seed!(11)
    problem = RandomizedTukeyProblem(responses)
    results = solve(problem, FixedTrials(1000))
    println(join([ r.pvalue for r in results ], ","))
    results = solve(problem, FixedTrials(1000); rng=Xoshiro(11))
    println(join([ r.pvalue for r in results ], ","))
    run = init(problem, FixedTrials(1000); rng=Xoshiro(11))
    step!(run, 3)
    println(join([ p.exceeding for p in pvalues(run) ], ","))
    step!(run, 5)
    println(join([ p.exceeding for p in pvalues(run) ], ","))
    struct Collect
        seen::Vector{Any}
    end
    RandomizedTukeyHSD.emit(m::Collect, c) = push!(m.seen, c)
    monitor = Collect(Any[])
    solve(problem, FixedTrials(1000); rng=Xoshiro(11), monitor=monitor,
          every=200)
    println(join([ join([ p.exceeding for p in c.pvalues ], ",")
                   for c in monitor.seen ], ";"))
    """
    julia = Base.julia_cmd()
    project = dirname(Base.active_project())
    cmd = `$julia --startup-file=no --project=$project -t $threads -e $code`

    return readchomp(cmd)
end

@testset "fixed seed" begin
    responses = rand(Xoshiro(7), 30, 6)

    @testset "repeats in one process" begin
        Random.seed!(5)
        first = tukey(responses; trials=1000)
        Random.seed!(5)
        second = tukey(responses; trials=1000)
        @test first == second
    end

    # 1000 trials is not a multiple of the chunk size
    @testset "same p-values at any thread count" begin
        expected = pvalues_with(1)
        @test !isempty(expected)
        for threads in (2, 4)
            @test pvalues_with(threads) == expected
        end
    end
end

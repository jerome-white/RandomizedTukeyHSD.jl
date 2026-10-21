using Random

# p-values for a fixed seed, computed in a fresh Julia with `threads` threads
function pvalues_with(threads)
    code = """
    using Random, RandomizedTukeyHSD
    scores = rand(Xoshiro(7), 30, 6)
    Random.seed!(11)
    results = randomized_tukey_hsd(scores; B=1000)
    println(join([ r.pvalue for r in results ], ","))
    """
    julia = Base.julia_cmd()
    project = dirname(Base.active_project())
    cmd = `$julia --startup-file=no --project=$project -t $threads -e $code`

    return readchomp(cmd)
end

@testset "fixed seed" begin
    scores = rand(Xoshiro(7), 30, 6)

    @testset "repeats in one process" begin
        Random.seed!(5)
        first = randomized_tukey_hsd(scores; B=1000)
        Random.seed!(5)
        second = randomized_tukey_hsd(scores; B=1000)
        @test first == second
    end

    # B = 1000 is not a multiple of the chunk size
    @testset "same p-values at any thread count" begin
        expected = pvalues_with(1)
        @test !isempty(expected)
        for threads in (2, 4)
            @test pvalues_with(threads) == expected
        end
    end
end

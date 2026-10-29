using Random
using Statistics

# The random stream of every trial depends on the base seed and the number of
# the trial alone (issue #34).
@testset "trial streams" begin
    stream = RandomizedTukeyHSD._stream
    base = rand(Xoshiro(1), UInt64)

    @testset "a stream is a function of the base and the trial" begin
        draw(base, i) = rand(stream(base, i), UInt64, 4)

        @test draw(base, 5) == draw(base, 5)
        @test draw(base, 5) != draw(base, 6)
        @test draw(base, 5) != draw(base + 1, 5)
    end

    @testset "trials do not share state words" begin
        # four words per trial, for consecutive trials: all different
        words = UInt64[]
        for i in 1:1000
            g = stream(base, i)
            append!(words, (g.s0, g.s1, g.s2, g.s3))
        end
        @test length(unique(words)) == length(words)
    end

    @testset "neighbouring trials are not correlated" begin
        n = 100_000
        draws = Matrix{Float64}(undef, n, 3)
        for i in 1:n
            g = stream(base, i)
            draws[i, :] = rand(g, 3)
        end

        # uniform on [0, 1): mean 1/2, variance 1/12
        @test all(abs.(mean(draws; dims=1) .- 0.5) .< 5 * sqrt(1 / 12 / n))

        # correlation of trial i with trial i + 1, for each draw, and of
        # the draws of one trial with each other
        limit = 5 / sqrt(n)
        for j in 1:3
            @test abs(cor(draws[1:end-1, j], draws[2:end, j])) < limit
        end
        @test abs(cor(draws[:, 1], draws[:, 2])) < limit
        @test abs(cor(draws[:, 2], draws[:, 3])) < limit

        # indices that differ by a power of two, where bad mixing shows
        for lag in (2, 4, 64, 1024)
            @test abs(cor(draws[1:end-lag, 1], draws[1+lag:end, 1])) < limit
        end
    end
end
